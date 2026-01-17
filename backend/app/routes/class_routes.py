"""
Class management routes.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel
from datetime import time

from app.db import get_db
from app.auth.dependencies import get_current_user, require_teacher_or_admin, UserContext
from app.schemas.classes import UpdateStudentsRequest
from app.services.class_service import get_classes_for_user, update_class_students, create_class, delete_class
from app.models.class_model import ClassSchedule

router = APIRouter(prefix="/classes", tags=["Classes"])


class CreateClassRequest(BaseModel):
    code: str
    name: str
    section: str
    ltp_pattern: Optional[str] = None
    teacher_type: Optional[str] = None
    practical_group: Optional[str] = None


class CreateScheduleRequest(BaseModel):
    day_of_week: int
    start_time: str  # HH:MM:SS format
    end_time: str  # HH:MM:SS format


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_new_class(
    request: CreateClassRequest,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Create a new class.
    """
    new_class = create_class(
        db=db,
        code=request.code,
        name=request.name,
        section=request.section,
        teacher_id=current_user.user_id,
        ltp_pattern=request.ltp_pattern,
        teacher_type=request.teacher_type,
        practical_group=request.practical_group
    )
    
    return {"id": str(new_class.id), "code": new_class.code, "name": new_class.name}


@router.post("/{class_id}/schedules", status_code=status.HTTP_201_CREATED)
async def add_class_schedule(
    class_id: UUID,
    request: CreateScheduleRequest,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Add a schedule to a class.
    """
    from app.models.class_model import Class
    
    # Verify ownership
    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")
    
    if current_user.role != 'admin' and cls.teacher_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    # Parse time strings
    start_time = time.fromisoformat(request.start_time)
    end_time = time.fromisoformat(request.end_time)
    
    # Create schedule
    schedule = ClassSchedule(
        class_id=class_id,
        day_of_week=request.day_of_week,
        start_time=start_time,
        end_time=end_time
    )
    
    db.add(schedule)
    db.commit()
    
    return {"status": "success"}


@router.get("")
async def list_classes(
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    List all classes accessible to the current user.
    
    - Teachers see only their own classes
    - Admins see all classes
    """
    classes = get_classes_for_user(db, current_user.user_id, current_user.role)
    return classes



@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_class(
    class_id: UUID,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Delete a class and all related records.
    """
    delete_class(db, class_id, current_user.user_id, current_user.role)


@router.put("/{class_id}/students")
async def update_students(
    class_id: UUID,
    request: UpdateStudentsRequest,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Update the roster of students enrolled in a class.
    
    - Upserts students based on roll number
    - Adds students to the class if not already enrolled
    - Only class owner or admin can update
    """
    students = update_class_students(
        db,
        class_id,
        current_user.user_id,
        current_user.role,
        request.students
    )
    
    return {"students": students}
