# backend/app/schemas/review.py

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class ReviewBase(BaseModel):
    rating: int = Field(..., ge=1, le=5, description="評分1-5星")
    comment: Optional[str] = Field(None, max_length=500)
    is_anonymous: Optional[bool] = False
    tags: Optional[str] = None

class ReviewCreate(ReviewBase):
    trip_id: int

class ReviewUpdate(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=500)
    is_anonymous: Optional[bool] = None
    tags: Optional[str] = None

class ReviewResponse(ReviewBase):
    review_id: int
    trip_id: int
    reviewer_id: int
    reviewee_id: int
    review_type: str
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        from_attributes = True
