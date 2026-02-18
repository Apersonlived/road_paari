from passlib.context import CryptContext
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
import model, schemas

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# Create fucntions
def create_user(db: Session, user_in: schemas.UserCreate) -> model.User:
    existing = db.query(model.User).filter(model.User.email == user_in.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    user = model.User(
        email=user_in.email,
        full_name=user_in.full_name,
        password_hash=hash_password(user_in.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# Read functions
def get_user(db: Session, user_id: int) -> model.User:
    user = db.query(model.User).filter(model.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user

def get_user_by_email(db: Session, email: str) -> model.User | None:
    return db.query(model.User).filter(model.User.email == email).first()

def get_users(db: Session, skip: int = 0, limit: int = 100) -> list[model.User]:
    return db.query(model.User).offset(skip).limit(limit).all()


# Update functions
def update_user(db: Session, user_id: int, user_in: schemas.UserUpdate) -> model.User:
    user = get_user(db, user_id)
    update_data = user_in.model_dump(exclude_unset=True)

    # Check for duplicate email if email is being changed
    if "email" in update_data and update_data["email"] != user.email:
        if get_user_by_email(db, update_data["email"]):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already in use",
            )

    for field, value in update_data.items():
        setattr(user, field, value)

    db.commit()
    db.refresh(user)
    return user

def update_password(db: Session, user_id: int, payload: schemas.UserPasswordUpdate) -> model.User:
    user = get_user(db, user_id)
    if not verify_password(payload.old_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect current password",
        )
    user.password_hash = hash_password(payload.new_password)
    db.commit()
    db.refresh(user)
    return user

# Delete function
def delete_user(db: Session, user_id: int) -> dict:
    user = get_user(db, user_id)
    db.delete(user)
    db.commit()
    return {"detail": f"User {user_id} deleted successfully"}