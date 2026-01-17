"""
Script to create missing tables (allowed_student_emails and notifications).
Run this after setup_gcp_database.py if these tables are missing.
"""
import psycopg2

# GCP Cloud SQL Connection Details
GCP_DB_CONFIG = {
    "host": "35.244.49.80",
    "port": 5432,
    "database": "db-antiproxy",
    "user": "shubhank165",
    "password": "shubhank@165google"
}

# SQL to create missing tables
MISSING_TABLES_SQL = """
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
"""

def create_missing_tables():
    """Create missing tables in the database."""
    
    print("=" * 60)
    print("  Creating Missing Tables")
    print("=" * 60)
    print()
    
    print(f"Connecting to GCP Cloud SQL at {GCP_DB_CONFIG['host']}...")
    
    try:
        conn = psycopg2.connect(**GCP_DB_CONFIG)
        conn.autocommit = False
        cursor = conn.cursor()
        
        print("✅ Connected successfully!\n")
        
        print("Creating missing tables...")
        cursor.execute(MISSING_TABLES_SQL)
        conn.commit()
        
        print("✅ Tables created successfully!\n")
        
        # Verify tables exist
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('allowed_student_emails', 'notifications')
            ORDER BY table_name
        """)
        tables = cursor.fetchall()
        
        print("✅ Verified tables exist:")
        for table in tables:
            print(f"   - {table[0]}")
        
        conn.close()
        print("\n✅ Done!")
        
    except psycopg2.OperationalError as e:
        print(f"\n❌ Connection failed: {e}")
        print("\nMake sure your IP is authorized in GCP Cloud SQL.")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        if 'conn' in locals():
            conn.rollback()
        raise


if __name__ == "__main__":
    create_missing_tables()

