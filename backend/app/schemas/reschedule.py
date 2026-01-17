"""
Pydantic schemas for class reschedule endpoints.
"""
from datetime import date, time
from typing import Optional
from pydantic import BaseModel, Field


class RescheduleCreate(BaseModel):
    """Request body for creating a class reschedule."""
    original_date: date = Field(..., description="Original scheduled date")
    rescheduled_date: date = Field(..., description="New rescheduled date")
    rescheduled_start_time: time = Field(..., description="New start time")
    rescheduled_end_time: time = Field(..., description="New end time")
    reason: Optional[str] = Field(None, description="Reason for rescheduling")


class RescheduleUpdate(BaseModel):
    """Request body for updating a reschedule."""
    rescheduled_date: Optional[date] = None
    rescheduled_start_time: Optional[time] = None
    rescheduled_end_time: Optional[time] = None
    reason: Optional[str] = None


class RescheduleResponse(BaseModel):
    """Response for reschedule operations."""
    id: str
    class_id: str
    original_date: date
    original_start_time: time
    original_end_time: time
    rescheduled_date: date
    rescheduled_start_time: time
    rescheduled_end_time: time
    reason: Optional[str]
    created_at: str

    class Config:
        from_attributes = True
