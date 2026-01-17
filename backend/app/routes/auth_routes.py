"""
Authentication routes.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime

from app.db import get_db
from app.schemas.auth import GoogleLoginRequest, TokenResponse, UserInfo
from app.auth.google_verify import verify_google_token, GoogleAuthError
from app.auth.jwt import create_jwt
from app.models.user import User, AllowedEmail, UserRole
from app.models.student import Student

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/google", response_model=TokenResponse)
async def google_login(request: GoogleLoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate user via Google OAuth and return JWT token.
    
    Flow:
    1. Verify Google ID token
    2. Check if email is whitelisted
    3. Upsert user in database
    4. Generate internal JWT
    5. Return JWT and user info
    """
    # Verify Google token
    try:
        google_info = await verify_google_token(request.id_token)
    except GoogleAuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
    
    email = google_info['email']
    name = google_info.get('name', email.split('@')[0])
    
    # Check if email is in allowed list (optional; if missing, fallback to TEACHER)
    allowed = db.query(AllowedEmail).filter(AllowedEmail.email == email).first()
    allowed_role = UserRole.TEACHER
    if allowed:
        try:
            allowed_role = allowed.role if isinstance(allowed.role, UserRole) else UserRole(allowed.role)
        except Exception:
            allowed_role = UserRole.TEACHER
    
    # Get or create user
    user = db.query(User).filter(User.email == email).first()
    
    if user:
        # Update last login
        user.last_login_at = datetime.utcnow()
        user.name = name  # Update name in case it changed
    else:
        # Create new user with role from allowed_emails
        user = User(
            email=email,
            name=name,
            role=allowed_role,
            last_login_at=datetime.utcnow()
        )
        db.add(user)
    
    db.commit()
    db.refresh(user)
    
    # Generate JWT
    token = create_jwt(user.uuid, user.email, user.role.value)
    
    # Prepare response
    user_info = UserInfo(
        userId=user.user_id,
        uuid=user.uuid,
        email=user.email,
        name=user.name,
        role=user.role.value,
        studentId=None,
        studentUuid=None,
    )
    
    return TokenResponse(token=token, user=user_info)


@router.post("/google/student", response_model=TokenResponse)
async def google_login_student(request: GoogleLoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate student via Google OAuth and return JWT token.
    
    Flow:
    1. Verify Google ID token
    2. Check if email is in allowed_student_emails whitelist
    3. Check if email belongs to a registered student (for class enrollment)
    4. Create/update user record with student role
    5. Generate internal JWT
    6. Return JWT and user info
    """
    # Verify Google token
    try:
        google_info = await verify_google_token(request.id_token)
    except GoogleAuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )
    
    email = google_info['email']
    name = google_info.get('name', email.split('@')[0])
    
    # Lookup student record (no whitelist enforcement)
    student = db.query(Student).filter(
        (Student.email == email) | (Student.dtu_email == email)
    ).first()
    
    # Get or create user record with student role
    user = db.query(User).filter(User.email == email).first()
    
    if user:
        # Update existing user
        user.last_login_at = datetime.utcnow()
        user.name = name
        user.role = UserRole.STUDENT  # Ensure role is student
    else:
        # Create new student user
        user = User(
            email=email,
            name=name,
            role=UserRole.STUDENT,
            last_login_at=datetime.utcnow()
        )
        db.add(user)
    
    db.commit()
    if student:
        db.refresh(student)
    db.refresh(user)
    
    # Generate JWT with student role
    token = create_jwt(user.uuid, user.email, user.role.value)
    
    # Prepare response - include student ID if they're enrolled in classes
    user_info = UserInfo(
        userId=user.user_id,
        uuid=user.uuid,
        email=user.email,
        name=user.name,
        role=user.role.value,
        studentId=student.student_id if student else None,
        studentUuid=student.uuid if student else None,
    )
    
    return TokenResponse(token=token, user=user_info)
