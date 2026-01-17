"""
Statistics routes.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from uuid import UUID
from typing import List

from app.db import get_db
from app.auth.dependencies import get_current_user, require_teacher_or_admin, UserContext
from app.models.class_model import Class
from app.models.user import UserRole
from app.schemas.stats import StudentAttendanceSummary

router = APIRouter(prefix="/stats", tags=["Statistics"])


@router.get("/classes/{class_id}/students", response_model=List[StudentAttendanceSummary])
async def get_class_attendance_summary(
    class_id: UUID,
    current_user: UserContext = Depends(require_teacher_or_admin),
    db: Session = Depends(get_db)
):
    """
    Get attendance summary for all students in a class.
    
    - Shows present count, total count, and attendance percentage
    - Only class owner or admin can view stats
    """
    # Verify class ownership
    cls = db.query(Class).filter(Class.id == class_id).first()
    
    if not cls:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    if current_user.role != UserRole.ADMIN and cls.teacher_id != current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this class's statistics"
        )
    
    # Query with detailed status counts
    query = text("""
        SELECT 
            s.id as student_id,
            s.roll_no,
            s.name,
            COUNT(CASE WHEN asr.status = 'present' THEN 1 END) as present_count,
            COUNT(CASE WHEN asr.status = 'absent' THEN 1 END) as absent_count,
            COUNT(CASE WHEN asr.status = 'late' THEN 1 END) as late_count,
            COUNT(CASE WHEN asr.status = 'excused' THEN 1 END) as excused_count,
            COUNT(asr.status) as total_count,
            CASE 
                WHEN COUNT(asr.status) > 0 
                THEN ROUND((COUNT(CASE WHEN asr.status = 'present' THEN 1 END)::numeric / COUNT(asr.status)::numeric) * 100, 2)
                ELSE 0 
            END as percentage
        FROM students s
        JOIN class_students cs ON s.id = cs.student_id
        LEFT JOIN attendance_status_records asr ON s.id = asr.student_id
        LEFT JOIN attendance_sessions asess ON asr.session_id = asess.id AND asess.class_id = :class_id
        WHERE cs.class_id = :class_id
        GROUP BY s.id, s.roll_no, s.name
        ORDER BY s.roll_no
    """)
    
    result = db.execute(query, {"class_id": str(class_id)})
    rows = result.fetchall()
    
    # Format response
    summaries = [
        StudentAttendanceSummary(
            studentId=row[0],
            rollNo=row[1],
            studentName=row[2],
            presentCount=row[3] or 0,
            absentCount=row[4] or 0,
            lateCount=row[5] or 0,
            excusedCount=row[6] or 0,
            totalCount=row[7] or 0,
            percentage=float(row[8] or 0)
        )
        for row in rows
    ]
    
    return summaries
