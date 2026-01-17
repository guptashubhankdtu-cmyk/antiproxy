"""
Attendance-related Pydantic schemas.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional, List
from datetime import date, datetime


class CreateSessionRequest(BaseModel):
    """Request to create an attendance session."""
    class_id: UUID = Field(..., alias="classId")
    session_date: str = Field(..., alias="sessionDate")  # "YYYY-MM-DD"
    processed_image_url: Optional[str] = Field(None, alias="processedImageUrl")
    
    class Config:
        populate_by_name = True


class SessionResponse(BaseModel):
    """Response for attendance session."""
    session_id: UUID = Field(..., alias="sessionId")
    class_id: UUID = Field(..., alias="classId")
    session_date: str = Field(..., alias="sessionDate")
    teacher_id: UUID = Field(..., alias="teacherId")
    processed_image_url: Optional[str] = Field(None, alias="processedImageUrl")
    created_at: datetime = Field(..., alias="createdAt")
    
    class Config:
        populate_by_name = True
        from_attributes = True


class StatusUpdate(BaseModel):
    """Individual student status update."""
    roll_no: str = Field(..., alias="rollNo")
    status: str  # "present", "absent", "late", "excused"
    recognized_by_ai: bool = Field(False, alias="recognizedByAi")
    similarity_score: Optional[float] = Field(None, alias="similarityScore")
    
    class Config:
        populate_by_name = True


class UpdateStatusesRequest(BaseModel):
    """Request to update attendance statuses for a session."""
    updates: List[StatusUpdate]


class StudentStatusResponse(BaseModel):
    """Response for a single student's attendance status."""
    roll_no: str = Field(..., alias="rollNo")
    name: str
    status: str
    recognized_by_ai: bool = Field(..., alias="recognizedByAi")
    similarity_score: Optional[float] = Field(None, alias="similarityScore")
    
    class Config:
        populate_by_name = True
