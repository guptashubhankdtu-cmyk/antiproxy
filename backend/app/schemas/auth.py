"""
Authentication-related Pydantic schemas.
"""
from pydantic import BaseModel, EmailStr, Field
from uuid import UUID


class GoogleLoginRequest(BaseModel):
    """Request body for Google OAuth login."""
    id_token: str = Field(..., alias="idToken", description="Google ID token from client")
    
    class Config:
        populate_by_name = True


class UserInfo(BaseModel):
    """User information in authentication response."""
    userId: int
    uuid: UUID
    email: EmailStr
    name: str
    role: str
    studentId: int | None = None   # int PK of student record (optional)
    studentUuid: UUID | None = None
    
    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Response containing JWT token and user info."""
    token: str
    user: UserInfo
