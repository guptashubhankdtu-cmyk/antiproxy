"""
Student-related Pydantic schemas.
"""
from pydantic import BaseModel, Field
from typing import List, Optional


class ScheduleEntry(BaseModel):
    """Schedule entry for a class."""
    dayOfWeek: int  # 1=Monday, 7=Sunday
    startTime: str  # HH:MM format
    endTime: str    # HH:MM format


class StudentClassInfo(BaseModel):
    """Class information for student view."""
    id: str
    code: str
    name: str
    section: str | None = None
    teacherType: Optional[str] = None
    ltpPattern: Optional[str] = None
    practicalGroup: Optional[str] = None
    teacherName: str
    teacherEmail: str
    schedule: List[ScheduleEntry] = []
    
    class Config:
        from_attributes = True


class AttendanceRecord(BaseModel):
    """Single attendance record for a student."""
    date: str  # ISO date format
    status: str  # PRESENT, ABSENT, LATE, EXCUSED
    recognizedByAi: bool = False
    similarityScore: Optional[float] = None


class StudentAttendanceStats(BaseModel):
    """Attendance statistics for a student in a specific class."""
    classId: str
    className: str
    classCode: str
    section: str
    studentName: str
    rollNo: str
    presentCount: int
    absentCount: int
    lateCount: int
    excusedCount: int
    totalCount: int
    percentage: float
    records: List[AttendanceRecord] = []
    
    class Config:
        from_attributes = True
