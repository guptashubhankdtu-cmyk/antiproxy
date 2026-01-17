"""
Attendance session and status models.
"""
import enum
import uuid
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Date, Boolean, Numeric, UniqueConstraint, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy import Enum as SQLEnum

from app.db import Base


class AttendanceStatus(str, enum.Enum):
    """Attendance status enumeration."""
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    LATE = "LATE"
    EXCUSED = "EXCUSED"


class AttendanceSession(Base):
    """
    One attendance-taking event for a class on a specific date.
    e.g., "IT307-D attendance on 2025-10-08"
    """
    __tablename__ = "sessions"
    
    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id", ondelete="CASCADE"), nullable=True)
    course_id = Column(Integer, ForeignKey("courses.course_id"), nullable=True)
    section_id = Column(Integer, ForeignKey("sections.section_id"), nullable=True)
    teacher_user_id = Column(Integer, ForeignKey("users.user_id"), nullable=True)
    session_date = Column(Date, nullable=False)
    start_time = Column(String, nullable=True)
    end_time = Column(String, nullable=True)
    topic = Column(Text, nullable=True)
    processed_image_url = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Prevent duplicate sessions for same class on same date
    __table_args__ = (
        UniqueConstraint('class_id', 'session_date', name='uq_sessions_class_date'),
    )
    
    # Relationships
    class_obj = relationship("Class", back_populates="attendance_sessions")
    teacher = relationship("User", back_populates="attendance_sessions")
    statuses = relationship("AttendanceStatusRecord", back_populates="session", cascade="all, delete-orphan")


class AttendanceStatusRecord(Base):
    """
    Per-student attendance record for a specific session.
    This replaces the Firestore "studentStatuses" map.
    """
    __tablename__ = "attendance"
    
    attendance_id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.session_id", ondelete="CASCADE"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.student_id"), nullable=False)
    status = Column(SQLEnum(AttendanceStatus, values_callable=lambda x: [e.value for e in x]), nullable=False, default=AttendanceStatus.ABSENT)
    marked_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    recognized_by_ai = Column(Boolean, nullable=False, default=False)
    similarity_score = Column(Numeric(5, 2))  # AI confidence percentage or similarity
    
    __table_args__ = (
        UniqueConstraint('session_id', 'student_id', name='uq_attendance_session_student'),
    )
    
    # Relationships
    session = relationship("AttendanceSession", back_populates="statuses")
    student = relationship("Student", back_populates="attendance_statuses")
