"""merge schemas remove whitelist

Revision ID: 59aefb6db558
Revises: 001_initial
Create Date: 2025-12-07 19:09:54.476785

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '59aefb6db558'
down_revision: Union[str, None] = '001_initial'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Ensure pgcrypto for gen_random_uuid
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')

    # New enums
    op.execute("CREATE TYPE role_enum AS ENUM ('ADMIN','HOD','TEACHER','STUDENT');")
    op.execute("CREATE TYPE attendance_status_enum AS ENUM ('PRESENT','ABSENT','LATE','EXCUSED');")
    op.execute("CREATE TYPE notification_type_enum AS ENUM ('ATTENDANCE','MANUAL','SYSTEM');")
    op.execute("CREATE TYPE target_role_enum AS ENUM ('ALL','TEACHER','HOD','ADMIN','STUDENT');")

    # Drop dependent tables to rebuild with new keys
    op.execute("DROP VIEW IF EXISTS v_student_attendance_summary;")
    op.execute("DROP TABLE IF EXISTS attendance_statuses CASCADE;")
    op.execute("DROP TABLE IF EXISTS attendance_sessions CASCADE;")
    op.execute("DROP TABLE IF EXISTS notifications CASCADE;")
    op.execute("DROP TABLE IF EXISTS class_students CASCADE;")
    op.execute("DROP TABLE IF EXISTS class_schedules CASCADE;")
    op.execute("DROP TABLE IF EXISTS class_reschedules CASCADE;")
    op.execute("DROP TABLE IF EXISTS classes CASCADE;")
    op.execute("DROP TABLE IF EXISTS allowed_student_emails CASCADE;")

    # Users: add serial PK, keep uuid unique, add password_hash, updated_at, new role enum
    op.execute("ALTER TABLE users ADD COLUMN user_id SERIAL;")
    op.execute("ALTER TABLE users ALTER COLUMN id SET DEFAULT gen_random_uuid();")
    op.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_pkey;")
    op.execute("ALTER TABLE users ADD CONSTRAINT pk_users_user_id PRIMARY KEY (user_id);")
    op.execute("ALTER TABLE users ADD CONSTRAINT uq_users_id UNIQUE (id);")
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(length=64), nullable=False, server_default=""),
    )
    op.add_column(
        "users",
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")
        ),
    )
    # Normalize role values and change to new enum
    op.execute("ALTER TABLE users ALTER COLUMN role TYPE text USING role::text;")
    op.execute("UPDATE users SET role = UPPER(role);")
    op.execute("ALTER TABLE users ALTER COLUMN role TYPE role_enum USING role::role_enum;")

    # Students: add serial PK, uuid unique, new fields, loosen roll_no
    op.execute("ALTER TABLE students ADD COLUMN student_id SERIAL;")
    op.execute("CREATE SEQUENCE IF NOT EXISTS students_student_id_seq OWNED BY students.student_id;")
    op.execute("ALTER TABLE students ALTER COLUMN student_id SET DEFAULT nextval('students_student_id_seq');")
    op.execute("ALTER TABLE students ALTER COLUMN id SET DEFAULT gen_random_uuid();")
    op.execute("ALTER TABLE students ALTER COLUMN roll_no DROP NOT NULL;")
    op.add_column("students", sa.Column("university_roll", sa.String(), nullable=True))
    op.add_column("students", sa.Column("batch", sa.String(), nullable=True))
    op.add_column("students", sa.Column("section_id", sa.Integer(), nullable=True))
    op.execute("ALTER TABLE students ALTER COLUMN semester TYPE INTEGER USING NULLIF(semester,'')::integer;")
    op.execute("ALTER TABLE students DROP CONSTRAINT IF EXISTS students_pkey;")
    op.execute("ALTER TABLE students ADD CONSTRAINT pk_students_student_id PRIMARY KEY (student_id);")
    op.execute("ALTER TABLE students ADD CONSTRAINT uq_students_uuid UNIQUE (id);")
    # Backfill university_roll from roll_no or generated fallback, then enforce constraints
    op.execute(
        """
        UPDATE students 
        SET university_roll = COALESCE(roll_no, CONCAT('TEMP_', id::text))
        WHERE university_roll IS NULL;
        """
    )
    op.execute("ALTER TABLE students ALTER COLUMN university_roll SET NOT NULL;")
    op.execute("ALTER TABLE students ADD CONSTRAINT uq_students_university_roll UNIQUE (university_roll);")

    # Courses
    op.create_table(
        "courses",
        sa.Column("course_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_code", sa.String(), nullable=False, unique=True),
        sa.Column("course_name", sa.String(), nullable=False),
        sa.Column("department", sa.String(), nullable=False),
        sa.Column("is_elective", sa.Boolean(), nullable=False, server_default=sa.text("FALSE")),
    )

    # Sections
    op.create_table(
        "sections",
        sa.Column("section_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("section_name", sa.String(), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("department", sa.String(), nullable=False),
    )

    # Course teachers
    op.create_table(
        "course_teachers",
        sa.Column("ct_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=True),
        sa.Column("teacher_user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=True),
        sa.Column("section_id", sa.Integer(), sa.ForeignKey("sections.section_id"), nullable=True),
    )

    # Classes (schema 1 style, teacher_user_id -> users.user_id)
    op.create_table(
        "classes",
        sa.Column("class_id", sa.dialects.postgresql.UUID(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("section", sa.String(), nullable=True),
        sa.Column("ltp_pattern", sa.String(), nullable=True),
        sa.Column("teacher_type", sa.String(), nullable=True),
        sa.Column("practical_group", sa.String(), nullable=True),
        sa.Column("teacher_user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.UniqueConstraint("teacher_user_id", "code", "section", name="uq_classes_teacher_code_section"),
    )

    # Class students
    op.create_table(
        "class_students",
        sa.Column("class_id", sa.dialects.postgresql.UUID(), sa.ForeignKey("classes.class_id"), nullable=False),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("students.student_id"), nullable=False),
        sa.Column("added_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.PrimaryKeyConstraint("class_id", "student_id", name="pk_class_students"),
    )

    # Class schedules
    op.create_table(
        "class_schedules",
        sa.Column("schedule_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("class_id", sa.dialects.postgresql.UUID(), sa.ForeignKey("classes.class_id"), nullable=False),
        sa.Column("day_of_week", sa.SmallInteger(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.UniqueConstraint("class_id", "day_of_week", name="uq_class_schedules_class_day"),
        sa.CheckConstraint("day_of_week >= 1 AND day_of_week <= 7", name="ck_class_schedules_day"),
    )

    # Class reschedules
    op.create_table(
        "class_reschedules",
        sa.Column("reschedule_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("class_id", sa.dialects.postgresql.UUID(), sa.ForeignKey("classes.class_id"), nullable=False),
        sa.Column("original_date", sa.Date(), nullable=True),
        sa.Column("original_start", sa.Time(), nullable=True),
        sa.Column("original_end", sa.Time(), nullable=True),
        sa.Column("rescheduled_date", sa.Date(), nullable=True),
        sa.Column("rescheduled_start", sa.Time(), nullable=True),
        sa.Column("rescheduled_end", sa.Time(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
    )

    # Sessions
    op.create_table(
        "sessions",
        sa.Column("session_id", sa.dialects.postgresql.UUID(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("class_id", sa.dialects.postgresql.UUID(), sa.ForeignKey("classes.class_id"), nullable=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=True),
        sa.Column("section_id", sa.Integer(), sa.ForeignKey("sections.section_id"), nullable=True),
        sa.Column("teacher_user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=True),
        sa.Column("session_date", sa.Date(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column("end_time", sa.Time(), nullable=True),
        sa.Column("topic", sa.String(), nullable=True),
        sa.Column("processed_image_url", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.UniqueConstraint("class_id", "session_date", name="uq_sessions_class_date"),
    )

    # Attendance
    op.create_table(
        "attendance",
        sa.Column("attendance_id", sa.BigInteger(), primary_key=True, autoincrement=True),
        sa.Column("session_id", sa.dialects.postgresql.UUID(), sa.ForeignKey("sessions.session_id"), nullable=False),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("students.student_id"), nullable=False),
        sa.Column(
            "status",
            sa.dialects.postgresql.ENUM(
                "PRESENT", "ABSENT", "LATE", "EXCUSED", name="attendance_status_enum", create_type=False
            ),
            nullable=False,
        ),
        sa.Column("marked_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.Column("recognized_by_ai", sa.Boolean(), nullable=True),
        sa.Column("similarity_score", sa.Numeric(5, 2), nullable=True),
        sa.UniqueConstraint("session_id", "student_id", name="uq_attendance_session_student"),
    )

    # Notifications
    op.create_table(
        "notifications",
        sa.Column("notification_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("students.student_id"), nullable=True),
        sa.Column("sender_user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column(
            "notification_type",
            sa.dialects.postgresql.ENUM(
                "ATTENDANCE", "MANUAL", "SYSTEM", name="notification_type_enum", create_type=False
            ),
            nullable=True,
        ),
        sa.Column(
            "target_role",
            sa.dialects.postgresql.ENUM(
                "ALL", "TEACHER", "HOD", "ADMIN", "STUDENT", name="target_role_enum", create_type=False
            ),
            nullable=True,
        ),
        sa.Column("attendance_threshold", sa.Float(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.text("FALSE")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
    )

    # Exam components
    op.create_table(
        "exam_components",
        sa.Column("component_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("weight", sa.Numeric(5, 2), nullable=True),
        sa.Column("max_score", sa.Numeric(5, 2), nullable=True),
    )

    # Marks
    op.create_table(
        "marks",
        sa.Column("mark_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("students.student_id"), nullable=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=True),
        sa.Column("component_id", sa.Integer(), sa.ForeignKey("exam_components.component_id"), nullable=True),
        sa.Column("score", sa.Numeric(5, 2), nullable=True),
        sa.Column("max_score", sa.Numeric(5, 2), nullable=True),
        sa.Column("evaluator_user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=True),
        sa.Column("evaluated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
    )

    # Feedback questions
    op.create_table(
        "feedback_questions",
        sa.Column("question_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=False),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("TRUE")),
    )

    # Teacher feedback
    op.create_table(
        "teacher_feedback",
        sa.Column("feedback_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("teacher_user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=True),
        sa.Column("section_id", sa.Integer(), sa.ForeignKey("sections.section_id"), nullable=True),
        sa.Column("submitted_by_student_id", sa.Integer(), sa.ForeignKey("students.student_id"), nullable=True),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
    )

    # Teacher feedback scores
    op.create_table(
        "teacher_feedback_scores",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("feedback_id", sa.Integer(), sa.ForeignKey("teacher_feedback.feedback_id"), nullable=False),
        sa.Column("question_id", sa.Integer(), sa.ForeignKey("feedback_questions.question_id"), nullable=False),
        sa.Column("score", sa.Numeric(5, 2), nullable=True),
    )

    # Elective enrollments
    op.create_table(
        "elective_enrollments",
        sa.Column("enrollment_id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("students.student_id"), nullable=True),
        sa.Column("course_id", sa.Integer(), sa.ForeignKey("courses.course_id"), nullable=True),
        sa.Column("section_id", sa.Integer(), sa.ForeignKey("sections.section_id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
    )

    # Notification users
    op.create_table(
        "notification_users",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("notification_id", sa.Integer(), sa.ForeignKey("notifications.notification_id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=False),
    )

    # Read receipts
    op.create_table(
        "read_receipts",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("notification_id", sa.Integer(), sa.ForeignKey("notifications.notification_id"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.user_id"), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
    )

    # Update students.section_id FK to sections
    op.create_foreign_key(
        "fk_students_section_id", "students", "sections", ["section_id"], ["section_id"]
    )

    # Recreate attendance summary view
    op.execute(
        """
        CREATE OR REPLACE VIEW v_student_attendance_summary AS
        SELECT 
            cs.class_id,
            cs.student_id,
            s.university_roll,
            s.name AS student_name,
            COUNT(a.attendance_id) FILTER (WHERE a.status IN ('PRESENT','LATE')) AS present_count,
            COUNT(a.attendance_id) AS total_count,
            CASE 
                WHEN COUNT(a.attendance_id) > 0 
                THEN ROUND((COUNT(a.attendance_id) FILTER (WHERE a.status IN ('PRESENT','LATE'))::numeric / COUNT(a.attendance_id)::numeric) * 100, 2)
                ELSE 0 
            END AS percentage
        FROM class_students cs
        JOIN students s ON cs.student_id = s.student_id
        LEFT JOIN sessions sess ON sess.class_id = cs.class_id
        LEFT JOIN attendance a ON a.session_id = sess.session_id AND a.student_id = cs.student_id
        GROUP BY cs.class_id, cs.student_id, s.university_roll, s.name;
        """
    )


def downgrade() -> None:
    raise NotImplementedError("Downgrade not supported for merged schema")
