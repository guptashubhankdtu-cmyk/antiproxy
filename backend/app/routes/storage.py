"""
Storage routes for handling file uploads to Azure Blob Storage.
"""
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status, BackgroundTasks
from typing import Annotated, Optional
from pydantic import BaseModel
import httpx
import logging

from app.auth.dependencies import get_current_user, UserContext
from app.models.user import User, UserRole
from app.services.azure_storage import azure_storage
from app.db import get_db
from app.config import settings
from sqlalchemy.orm import Session
from sqlalchemy import func
from sqlalchemy.dialects.postgresql import UUID
from app.models.student import Student
from app.models.class_model import Class

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/api/storage", tags=["storage"])


class UploadResponse(BaseModel):
    """Response for successful file upload."""
    url: str
    blob_name: str
    message: str


class SasUrlRequest(BaseModel):
    """Request for generating SAS URL."""
    container_name: str
    blob_name: str
    expiry_hours: int = 1


class SasUrlResponse(BaseModel):
    """Response with SAS URL."""
    sas_url: str
    expires_in_hours: int


# Student photo upload (accessible by admins and the student's teachers)
@router.post("/students/{roll_no}/photo", response_model=UploadResponse)
async def upload_student_photo(
    roll_no: str,
    file: Annotated[UploadFile, File(...)],
    background_tasks: BackgroundTasks,
    current_user: Annotated[UserContext, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    Upload or update a student's profile photo.
    
    Accessible by:
    - Admins (can upload for any student)
    - Teachers (can upload for students in their classes)
    """
    # Verify student exists
    student = db.query(Student).filter(Student.roll_no == roll_no).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found"
        )
    
    # Permission check
    if current_user.role != UserRole.ADMIN:
        # Check if teacher has this student in any of their classes
        from app.models.class_model import ClassStudent
        
        has_access = db.query(ClassStudent).join(Class).filter(
            Class.teacher_id == current_user.user_id,
            ClassStudent.student_id == student.id
        ).first() is not None
        
        if not has_access:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You can only upload photos for students in your classes"
            )
    
    # Validate file type
    allowed_types = ["image/jpeg", "image/png", "image/jpg"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )
    
    # Validate file size (max 5MB)
    max_size = 5 * 1024 * 1024  # 5MB
    file_data = await file.read()
    if len(file_data) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size is 5MB"
        )
    
    # Upload to Azure
    if not azure_storage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Azure Storage is not configured. Please set AZURE_STORAGE_CONNECTION_STRING in environment variables."
        )
    
    try:
        from io import BytesIO
        url = azure_storage.upload_student_photo(
            roll_no=roll_no,
            file_data=BytesIO(file_data),
            filename=file.filename,
            content_type=file.content_type
        )
        
        # Update student photo URL in database
        student.photo_url = url
        db.commit()
        
        # Trigger face embedding generation in background (non-blocking)
        if settings.face_api_service_url:
            background_tasks.add_task(
                generate_face_embedding_for_student,
                roll_no
            )
        
        return UploadResponse(
            url=url,
            blob_name=url.split('/')[-1],
            message="Student photo uploaded successfully"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )


# Student self-upload photo (students can upload their own photo)
@router.post("/students/me/photo", response_model=UploadResponse)
async def upload_my_photo(
    file: Annotated[UploadFile, File(...)],
    background_tasks: BackgroundTasks,
    current_user: Annotated[UserContext, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    Upload or update the current student's profile photo.
    
    Only accessible by students uploading their own photo.
    """
    # Verify user is a student
    if current_user.role != UserRole.STUDENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students can upload their own photos"
        )
    
    # Photo uploads disabled: short-circuit with success
    return UploadResponse(
        url="",
        blob_name="",
        message="Photo uploads are currently disabled"
    )
    
    # Find student record by email - case-insensitive
    email_lower = current_user.email.lower()
    student = db.query(Student).filter(
        (func.lower(Student.email) == email_lower) | (func.lower(Student.dtu_email) == email_lower)
    ).first()
    
    logger.info(f"Initial student lookup for {current_user.email}: {'found' if student else 'not found'}")
    
    # If student record doesn't exist, try multiple fallback strategies
    if not student:
        from app.models.user import AllowedStudentEmail
        from app.models.class_model import ClassStudent
        
        logger.info(f"Student record not found for {current_user.email}, trying fallback strategies...")
        
        email_prefix = current_user.email.split('@')[0].lower()
        
        # Strategy 1: Check allowed_student_emails
        allowed_student = db.query(AllowedStudentEmail).filter(
            (func.lower(AllowedStudentEmail.email) == email_lower) | 
            (func.lower(AllowedStudentEmail.dtu_email) == email_lower)
        ).first()
        
        if allowed_student:
            logger.info(f"Found in allowed_student_emails, roll_no: {allowed_student.roll_no}")
            # Try to find existing student by roll_no first
            if allowed_student.roll_no:
                student = db.query(Student).filter(Student.roll_no == allowed_student.roll_no).first()
                if student:
                    logger.info(f"Found existing student by roll_no: {student.roll_no}")
                    # Update email if it doesn't match
                    if student.email != current_user.email and student.dtu_email != current_user.email:
                        student.email = current_user.email
                        db.commit()
                        db.refresh(student)
                        logger.info(f"Updated student email to {current_user.email}")
            
            # If still not found, create new student record
            if not student:
                roll_no = allowed_student.roll_no or f"TEMP_{current_user.email.split('@')[0].upper()}"
                existing = db.query(Student).filter(Student.roll_no == roll_no).first()
                if existing:
                    import time
                    roll_no = f"{roll_no}_{int(time.time())}"
                
                student = Student(
                    roll_no=roll_no,
                    name=allowed_student.name or current_user.email.split('@')[0],
                    email=allowed_student.email or current_user.email,
                    dtu_email=allowed_student.dtu_email,
                    program=allowed_student.program
                )
                db.add(student)
                db.commit()
                db.refresh(student)
                logger.info(f"Auto-created student record for {current_user.email} with roll_no {roll_no}")
        else:
            # Strategy 2: Try to find by email pattern in enrolled classes
            logger.info(f"Not in allowed_student_emails, trying enrolled classes with pattern: {email_prefix}")
            enrolled_student = db.query(Student).join(ClassStudent).filter(
                (Student.email.ilike(f"%{email_prefix}%")) |
                (Student.dtu_email.ilike(f"%{email_prefix}%"))
            ).first()
            
            if enrolled_student:
                logger.info(f"Found enrolled student: {enrolled_student.roll_no}, updating email")
                enrolled_student.email = current_user.email
                db.commit()
                db.refresh(enrolled_student)
                student = enrolled_student
            else:
                # Strategy 3: Check if student exists with photo_url (was uploaded before)
                logger.info(f"Trying to find student with photo_url (might have been uploaded before)")
                student_with_photo = db.query(Student).filter(
                    Student.photo_url.isnot(None)
                ).filter(
                    (Student.email.ilike(f"%{email_prefix}%")) |
                    (Student.dtu_email.ilike(f"%{email_prefix}%"))
                ).first()
                
                if student_with_photo:
                    logger.info(f"Found student with photo: {student_with_photo.roll_no}, updating email")
                    student_with_photo.email = current_user.email
                    db.commit()
                    db.refresh(student_with_photo)
                    student = student_with_photo
                else:
                    logger.error(f"All strategies failed for {current_user.email}")
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"Student record not found for {current_user.email}. Please ensure your email is included in the class enrollment CSV or contact your teacher."
                    )
    
    if not student:
        # As a last resort, auto-create a temp student record to unblock upload
        temp_roll = f"TEMP_{email_lower.split('@')[0].upper()}"
        student = Student(
            roll_no=temp_roll,
            name=current_user.email.split('@')[0],
            email=current_user.email,
            dtu_email=None,
            program=None
        )
        db.add(student)
        db.commit()
        db.refresh(student)
        logger.info(f"Auto-created temp student record for {current_user.email} with roll_no {temp_roll}")
    
    logger.info(f"Student found/created: {student.roll_no}, email: {student.email}, photo_url: {student.photo_url}")
    
    # Validate file type
    allowed_types = ["image/jpeg", "image/png", "image/jpg"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )
    
    # Validate file size (max 5MB)
    max_size = 5 * 1024 * 1024  # 5MB
    file_data = await file.read()
    if len(file_data) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size is 5MB"
        )
    
    # Upload to Azure
    if not azure_storage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Azure Storage is not configured. Please contact administrator."
        )
    
    try:
        from io import BytesIO
        url = azure_storage.upload_student_photo(
            roll_no=student.roll_no,
            file_data=BytesIO(file_data),
            filename=file.filename,
            content_type=file.content_type
        )
        
        # Update student photo URL in database
        student.photo_url = url
        db.commit()
        
        # Trigger face embedding generation in background (non-blocking)
        if settings.face_api_service_url:
            background_tasks.add_task(
                generate_face_embedding_for_student,
                student.roll_no
            )
        
        return UploadResponse(
            url=url,
            blob_name=url.split('/')[-1],
            message="Photo uploaded successfully"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )


# Assignment upload (teachers only)
@router.post("/classes/{class_id}/assignments", response_model=UploadResponse)
async def upload_assignment(
    class_id: str,
    file: Annotated[UploadFile, File(...)],
    current_user: Annotated[UserContext, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    Upload an assignment file for a class.
    
    Only accessible by:
    - The teacher who owns the class
    - Admins
    """
    # Verify class exists
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    # Permission check
    if current_user.role != UserRole.ADMIN and str(class_obj.teacher_id) != str(current_user.user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only upload assignments for your own classes"
        )
    
    # Validate file type (allow common document types)
    allowed_types = [
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "text/plain"
    ]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file type. Allowed: PDF, DOC, DOCX, PPT, PPTX, TXT"
        )
    
    # Validate file size (max 20MB)
    max_size = 20 * 1024 * 1024  # 20MB
    file_data = await file.read()
    if len(file_data) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size is 20MB"
        )
    
    # Upload to Azure
    if not azure_storage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Azure Storage is not configured. Please set AZURE_STORAGE_CONNECTION_STRING in environment variables."
        )
    
    try:
        from io import BytesIO
        url = azure_storage.upload_assignment(
            class_id=class_id,
            teacher_id=str(current_user.user_id),
            file_data=BytesIO(file_data),
            filename=file.filename,
            content_type=file.content_type
        )
        
        return UploadResponse(
            url=url,
            blob_name=url.split('/')[-1],
            message="Assignment uploaded successfully"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )


# Attendance image upload (teachers only, automatically called during attendance)
@router.post("/attendance/{session_id}/image", response_model=UploadResponse)
async def upload_attendance_image(
    session_id: str,
    file: Annotated[UploadFile, File(...)],
    current_user: Annotated[UserContext, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    Upload an attendance session image.
    
    Only accessible by:
    - The teacher who created the session
    - Admins
    """
    from app.models.attendance import AttendanceSession
    
    # Verify session exists
    session = db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found"
        )
    
    # Permission check
    if current_user.role != UserRole.ADMIN and str(session.teacher_id) != str(current_user.user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only upload images for your own attendance sessions"
        )
    
    # Validate file type
    allowed_types = ["image/jpeg", "image/png", "image/jpg"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )
    
    # Validate file size (max 10MB)
    max_size = 10 * 1024 * 1024  # 10MB
    file_data = await file.read()
    if len(file_data) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large. Maximum size is 10MB"
        )
    
    # Upload to Azure
    if not azure_storage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Azure Storage is not configured. Please set AZURE_STORAGE_CONNECTION_STRING in environment variables."
        )
    
    try:
        from io import BytesIO
        url = azure_storage.upload_attendance_image(
            session_id=session_id,
            teacher_id=str(current_user.user_id),
            file_data=BytesIO(file_data),
            filename=file.filename,
            content_type=file.content_type
        )
        
        # Update session with processed image URL
        session.processed_image_url = url
        db.commit()
        
        return UploadResponse(
            url=url,
            blob_name=url.split('/')[-1],
            message="Attendance image uploaded successfully"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )


# Generate temporary SAS URL for secure access
@router.post("/sas-url", response_model=SasUrlResponse)
async def generate_sas_url(
    request: SasUrlRequest,
    current_user: Annotated[UserContext, Depends(get_current_user)]
):
    """
    Generate a temporary SAS URL for accessing a blob.
    
    This allows secure, time-limited access to files.
    Only authenticated users can generate SAS URLs.
    """
    if not azure_storage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Azure Storage is not configured. Please set AZURE_STORAGE_CONNECTION_STRING in environment variables."
        )
    
    try:
        sas_url = azure_storage.generate_sas_url(
            container_name=request.container_name,
            blob_name=request.blob_name,
            expiry_hours=request.expiry_hours
        )
        
        return SasUrlResponse(
            sas_url=sas_url,
            expires_in_hours=request.expiry_hours
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate SAS URL: {str(e)}"
        )


# List assignments for a class
@router.get("/classes/{class_id}/assignments")
async def list_class_assignments(
    class_id: str,
    current_user: Annotated[UserContext, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    List all assignment files for a class.
    
    Accessible by:
    - The teacher who owns the class
    - Admins
    """
    # Verify class exists
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found"
        )
    
    # Permission check
    if current_user.role != UserRole.ADMIN and str(class_obj.teacher_id) != str(current_user.user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view assignments for your own classes"
        )
    
    if not azure_storage:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Azure Storage is not configured. Please set AZURE_STORAGE_CONNECTION_STRING in environment variables."
        )
    
    try:
        prefix = f"classes/{class_id}/assignments"
        blobs = azure_storage.list_blobs(
            container_name=azure_storage.CONTAINER_ASSIGNMENTS,
            prefix=prefix
        )
        
        assignments = []
        for blob in blobs:
            assignments.append({
                "name": blob.name.split('/')[-1],
                "url": f"https://{azure_storage.blob_service_client.account_name}.blob.core.windows.net/{azure_storage.CONTAINER_ASSIGNMENTS}/{blob.name}",
                "size": blob.size,
                "created": blob.creation_time.isoformat() if blob.creation_time else None,
                "metadata": blob.metadata
            })
        
        return {
            "class_id": class_id,
            "assignments": assignments,
            "count": len(assignments)
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list assignments: {str(e)}"
        )


async def generate_face_embedding_for_student(roll_no: str):
    """
    Background task to generate face embedding for a student after photo upload.
    Calls the face recognition service to rebuild database with the new student photo.
    """
    if not settings.face_api_service_url:
        logger.warning("Face API service URL not configured, skipping embedding generation")
        return
    
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            # Call rebuild_database endpoint with roll_no parameter
            # This ensures the specific student's embedding is generated immediately
            response = await client.post(
                f"{settings.face_api_service_url}/rebuild_database",
                params={"roll_no": roll_no}
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully generated face embeddings for student {roll_no}")
            else:
                logger.warning(
                    f"Failed to generate embeddings for {roll_no}: "
                    f"HTTP {response.status_code} - {response.text}"
                )
    except Exception as e:
        logger.error(f"Error generating face embeddings for {roll_no}: {e}", exc_info=True)
