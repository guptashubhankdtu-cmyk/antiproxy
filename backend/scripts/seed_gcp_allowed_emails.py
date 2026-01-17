"""
 script to populate allowed_emails table on GCP Cloud SQL.
Run this locally to add faculty/admin emails to the GCP database.
"""
import psycopg2
from psycopg2.extras import execute_values
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

# Allowed emails to  (same as your original  file)
ALLOWED_EMAILS = [
    {
        "email": "mayank.jangid.moon@gmail.com",
        "name": "Mayank Jangid",
        "role": "teacher"
    },
    {
        "email": "vivjain2007@gmail.com",
        "name": "Vivaan Jain",
        "role": "teacher"
    },
    {
        "email": "aaarat72@gmail.com",
        "name": "Aaarat Chaddha",
        "role": "teacher"
    },
    {
        "email": "rudranshsinghrathore15@gmail.com",
        "name": "Rudransh Singh Rathore",
        "role": "teacher"
    },
    {
        "email": "007aryansood@gmail.com",
        "name": "Aryan Sood",
        "role": "teacher"
    },
    {
        "email": "aforaarushianand@gmail.com",
        "name": "Aarushi Anand",
        "role": "teacher"
    },
    {
        "email": "admin@dtu.ac.in",
        "name": "System Administrator",
        "role": "admin"
    },
    {
        "email": "shubhankgupta165@gmail.com",
        "name": "Shubhank Gupta",
        "role": "teacher"
    },
    {
        "email": "teacher1@dtu.ac.in",
        "name": "Dr. Faculty Member 1",
        "role": "teacher"
    },
    {
        "email": "teacher2@dtu.ac.in",
        "name": "Dr. Faculty Member 2",
        "role": "teacher"
    },
]


def _allowed_emails():
    """Connect to GCP Cloud SQL and  allowed_emails table."""
    
    print(f"Connecting to GCP Cloud SQL at {GCP_DB_CONFIG['host']}...")
    
    try:
        # Connect to the database
        conn = psycopg2.connect(**GCP_DB_CONFIG)
        conn.autocommit = False
        cursor = conn.cursor()
        
        print("✅ Connected successfully!\n")
        
        # Check if table exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'allowed_emails'
            );
        """)
        table_exists = cursor.fetchone()[0]
        
        if not table_exists:
            print("❌ Table 'allowed_emails' does not exist!")
            print("   Make sure you've run the migrations on the GCP database.")
            return
        
        print("ing allowed_emails table...\n")
        
        now = datetime.utcnow()
        
        for email_data in ALLOWED_EMAILS:
            email = email_data["email"].strip()  # Remove any whitespace
            name = email_data["name"]
            role = email_data["role"]
            
            # Check if email already exists
            cursor.execute(
                "SELECT id FROM allowed_emails WHERE email = %s",
                (email,)
            )
            existing = cursor.fetchone()
            
            if existing:
                # Update existing record
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
                # Insert new record
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
        print("\n✅ Successfully ed allowed_emails table on GCP!")
        
        # Show current count
        cursor.execute("SELECT COUNT(*) FROM allowed_emails")
        count = cursor.fetchone()[0]
        print(f"   Total allowed emails in database: {count}")
        
    except psycopg2.OperationalError as e:
        print(f"\n❌ Connection failed: {e}")
        print("\nTroubleshooting:")
        print("  1. Make sure your IP (103.211.12.235) is added to 'Authorised networks' in GCP")
        print("  2. Wait a minute after adding for changes to propagate")
        print("  3. Check that the Cloud SQL instance is running")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        if conn:
            conn.rollback()
        raise
        
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
            print("\nConnection closed.")


if __name__ == "__main__":
    print("=" * 60)
    print("  GCP Cloud SQL -  Allowed Emails")
    print("=" * 60)
    print()
    _allowed_emails()

