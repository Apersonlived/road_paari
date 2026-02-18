from sqlalchemy import Column, Integer, BigInteger, String, Text, Boolean, ForeignKey
from database import Base

class User(Base):
    __tablename__ = "app_user"

    id = Column(Integer, primary_key=True)
    full_name = Column(String(100))
    email = Column(String(150), unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
