"""
Configuration for the AIMS Attendance Backend.
Loads environment variables and provides application settings.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Application
    app_name: str = "AIMS Attendance API"
    debug: bool = False
    
    # Database
    database_url: str
    
    # JWT
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 1
    
    # Google OAuth
    google_client_id: str
    
    # CORS
    cors_origins: list[str] = ["*"]
    
    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    
    # Azure Blob Storage
    azure_storage_connection_string: Optional[str] = None
    azure_storage_account_name: str = "aimsattendanceapp"
    
    # Face Recognition Service
    face_api_service_url: Optional[str] = None
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )


# Global settings instance
settings = Settings()
