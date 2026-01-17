"""
User routes.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.auth.dependencies import get_current_user, UserContext
from app.schemas.users import UserProfile

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserProfile)
async def get_current_user_profile(
    current_user: UserContext = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get the current authenticated user's profile.
    """
    return UserProfile.model_validate(current_user.user)
