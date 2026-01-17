"""
AIMS Attendance Backend - Main FastAPI Application
"""
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging

from app.config import settings
from app.db import engine, Base
from app.routes import (
    auth_routes,
    user_routes,
    class_routes,
    attendance_routes,
    stats_routes,
    reschedule_routes,
    storage,
    student_routes,
    notification_routes,
    leaderboard_routes,
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan events for the FastAPI application.
    """
    # Startup
    logger.info("Starting AIMS Attendance Backend...")
    logger.info(f"Debug mode: {settings.debug}")
    
    # Create tables (for development; in production use Alembic migrations)
    # Base.metadata.create_all(bind=engine)
    
    yield
    
    # Shutdown
    logger.info("Shutting down AIMS Attendance Backend...")


# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    description="Production-grade backend for AIMS attendance tracking system",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Global exception handler for unhandled errors.
    """
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )


# Health check endpoint
@app.get("/health")
async def health_check():
    """
    Health check endpoint.
    """
    return {"status": "healthy", "service": "AIMS Attendance Backend"}


# Include routers
app.include_router(auth_routes.router)
app.include_router(user_routes.router)
app.include_router(class_routes.router)
app.include_router(attendance_routes.router)
app.include_router(stats_routes.router)
app.include_router(reschedule_routes.router)
app.include_router(storage.router)
app.include_router(student_routes.router)
app.include_router(notification_routes.router)
app.include_router(leaderboard_routes.router)


# Root endpoint
@app.get("/")
async def root():
    """
    Root endpoint with API information.
    """
    return {
        "message": "AIMS Attendance Backend API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health"
    }


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )
