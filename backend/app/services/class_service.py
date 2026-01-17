"""
Class-related business logic services.
"""
from sqlalchemy.orm import Session, joinedload
from uuid import UUID
from typing import List, Optional
from datetime import datetime, time as dt_time, date as dt_date
from fastapi import HTTPException, status

from app.models.class_model import Class, ClassSchedule, ClassReschedule, ClassStudent
from app.models.student import Student
from app.models.user import User, UserRole, AllowedStudentEmail
from app.schemas.classes import ClassResponse, ScheduleInfo, RescheduleInfo, StudentInClass, StudentInput


def create_class(
    db: Session,
    code: str,
    name: str,
    section: str,
    teacher_id: UUID,
    ltp_pattern: Optional[str] = None,
    teacher_type: Optional[str] = None,
    practical_group: Optional[str] = None
) -> Class:
    """
    Create a new class.
    
    Args:
        db: Database session
        code: Class code
        name: Class name
        section: Class section
        teacher_id: Teacher's UUID
        ltp_pattern: Optional LTP pattern
        teacher_type: Optional teacher type
        practical_group: Optional practical group
        
    Returns:
        Created Class object
        
    Raises:
        HTTPException: If class already exists
    """
    # Check for duplicate
    existing = db.query(Class).filter(
        Class.teacher_id == teacher_id,
        Class.code == code,
        Class.section == section
    ).first()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Class {code}-{section} already exists for this teacher"
        )
    
    # Create new class
    new_class = Class(
        code=code,
        name=name,
        section=section,
        teacher_id=teacher_id,
        ltp_pattern=ltp_pattern,
        teacher_type=teacher_type,
        practical_group=practical_group
    )
    
    db.add(new_class)
    db.commit()
    db.refresh(new_class)
    
    return new_class


def get_classes_for_user(db: Session, user_id: UUID, role: UserRole) -> List[dict]:
    """
    Get classes for a user based on their role.
    
    Args:
        db: Database session
        user_id: User's UUID
        role: User's role (teacher or admin)
        
    Returns:
        List of class dictionaries with full details
    """
    # Build query with eager loading
    query = db.query(Class).options(
        joinedload(Class.schedules),
        joinedload(Class.reschedules),
        joinedload(Class.student_enrollments).joinedload(ClassStudent.student)
    )
    
    # Filter by teacher if not admin
    if role != UserRole.ADMIN:
        query = query.filter(Class.teacher_id == user_id)
    
    classes = query.all()
    
    # Format response
    result = []
    for cls in classes:
        # Format schedules
        schedules = [
            {
                "dayOfWeek": sched.day_of_week,
                "start": sched.start_time.strftime("%H:%M"),
                "end": sched.end_time.strftime("%H:%M")
            }
            for sched in cls.schedules
        ]
        
        # Format reschedules
        reschedules = [
            {
                "originalDate": resched.original_date.isoformat(),
                "originalStartTime": resched.original_start_time.strftime("%H:%M"),
                "originalEndTime": resched.original_end_time.strftime("%H:%M"),
                "rescheduledDate": resched.rescheduled_date.isoformat(),
                "rescheduledStartTime": resched.rescheduled_start_time.strftime("%H:%M"),
                "rescheduledEndTime": resched.rescheduled_end_time.strftime("%H:%M"),
                "reason": resched.reason
            }
            for resched in cls.reschedules
        ]
        
        # Format students
        students = [
            {
                "studentId": str(enrollment.student.id),
                "rollNo": enrollment.student.roll_no,
                "name": enrollment.student.name,
                "photoUrl": enrollment.student.photo_url,
                "program": enrollment.student.program,
                "spCode": enrollment.student.sp_code,
                "semester": enrollment.student.semester,
                "status": enrollment.student.status,
                "duration": enrollment.student.duration,
                "email": enrollment.student.email,
                "dtuEmail": enrollment.student.dtu_email,
                "phone": enrollment.student.phone
            }
            for enrollment in cls.student_enrollments
        ]
        
        result.append({
            "id": str(cls.id),
            "code": cls.code,
            "name": cls.name,
            "section": cls.section,
            "teacherType": cls.teacher_type,
            "ltpPattern": cls.ltp_pattern,
            "practicalGroup": cls.practical_group,
            "teacherId": str(cls.teacher_id),
            "schedule": schedules,
            "reschedules": reschedules,
            "students": students,
            "createdAt": cls.created_at.isoformat(),
            "updatedAt": cls.updated_at.isoformat()
        })
    
    return result


def verify_class_ownership(db: Session, class_id: UUID, user_id: UUID, role: UserRole) -> Class:
    """
    Verify that a user has permission to access a class.
    
    Args:
        db: Database session
        class_id: Class UUID
        user_id: User UUID
        role: User role
        
    Returns:
        Class object if authorized
        
    Raises:
        HTTPException: If class not found or user not authorized
    """
    cls = db.query(Class).filter(Class.id == class_id).first()
    
    if not cls:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    # Admin can access any class
    if role == UserRole.ADMIN:
        return cls
    
    # Teacher can only access their own classes
    if cls.teacher_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this class"
        )
    
    return cls


def update_class_students(
    db: Session,
    class_id: UUID,
    user_id: UUID,
    role: UserRole,
    students_data: List[StudentInput]
) -> List[dict]:
    """
    Update students enrolled in a class.
    
    Args:
        db: Database session
        class_id: Class UUID
        user_id: User UUID
        role: User role
        students_data: List of student information
        
    Returns:
        Updated list of students in the class
        
    Raises:
        HTTPException: If not authorized or class not found
    """
    # Verify ownership
    cls = verify_class_ownership(db, class_id, user_id, role)
    
    # Upsert students and add to class
    for student_input in students_data:
        # Check if student exists by roll_no
        student = db.query(Student).filter(Student.roll_no == student_input.roll_no).first()
        
        if student:
            # Update existing student
            student.name = student_input.name
            if student_input.photo_url:
                student.photo_url = student_input.photo_url
            if student_input.program:
                student.program = student_input.program
            if student_input.sp_code:
                student.sp_code = student_input.sp_code
            if student_input.semester:
                student.semester = student_input.semester
            if student_input.status:
                student.status = student_input.status
            if student_input.duration:
                student.duration = student_input.duration
            if student_input.email:
                student.email = student_input.email
            if student_input.dtu_email:
                student.dtu_email = student_input.dtu_email
            if student_input.phone:
                student.phone = student_input.phone
        else:
            # Create new student
            student = Student(
                roll_no=student_input.roll_no,
                name=student_input.name,
                photo_url=student_input.photo_url,
                program=student_input.program,
                sp_code=student_input.sp_code,
                semester=student_input.semester,
                status=student_input.status,
                duration=student_input.duration,
                email=student_input.email,
                dtu_email=student_input.dtu_email,
                phone=student_input.phone
            )
            db.add(student)
            db.flush()  # Get student ID
        
        # Add to class if not already enrolled
        enrollment = db.query(ClassStudent).filter(
            ClassStudent.class_id == class_id,
            ClassStudent.student_id == student.id
        ).first()
        
        if not enrollment:
            enrollment = ClassStudent(class_id=class_id, student_id=student.id)
            db.add(enrollment)
        
        # Auto-add student emails to allowed_student_emails table
        # This enables students to log into the student app
        if student_input.email or student_input.dtu_email:
            _add_to_allowed_student_emails(db, student_input, student)
    
    db.commit()
    
    # Return updated roster
    return get_class_students_list(db, class_id)


def _add_to_allowed_student_emails(db: Session, student_input: StudentInput, student: Student):
    """
    Add student email to allowed_student_emails table if not already present.
    This is called automatically when a teacher uploads student data.
    """
    # Clean up 'NULL' strings to actual None
    email = student_input.email if student_input.email and student_input.email.upper() != 'NULL' else None
    dtu_email = student_input.dtu_email if student_input.dtu_email and student_input.dtu_email.upper() != 'NULL' else None
    
    # Check by primary email
    if email:
        existing = db.query(AllowedStudentEmail).filter(
            AllowedStudentEmail.email == email
        ).first()
        
        if not existing:
            # Create new allowed student email entry
            allowed = AllowedStudentEmail(
                email=email,
                dtu_email=dtu_email,
                roll_no=student_input.roll_no,
                name=student_input.name,
                program=student_input.program
            )
            db.add(allowed)
        else:
            # Update existing entry with additional info
            if dtu_email and not existing.dtu_email:
                existing.dtu_email = dtu_email
            if student_input.roll_no and not existing.roll_no:
                existing.roll_no = student_input.roll_no
            if student_input.name and not existing.name:
                existing.name = student_input.name
            existing.updated_at = datetime.utcnow()
    
    # Also check by DTU email if different from primary
    if dtu_email and dtu_email != email:
        existing_dtu = db.query(AllowedStudentEmail).filter(
            AllowedStudentEmail.dtu_email == dtu_email
        ).first()
        
        if not existing_dtu:
            # Check if this DTU email should be added as primary for another entry
            existing_by_email = db.query(AllowedStudentEmail).filter(
                AllowedStudentEmail.email == dtu_email
            ).first()
            
            if not existing_by_email:
                # Create entry with DTU email as primary if no personal email
                if not email:
                    allowed = AllowedStudentEmail(
                        email=dtu_email,
                        roll_no=student_input.roll_no,
                        name=student_input.name,
                        program=student_input.program
                    )
                    db.add(allowed)



def delete_class(db: Session, class_id: UUID, user_id: UUID, role: UserRole) -> None:
    """
    Delete a class and all related data if the requester owns it or is admin.
    """
    cls = verify_class_ownership(db, class_id, user_id, role)
    db.delete(cls)
    db.commit()


def get_class_students_list(db: Session, class_id: UUID) -> List[dict]:
    """
    Get the list of students enrolled in a class.
    """
    enrollments = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id
    ).options(joinedload(ClassStudent.student)).all()
    
    return [
        {
            "studentId": str(e.student.id),
            "rollNo": e.student.roll_no,
            "name": e.student.name,
            "photoUrl": e.student.photo_url,
            "program": e.student.program,
            "spCode": e.student.sp_code,
            "semester": e.student.semester,
            "status": e.student.status,
            "duration": e.student.duration,
            "email": e.student.email,
            "dtuEmail": e.student.dtu_email,
            "phone": e.student.phone
        }
        for e in enrollments
    ]
