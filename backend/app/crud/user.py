from sqlalchemy.orm import Session
from fastapi import HTTPException, status, UploadFile
from app.model import User as UserModel
from app.schemas.user import UserCreate, UserUpdate, UserPasswordUpdate
from app.core.security import get_password_hash, verify_password

import os
import uuid
import shutil

# Configuring image upload
UPLOAD_DIR = "static/user_images"
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_FILE_SIZE_MB = 5

os.makedirs(UPLOAD_DIR, exist_ok=True)

# Helper functions for image
def save_user_image(file: UploadFile, user_id: int) -> str:
    """
    Saves uploaded image to disk and returns the URL path.
    Raises HTTPException if file type or size is invalid.
    """
    # Validate extension
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )

    # Validate file size
    file.file.seek(0, 2)  # seek to end
    size_bytes = file.file.tell()
    file.file.seek(0)     # reset to start
    if size_bytes > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE_MB}MB",
        )
    
    # Generate unique filename and save
    filename = f"user_{user_id}_{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(UPLOAD_DIR, filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Return URL path (served as static file)
    return f"/static/user_images/{filename}"

def delete_user_image(image_url: str) -> None:
    """
    Deletes old image file from disk if it exists.
    """
    if not image_url:
        return
    # Convert URL path back to file path
    file_path = image_url.lstrip("/")
    if os.path.exists(file_path):
        os.remove(file_path)
        
# Create fucntions
def create_user(db: Session, user_in: UserCreate) -> UserModel:
    existing = db.query(UserModel).filter(UserModel.email == user_in.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    user = UserModel(
        email=user_in.email,
        full_name=user_in.full_name,
        password_hash=get_password_hash(user_in.password)
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# Read functions
def get_user(db: Session, user_id: int) -> UserModel:
    user = db.query(UserModel).filter(UserModel.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user

def get_user_by_email(db: Session, email: str) -> UserModel | None:
    return db.query(UserModel).filter(UserModel.email == email).first()

def get_users(db: Session, skip: int = 0, limit: int = 100) -> list[UserModel]:
    return db.query(UserModel).offset(skip).limit(limit).all()


# Update functions
def update_user(db: Session, user_id: int, user_in: UserUpdate) -> UserModel:
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

def update_password(db: Session, user_id: int, payload: UserPasswordUpdate) -> UserModel:
    user = get_user(db, user_id)
    if not verify_password(payload.old_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect current password",
        )
    user.password_hash = get_password_hash(payload.new_password)
    db.commit()
    db.refresh(user)
    return user

def update_user_image(db: Session, user_id: int, file: UploadFile) -> UserModel:
    # Uploads a new profile image for the user, deleting the old one if it exists.
    user = get_user(db, user_id)

    # Delete old image from disk if one exists
    if user.user_image_url:
        delete_user_image(user.user_image_url)

    # Save new image and update URL on user record
    user.user_image_url = save_user_image(file, user_id)

    db.commit()
    db.refresh(user)
    return user

def delete_user_image_record(db: Session, user_id: int) -> UserModel:
    #Removes the profile image from disk and clears the URL on the user record.
    user = get_user(db, user_id)

    if user.user_image_url:
        delete_user_image(user.user_image_url)
        user.user_image_url = None
        db.commit()
        db.refresh(user)

    return user

# Delete function
def delete_user(db: Session, user_id: int) -> dict:
    user = get_user(db, user_id)
    # Clean up image from disk before deleting user
    if user.user_image_url:
        delete_user_image(user.user_image_url)
    db.delete(user)
    db.commit()
    return {"detail": f"User {user_id} deleted successfully"}