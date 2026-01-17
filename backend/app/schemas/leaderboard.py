from typing import List, Optional
from pydantic import BaseModel


class LeaderboardEntry(BaseModel):
    studentId: str
    rollNo: Optional[str]
    name: str
    attendancePercentage: float
    consistency: float
    maxStreak: int
    coins: float
    level: int
    attendedCount: int
    totalCount: int
    presentCount: int
    lateCount: int
    absentCount: int
    excusedCount: int
    rank: int


class LeaderboardResponse(BaseModel):
    total: int
    limit: int
    offset: int
    items: List[LeaderboardEntry]
    selfEntry: Optional[LeaderboardEntry] = None

