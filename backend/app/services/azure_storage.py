"""
Azure Blob Storage service for handling file uploads.
"""
import os
import uuid
from datetime import datetime, timedelta
from typing import Optional, BinaryIO
from azure.storage.blob import BlobServiceClient, BlobSasPermissions, generate_blob_sas, ContentSettings
from azure.core.exceptions import ResourceNotFoundError

from app.config import settings


class AzureStorageService:
    """Service for interacting with Azure Blob Storage."""
    
    # Container names for different types of content
    CONTAINER_STUDENT_PHOTOS = "student-photos"
    CONTAINER_ASSIGNMENTS = "class-uploads"
    CONTAINER_ATTENDANCE_IMAGES = "attendance-images"
    
    def __init__(self):
        """Initialize Azure Blob Storage client."""
        if not settings.azure_storage_connection_string:
            raise ValueError("Azure Storage connection string not configured")
        
        self.blob_service_client = BlobServiceClient.from_connection_string(
            settings.azure_storage_connection_string
        )
        self._ensure_containers_exist()
    
    def _ensure_containers_exist(self):
        """Ensure all required containers exist."""
        containers = [
            self.CONTAINER_STUDENT_PHOTOS,
            self.CONTAINER_ASSIGNMENTS,
            self.CONTAINER_ATTENDANCE_IMAGES,
        ]
        
        for container_name in containers:
            try:
                container_client = self.blob_service_client.get_container_client(container_name)
                if not container_client.exists():
                    container_client.create_container()
            except Exception as e:
                print(f"Error ensuring container {container_name} exists: {e}")
    
    def _generate_blob_name(self, original_filename: str, prefix: str = "") -> str:
        """
        Generate a unique blob name with timestamp and UUID.
        
        Args:
            original_filename: Original name of the file
            prefix: Optional prefix for the blob name
            
        Returns:
            Unique blob name
        """
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        file_extension = os.path.splitext(original_filename)[1]
        
        if prefix:
            return f"{prefix}/{timestamp}_{unique_id}{file_extension}"
        return f"{timestamp}_{unique_id}{file_extension}"
    
    def upload_student_photo(
        self,
        roll_no: str,
        file_data: BinaryIO,
        filename: str,
        content_type: str = "image/jpeg"
    ) -> str:
        """
        Upload a student profile photo.
        
        Args:
            roll_no: Student roll number
            file_data: File binary data
            filename: Original filename
            content_type: MIME type of the file
            
        Returns:
            URL of the uploaded blob
        """
        blob_name = self._generate_blob_name(filename, prefix=f"students/{roll_no}")
        
        blob_client = self.blob_service_client.get_blob_client(
            container=self.CONTAINER_STUDENT_PHOTOS,
            blob=blob_name
        )
        
        blob_client.upload_blob(
            file_data,
            content_settings=ContentSettings(content_type=content_type),
            overwrite=True
        )
        
        return blob_client.url
    
    def upload_assignment(
        self,
        class_id: str,
        teacher_id: str,
        file_data: BinaryIO,
        filename: str,
        content_type: str = "application/pdf"
    ) -> str:
        """
        Upload an assignment file (teachers only).
        
        Args:
            class_id: Class ID
            teacher_id: Teacher ID who is uploading
            file_data: File binary data
            filename: Original filename
            content_type: MIME type of the file
            
        Returns:
            URL of the uploaded blob
        """
        blob_name = self._generate_blob_name(
            filename,
            prefix=f"classes/{class_id}/assignments"
        )
        
        blob_client = self.blob_service_client.get_blob_client(
            container=self.CONTAINER_ASSIGNMENTS,
            blob=blob_name
        )
        
        # Store metadata about who uploaded
        metadata = {
            "uploaded_by": teacher_id,
            "class_id": class_id,
            "original_filename": filename
        }
        
        blob_client.upload_blob(
            file_data,
            content_settings=ContentSettings(content_type=content_type),
            metadata=metadata,
            overwrite=True
        )
        
        return blob_client.url
    
    def upload_attendance_image(
        self,
        session_id: str,
        teacher_id: str,
        file_data: BinaryIO,
        filename: str,
        content_type: str = "image/jpeg"
    ) -> str:
        """
        Upload an attendance session image.
        
        Args:
            session_id: Attendance session ID
            teacher_id: Teacher ID who took attendance
            file_data: File binary data
            filename: Original filename
            content_type: MIME type of the file
            
        Returns:
            URL of the uploaded blob
        """
        blob_name = self._generate_blob_name(
            filename,
            prefix=f"attendance/{session_id}"
        )
        
        blob_client = self.blob_service_client.get_blob_client(
            container=self.CONTAINER_ATTENDANCE_IMAGES,
            blob=blob_name
        )
        
        metadata = {
            "uploaded_by": teacher_id,
            "session_id": session_id
        }
        
        blob_client.upload_blob(
            file_data,
            content_settings=ContentSettings(content_type=content_type),
            metadata=metadata,
            overwrite=True
        )
        
        return blob_client.url
    
    def delete_blob(self, container_name: str, blob_name: str) -> bool:
        """
        Delete a blob from storage.
        
        Args:
            container_name: Name of the container
            blob_name: Name of the blob to delete
            
        Returns:
            True if deleted, False if not found
        """
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=container_name,
                blob=blob_name
            )
            blob_client.delete_blob()
            return True
        except ResourceNotFoundError:
            return False
    
    def generate_sas_url(
        self,
        container_name: str,
        blob_name: str,
        expiry_hours: int = 1,
        permission: str = "r"
    ) -> str:
        """
        Generate a SAS (Shared Access Signature) URL for temporary access.
        
        Args:
            container_name: Name of the container
            blob_name: Name of the blob
            expiry_hours: Hours until the URL expires
            permission: Permissions ('r' for read, 'w' for write, etc.)
            
        Returns:
            SAS URL
        """
        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )
        
        # Convert permission string to BlobSasPermissions
        permissions = BlobSasPermissions(read='r' in permission, write='w' in permission)
        
        sas_token = generate_blob_sas(
            account_name=settings.azure_storage_account_name,
            container_name=container_name,
            blob_name=blob_name,
            account_key=self._get_account_key(),
            permission=permissions,
            expiry=datetime.utcnow() + timedelta(hours=expiry_hours)
        )
        
        return f"{blob_client.url}?{sas_token}"
    
    def _get_account_key(self) -> str:
        """Extract account key from connection string."""
        connection_string = settings.azure_storage_connection_string
        for part in connection_string.split(';'):
            if part.startswith('AccountKey='):
                return part.split('=', 1)[1]
        raise ValueError("Account key not found in connection string")
    
    def list_blobs(self, container_name: str, prefix: Optional[str] = None):
        """
        List blobs in a container with optional prefix filter.
        
        Args:
            container_name: Name of the container
            prefix: Optional prefix to filter blobs
            
        Returns:
            Iterator of blob properties
        """
        container_client = self.blob_service_client.get_container_client(container_name)
        return container_client.list_blobs(name_starts_with=prefix)


# Singleton instance (lazy initialization to avoid crashes if Azure is not configured)
_azure_storage_instance = None

def get_azure_storage() -> Optional[AzureStorageService]:
    """Get Azure Storage instance, or None if not configured."""
    global _azure_storage_instance
    if _azure_storage_instance is None:
        if not settings.azure_storage_connection_string:
            return None
        try:
            _azure_storage_instance = AzureStorageService()
        except Exception as e:
            print(f"Warning: Azure Storage not available: {e}")
            return None
    return _azure_storage_instance

# For backward compatibility, try to initialize if connection string exists
try:
    if settings.azure_storage_connection_string:
        azure_storage = AzureStorageService()
    else:
        azure_storage = None
except Exception as e:
    print(f"Warning: Azure Storage initialization failed: {e}")
    azure_storage = None
