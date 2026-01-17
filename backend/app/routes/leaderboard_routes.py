"""
Leaderboard routes (read-only, no schema changes).
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session
from typing import Optional

from app.db import get_db
from app.auth.dependencies import get_current_user, UserContext
from app.models.user import UserRole
from app.models.student import Student
from app.schemas.leaderboard import LeaderboardEntry, LeaderboardResponse


router = APIRouter(prefix="/leaderboard", tags=["Leaderboard"])


async def require_student_or_admin(
    current_user: UserContext = Depends(get_current_user),
) -> UserContext:
    """
    Allow students (primary) and admins to view leaderboard. Teachers are excluded by design.
    """
    if current_user.role not in {UserRole.STUDENT, UserRole.ADMIN}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student access required",
        )
    return current_user


@router.get("", response_model=LeaderboardResponse)
async def get_leaderboard(
    limit: int = Query(50, ge=1, le=200, description="Page size"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    current_user: UserContext = Depends(require_student_or_admin),
    db: Session = Depends(get_db),
):
    """
    Read-only college-wide leaderboard.

    - Ranks by attendance percentage, then consistency, then max streak (per requirements).
    - Coins calculated from provided weights; streak normalized by global max streak.
    - Levels: 1 (default), 2 if attendance >=80% AND attended >=20, 3 if attendance >=90% AND attended >=50.
    - Excludes students with zero recorded attendance (empty roster / no statuses).
    - No schema or data mutations.
    """
    # Resolve current student record by email; optional, for selfEntry
    student = db.query(Student).filter(
        (Student.email == current_user.email) | (Student.dtu_email == current_user.email)
    ).first()
    current_student_id: Optional[str] = str(student.id) if student else None

    # Core leaderboard CTE (uses attendance_statuses / attendance_sessions as in existing routes)
    leaderboard_sql = text(
        """
        WITH base AS (
            SELECT
                s.id AS student_id,
                s.name,
                s.roll_no,
                COUNT(CASE WHEN asr.status = 'present' THEN 1 END) AS present_count,
                COUNT(CASE WHEN asr.status = 'late' THEN 1 END) AS late_count,
                COUNT(CASE WHEN asr.status = 'absent' THEN 1 END) AS absent_count,
                COUNT(CASE WHEN asr.status = 'excused' THEN 1 END) AS excused_count,
                COUNT(asr.status) AS total_count
            FROM students s
            JOIN class_students cs ON cs.student_id = s.id
            LEFT JOIN attendance_statuses asr ON asr.student_id = s.id
            LEFT JOIN attendance_sessions asess ON asess.id = asr.session_id
            GROUP BY s.id, s.name, s.roll_no
        ),
        filtered AS (
            -- Remove students with no attendance records to avoid empty roster accounts
            SELECT * FROM base WHERE total_count > 0
        ),
        attended_dates AS (
            -- Unique dates where student was present or late
            SELECT DISTINCT
                s.id AS student_id,
                asess.session_date::date AS session_date
            FROM students s
            JOIN attendance_statuses asr ON asr.student_id = s.id
            JOIN attendance_sessions asess ON asess.id = asr.session_id
            WHERE asr.status IN ('present', 'late')
        ),
        streaks AS (
            -- Compute consecutive day streaks using date gaps
            SELECT
                student_id,
                COUNT(*) AS streak_len
            FROM (
                SELECT
                    student_id,
                    session_date,
                    session_date - (ROW_NUMBER() OVER (PARTITION BY student_id ORDER BY session_date)) * INTERVAL '1 day' AS grp
                FROM attended_dates
            ) t
            GROUP BY student_id, grp
        ),
        max_streak AS (
            SELECT student_id, MAX(streak_len) AS max_streak
            FROM streaks
            GROUP BY student_id
        ),
        global_max AS (
            SELECT COALESCE(MAX(max_streak), 0) AS global_max FROM max_streak
        ),
        ranked AS (
            SELECT
                f.student_id,
                f.name,
                f.roll_no,
                f.present_count,
                f.late_count,
                f.absent_count,
                f.excused_count,
                f.total_count,
                (f.present_count + f.late_count) AS attended_count,
                COALESCE(ms.max_streak, 0) AS max_streak,
                CASE
                    WHEN f.total_count > 0 THEN ROUND(((f.present_count + f.late_count)::numeric / f.total_count::numeric) * 100, 2)
                    ELSE 0
                END AS attendance_pct,
                CASE
                    WHEN f.total_count > 0 THEN (f.present_count + f.late_count)::numeric / f.total_count::numeric
                    ELSE 0
                END AS consistency,
                gm.global_max
            FROM filtered f
            LEFT JOIN max_streak ms ON ms.student_id = f.student_id
            CROSS JOIN global_max gm
        ),
        scored AS (
            SELECT
                *,
                CASE
                    WHEN global_max > 0 THEN POWER(max_streak::numeric / global_max, 2)
                    ELSE 0
                END AS streak_score
            FROM ranked
        ),
        final AS (
            SELECT
                *,
                ROUND(0.7 * attendance_pct + 0.2 * (consistency * 100) + 0.1 * (streak_score * 100), 2) AS coins,
                CASE
                    WHEN attendance_pct >= 90 AND attended_count >= 50 THEN 3
                    WHEN attendance_pct >= 80 AND attended_count >= 20 THEN 2
                    ELSE 1
                END AS level,
                ROW_NUMBER() OVER (ORDER BY attendance_pct DESC, consistency DESC, max_streak DESC, name ASC) AS rank
            FROM scored
        )
        SELECT
            student_id,
            name,
            roll_no,
            attendance_pct,
            consistency,
            max_streak,
            coins,
            level,
            attended_count,
            total_count,
            present_count,
            late_count,
            absent_count,
            excused_count,
            rank,
            COUNT(*) OVER () AS total_rows
        FROM final
        ORDER BY rank
        LIMIT :limit OFFSET :offset;
        """
    )

    rows = db.execute(
        leaderboard_sql, {"limit": limit, "offset": offset}
    ).fetchall()

    items = [
        LeaderboardEntry(
            studentId=str(row.student_id),
            rollNo=row.roll_no,
            name=row.name,
            attendancePercentage=float(row.attendance_pct or 0),
            consistency=float(row.consistency or 0),
            maxStreak=int(row.max_streak or 0),
            coins=float(row.coins or 0),
            level=int(row.level or 1),
            attendedCount=int(row.attended_count or 0),
            totalCount=int(row.total_count or 0),
            presentCount=int(row.present_count or 0),
            lateCount=int(row.late_count or 0),
            absentCount=int(row.absent_count or 0),
            excusedCount=int(row.excused_count or 0),
            rank=int(row.rank),
        )
        for row in rows
    ]

    total_rows = int(rows[0].total_rows) if rows else 0

    # Self entry (optional) using same ranking; avoids pagination truncation
    self_entry: Optional[LeaderboardEntry] = None
    if current_student_id:
        self_sql = text(
            """
            WITH base AS (
                SELECT
                    s.id AS student_id,
                    s.name,
                    s.roll_no,
                    COUNT(CASE WHEN asr.status = 'present' THEN 1 END) AS present_count,
                    COUNT(CASE WHEN asr.status = 'late' THEN 1 END) AS late_count,
                    COUNT(CASE WHEN asr.status = 'absent' THEN 1 END) AS absent_count,
                    COUNT(CASE WHEN asr.status = 'excused' THEN 1 END) AS excused_count,
                    COUNT(asr.status) AS total_count
                FROM students s
                JOIN class_students cs ON cs.student_id = s.id
                LEFT JOIN attendance_statuses asr ON asr.student_id = s.id
                LEFT JOIN attendance_sessions asess ON asess.id = asr.session_id
                GROUP BY s.id, s.name, s.roll_no
            ),
            filtered AS (
                SELECT * FROM base WHERE total_count > 0
            ),
            attended_dates AS (
                SELECT DISTINCT
                    s.id AS student_id,
                    asess.session_date::date AS session_date
                FROM students s
                JOIN attendance_statuses asr ON asr.student_id = s.id
                JOIN attendance_sessions asess ON asess.id = asr.session_id
                WHERE asr.status IN ('present', 'late')
            ),
            streaks AS (
                SELECT
                    student_id,
                    COUNT(*) AS streak_len
                FROM (
                    SELECT
                        student_id,
                        session_date,
                        session_date - (ROW_NUMBER() OVER (PARTITION BY student_id ORDER BY session_date)) * INTERVAL '1 day' AS grp
                    FROM attended_dates
                ) t
                GROUP BY student_id, grp
            ),
            max_streak AS (
                SELECT student_id, MAX(streak_len) AS max_streak
                FROM streaks
                GROUP BY student_id
            ),
            global_max AS (
                SELECT COALESCE(MAX(max_streak), 0) AS global_max FROM max_streak
            ),
            ranked AS (
                SELECT
                    f.student_id,
                    f.name,
                    f.roll_no,
                    f.present_count,
                    f.late_count,
                    f.absent_count,
                    f.excused_count,
                    f.total_count,
                    (f.present_count + f.late_count) AS attended_count,
                    COALESCE(ms.max_streak, 0) AS max_streak,
                    CASE
                        WHEN f.total_count > 0 THEN ROUND(((f.present_count + f.late_count)::numeric / f.total_count::numeric) * 100, 2)
                        ELSE 0
                    END AS attendance_pct,
                    CASE
                        WHEN f.total_count > 0 THEN (f.present_count + f.late_count)::numeric / f.total_count::numeric
                        ELSE 0
                    END AS consistency,
                    gm.global_max
                FROM filtered f
                LEFT JOIN max_streak ms ON ms.student_id = f.student_id
                CROSS JOIN global_max gm
            ),
            scored AS (
                SELECT
                    *,
                    CASE
                        WHEN global_max > 0 THEN POWER(max_streak::numeric / global_max, 2)
                        ELSE 0
                    END AS streak_score
                FROM ranked
            ),
            final AS (
                SELECT
                    *,
                    ROUND(0.7 * attendance_pct + 0.2 * (consistency * 100) + 0.1 * (streak_score * 100), 2) AS coins,
                    CASE
                        WHEN attendance_pct >= 90 AND attended_count >= 50 THEN 3
                        WHEN attendance_pct >= 80 AND attended_count >= 20 THEN 2
                        ELSE 1
                    END AS level,
                    ROW_NUMBER() OVER (ORDER BY attendance_pct DESC, consistency DESC, max_streak DESC, name ASC) AS rank
                FROM scored
            )
            SELECT
                student_id,
                name,
                roll_no,
                attendance_pct,
                consistency,
                max_streak,
                coins,
                level,
                attended_count,
                total_count,
                present_count,
                late_count,
                absent_count,
                excused_count,
                rank
            FROM final
            WHERE student_id = :student_id
            LIMIT 1;
            """
        )

        self_row = db.execute(self_sql, {"student_id": current_student_id}).fetchone()
        if self_row:
            self_entry = LeaderboardEntry(
                studentId=str(self_row.student_id),
                rollNo=self_row.roll_no,
                name=self_row.name,
                attendancePercentage=float(self_row.attendance_pct or 0),
                consistency=float(self_row.consistency or 0),
                maxStreak=int(self_row.max_streak or 0),
                coins=float(self_row.coins or 0),
                level=int(self_row.level or 1),
                attendedCount=int(self_row.attended_count or 0),
                totalCount=int(self_row.total_count or 0),
                presentCount=int(self_row.present_count or 0),
                lateCount=int(self_row.late_count or 0),
                absentCount=int(self_row.absent_count or 0),
                excusedCount=int(self_row.excused_count or 0),
                rank=int(self_row.rank),
            )

    return LeaderboardResponse(
        total=total_rows,
        limit=limit,
        offset=offset,
        items=items,
        selfEntry=self_entry,
    )

