from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db
from ..deps import get_current_user
from ..serializers import property_out, user_out
from ..utils.files import delete_upload, save_upload

router = APIRouter(prefix="/users", tags=["Users"])


@router.put("/me", response_model=schemas.UserOut)
def update_me(
    payload: schemas.UserUpdate,
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    sent = payload.model_fields_set

    if payload.full_name is not None:
        current_user.full_name = payload.full_name

    if payload.email is not None and payload.email != current_user.email:
        taken = (
            db.query(models.User)
            .filter(models.User.email == payload.email, models.User.id != current_user.id)
            .first()
        )
        if taken:
            raise HTTPException(status_code=400, detail="Bu elektron pochta allaqachon band")
        current_user.email = payload.email

    # Phone / telegram can be cleared by sending an empty value.
    if "phone" in sent:
        current_user.phone = payload.phone
    if "telegram" in sent:
        current_user.telegram = payload.telegram

    if payload.password:
        current_user.hashed_password = security.get_password_hash(payload.password)

    db.commit()
    db.refresh(current_user)
    return user_out(current_user, request)


@router.post("/me/avatar", response_model=schemas.UserOut)
def upload_avatar(
    request: Request,
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    delete_upload(current_user.avatar_path)
    current_user.avatar_path = save_upload(file, "avatars")
    db.commit()
    db.refresh(current_user)
    return user_out(current_user, request)


@router.get("/me/saved", response_model=list[schemas.PropertyOut])
def my_saved_properties(
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    links = sorted(current_user.saved, key=lambda link: link.created_at, reverse=True)
    return [property_out(link.property, request, current_user) for link in links]
