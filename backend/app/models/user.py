"""
User and AllowedEmail models.
"""
import enum
import uuid
from sqlalchemy import Column, String, Enum as SQLEnum, DateTime, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db import Base


class UserRole(str, enum.Enum):
    """User role enumeration."""
    ADMIN = "ADMIN"
    HOD = "HOD"
    TEACHER = "TEACHER"
    STUDENT = "STUDENT"


class AllowedEmail(Base):
    """
    Whitelist of emails allowed to access the system.
    Only users with emails in this table can log in.
    """
    __tablename__ = "allowed_emails"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(Text, unique=True, nullable=False, index=True)
    name = Column(Text)
    # Stored as text to avoid enum mismatch issues; normalize in code
    role = Column(Text, nullable=False, default=UserRole.TEACHER.value)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class AllowedStudentEmail(Base):
    """
    Whitelist of student emails allowed to use the student app.
    Keeps both personal and DTU emails plus roll/name metadata.
    """
    __tablename__ = "allowed_student_emails"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(Text, unique=True, nullable=True, index=True)
    dtu_email = Column(Text, unique=True, nullable=True, index=True)
    roll_no = Column(Text)
    name = Column(Text)
    program = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())


class User(Base):
    """
    System users (teachers and admins) who operate the attendance system.
    Not for students - students are tracked separately.
    """
    __tablename__ = "users"
    
    user_id = Column(Integer, primary_key=True, autoincrement=True)
    uuid = Column(UUID(as_uuid=True), unique=True, nullable=False, default=uuid.uuid4)
    email = Column(Text, unique=True, nullable=False, index=True)
    name = Column(Text, nullable=False)
    password_hash = Column(String(64), nullable=False, default="")
    role = Column(SQLEnum(UserRole, values_callable=lambda x: [e.value for e in x]), nullable=False, default=UserRole.TEACHER)
    department = Column(Text)
    employee_id = Column(Text)
    last_login_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    
    # Relationships
    classes = relationship("Class", back_populates="teacher")
    attendance_sessions = relationship("AttendanceSession", back_populates="teacher")
