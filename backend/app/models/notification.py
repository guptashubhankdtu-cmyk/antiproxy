"""
Notification model for student notifications.
"""
from sqlalchemy import Column, String, Text, DateTime, Boolean, ForeignKey, Integer, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db import Base


class Notification(Base):
    """
    Notifications sent to students based on attendance percentage or manually by admin.
    """
    __tablename__ = "notifications"
    
    notification_id = Column(Integer, primary_key=True, autoincrement=True)
    student_id = Column(Integer, ForeignKey("students.student_id", ondelete="CASCADE"), nullable=True)
    sender_user_id = Column(Integer, ForeignKey("users.user_id"), nullable=True)
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    notification_type = Column(String(50), nullable=True)  # ATTENDANCE, MANUAL, SYSTEM
    target_role = Column(String(20), nullable=True)        # ALL, TEACHER, HOD, ADMIN, STUDENT
    attendance_threshold = Column(Float, nullable=True)    # For attendance-based notifications
    is_read = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    read_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    student = relationship("Student", back_populates="notifications")
    sender = relationship("User")
    
    def __repr__(self):
        return f"<Notification(id={self.id}, student_id={self.student_id}, title='{self.title}', is_read={self.is_read})>"


