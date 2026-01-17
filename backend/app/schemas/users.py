"""
User-related Pydantic schemas.
"""
from pydantic import BaseModel, EmailStr
from uuid import UUID
from typing import Optional
from datetime import datetime


class UserProfile(BaseModel):
    """User profile information."""
    id: UUID
    email: EmailStr
    name: str
    role: str
    department: Optional[str] = None
    employee_id: Optional[str] = None
    last_login_at: Optional[datetime] = None
    created_at: datetime
    
    class Config:
        from_attributes = True
