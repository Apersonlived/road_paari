from sqlalchemy import Column, Integer, BigInteger, String, Text, Boolean, ForeignKey
from database import Base

class Notification(Base):
    __tablename__ = "notification"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("app_user.id"))
    title = Column(String(150))
    message = Column(Text)
    is_read = Column(Boolean, default=False)
