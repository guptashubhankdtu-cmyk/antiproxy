from google.cloud import storage
from datetime import timedelta
import logging
import os

# Assuming you will add GOOGLE_STORAGE_BUCKET to your config.py
# from app.config import settings 

logger = logging.getLogger(__name__)

class GoogleCloudStorageService:
    def __init__(self):
        self.client = None
        # Replace with settings.GOOGLE_STORAGE_BUCKET or os.getenv("GOOGLE_STORAGE_BUCKET")
        self.bucket_name = os.getenv("GOOGLE_STORAGE_BUCKET", "your-gcs-bucket-name")
        self.bucket = None
        
        # GCS doesn't use containers like Azure, we use top-level folders
        self.CONTAINER_ASSIGNMENTS = "assignments"
        
        try:
            # Automatically looks for GOOGLE_APPLICATION_CREDENTIALS env var
            self.client = storage.Client()
            self.bucket = self.client.bucket(self.bucket_name)
            logger.info(f"Connected to GCS bucket: {self.bucket_name}")
        except Exception as e:
            logger.error(f"Failed to initialize GCS client: {e}")

    def upload_student_photo(self, roll_no, file_data, filename, content_type):
        # path: students/{roll_no}/photo.jpg
        extension = filename.split('.')[-1] if '.' in filename else 'jpg'
        blob_name = f"students/{roll_no}/photo.{extension}"
        return self._upload_blob(blob_name, file_data, content_type)

    def upload_assignment(self, class_id, teacher_id, file_data, filename, content_type):
        # path: assignments/classes/{class_id}/{filename}
        blob_name = f"{self.CONTAINER_ASSIGNMENTS}/classes/{class_id}/{filename}"
        return self._upload_blob(blob_name, file_data, content_type)

    def upload_attendance_image(self, session_id, teacher_id, file_data, filename, content_type):
        # path: attendance/{session_id}/evidence.jpg
        extension = filename.split('.')[-1] if '.' in filename else 'jpg'
        blob_name = f"attendance/{session_id}/evidence.{extension}"
        return self._upload_blob(blob_name, file_data, content_type)

    def _upload_blob(self, blob_name, file_data, content_type):
        if not self.bucket:
            raise Exception("GCS Bucket not initialized")
        
        blob = self.bucket.blob(blob_name)
        file_data.seek(0)
        blob.upload_from_file(file_data, content_type=content_type)
        
        # Return public URL (assuming bucket is public or you want the public link)
        # For private buckets, you might want to return blob.name and generate SAS URLs on read
        return blob.public_url

    def generate_sas_url(self, container_name, blob_name, expiry_hours=1):
        """Generate a V4 Signed URL (equivalent to SAS URL)."""
        if not self.bucket:
            raise Exception("GCS Bucket not initialized")
        
        # Handle container mapping
        full_blob_name = blob_name
        if container_name and not blob_name.startswith(container_name):
             full_blob_name = f"{container_name}/{blob_name}"

        blob = self.bucket.blob(full_blob_name)
        
        try:
            url = blob.generate_signed_url(
                version="v4",
                expiration=timedelta(hours=expiry_hours),
                method="GET"
            )
            return url
        except Exception as e:
            logger.error(f"Error generating signed URL: {e}")
            raise

    def list_blobs(self, container_name, prefix):
        if not self.bucket:
            raise Exception("GCS Bucket not initialized")
        
        full_prefix = prefix
        if container_name:
            full_prefix = f"{container_name}/{prefix}"
            
        return self.client.list_blobs(prefix=full_prefix)

# Singleton instance
gcs_storage = GoogleCloudStorageService()