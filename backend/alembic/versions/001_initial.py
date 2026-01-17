"""Initial schema with all tables and enums

Revision ID: 001_initial
Revises: 
Create Date: 2025-10-26 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001_initial'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create ENUM types (with proper checkfirst)
    connection = op.get_bind()
    
    # Check if userrole enum exists
    result = connection.execute(sa.text(
        "SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'userrole')"
    ))
    if not result.scalar():
        user_role_enum = postgresql.ENUM('teacher', 'admin', 'student', name='userrole', create_type=False)
        user_role_enum.create(connection)
    else:
        # If enum exists, ensure 'student' value is added
        connection.execute(sa.text(
            "ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'student'"
        ))
    
    # Check if attendancestatus enum exists
    result = connection.execute(sa.text(
        "SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendancestatus')"
    ))
    if not result.scalar():
        attendance_status_enum = postgresql.ENUM('present', 'absent', 'late', 'excused', name='attendancestatus', create_type=False)
        attendance_status_enum.create(connection)
    
    # Create allowed_emails table
    op.create_table(
        'allowed_emails',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('email', sa.Text(), nullable=False),
        sa.Column('name', sa.Text(), nullable=True),
        sa.Column('role', user_role_enum, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email')
    )
    op.create_index('ix_allowed_emails_email', 'allowed_emails', ['email'])
    
    # Create users table
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('email', sa.Text(), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('role', user_role_enum, nullable=False),
        sa.Column('department', sa.Text(), nullable=True),
        sa.Column('employee_id', sa.Text(), nullable=True),
        sa.Column('last_login_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email')
    )
    op.create_index('ix_users_email', 'users', ['email'])
    
    # Create students table
    op.create_table(
        'students',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('roll_no', sa.Text(), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('photo_url', sa.Text(), nullable=True),
        sa.Column('program', sa.Text(), nullable=True),
        sa.Column('sp_code', sa.Text(), nullable=True),
        sa.Column('semester', sa.Text(), nullable=True),
        sa.Column('status', sa.Text(), nullable=True),
        sa.Column('duration', sa.Text(), nullable=True),
        sa.Column('email', sa.Text(), nullable=True),
        sa.Column('dtu_email', sa.Text(), nullable=True),
        sa.Column('phone', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('roll_no')
    )
    op.create_index('ix_students_roll_no', 'students', ['roll_no'])
    
    # Create classes table
    op.create_table(
        'classes',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('code', sa.Text(), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('section', sa.Text(), nullable=False),
        sa.Column('ltp_pattern', sa.Text(), nullable=True),
        sa.Column('teacher_type', sa.Text(), nullable=True),
        sa.Column('practical_group', sa.Text(), nullable=True),
        sa.Column('teacher_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['teacher_id'], ['users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('teacher_id', 'code', 'section', name='uq_teacher_class_section')
    )
    op.create_index('ix_classes_teacher_id', 'classes', ['teacher_id'])
    
    # Create class_schedules table
    op.create_table(
        'class_schedules',
        sa.Column('id', sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column('class_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('day_of_week', sa.SmallInteger(), nullable=False),
        sa.Column('start_time', sa.Time(), nullable=False),
        sa.Column('end_time', sa.Time(), nullable=False),
        sa.CheckConstraint('day_of_week >= 1 AND day_of_week <= 7', name='ck_day_of_week_range'),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('class_id', 'day_of_week', name='uq_class_schedule_day')
    )
    
    # Create class_reschedules table
    op.create_table(
        'class_reschedules',
        sa.Column('id', sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column('class_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('original_date', sa.Date(), nullable=False),
        sa.Column('original_start_time', sa.Time(), nullable=False),
        sa.Column('original_end_time', sa.Time(), nullable=False),
        sa.Column('rescheduled_date', sa.Date(), nullable=False),
        sa.Column('rescheduled_start_time', sa.Time(), nullable=False),
        sa.Column('rescheduled_end_time', sa.Time(), nullable=False),
        sa.Column('reason', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create class_students table (many-to-many)
    op.create_table(
        'class_students',
        sa.Column('class_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('student_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('added_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id']),
        sa.PrimaryKeyConstraint('class_id', 'student_id')
    )
    op.create_index('ix_class_students_student_id', 'class_students', ['student_id'])
    
    # Create attendance_sessions table
    op.create_table(
        'attendance_sessions',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('class_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('teacher_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('session_date', sa.Date(), nullable=False),
        sa.Column('processed_image_url', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['teacher_id'], ['users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('class_id', 'session_date', name='uq_session_class_date')
    )
    op.create_index('ix_sessions_class_date', 'attendance_sessions', ['class_id', 'session_date'])
    
    # Create attendance_statuses table
    op.create_table(
        'attendance_statuses',
        sa.Column('session_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('student_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('status', attendance_status_enum, nullable=False),
        sa.Column('recognized_by_ai', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('similarity_score', sa.Numeric(5, 2), nullable=True),
        sa.ForeignKeyConstraint(['session_id'], ['attendance_sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id']),
        sa.PrimaryKeyConstraint('session_id', 'student_id')
    )
    op.create_index('ix_statuses_student_id', 'attendance_statuses', ['student_id'])
    
    # Create view for student attendance summary
    op.execute("""
        CREATE OR REPLACE VIEW v_student_attendance_summary AS
        SELECT 
            cs.class_id,
            cs.student_id,
            s.roll_no,
            s.name as student_name,
            COUNT(ast.session_id) FILTER (WHERE ast.status IN ('present', 'late')) as present_count,
            COUNT(ast.session_id) as total_count,
            CASE 
                WHEN COUNT(ast.session_id) > 0 
                THEN ROUND((COUNT(ast.session_id) FILTER (WHERE ast.status IN ('present', 'late'))::numeric / COUNT(ast.session_id)::numeric) * 100, 2)
                ELSE 0 
            END as percentage
        FROM class_students cs
        JOIN students s ON cs.student_id = s.id
        LEFT JOIN attendance_sessions asess ON asess.class_id = cs.class_id
        LEFT JOIN attendance_statuses ast ON ast.session_id = asess.id AND ast.student_id = cs.student_id
        GROUP BY cs.class_id, cs.student_id, s.roll_no, s.name
    """)


def downgrade() -> None:
    # Drop view
    op.execute("DROP VIEW IF EXISTS v_student_attendance_summary")
    
    # Drop tables in reverse order
    op.drop_index('ix_statuses_student_id', 'attendance_statuses')
    op.drop_table('attendance_statuses')
    
    op.drop_index('ix_sessions_class_date', 'attendance_sessions')
    op.drop_table('attendance_sessions')
    
    op.drop_index('ix_class_students_student_id', 'class_students')
    op.drop_table('class_students')
    
    op.drop_table('class_reschedules')
    op.drop_table('class_schedules')
    
    op.drop_index('ix_classes_teacher_id', 'classes')
    op.drop_table('classes')
    
    op.drop_index('ix_students_roll_no', 'students')
    op.drop_table('students')
    
    op.drop_index('ix_users_email', 'users')
    op.drop_table('users')
    
    op.drop_index('ix_allowed_emails_email', 'allowed_emails')
    op.drop_table('allowed_emails')
    
    # Drop ENUM types
    sa.Enum(name='attendancestatus').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='userrole').drop(op.get_bind(), checkfirst=True)
