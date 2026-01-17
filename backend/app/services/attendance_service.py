"""
Attendance-related business logic services.
"""
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_
from uuid import UUID
from typing import List, Optional
from datetime import datetime, date as dt_date
from fastapi import HTTPException, status

from app.models.attendance import AttendanceSession, AttendanceStatusRecord, AttendanceStatus
from app.models.class_model import Class, ClassStudent
from app.models.student import Student
from app.models.user import UserRole
from app.schemas.attendance import StatusUpdate


def create_attendance_session(
    db: Session,
    class_id: UUID,
    user_id: UUID,
    role: UserRole,
    session_date: str,
    processed_image_url: Optional[str] = None
) -> dict:
    """
    Create an attendance session for a class.
    
    Args:
        db: Database session
        class_id: Class UUID
        user_id: User UUID
        role: User role
        session_date: Date string (YYYY-MM-DD)
        processed_image_url: Optional image URL
        
    Returns:
        Session information dictionary
        
    Raises:
        HTTPException: If not authorized or class not found
    """
    # Verify class exists and user has permission
    cls = db.query(Class).filter(Class.id == class_id).first()
    
    if not cls:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    # Check authorization
    if role != UserRole.ADMIN and cls.teacher_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to create sessions for this class"
        )
    
    # Parse date
    try:
        parsed_date = dt_date.fromisoformat(session_date)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Use YYYY-MM-DD"
        )
    
    # Check if session already exists
    existing_session = db.query(AttendanceSession).filter(
        and_(
            AttendanceSession.class_id == class_id,
            AttendanceSession.session_date == parsed_date
        )
    ).first()
    
    if existing_session:
        # Return existing session instead of failing
        return {
            "sessionId": str(existing_session.id),
            "classId": str(existing_session.class_id),
            "sessionDate": existing_session.session_date.isoformat(),
            "teacherId": str(existing_session.teacher_id),
            "processedImageUrl": existing_session.processed_image_url,
            "createdAt": existing_session.created_at.isoformat()
        }
    
    # Create new session
    session = AttendanceSession(
        class_id=class_id,
        teacher_id=user_id,
        session_date=parsed_date,
        processed_image_url=processed_image_url
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    
    return {
        "sessionId": str(session.id),
        "classId": str(session.class_id),
        "sessionDate": session.session_date.isoformat(),
        "teacherId": str(session.teacher_id),
        "processedImageUrl": session.processed_image_url,
        "createdAt": session.created_at.isoformat()
    }


def update_attendance_statuses(
    db: Session,
    session_id: UUID,
    user_id: UUID,
    role: UserRole,
    updates: List[StatusUpdate]
) -> List[dict]:
    """
    Update attendance statuses for students in a session.
    
    Args:
        db: Database session
        session_id: Session UUID
        user_id: User UUID
        role: User role
        updates: List of status updates
        
    Returns:
        Updated list of attendance statuses
        
    Raises:
        HTTPException: If not authorized or session not found
    """
    # Get session with class info
    session = db.query(AttendanceSession).options(
        joinedload(AttendanceSession.class_obj)
    ).filter(AttendanceSession.id == session_id).first()
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found"
        )
    
    # Check authorization
    if role != UserRole.ADMIN and session.teacher_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to update this session"
        )
    
    # Process each update
    for update in updates:
        # Find student by roll_no
        student = db.query(Student).filter(Student.roll_no == update.roll_no).first()
        
        if not student:
            # Skip if student not found
            continue
        
        # Verify student is enrolled in the class
        enrollment = db.query(ClassStudent).filter(
            and_(
                ClassStudent.class_id == session.class_id,
                ClassStudent.student_id == student.id
            )
        ).first()
        
        if not enrollment:
            # Student not enrolled in this class, skip
            continue
        
        # Validate status
        try:
            status_enum = AttendanceStatus(update.status.lower())
        except ValueError:
            # Invalid status, skip
            continue
        
        # Upsert attendance status
        existing_status = db.query(AttendanceStatusRecord).filter(
            and_(
                AttendanceStatusRecord.session_id == session_id,
                AttendanceStatusRecord.student_id == student.id
            )
        ).first()
        
        if existing_status:
            existing_status.status = status_enum
            existing_status.recognized_by_ai = update.recognized_by_ai
            existing_status.similarity_score = update.similarity_score
        else:
            new_status = AttendanceStatusRecord(
                session_id=session_id,
                student_id=student.id,
                status=status_enum,
                recognized_by_ai=update.recognized_by_ai,
                similarity_score=update.similarity_score
            )
            db.add(new_status)
    
    db.commit()
    
    # Return updated statuses
    statuses = db.query(AttendanceStatusRecord).filter(
        AttendanceStatusRecord.session_id == session_id
    ).options(joinedload(AttendanceStatusRecord.student)).all()
    
    return [
        {
            "rollNo": s.student.roll_no,
            "name": s.student.name,
            "status": s.status.value,
            "recognizedByAi": s.recognized_by_ai,
            "similarityScore": float(s.similarity_score) if s.similarity_score else None
        }
        for s in statuses
    ]


def get_attendance_sessions(
    db: Session,
    class_id: UUID,
    user_id: UUID,
    role: UserRole,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None
) -> List[dict]:
    """
    Get attendance sessions for a class within a date range.
    
    Args:
        db: Database session
        class_id: Class UUID
        user_id: User UUID
        role: User role
        from_date: Start date (YYYY-MM-DD)
        to_date: End date (YYYY-MM-DD)
        
    Returns:
        List of sessions with statuses
        
    Raises:
        HTTPException: If not authorized
    """
    # Verify class ownership
    cls = db.query(Class).filter(Class.id == class_id).first()
    
    if not cls:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    if role != UserRole.ADMIN and cls.teacher_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this class's attendance"
        )
    
    # Build query
    query = db.query(AttendanceSession).filter(
        AttendanceSession.class_id == class_id
    )
    
    # Apply date filters
    if from_date:
        try:
            from_dt = dt_date.fromisoformat(from_date)
            query = query.filter(AttendanceSession.session_date >= from_dt)
        except ValueError:
            pass
    
    if to_date:
        try:
            to_dt = dt_date.fromisoformat(to_date)
            query = query.filter(AttendanceSession.session_date <= to_dt)
        except ValueError:
            pass
    
    sessions = query.options(
        joinedload(AttendanceSession.statuses).joinedload(AttendanceStatusRecord.student)
    ).order_by(AttendanceSession.session_date.desc()).all()
    
    # Format response
    result = []
    for session in sessions:
        statuses = [
            {
                "rollNo": s.student.roll_no,
                "name": s.student.name,
                "status": s.status.value,
                "recognizedByAi": s.recognized_by_ai,
                "similarityScore": float(s.similarity_score) if s.similarity_score else None
            }
            for s in session.statuses
        ]
        
        result.append({
            "sessionId": str(session.id),
            "classId": str(session.class_id),
            "sessionDate": session.session_date.isoformat(),
            "teacherId": str(session.teacher_id),
            "processedImageUrl": session.processed_image_url,
            "createdAt": session.created_at.isoformat(),
            "statuses": statuses
        })
    
    return result
