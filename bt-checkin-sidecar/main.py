import os
from typing import Dict
from fastapi import FastAPI, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
import aiosqlite
from pathlib import Path

# Configuration
API_KEY = os.getenv("API_KEY", "change-me")
DB_PATH = os.getenv("DB_PATH", "/app/data/bt_checkin.db")
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*")

app = FastAPI(title="BT Check-in Sidecar", version="1.0.0")

# CORS
origins = [o.strip() for o in ALLOWED_ORIGINS.split(",")] if ALLOWED_ORIGINS else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def get_db():
    if not hasattr(app.state, "db"):
        # Ensure parent directory exists
        Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
        app.state.db = await aiosqlite.connect(DB_PATH)
        await app.state.db.execute(
            """
            CREATE TABLE IF NOT EXISTS bt_checkin (
                class_id TEXT PRIMARY KEY,
                enabled INTEGER NOT NULL
            )
            """
        )
        await app.state.db.execute(
            """
            CREATE TABLE IF NOT EXISTS bt_checkin_present (
                class_id TEXT NOT NULL,
                email TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (class_id, email)
            )
            """
        )
        await app.state.db.commit()
    return app.state.db


async def require_api_key(x_api_key: str = Header(None)):
    if API_KEY and API_KEY != "change-me":
        if x_api_key is None or x_api_key != API_KEY:
            raise HTTPException(status_code=401, detail="Invalid API key")
    # If API_KEY is unset or default, allow (for local/dev)
    return True


@app.on_event("startup")
async def startup():
    await get_db()


@app.on_event("shutdown")
async def shutdown():
    if hasattr(app.state, "db"):
        await app.state.db.close()


@app.put("/bt-checkin/{class_id}")
async def set_bt_checkin(
    class_id: str,
    payload: Dict,
    _=Depends(require_api_key),
    db=Depends(get_db),
):
    enabled = bool(payload.get("enabled", False))
    await db.execute(
        """
        INSERT INTO bt_checkin (class_id, enabled)
        VALUES (?, ?)
        ON CONFLICT(class_id) DO UPDATE SET enabled=excluded.enabled
        """,
        (class_id, int(enabled)),
    )
    await db.commit()
    return {"class_id": class_id, "enabled": enabled}


@app.get("/bt-checkin/{class_id}")
async def get_bt_checkin(
    class_id: str,
    _=Depends(require_api_key),
    db=Depends(get_db),
):
    cur = await db.execute(
        "SELECT enabled FROM bt_checkin WHERE class_id = ?", (class_id,)
    )
    row = await cur.fetchone()
    return {"class_id": class_id, "enabled": bool(row[0]) if row else False}


@app.post("/bt-checkin/{class_id}/present")
async def set_bt_present(
    class_id: str,
    payload: Dict,
    _=Depends(require_api_key),
    db=Depends(get_db),
):
    email = payload.get("email")
    present = bool(payload.get("present", True))
    if not email:
        raise HTTPException(status_code=400, detail="email is required")

    if present:
        await db.execute(
            """
            INSERT INTO bt_checkin_present (class_id, email, updated_at)
            VALUES (?, ?, strftime('%s','now'))
            ON CONFLICT(class_id, email) DO UPDATE SET updated_at=strftime('%s','now')
            """,
            (class_id, email),
        )
    else:
        await db.execute(
            "DELETE FROM bt_checkin_present WHERE class_id = ? AND email = ?",
            (class_id, email),
        )
    await db.commit()
    return {"class_id": class_id, "email": email, "present": present}


@app.get("/bt-checkin/{class_id}/present")
async def get_bt_present(
    class_id: str,
    _=Depends(require_api_key),
    db=Depends(get_db),
):
    cur = await db.execute(
        "SELECT email FROM bt_checkin_present WHERE class_id = ?", (class_id,)
    )
    rows = await cur.fetchall()
    emails = [r[0] for r in rows] if rows else []
    return {"class_id": class_id, "present": emails}


