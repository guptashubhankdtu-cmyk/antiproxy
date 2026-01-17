"""
 script to populate allowed_emails table with initial faculty/admin emails.
"""
import sys
import os
from sqlalchemy.orm import Session

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import SessionLocal
from app.models.user import AllowedEmail, UserRole


def _allowed_emails():
    """
    Populate the allowed_emails table with initial faculty/admin emails.
    
    Modify this list to include your actual faculty emails.
    """
    db: Session = SessionLocal()
    
    try:
        # Sample allowed emails (replace with actual faculty emails)
        allowed_emails = [
            {
                "email": "mayank.jangid.moon@gmail.com",
                "name": "Mayank Jangid",
                "role": UserRole.TEACHER
            },
            {
                "email": "vivjain2007@gmail.com",
                "name": "Vivaan Jain",
                "role": UserRole.TEACHER
            },
            {
                "email": "aaarat72@gmail.com",
                "name": "Aaarat Chaddha",
                "role": UserRole.TEACHER
            },
            {
                "email": "rudranshsinghrathore15@gmail.com",
                "name": "Rudransh Singh Rathore",
                "role": UserRole.TEACHER
            },
            {
                "email": "007aryansood@gmail.com ",
                "name": "Aryan Sood",
                "role": UserRole.TEACHER
            },
            {
                "email": "aforaarushianand@gmail.com",
                "name": "Aarushi Anand",
                "role": UserRole.TEACHER
            },
            {
                "email": "admin@dtu.ac.in",
                "name": "System Administrator",
                "role": UserRole.ADMIN
            },
            {
                "email": "shubhankgupta165@gmail.com",
                "name": "Shubhank Gupta",
                "role": UserRole.TEACHER
            },
            {
                "email": "teacher1@dtu.ac.in",
                "name": "Dr. Faculty Member 1",
                "role": UserRole.TEACHER
            },
            {
                "email": "teacher2@dtu.ac.in",
                "name": "Dr. Faculty Member 2",
                "role": UserRole.TEACHER
            },
            # Add more faculty emails here
        ]
        
        for email_data in allowed_emails:
            # Check if email already exists
            existing = db.query(AllowedEmail).filter(
                AllowedEmail.email == email_data["email"]
            ).first()
            
            if existing:
                # Update existing record
                existing.name = email_data["name"]
                existing.role = email_data["role"]
                db.add(existing)
                print(f"Updated {email_data['email']} ({email_data['role'].value})")
            else:
                # Create new allowed email
                allowed_email = AllowedEmail(
                    email=email_data["email"],
                    name=email_data["name"],
                    role=email_data["role"]
                )
                db.add(allowed_email)
                print(f"Added {email_data['email']} ({email_data['role'].value})")
        
        db.commit()
        print("\n✅ Successfully ed allowed_emails table")
        
    except Exception as e:
        print(f"\n❌ Error ing database: {e}")
        db.rollback()
        raise
        
    finally:
        db.close()


if __name__ == "__main__":
    print("ing allowed_emails table...\n")
    _allowed_emails()
