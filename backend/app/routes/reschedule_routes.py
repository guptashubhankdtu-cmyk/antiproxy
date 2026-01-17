"""
API routes for class reschedule management.
"""
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.auth.dependencies import UserContext, get_current_user
from app.schemas.reschedule import RescheduleCreate, RescheduleUpdate, RescheduleResponse
from app.services import reschedule_service

router = APIRouter(prefix="/classes", tags=["reschedules"])


@router.post("/{class_id}/reschedules", response_model=RescheduleResponse, status_code=201)
def create_class_reschedule(
    class_id: str,
    data: RescheduleCreate,
    db: Session = Depends(get_db),
    user: UserContext = Depends(get_current_user)
):
    """
    Create a new reschedule for a class.
    
    Teachers can only reschedule their own classes.
    Admins can reschedule any class.
    """
    try:
        reschedule = reschedule_service.create_reschedule(
            db=db,
            class_id=class_id,
            data=data,
            user_id=user.user_id,
            is_admin=user.is_admin
        )
        
        return RescheduleResponse(
            id=str(reschedule.id),
            class_id=str(reschedule.class_id),
            original_date=reschedule.original_date,
            original_start_time=reschedule.original_start_time,
            original_end_time=reschedule.original_end_time,
            rescheduled_date=reschedule.rescheduled_date,
            rescheduled_start_time=reschedule.rescheduled_start_time,
            rescheduled_end_time=reschedule.rescheduled_end_time,
            reason=reschedule.reason,
            created_at=reschedule.created_at.isoformat()
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create reschedule: {str(e)}")


@router.get("/{class_id}/reschedules", response_model=List[RescheduleResponse])
def get_class_reschedules(
    class_id: str,
    start_date: Optional[date] = Query(None, description="Filter reschedules from this date"),
    end_date: Optional[date] = Query(None, description="Filter reschedules until this date"),
    db: Session = Depends(get_db),
    user: UserContext = Depends(get_current_user)
):
    """
    Get all reschedules for a class.
    
    Optional date range filtering.
    """
    try:
        reschedules = reschedule_service.get_class_reschedules(
            db=db,
            class_id=class_id,
            user_id=user.user_id,
            is_admin=user.is_admin,
            start_date=start_date,
            end_date=end_date
        )
        
        return [
            RescheduleResponse(
                id=str(r.id),
                class_id=str(r.class_id),
                original_date=r.original_date,
                original_start_time=r.original_start_time,
                original_end_time=r.original_end_time,
                rescheduled_date=r.rescheduled_date,
                rescheduled_start_time=r.rescheduled_start_time,
                rescheduled_end_time=r.rescheduled_end_time,
                reason=r.reason,
                created_at=r.created_at.isoformat()
            )
            for r in reschedules
        ]
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.put("/reschedules/{reschedule_id}", response_model=RescheduleResponse)
def update_reschedule(
    reschedule_id: str,
    data: RescheduleUpdate,
    db: Session = Depends(get_db),
    user: UserContext = Depends(get_current_user)
):
    """Update a reschedule."""
    try:
        reschedule = reschedule_service.update_reschedule(
            db=db,
            reschedule_id=reschedule_id,
            data=data,
            user_id=user.user_id,
            is_admin=user.is_admin
        )
        
        return RescheduleResponse(
            id=str(reschedule.id),
            class_id=str(reschedule.class_id),
            original_date=reschedule.original_date,
            original_start_time=reschedule.original_start_time,
            original_end_time=reschedule.original_end_time,
            rescheduled_date=reschedule.rescheduled_date,
            rescheduled_start_time=reschedule.rescheduled_start_time,
            rescheduled_end_time=reschedule.rescheduled_end_time,
            reason=reschedule.reason,
            created_at=reschedule.created_at.isoformat()
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/reschedules/{reschedule_id}", status_code=204)
def delete_reschedule(
    reschedule_id: str,
    db: Session = Depends(get_db),
    user: UserContext = Depends(get_current_user)
):
    """Delete a reschedule."""
    try:
        reschedule_service.delete_reschedule(
            db=db,
            reschedule_id=reschedule_id,
            user_id=user.user_id,
            is_admin=user.is_admin
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
