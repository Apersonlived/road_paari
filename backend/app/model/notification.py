from sqlalchemy import Column, DateTime, Integer, BigInteger, String, Text, Boolean, ForeignKey, func
from app.core.database import Base

class Notification(Base):
    __tablename__ = "notification"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("app_user.id"))
    poi_id     = Column(Integer, ForeignKey("poi.id"), nullable=True)
    title = Column(String(150))
    message = Column(Text)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)