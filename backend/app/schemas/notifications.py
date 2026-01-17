"""
Pydantic schemas for notifications.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID


class NotificationBase(BaseModel):
    """Base notification schema."""
    title: str = Field(..., description="Notification title")
    message: str = Field(..., description="Notification message")
    notification_type: str = Field(..., description="Type: 'attendance', 'manual', 'system'")


class NotificationCreate(NotificationBase):
    """Schema for creating a notification."""
    student_id: Optional[UUID] = Field(None, description="Student ID (optional, for admin)")
    attendance_threshold: Optional[float] = Field(None, description="Attendance threshold for attendance-based notifications")


class NotificationResponse(NotificationBase):
    """Schema for notification response."""
    id: UUID
    student_id: UUID
    attendance_threshold: Optional[float] = None
    is_read: bool
    created_at: datetime
    read_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class NotificationReadRequest(BaseModel):
    """Schema for marking notification as read."""
    notification_id: UUID


class SendNotificationToStudentsRequest(BaseModel):
    """Schema for sending notifications to multiple students based on attendance."""
    title: str
    message: str
    attendance_threshold: float = Field(..., description="Send to students with attendance <= this threshold")
    class_id: Optional[UUID] = Field(None, description="Optional: limit to specific class")


