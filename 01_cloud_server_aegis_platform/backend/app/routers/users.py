from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, Literal
from ..database import get_db
from .. import models
from ..deps import get_current_user
from ..core.security import get_password_hash

router = APIRouter(prefix="/api/v1/users", tags=["Users"])

class UserCreate(BaseModel):
    username: str
    password: str
    role: Literal["admin", "user"] = "user"

class PasswordUpdate(BaseModel):
    new_password: str

class UserUpdateInfo(BaseModel):
    username: Optional[str] = None
    role: Optional[Literal["admin", "user"]] = None
    password: Optional[str] = None

@router.get("/me")
def get_me(current_user: models.User = Depends(get_current_user)):
    return {"id": current_user.id, "username": current_user.username, "role": current_user.role}

@router.put("/me/password")
def update_my_password(pwd: PasswordUpdate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    current_user.hashed_password = get_password_hash(pwd.new_password)
    db.commit()
    return {"status": "success"}

@router.get("")
def get_all_users(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin": raise HTTPException(status_code=403, detail="Permission denied")
    users = db.query(models.User).order_by(models.User.id.asc()).all()
    result = [{"id": u.id, "username": u.username, "role": u.role} for u in users]
    return {"status": "success", "data": result}

@router.put("/{user_id}")
def update_user_info(user_id: int, user_update: UserUpdateInfo, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin": raise HTTPException(status_code=403, detail="Permission denied")
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user: raise HTTPException(status_code=404, detail="User not found")
    
    if user_update.username: db_user.username = user_update.username
    if user_update.role: db_user.role = user_update.role
    if user_update.password: db_user.hashed_password = get_password_hash(user_update.password)
    
    db.commit()
    return {"status": "success"}

@router.post("")
def create_user(user: UserCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin": raise HTTPException(status_code=403, detail="Permission denied")
    if db.query(models.User).filter(models.User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    
    new_user = models.User(username=user.username, hashed_password=get_password_hash(user.password), role=user.role)
    db.add(new_user)
    db.commit()
    return {"status": "success"}

@router.delete("/{user_id}")
def delete_user(user_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin": raise HTTPException(status_code=403, detail="Permission denied")
    if current_user.id == user_id: raise HTTPException(status_code=400, detail="Cannot delete self")
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(db_user)
    db.commit()
    return {"status": "success"}
