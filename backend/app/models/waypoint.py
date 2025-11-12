from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class TripWaypoint(Base):
    """行程中繼點/停靠點"""
    __tablename__ = "trip_waypoints"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(
        Integer,
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="行程 ID"
    )

    sequence = Column(
        Integer,
        nullable=False,
        comment="停靠順序：1, 2, 3... (起點為0，終點為最後)"
    )

    lat = Column(
        Float,
        nullable=False,
        comment="緯度"
    )

    lng = Column(
        Float,
        nullable=False,
        comment="經度"
    )

    address = Column(
        String(500),
        nullable=True,
        comment="地址"
    )

    arrival_time = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="實際到達時間（用於追蹤行程進度）"
    )

    # 關聯
    trip = relationship("Trip", back_populates="waypoints")

    def __repr__(self):
        return f"<TripWaypoint {self.id} trip={self.trip_id} seq={self.sequence}>"
