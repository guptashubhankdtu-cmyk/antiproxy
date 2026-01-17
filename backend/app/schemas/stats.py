"""
Statistics-related Pydantic schemas.
"""
from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional


class StudentAttendanceSummary(BaseModel):
    """Summary of a student's attendance in a class."""
    student_id: UUID = Field(alias="studentId")
    roll_no: str = Field(alias="rollNo")
    name: str = Field(alias="studentName")
    present_count: int = Field(default=0, alias="presentCount")
    absent_count: int = Field(default=0, alias="absentCount")
    late_count: int = Field(default=0, alias="lateCount")
    excused_count: int = Field(default=0, alias="excusedCount")
    total_count: int = Field(default=0, alias="totalCount")
    percentage: float = Field(default=0.0)
    
    class Config:
        populate_by_name = True
