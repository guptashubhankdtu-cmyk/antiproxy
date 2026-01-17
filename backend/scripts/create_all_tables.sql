-- Create extension for UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create ENUM types
DO $$ BEGIN
    CREATE TYPE userrole AS ENUM ('teacher', 'admin', 'student');
EXCEPTION
    WHEN duplicate_object THEN 
        BEGIN
            ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'student';
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
END $$;

DO $$ BEGIN
    CREATE TYPE attendancestatus AS ENUM ('present', 'absent', 'late', 'excused');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create allowed_emails table
CREATE TABLE IF NOT EXISTS allowed_emails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT NOT NULL UNIQUE,
    name TEXT,
    role userrole NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_allowed_emails_email ON allowed_emails(email);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role userrole NOT NULL,
    department TEXT,
    employee_id TEXT,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_users_email ON users(email);

-- Create students table
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    roll_no TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    photo_url TEXT,
    program TEXT,
    sp_code TEXT,
    semester TEXT,
    status TEXT,
    duration TEXT,
    email TEXT,
    dtu_email TEXT,
    phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_students_roll_no ON students(roll_no);
CREATE INDEX IF NOT EXISTS ix_students_email ON students(email);
CREATE INDEX IF NOT EXISTS ix_students_dtu_email ON students(dtu_email);

-- Create allowed_student_emails table
CREATE TABLE IF NOT EXISTS allowed_student_emails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT,
    dtu_email TEXT,
    roll_no TEXT,
    name TEXT,
    batch TEXT,
    department TEXT,
    program TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_allowed_student_emails_email ON allowed_student_emails(email);
CREATE INDEX IF NOT EXISTS ix_allowed_student_emails_dtu_email ON allowed_student_emails(dtu_email);

-- Create classes table
CREATE TABLE IF NOT EXISTS classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    section TEXT NOT NULL,
    ltp_pattern TEXT,
    teacher_type TEXT,
    practical_group TEXT,
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT uq_teacher_class_section UNIQUE (teacher_id, code, section)
);
CREATE INDEX IF NOT EXISTS ix_classes_teacher_id ON classes(teacher_id);

-- Create class_schedules table
CREATE TABLE IF NOT EXISTS class_schedules (
    id BIGSERIAL PRIMARY KEY,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week >= 1 AND day_of_week <= 7),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CONSTRAINT uq_class_schedule_day UNIQUE (class_id, day_of_week)
);

-- Create class_reschedules table
CREATE TABLE IF NOT EXISTS class_reschedules (
    id BIGSERIAL PRIMARY KEY,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    original_date DATE NOT NULL,
    original_start_time TIME NOT NULL,
    original_end_time TIME NOT NULL,
    rescheduled_date DATE NOT NULL,
    rescheduled_start_time TIME NOT NULL,
    rescheduled_end_time TIME NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create class_students table (many-to-many)
CREATE TABLE IF NOT EXISTS class_students (
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    PRIMARY KEY (class_id, student_id)
);
CREATE INDEX IF NOT EXISTS ix_class_students_student_id ON class_students(student_id);

-- Create attendance_sessions table
CREATE TABLE IF NOT EXISTS attendance_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    session_date DATE NOT NULL,
    processed_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    CONSTRAINT uq_session_class_date UNIQUE (class_id, session_date)
);
CREATE INDEX IF NOT EXISTS ix_sessions_class_date ON attendance_sessions(class_id, session_date);

-- Create attendance_statuses table
CREATE TABLE IF NOT EXISTS attendance_statuses (
    session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id),
    status attendancestatus NOT NULL,
    recognized_by_ai BOOLEAN NOT NULL DEFAULT FALSE,
    similarity_score NUMERIC(5, 2),
    PRIMARY KEY (session_id, student_id)
);
CREATE INDEX IF NOT EXISTS ix_statuses_student_id ON attendance_statuses(student_id);

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    attendance_threshold FLOAT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT notifications_type_check CHECK (notification_type IN ('attendance', 'manual', 'system'))
);
CREATE INDEX IF NOT EXISTS idx_notifications_student_id ON notifications(student_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Create view for student attendance summary
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
GROUP BY cs.class_id, cs.student_id, s.roll_no, s.name;

-- Create alembic_version table
CREATE TABLE IF NOT EXISTS alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Insert version
INSERT INTO alembic_version (version_num) VALUES ('001_initial')
ON CONFLICT (version_num) DO NOTHING;

