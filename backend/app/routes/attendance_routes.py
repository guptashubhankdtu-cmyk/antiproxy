"""
Attendance routes.
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional
from uuid import UUID

from app.db import get_db
from app.auth.dependencies import get_current_user, require_teacher_or_admin, UserContext
from app.schemas.attendance import (
    CreateSessionRequest,
    SessionResponse,
    UpdateStatusesRequest
)
from app.services.attendance_service import (
    create_attendance_session,
    update_attendance_statuses,
    get_attendance_sessions
)

router = APIRouter(prefix="/attendance", tags=["Attendance"])


@router.post("/sessions")
async def create_session(
    request: CreateSessionRequest,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Create an attendance session for a class on a specific date.
    
    - Returns existing session if one already exists for that class/date
    - Only class owner or admin can create sessions
    """
    session = create_attendance_session(
        db,
        request.class_id,
        current_user.user_id,
        current_user.role,
        request.session_date,
        request.processed_image_url
    )
    
    return session


@router.put("/sessions/{session_id}/statuses")
async def update_statuses(
    session_id: UUID,
    request: UpdateStatusesRequest,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Update attendance statuses for students in a session.
    
    - Only session owner or admin can update statuses
    - Validates that students are enrolled in the class
    - Upserts status records
    """
    statuses = update_attendance_statuses(
        db,
        session_id,
        current_user.user_id,
        current_user.role,
        request.updates
    )
    
    return {"statuses": statuses}


@router.get("/sessions")
async def get_sessions(
    class_id: UUID = Query(..., alias="classId"),
    from_date: Optional[str] = Query(None, alias="from"),
    to_date: Optional[str] = Query(None, alias="to"),
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Get attendance sessions for a class within a date range.
    
    - Only class owner or admin can view sessions
    - Returns sessions with all student statuses
    """
    sessions = get_attendance_sessions(
        db,
        class_id,
        current_user.user_id,
        current_user.role,
        from_date,
        to_date
    )
    
    return sessions
