"""
Student model.
"""
from sqlalchemy import Column, String, Text, DateTime, Integer, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.db import Base


class Student(Base):
    """
    Students whose attendance is tracked.
    Students are not app users unless explicitly added to users table.
    """
    __tablename__ = "students"
    
    student_id = Column(Integer, primary_key=True, autoincrement=True)
    uuid = Column(UUID(as_uuid=True), unique=True, nullable=False, default=uuid.uuid4)
    university_roll = Column(Text, unique=True, nullable=False, index=True)
    roll_no = Column(Text, unique=True, nullable=True, index=True)
    name = Column(Text, nullable=False)
    photo_url = Column(Text)
    program = Column(Text)
    batch = Column(Text)
    department = Column(Text)
    sp_code = Column(Text)
    semester = Column(Integer)
    status = Column(Text)
    duration = Column(Text)
    email = Column(Text)
    dtu_email = Column(Text)
    phone = Column(Text)
    section_id = Column(Integer, ForeignKey("sections.section_id"), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Relationships
    class_enrollments = relationship("ClassStudent", back_populates="student")
    attendance_statuses = relationship("AttendanceStatusRecord", back_populates="student")
    notifications = relationship("Notification", back_populates="student", cascade="all, delete-orphan")
