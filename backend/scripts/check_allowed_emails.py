"""
Script to check allowed emails in the database.
Can be run locally or on Cloud Run.
"""
import sys
import os
from sqlalchemy.orm import Session

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import SessionLocal
from app.models.user import AllowedEmail, AllowedStudentEmail


def check_allowed_emails():
    """Check and display all allowed emails."""
    db: Session = SessionLocal()
    
    try:
        # Query allowed emails (teachers/admins)
        teacher_emails = db.query(AllowedEmail).order_by(AllowedEmail.email).all()
        
        print("=" * 60)
        print("ALLOWED EMAILS (Teachers/Admins)")
        print("=" * 60)
        if teacher_emails:
            for email in teacher_emails:
                print(f"  - {email.email} ({email.role.value}) - {email.name}")
        else:
            print("  No emails found!")
        print(f"\nTotal: {len(teacher_emails)} emails")
        
        # Query allowed student emails
        student_emails = db.query(AllowedStudentEmail).order_by(AllowedStudentEmail.email).all()
        
        print("\n" + "=" * 60)
        print("ALLOWED STUDENT EMAILS")
        print("=" * 60)
        if student_emails:
            for email in student_emails:
                print(f"  - {email.email} - {email.name or 'N/A'}")
        else:
            print("  No emails found!")
        print(f"\nTotal: {len(student_emails)} emails")
        
        print("\n✅ Database query successful!")
        
    except Exception as e:
        print(f"\n❌ Error querying database: {e}")
        import traceback
        traceback.print_exc()
        return False
        
    finally:
        db.close()
    
    return True


if __name__ == "__main__":
    print("Checking allowed emails in database...\n")
    success = check_allowed_emails()
    sys.exit(0 if success else 1)

