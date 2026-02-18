from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import List

import schemas, crud.user
from database import get_db  

router = APIRouter(prefix="/users", tags=["Users"])


@router.post("/", response_model=schemas.User, status_code=status.HTTP_201_CREATED)
def create_user(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    return crud.user.create_user(db, user_in)


@router.get("/", response_model=List[schemas.User])
def list_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return crud.user.get_users(db, skip=skip, limit=limit)


@router.get("/{user_id}", response_model=schemas.User)
def read_user(user_id: int, db: Session = Depends(get_db)):
    return crud.user.get_user(db, user_id)


@router.patch("/{user_id}", response_model=schemas.User)
def update_user(user_id: int, user_in: schemas.UserUpdate, db: Session = Depends(get_db)):
    return crud.user.update_user(db, user_id, user_in)


@router.patch("/{user_id}/password", response_model=schemas.User)
def update_password(user_id: int, payload: schemas.UserPasswordUpdate, db: Session = Depends(get_db)):
    return crud.user.update_password(db, user_id, payload)


@router.delete("/{user_id}", status_code=status.HTTP_200_OK)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    return crud.user.delete_user(db, user_id)