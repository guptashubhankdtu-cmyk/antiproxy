"""
 script to populate allowed_student_emails table.
This table controls which students can log into the student app.

Usage:
    python scripts/_allowed_student_emails.py

Students can be added:
1. Manually via this script
2. Automatically when a teacher uploads a CSV with student emails
"""
import psycopg2
from datetime import datetime, timezone
import uuid
import sys

# GCP Cloud SQL Connection Details
GCP_DB_CONFIG = {
    "host": "35.244.49.80",
    "port": 5432,
    "database": "db-antiproxy",
    "user": "shubhank165",
    "password": "shubhank@165google"
}

# ============================================================
# ADD STUDENT EMAILS HERE
# ============================================================
# Each student needs at least an email. Other fields are optional.
# 
# Fields:
#   - email: Primary email (required) - used for Google Sign-In
#   - dtu_email: Institutional email (optional)
#   - roll_no: Student roll number (optional)
#   - name: Student name (optional)
#   - batch: Batch year like "2024" (optional)
#   - department: Department like "CSE", "ECE" (optional)
#   - program: Program like "B.Tech", "M.Tech" (optional)
#
ALLOWED_STUDENT_EMAILS = [
    # === TEST EMAILS (Same as teachers for testing) ===
    {
        "email": "mayank.jangid.moon@gmail.com",
        "name": "Mayank Jangid (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "vivaanjaindps@gmail.com",
        "name": "Vivaan Jain (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "aliothmerak123@gmail.com",
        "name": "Aaarat Chaddha (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "rudranshsinghrathore.official@gmail.com",
        "name": "Rudransh Singh Rathore (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "aryansood005@gmail.com",
        "name": "Aryan Sood (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "aarushipadhle@gmail.com",
        "name": "Aarushi Anand (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "guptashubhankdtu@gmail.com",
        "name": "Shubhank Gupta (Test Student)",
        "batch": "2024",
        "department": "CSE"
    },
    {
        "email": "shubhanktopjeerankaspirant165@gmail.com",
        "name": "Shubhank Test 1",
        "roll_no": "24/CSE/01",
        "batch": "2024",
        "department": "CSE",
        "program": "B.Tech"
    },
    {
        "email": "jeeprep165@gmail.com",
        "name": "Shubhank Test 2",
        "roll_no": "24/CSE/02",
        "batch": "2024",
        "department": "CSE",
        "program": "B.Tech"
    },
    {
        "email": "shubhankgupta1j2005@gmail.com",
        "name": "Shubhank Test 3",
        "roll_no": "24/CSE/03",
        "batch": "2024",
        "department": "CSE",
        "program": "B.Tech"
    },

    # === ADD REAL STUDENT EMAILS BELOW ===
    # Example:
    # {
    #     "email": "student@gmail.com",
    #     "dtu_email": "student@dtu.ac.in",
    #     "roll_no": "2K24/CO/123",
    #     "name": "Student Name",
    #     "batch": "2024",
    #     "department": "COE",
    #     "program": "B.Tech"
    # },
    {
        "email": "vivjain2007@gmail.com",
        "name": "Viv Jain",
        "batch": "2024",
        "department": "CSE",
        "program": "B.Tech"
    },
]


def _allowed_student_emails(emails_to_add=None):
    """
    Add student emails to the allowed_student_emails table.
    
    Args:
        emails_to_add: Optional list of email dicts. If None, uses ALLOWED_STUDENT_EMAILS.
    """
    if emails_to_add is None:
        emails_to_add = ALLOWED_STUDENT_EMAILS
    
    print(f"Connecting to GCP Cloud SQL at {GCP_DB_CONFIG['host']}...")
    
    try:
        conn = psycopg2.connect(**GCP_DB_CONFIG)
        conn.autocommit = False
        cursor = conn.cursor()
        
        print("✅ Connected successfully!\n")
        print("ing allowed_student_emails table...\n")
        
        now = datetime.now(timezone.utc)
        added = 0
        updated = 0
        
        for student_data in emails_to_add:
            email = student_data.get("email", "").strip()
            if not email:
                print(f"  ⚠️  Skipping entry with no email")
                continue
            
            dtu_email = student_data.get("dtu_email", "").strip() or None
            roll_no = student_data.get("roll_no", "").strip() or None
            name = student_data.get("name", "").strip() or None
            batch = student_data.get("batch", "").strip() or None
            department = student_data.get("department", "").strip() or None
            program = student_data.get("program", "").strip() or None
            
            # Check if email already exists
            cursor.execute(
                "SELECT id FROM allowed_student_emails WHERE email = %s",
                (email,)
            )
            existing = cursor.fetchone()
            
            if existing:
                # Update existing record
                cursor.execute(
                    """
                    UPDATE allowed_student_emails 
                    SET dtu_email = COALESCE(%s, dtu_email),
                        roll_no = COALESCE(%s, roll_no),
                        name = COALESCE(%s, name),
                        batch = COALESCE(%s, batch),
                        department = COALESCE(%s, department),
                        program = COALESCE(%s, program),
                        updated_at = %s 
                    WHERE email = %s
                    """,
                    (dtu_email, roll_no, name, batch, department, program, now, email)
                )
                print(f"  Updated: {email}")
                updated += 1
            else:
                # Insert new record
                new_id = str(uuid.uuid4())
                cursor.execute(
                    """
                    INSERT INTO allowed_student_emails 
                    (id, email, dtu_email, roll_no, name, batch, department, program, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (new_id, email, dtu_email, roll_no, name, batch, department, program, now, now)
                )
                print(f"  Added: {email}")
                added += 1
        
        conn.commit()
        
        # Show summary
        cursor.execute("SELECT COUNT(*) FROM allowed_student_emails")
        total = cursor.fetchone()[0]
        
        print(f"\n✅ Done! Added: {added}, Updated: {updated}")
        print(f"   Total allowed student emails: {total}")
        
    except psycopg2.OperationalError as e:
        print(f"\n❌ Connection failed: {e}")
        print("\nMake sure your IP is authorized in GCP Cloud SQL.")
        
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


def add_single_student(email, name=None, roll_no=None, dtu_email=None, 
                       batch=None, department=None, program=None):
    """
    Convenience function to add a single student.
    
    Example:
        add_single_student(
            email="student@gmail.com",
            name="Student Name",
            roll_no="2K24/CO/123"
        )
    """
    _allowed_student_emails([{
        "email": email,
        "name": name,
        "roll_no": roll_no,
        "dtu_email": dtu_email,
        "batch": batch,
        "department": department,
        "program": program
    }])


def list_allowed_students():
    """List all currently allowed student emails."""
    try:
        conn = psycopg2.connect(**GCP_DB_CONFIG)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT email, dtu_email, roll_no, name, batch, department 
            FROM allowed_student_emails 
            ORDER BY email
        """)
        rows = cursor.fetchall()
        
        print(f"\n=== Allowed Student Emails ({len(rows)} total) ===\n")
        for row in rows:
            email, dtu_email, roll_no, name, batch, dept = row
            print(f"  {email}")
            if name:
                print(f"    Name: {name}")
            if roll_no:
                print(f"    Roll: {roll_no}")
            if dtu_email:
                print(f"    DTU Email: {dtu_email}")
            if batch or dept:
                print(f"    {batch or ''} {dept or ''}")
            print()
        
        conn.close()
        
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        list_allowed_students()
    else:
        print("=" * 60)
        print("   Allowed Student Emails")
        print("=" * 60)
        print()
        _allowed_student_emails()
        print()
        print("To list all allowed students, run:")
        print("  python scripts/_allowed_student_emails.py --list")

