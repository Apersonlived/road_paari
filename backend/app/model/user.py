from sqlalchemy import Column, DateTime, Integer, BigInteger, String, Text, Boolean, ForeignKey, func
from app.core.database import Base

class User(Base):
    __tablename__ = "app_user"

    id = Column(Integer, primary_key=True)
    full_name = Column(String(100))
    email = Column(String(150), unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean)
    user_image_url = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)