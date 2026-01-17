"""
Google ID token verification utilities.
"""
from google.auth.transport import requests
from google.oauth2 import id_token
from typing import Dict, Optional

from app.config import settings


class GoogleAuthError(Exception):
    """Exception raised for Google authentication errors."""
    pass


async def verify_google_token(token: str) -> Dict[str, str]:
    """
    Verify a Google ID token and extract user information.
    
    Args:
        token: Google ID token from the client
        
    Returns:
        Dictionary containing user info (email, name, sub)
        
    Raises:
        GoogleAuthError: If token is invalid or verification fails
    """
    try:
        # Verify the token against Google's public keys
        idinfo = id_token.verify_oauth2_token(
            token, 
            requests.Request(), 
            settings.google_client_id
        )
        
        # Token is valid, extract user information
        email = idinfo.get('email')
        name = idinfo.get('name', '')
        google_sub = idinfo.get('sub')
        
        if not email:
            raise GoogleAuthError("Email not found in Google token")
        
        return {
            'email': email,
            'name': name,
            'sub': google_sub
        }
        
    except ValueError as e:
        # Token is invalid
        raise GoogleAuthError(f"Invalid Google token: {str(e)}")
    except Exception as e:
        raise GoogleAuthError(f"Token verification failed: {str(e)}")
