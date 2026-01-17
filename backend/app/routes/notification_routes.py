"""
Notification routes for students and admins.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from uuid import UUID

from app.db import get_db
from app.models.notification import Notification
from app.models.student import Student
from app.models.class_model import ClassStudent
from app.schemas.notifications import (
    NotificationCreate,
    NotificationResponse,
    SendNotificationToStudentsRequest
)
from app.auth.dependencies import get_current_user, UserContext
from app.models.user import UserRole

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/me", response_model=List[NotificationResponse])
async def get_my_notifications(
    current_user: UserContext = Depends(get_current_user),
    db: Session = Depends(get_db),
    unread_only: bool = False
):
    """
    Get notifications for the current student.
    
    Args:
        unread_only: If True, return only unread notifications
    """
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students can access their notifications"
        )
    
    # Find student record
    student = db.query(Student).filter(
        (Student.email == current_user.email) | (Student.dtu_email == current_user.email)
    ).first()
    
    if not student:
        return []
    
    # Query notifications
    query = db.query(Notification).filter(Notification.student_id == student.id)
    
    if unread_only:
        query = query.filter(Notification.is_read == False)
    
    notifications = query.order_by(Notification.created_at.desc()).all()
    
    return [NotificationResponse.model_validate(n) for n in notifications]


@router.post("/me/{notification_id}/read")
async def mark_notification_read(
    notification_id: UUID,
    current_user: UserContext = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Mark a notification as read."""
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students can mark notifications as read"
        )
    
    # Find student record
    student = db.query(Student).filter(
        (Student.email == current_user.email) | (Student.dtu_email == current_user.email)
    ).first()
    
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student record not found"
        )
    
    # Find notification
    notification = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.student_id == student.id
    ).first()
    
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found"
        )
    
    # Mark as read
    notification.is_read = True
    from datetime import datetime, timezone
    notification.read_at = datetime.now(timezone.utc)
    db.commit()
    
    return {"message": "Notification marked as read"}


@router.post("/admin/send", response_model=dict)
async def send_notification_to_students(
    request: SendNotificationToStudentsRequest,
    current_user: UserContext = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Admin endpoint: Send notifications to students based on attendance percentage.
    
    Sends notification to all students (or students in a specific class) 
    whose attendance is below the specified threshold.
    """
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can send notifications"
        )
    
    # Build query to find students with attendance <= threshold
    if request.class_id:
        # Limit to specific class
        query = text("""
            SELECT DISTINCT s.id, s.roll_no, s.name, s.email
            FROM students s
            JOIN class_students cs ON s.id = cs.student_id
            JOIN classes c ON cs.class_id = c.id
            WHERE c.id = :class_id
            AND (
                SELECT 
                    CASE 
                        WHEN COUNT(asess.id) = 0 THEN 0
                        ELSE (COUNT(CASE WHEN asr.status = 'present' THEN 1 END)::float / COUNT(asess.id)::float) * 100
                    END
                FROM attendance_sessions asess
                LEFT JOIN attendance_statuses asr ON asess.id = asr.session_id AND asr.student_id = s.id
                WHERE asess.class_id = :class_id
            ) <= :threshold
        """)
        result = db.execute(query, {
            "class_id": str(request.class_id),
            "threshold": request.attendance_threshold
        })
    else:
        # All students across all classes
        query = text("""
            SELECT DISTINCT s.id, s.roll_no, s.name, s.email
            FROM students s
            JOIN class_students cs ON s.id = cs.student_id
            WHERE (
                SELECT 
                    CASE 
                        WHEN COUNT(asess.id) = 0 THEN 0
                        ELSE (COUNT(CASE WHEN asr.status = 'present' THEN 1 END)::float / COUNT(asess.id)::float) * 100
                    END
                FROM attendance_sessions asess
                LEFT JOIN attendance_statuses asr ON asess.id = asr.session_id AND asr.student_id = s.id
                WHERE asess.class_id = cs.class_id
            ) <= :threshold
        """)
        result = db.execute(query, {"threshold": request.attendance_threshold})
    
    students = result.fetchall()
    
    # Create notifications for each student
    notifications_created = 0
    from datetime import datetime, timezone
    
    for row in students:
        student_id = row[0]
        notification = Notification(
            student_id=student_id,
            title=request.title,
            message=request.message,
            notification_type="attendance",
            attendance_threshold=request.attendance_threshold,
            is_read=False
        )
        db.add(notification)
        notifications_created += 1
    
    db.commit()
    
    return {
        "message": f"Notifications sent to {notifications_created} students",
        "notifications_created": notifications_created
    }


@router.post("/admin/send-to-student", response_model=NotificationResponse)
async def send_notification_to_student(
    request: NotificationCreate,
    current_user: UserContext = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Admin endpoint: Send a notification to a specific student.
    """
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can send notifications"
        )
    
    if not request.student_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="student_id is required"
        )
    
    # Verify student exists
    student = db.query(Student).filter(Student.id == request.student_id).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found"
        )
    
    # Create notification
    notification = Notification(
        student_id=request.student_id,
        title=request.title,
        message=request.message,
        notification_type=request.notification_type or "manual",
        attendance_threshold=request.attendance_threshold,
        is_read=False
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    
    return NotificationResponse.model_validate(notification)


