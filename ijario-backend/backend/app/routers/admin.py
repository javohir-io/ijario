from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..deps import get_current_admin
from ..serializers import user_out

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/stats", response_model=schemas.AdminStatsOut)
def stats(
    db: Session = Depends(get_db),
    _admin: models.User = Depends(get_current_admin),
):
    return schemas.AdminStatsOut(
        total_users=db.query(models.User).count(),
        total_properties=db.query(models.Property).count(),
        active_properties=db.query(models.Property).filter(models.Property.status == "faol").count(),
        total_messages=db.query(models.Message).count(),
        total_saved=db.query(models.SavedProperty).count(),
        total_viewings=db.query(models.ViewingRequest).count(),
        total_reports=db.query(models.Report).count(),
    )


@router.get("/users", response_model=list[schemas.UserOut])
def list_users(
    request: Request,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(get_current_admin),
):
    users = db.query(models.User).order_by(models.User.created_at.desc()).all()
    return [user_out(u, request) for u in users]


@router.delete("/users/{user_id}", status_code=204)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin: models.User = Depends(get_current_admin),
):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="O'zingizni o'chira olmaysiz")
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")
    db.delete(user)
    db.commit()
    return None


@router.delete("/properties/{property_id}", status_code=204)
def delete_any_property(
    property_id: int,
    db: Session = Depends(get_db),
    _admin: models.User = Depends(get_current_admin),
):
    """Same as DELETE /properties/{id}, but bypasses the owner check —
    lets an admin moderate/remove any listing."""
    from ..utils.files import delete_upload

    property_ = db.query(models.Property).filter(models.Property.id == property_id).first()
    if not property_:
        raise HTTPException(status_code=404, detail="E'lon topilmadi")
    for img in property_.images:
        delete_upload(img.path)
    db.delete(property_)
    db.commit()
    return None


@router.get("/reports", response_model=list[schemas.ReportOut])
def list_reports(
    db: Session = Depends(get_db),
    _admin: models.User = Depends(get_current_admin),
):
    """Newest complaints first, so a moderator can review flagged listings."""
    return db.query(models.Report).order_by(models.Report.created_at.desc()).all()
