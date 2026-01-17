"""
Setup script to initialize GCP Cloud SQL database with all tables.
Runs migrations directly using SQL, bypassing alembic configparser issues.
"""
import psycopg2
from datetime import datetime
import uuid

# GCP Cloud SQL Connection Details
GCP_DB_CONFIG = {
    "host": "35.244.49.80",
    "port": 5432,
    "database": "db-antiproxy",
    "user": "shubhank165",
    "password": "shubhank@165google"
}

# Allowed emails to seed
ALLOWED_EMAILS = [
    {"email": "mayank.jangid.moon@gmail.com", "name": "Mayank Jangid", "role": "teacher"},
    {"email": "vivjain2007@gmail.com", "name": "Vivaan Jain", "role": "teacher"},
    {"email": "aaarat72@gmail.com", "name": "Aaarat Chaddha", "role": "teacher"},
    {"email": "rudranshsinghrathore15@gmail.com", "name": "Rudransh Singh Rathore", "role": "teacher"},
    {"email": "007aryansood@gmail.com", "name": "Aryan Sood", "role": "teacher"},
    {"email": "aforaarushianand@gmail.com", "name": "Aarushi Anand", "role": "teacher"},
    {"email": "admin@dtu.ac.in", "name": "System Administrator", "role": "admin"},
    {"email": "shubhankgupta165@gmail.com", "name": "Shubhank Gupta", "role": "teacher"},
    {"email": "teacher1@dtu.ac.in", "name": "Dr. Faculty Member 1", "role": "teacher"},
    {"email": "teacher2@dtu.ac.in", "name": "Dr. Faculty Member 2", "role": "teacher"},
]

# SQL to create all tables and types
SCHEMA_SQL = """
-- Create extension for UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create ENUM types
DO $$ BEGIN
    CREATE TYPE userrole AS ENUM ('teacher', 'admin', 'student');
EXCEPTION
    WHEN duplicate_object THEN 
        -- Add 'student' if enum exists but doesn't have it
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

-- Create alembic_version table to mark migration as complete
CREATE TABLE IF NOT EXISTS alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Insert version (or update if exists)
INSERT INTO alembic_version (version_num) VALUES ('001_initial')
ON CONFLICT (version_num) DO NOTHING;
"""


def setup_database():
    """Set up the GCP database with all tables and seed allowed emails."""
    
    print("=" * 60)
    print("  GCP Cloud SQL - Database Setup")
    print("=" * 60)
    print()
    
    print(f"Connecting to GCP Cloud SQL at {GCP_DB_CONFIG['host']}...")
    
    try:
        conn = psycopg2.connect(**GCP_DB_CONFIG)
        conn.autocommit = False
        cursor = conn.cursor()
        
        print("✅ Connected successfully!\n")
        
        # Step 1: Create schema
        print("Step 1: Creating database schema...")
        cursor.execute(SCHEMA_SQL)
        conn.commit()
        print("✅ Schema created successfully!\n")
        
        # Step 2: Seed allowed emails
        print("Step 2: Seeding allowed_emails...")
        now = datetime.utcnow()
        
        for email_data in ALLOWED_EMAILS:
            email = email_data["email"].strip()
            name = email_data["name"]
            role = email_data["role"]
            
            cursor.execute(
                "SELECT id FROM allowed_emails WHERE email = %s",
                (email,)
            )
            existing = cursor.fetchone()
            
            if existing:
                cursor.execute(
                    """
                    UPDATE allowed_emails 
                    SET name = %s, role = %s, updated_at = %s 
                    WHERE email = %s
                    """,
                    (name, role, now, email)
                )
                print(f"  Updated: {email} ({role})")
            else:
                new_id = str(uuid.uuid4())
                cursor.execute(
                    """
                    INSERT INTO allowed_emails (id, email, name, role, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (new_id, email, name, role, now, now)
                )
                print(f"  Added: {email} ({role})")
        
        conn.commit()
        
        # Step 3: Verify
        print("\nStep 3: Verifying setup...")
        
        cursor.execute("""
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        tables = cursor.fetchall()
        print(f"\n  Tables created: {len(tables)}")
        for t in tables:
            print(f"    - {t[0]}")
        
        cursor.execute("SELECT COUNT(*) FROM allowed_emails")
        count = cursor.fetchone()[0]
        print(f"\n  Allowed emails: {count}")
        
        print("\n" + "=" * 60)
        print("  ✅ GCP Database Setup Complete!")
        print("=" * 60)
        print("\nYour GCP backend is now ready to use.")
        print("You can now log in with any of the seeded email addresses.")
        
    except psycopg2.OperationalError as e:
        print(f"\n❌ Connection failed: {e}")
        print("\nTroubleshooting:")
        print("  1. Make sure your IP is added to 'Authorised networks' in GCP")
        print("  2. Wait a minute after adding for changes to propagate")
        print("  3. Check that the Cloud SQL instance is running")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        if 'conn' in locals():
            conn.rollback()
        raise
        
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
            print("\nConnection closed.")


if __name__ == "__main__":
    setup_database()

