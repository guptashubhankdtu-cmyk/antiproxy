"""
Class-related Pydantic schemas.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional, List
from datetime import datetime, date, time


class ScheduleInfo(BaseModel):
    """Weekly schedule information."""
    day_of_week: int = Field(..., alias="dayOfWeek", ge=1, le=7)
    start: str  # Time as string "HH:MM"
    end: str    # Time as string "HH:MM"
    
    class Config:
        populate_by_name = True


class RescheduleInfo(BaseModel):
    """Reschedule information."""
    original_date: str = Field(..., alias="originalDate")
    original_start_time: str = Field(..., alias="originalStartTime")
    original_end_time: str = Field(..., alias="originalEndTime")
    rescheduled_date: str = Field(..., alias="rescheduledDate")
    rescheduled_start_time: str = Field(..., alias="rescheduledStartTime")
    rescheduled_end_time: str = Field(..., alias="rescheduledEndTime")
    reason: Optional[str] = None
    
    class Config:
        populate_by_name = True


class StudentInClass(BaseModel):
    """Student information within a class roster."""
    studentId: int = Field(..., alias="studentId")
    studentUuid: Optional[UUID] = Field(None, alias="studentUuid")
    universityRoll: str
    rollNo: Optional[str] = None
    name: str
    photoUrl: Optional[str] = None
    program: Optional[str] = None
    batch: Optional[str] = None
    department: Optional[str] = None
    spCode: Optional[str] = None
    semester: Optional[int] = None
    email: Optional[str] = None
    dtuEmail: Optional[str] = None
    phone: Optional[str] = None
    
    class Config:
        populate_by_name = True
        from_attributes = True


class ClassResponse(BaseModel):
    """Class information response."""
    id: UUID
    code: str
    name: str
    section: Optional[str] = None
    teacher_type: Optional[str] = Field(None, alias="teacherType")
    ltp_pattern: Optional[str] = Field(None, alias="ltpPattern")
    practical_group: Optional[str] = Field(None, alias="practicalGroup")
    teacher_id: Optional[int] = Field(None, alias="teacherId")
    teacher_uuid: Optional[UUID] = Field(None, alias="teacherUuid")
    schedule: List[ScheduleInfo] = []
    reschedules: List[RescheduleInfo] = []
    students: List[StudentInClass] = []
    created_at: datetime = Field(..., alias="createdAt")
    updated_at: datetime = Field(..., alias="updatedAt")
    
    class Config:
        populate_by_name = True
        from_attributes = True


class StudentInput(BaseModel):
    """Student input for adding to class."""
    university_roll: str = Field(..., alias="universityRoll")
    roll_no: Optional[str] = Field(None, alias="rollNo")
    name: str
    photo_url: Optional[str] = Field(None, alias="photoUrl")
    program: Optional[str] = None
    batch: Optional[str] = None
    department: Optional[str] = None
    sp_code: Optional[str] = Field(None, alias="spCode")
    semester: Optional[int] = None
    status: Optional[str] = None
    duration: Optional[str] = None
    email: Optional[str] = None
    dtu_email: Optional[str] = Field(None, alias="dtuEmail")
    phone: Optional[str] = None
    
    class Config:
        populate_by_name = True


class UpdateStudentsRequest(BaseModel):
    """Request to update students in a class."""
    students: List[StudentInput]
