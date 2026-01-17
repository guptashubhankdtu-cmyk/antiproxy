"""
FastAPI dependencies for authentication and authorization.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from fastapi.security.http import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional
from uuid import UUID

from app.db import get_db
from app.models.user import User, UserRole
from app.auth.jwt import verify_jwt, JWTError as JWTVerificationError


# HTTP Bearer token security scheme
security = HTTPBearer()


class UserContext:
    """Context object containing authenticated user information."""
    
    def __init__(self, user_id: UUID, email: str, role: UserRole, user: Optional[User] = None):
        self.user_id = user_id
        self.email = email
        self.role = role
        self.user = user
    
    def is_admin(self) -> bool:
        """Check if user is an admin."""
        return self.role == UserRole.ADMIN
    
    def is_teacher(self) -> bool:
        """Check if user is a teacher."""
        return self.role == UserRole.TEACHER


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> UserContext:
    """
    FastAPI dependency to extract and verify the current user from JWT.
    
    Args:
        credentials: HTTP Bearer token from Authorization header
        db: Database session
        
    Returns:
        UserContext with authenticated user information
        
    Raises:
        HTTPException: If token is invalid or user not found
    """
    token = credentials.credentials
    
    try:
        # Verify JWT token
        payload = verify_jwt(token)
        user_id = UUID(payload["user_id"])
        email = payload["email"]
        role = UserRole(payload["role"])
        
    except JWTVerificationError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
    except (ValueError, KeyError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Load user from database to ensure they still exist
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return UserContext(user_id=user_id, email=email, role=role, user=user)


async def require_admin(
    current_user: UserContext = Depends(get_current_user)
) -> UserContext:
    """
    FastAPI dependency to require admin role.
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        UserContext if user is admin
        
    Raises:
        HTTPException: If user is not an admin
    """
    if not current_user.is_admin():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    return current_user


async def require_teacher_or_admin(
    current_user: UserContext = Depends(get_current_user)
) -> UserContext:
    """
    FastAPI dependency to require teacher or admin role.
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        UserContext if user is teacher or admin
        
    Raises:
        HTTPException: If user is neither teacher nor admin
    """
    if not (current_user.is_teacher() or current_user.is_admin()):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher or admin access required"
        )
    
    return current_user
