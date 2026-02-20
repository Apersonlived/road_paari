from fastapi import APIRouter, Depends, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List


from app.schemas.user import User, UserCreate, UserUpdate, UserPasswordUpdate
from app.crud import user
from app.core.database import get_db  

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/", response_model=User, status_code=status.HTTP_201_CREATED)
def create_user(user_in: UserCreate, db: Session = Depends(get_db)):
    return user.create_user(db, user_in)

@router.get("/", response_model=List[User])
def list_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return user.get_users(db, skip=skip, limit=limit)

@router.get("/{user_id}", response_model=User)
def read_user(user_id: int, db: Session = Depends(get_db)):
    return user.get_user(db, user_id)

@router.patch("/{user_id}", response_model=User)
def update_user(user_id: int, user_in: UserUpdate, db: Session = Depends(get_db)):
    return user.update_user(db, user_id, user_in)

@router.patch("/{user_id}/password", response_model=User)
def update_password(user_id: int, payload: UserPasswordUpdate, db: Session = Depends(get_db)):
    return user.update_password(db, user_id, payload)

@router.patch("/{user_id}/image", response_model=User)
def upload_image(
    user_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    return user.update_user_image(db, user_id, file)

@router.delete("/{user_id}/image", response_model=User)
def remove_image(user_id: int, db: Session = Depends(get_db)):
    return user.delete_user_image_record(db, user_id)

@router.delete("/{user_id}", status_code=status.HTTP_200_OK)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    return user.delete_user(db, user_id)