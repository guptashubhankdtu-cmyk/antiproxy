"""
JWT token utilities for internal authentication.
"""
from datetime import datetime, timedelta
from typing import Dict, Optional
from jose import JWTError, jwt
from uuid import UUID

from app.config import settings


class JWTError(Exception):
    """Exception raised for JWT errors."""
    pass


def create_jwt(user_id: UUID, email: str, role: str) -> str:
    """
    Create a signed JWT token for internal authentication.
    
    Args:
        user_id: User's UUID
        email: User's email
        role: User's role (teacher or admin)
        
    Returns:
        Signed JWT token string
    """
    expiration = datetime.utcnow() + timedelta(hours=settings.jwt_expiration_hours)
    
    payload = {
        "sub": str(user_id),
        "email": email,
        "role": role,
        "exp": expiration,
        "iat": datetime.utcnow()
    }
    
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token


def verify_jwt(token: str) -> Dict[str, str]:
    """
    Verify and decode a JWT token.
    
    Args:
        token: JWT token string
        
    Returns:
        Dictionary containing token payload (sub, email, role)
        
    Raises:
        JWTError: If token is invalid or expired
    """
    try:
        payload = jwt.decode(
            token, 
            settings.jwt_secret, 
            algorithms=[settings.jwt_algorithm]
        )
        
        user_id = payload.get("sub")
        email = payload.get("email")
        role = payload.get("role")
        
        if not user_id or not email or not role:
            raise JWTError("Invalid token payload")
        
        return {
            "user_id": user_id,
            "email": email,
            "role": role
        }
        
    except jwt.ExpiredSignatureError:
        raise JWTError("Token has expired")
    except jwt.JWTError as e:
        raise JWTError(f"Invalid token: {str(e)}")
