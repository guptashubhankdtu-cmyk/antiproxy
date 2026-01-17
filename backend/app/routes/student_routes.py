"""
Student routes - for student app functionality.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from uuid import UUID
from typing import List
from datetime import datetime

from app.db import get_db
from app.auth.dependencies import get_current_user, UserContext
from app.models.user import UserRole
from app.models.student import Student
from app.models.class_model import Class, ClassStudent
from app.models.attendance import AttendanceSession, AttendanceStatusRecord
from app.schemas.student import (
    StudentClassInfo,
    StudentAttendanceStats,
    AttendanceRecord
)

router = APIRouter(prefix="/students", tags=["Students"])


async def require_student(
    current_user: UserContext = Depends(get_current_user)
) -> UserContext:
    """
    Dependency to ensure current user is a student.
    """
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student access required"
        )
    return current_user


@router.get("/me/classes", response_model=List[StudentClassInfo])
async def get_my_classes(
    current_user: UserContext = Depends(require_student),
    db: Session = Depends(get_db)
):
    """
    Get all classes that the current student is enrolled in.
    
    Returns:
        List of classes with basic info (code, name, section, teacher name, schedule)
        Empty list if student exists but not enrolled in any classes yet
    """
    # Find the student record by email
    student = db.query(Student).filter(
        (Student.email == current_user.email) | (Student.dtu_email == current_user.email)
    ).first()
    
    if not student:
        # Student is in allowed_student_emails but not enrolled in any class yet
        # Return empty list instead of error
        return []
    
    # Get all classes the student is enrolled in
    query = text("""
        SELECT 
            c.id,
            c.code,
            c.name,
            c.section,
            c.teacher_type,
            c.ltp_pattern,
            c.practical_group,
            u.name as teacher_name,
            u.email as teacher_email
        FROM classes c
        JOIN class_students cs ON c.id = cs.class_id
        JOIN users u ON c.teacher_id = u.id
        WHERE cs.student_id = :student_id
        ORDER BY c.code, c.section
    """)
    
    result = db.execute(query, {"student_id": str(student.id)})
    rows = result.fetchall()
    
    classes = []
    for row in rows:
        class_id = row[0]
        
        # Get schedule for this class
        schedule_query = text("""
            SELECT day_of_week, start_time, end_time
            FROM class_schedules
            WHERE class_id = :class_id
            ORDER BY day_of_week
        """)
        schedule_result = db.execute(schedule_query, {"class_id": class_id})
        schedule_rows = schedule_result.fetchall()
        
        schedule = [
            {
                "dayOfWeek": sched[0],
                "startTime": sched[1].strftime("%H:%M"),
                "endTime": sched[2].strftime("%H:%M")
            }
            for sched in schedule_rows
        ]
        
        classes.append(StudentClassInfo(
            id=str(row[0]),  # Convert UUID to string
            code=row[1],
            name=row[2],
            section=row[3],
            teacherType=row[4],
            ltpPattern=row[5],
            practicalGroup=row[6],
            teacherName=row[7],
            teacherEmail=row[8],
            schedule=schedule
        ))
    
    return classes


@router.get("/me/classes/{class_id}/attendance", response_model=StudentAttendanceStats)
async def get_my_attendance_for_class(
    class_id: UUID,
    current_user: UserContext = Depends(require_student),
    db: Session = Depends(get_db)
):
    """
    Get attendance statistics for the current student in a specific class.
    
    Returns:
        - Summary stats (present, absent, late, excused counts and percentage)
        - List of all attendance records with dates and statuses
    """
    # Find the student record by email
    student = db.query(Student).filter(
        (Student.email == current_user.email) | (Student.dtu_email == current_user.email)
    ).first()
    
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student record not found"
        )
    
    # Verify student is enrolled in this class
    enrollment = db.query(ClassStudent).filter(
        ClassStudent.class_id == class_id,
        ClassStudent.student_id == student.id
    ).first()
    
    if not enrollment:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not enrolled in this class"
        )
    
    # Get class info
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    # Get attendance statistics
    stats_query = text("""
        SELECT 
            COUNT(CASE WHEN asr.status = 'present' THEN 1 END) as present_count,
            COUNT(CASE WHEN asr.status = 'absent' THEN 1 END) as absent_count,
            COUNT(CASE WHEN asr.status = 'late' THEN 1 END) as late_count,
            COUNT(CASE WHEN asr.status = 'excused' THEN 1 END) as excused_count,
            COUNT(asr.status) as total_count
        FROM attendance_sessions asess
        LEFT JOIN attendance_statuses asr ON asess.id = asr.session_id AND asr.student_id = :student_id
        WHERE asess.class_id = :class_id
    """)
    
    stats_result = db.execute(stats_query, {
        "student_id": str(student.id),
        "class_id": str(class_id)
    })
    stats_row = stats_result.fetchone()
    
    present_count = stats_row[0] or 0
    absent_count = stats_row[1] or 0
    late_count = stats_row[2] or 0
    excused_count = stats_row[3] or 0
    total_count = stats_row[4] or 0
    
    percentage = round((present_count / total_count * 100), 2) if total_count > 0 else 0.0
    
    # Get individual attendance records
    records_query = text("""
        SELECT 
            asess.session_date,
            COALESCE(asr.status, 'absent') as status,
            asr.recognized_by_ai,
            asr.similarity_score
        FROM attendance_sessions asess
        LEFT JOIN attendance_statuses asr ON asess.id = asr.session_id AND asr.student_id = :student_id
        WHERE asess.class_id = :class_id
        ORDER BY asess.session_date DESC
    """)
    
    records_result = db.execute(records_query, {
        "student_id": str(student.id),
        "class_id": str(class_id)
    })
    records_rows = records_result.fetchall()
    
    records = [
        AttendanceRecord(
            date=row[0].isoformat(),
            status=row[1],
            recognizedByAi=row[2] or False,
            similarityScore=float(row[3]) if row[3] else None
        )
        for row in records_rows
    ]
    
    return StudentAttendanceStats(
        classId=str(class_id),
        className=class_obj.name,
        classCode=class_obj.code,
        section=class_obj.section,
        studentName=student.name,
        rollNo=student.roll_no,
        presentCount=present_count,
        absentCount=absent_count,
        lateCount=late_count,
        excusedCount=excused_count,
        totalCount=total_count,
        percentage=percentage,
        records=records
    )


@router.get("/me/photo")
async def get_my_photo(
    current_user: UserContext = Depends(require_student),
    db: Session = Depends(get_db)
):
    """
    Get the current student's photo URL.
    
    Returns:
        - photo_url: URL of the student's photo (null if not uploaded)
        - has_photo: Boolean indicating if photo exists
    """
    # Find student record by email - try multiple approaches
    student = db.query(Student).filter(
        (Student.email == current_user.email) | (Student.dtu_email == current_user.email)
    ).first()
    
    # If not found, try to find by enrolled classes (student might exist but email doesn't match)
    if not student:
        from app.models.class_model import ClassStudent
        from app.models.user import AllowedStudentEmail
        
        # Check allowed_student_emails first
        allowed_student = db.query(AllowedStudentEmail).filter(
            (AllowedStudentEmail.email == current_user.email) | 
            (AllowedStudentEmail.dtu_email == current_user.email)
        ).first()
        
        if allowed_student:
            # Try to find by roll_no from allowed_student_emails
            student = db.query(Student).filter(
                Student.roll_no == allowed_student.roll_no
            ).first()
        
        # If still not found, try enrolled classes
        if not student:
            email_prefix = current_user.email.split('@')[0].lower()
            enrolled_student = db.query(Student).join(ClassStudent).filter(
                (Student.email.ilike(f"%{email_prefix}%")) |
                (Student.dtu_email.ilike(f"%{email_prefix}%"))
            ).first()
            
            if enrolled_student:
                student = enrolled_student
    
    if not student:
        # Return empty response instead of error - student might not have uploaded photo yet
        return {
            "photo_url": None,
            "has_photo": False
        }
    
    return {
        "photo_url": student.photo_url,
        "has_photo": student.photo_url is not None
    }
