"""
Business logic for class reschedule operations.
"""
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import and_
from datetime import date

from app.models.class_model import ClassReschedule, Class
from app.schemas.reschedule import RescheduleCreate, RescheduleUpdate


def verify_class_ownership(db: Session, class_id: str, user_id: str, is_admin: bool) -> Class:
    """Verify user owns/can access the class."""
    query = db.query(Class).filter(Class.id == class_id)
    
    if not is_admin:
        query = query.filter(Class.teacher_id == user_id)
    
    class_obj = query.first()
    if not class_obj:
        raise ValueError("Class not found or access denied")
    
    return class_obj


def create_reschedule(
    db: Session,
    class_id: str,
    data: RescheduleCreate,
    user_id: str,
    is_admin: bool
) -> ClassReschedule:
    """Create a new class reschedule."""
    # Verify ownership
    class_obj = verify_class_ownership(db, class_id, user_id, is_admin)
    
    # Get the day of week for the original date
    original_day_of_week = data.original_date.isoweekday()  # 1=Monday, 7=Sunday
    
    # Find the schedule for this day
    from app.models.class_model import ClassSchedule
    schedule = db.query(ClassSchedule).filter(
        ClassSchedule.class_id == class_id,
        ClassSchedule.day_of_week == original_day_of_week
    ).first()
    
    if not schedule:
        raise ValueError(f"No schedule found for this class on the original date's day of week")
    
    # Create reschedule with original times from schedule
    reschedule = ClassReschedule(
        class_id=class_id,
        original_date=data.original_date,
        original_start_time=schedule.start_time,
        original_end_time=schedule.end_time,
        rescheduled_date=data.rescheduled_date,
        rescheduled_start_time=data.rescheduled_start_time,
        rescheduled_end_time=data.rescheduled_end_time,
        reason=data.reason
    )
    
    db.add(reschedule)
    db.commit()
    db.refresh(reschedule)
    
    return reschedule


def get_class_reschedules(
    db: Session,
    class_id: str,
    user_id: str,
    is_admin: bool,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None
) -> List[ClassReschedule]:
    """Get all reschedules for a class."""
    # Verify ownership
    verify_class_ownership(db, class_id, user_id, is_admin)
    
    query = db.query(ClassReschedule).filter(ClassReschedule.class_id == class_id)
    
    # Optional date filtering
    if start_date:
        query = query.filter(ClassReschedule.rescheduled_date >= start_date)
    if end_date:
        query = query.filter(ClassReschedule.rescheduled_date <= end_date)
    
    return query.order_by(ClassReschedule.rescheduled_date).all()


def get_reschedule_by_id(
    db: Session,
    reschedule_id: str,
    user_id: str,
    is_admin: bool
) -> ClassReschedule:
    """Get a specific reschedule by ID."""
    reschedule = db.query(ClassReschedule).filter(ClassReschedule.id == reschedule_id).first()
    
    if not reschedule:
        raise ValueError("Reschedule not found")
    
    # Verify ownership of the class
    verify_class_ownership(db, reschedule.class_id, user_id, is_admin)
    
    return reschedule


def update_reschedule(
    db: Session,
    reschedule_id: str,
    data: RescheduleUpdate,
    user_id: str,
    is_admin: bool
) -> ClassReschedule:
    """Update a reschedule."""
    reschedule = get_reschedule_by_id(db, reschedule_id, user_id, is_admin)
    
    # Update fields
    if data.rescheduled_date is not None:
        reschedule.rescheduled_date = data.rescheduled_date
    if data.rescheduled_start_time is not None:
        reschedule.rescheduled_start_time = data.rescheduled_start_time
    if data.rescheduled_end_time is not None:
        reschedule.rescheduled_end_time = data.rescheduled_end_time
    if data.reason is not None:
        reschedule.reason = data.reason
    
    db.commit()
    db.refresh(reschedule)
    
    return reschedule


def delete_reschedule(
    db: Session,
    reschedule_id: str,
    user_id: str,
    is_admin: bool
) -> None:
    """Delete a reschedule."""
    reschedule = get_reschedule_by_id(db, reschedule_id, user_id, is_admin)
    
    db.delete(reschedule)
    db.commit()
