"""
Class and related models (schedules, reschedules, class_students).
"""
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, UniqueConstraint, Time, Date, Integer, SmallInteger, CheckConstraint, BigInteger
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.db import Base


class Class(Base):
    """
    A class is one subject-section a teacher is responsible for.
    e.g., "IT307 - Deep Learning - Section D"
    """
    __tablename__ = "classes"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(Text, nullable=False)
    name = Column(Text, nullable=False)
    section = Column(Text, nullable=True)
    ltp_pattern = Column(Text)  # e.g., "3-1-0"
    teacher_type = Column(Text)  # 'lecture' or 'practical'
    practical_group = Column(Text)
    teacher_user_id = Column(Integer, ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
    
    # Unique constraint: same teacher can't have duplicate class for same course/section
    __table_args__ = (
        UniqueConstraint('teacher_user_id', 'code', 'section', name='uq_teacher_class_section'),
    )
    
    # Relationships
    teacher = relationship("User", back_populates="classes")
    schedules = relationship("ClassSchedule", back_populates="class_obj", cascade="all, delete-orphan")
    reschedules = relationship("ClassReschedule", back_populates="class_obj", cascade="all, delete-orphan")
    student_enrollments = relationship("ClassStudent", back_populates="class_obj", cascade="all, delete-orphan")
    attendance_sessions = relationship("AttendanceSession", back_populates="class_obj", cascade="all, delete-orphan")


class ClassSchedule(Base):
    """
    Weekly recurring schedule for a class.
    e.g., "Every Monday 10:00-11:00"
    """
    __tablename__ = "class_schedules"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    day_of_week = Column(SmallInteger, nullable=False)  # 1=Monday, 7=Sunday
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    
    __table_args__ = (
        UniqueConstraint('class_id', 'day_of_week', name='uq_class_schedule_day'),
        CheckConstraint('day_of_week >= 1 AND day_of_week <= 7', name='ck_day_of_week_range'),
    )
    
    # Relationships
    class_obj = relationship("Class", back_populates="schedules")


class ClassReschedule(Base):
    """
    One-time schedule changes.
    e.g., "Wednesday 10:00 lecture moved to Friday 14:00"
    """
    __tablename__ = "class_reschedules"
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    original_date = Column(Date, nullable=False)
    original_start_time = Column(Time, nullable=False)
    original_end_time = Column(Time, nullable=False)
    rescheduled_date = Column(Date, nullable=False)
    rescheduled_start_time = Column(Time, nullable=False)
    rescheduled_end_time = Column(Time, nullable=False)
    reason = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Relationships
    class_obj = relationship("Class", back_populates="reschedules")


class ClassStudent(Base):
    """
    Many-to-many relationship: which students are enrolled in which classes.
    This is the roster.
    """
    __tablename__ = "class_students"
    
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id", ondelete="CASCADE"), primary_key=True)
    student_id = Column(Integer, ForeignKey("students.student_id"), primary_key=True)
    added_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Relationships
    class_obj = relationship("Class", back_populates="student_enrollments")
    student = relationship("Student", back_populates="class_enrollments")
