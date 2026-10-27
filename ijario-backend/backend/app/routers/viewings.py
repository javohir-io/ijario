import datetime as dt

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import or_
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db
from ..deps import absolute_url, get_current_user
from ..models import utcnow
from ..routers.messages import message_payload
from ..serializers import owner_out
from ..ws_manager import manager

router = APIRouter(prefix="/viewings", tags=["Viewings"])

MAX_DAYS_AHEAD = 60
# 'Asia/Tashkent' is a fixed UTC+5 (no daylight saving) — used only to write
# a readable local time into the automatic chat message.
_TASHKENT = dt.timezone(dt.timedelta(hours=5))


def _naive_utc(value: dt.datetime) -> dt.datetime:
    """Client sends an ISO string; a missing offset is read as UTC."""
    if value.tzinfo is not None:
        return value.astimezone(dt.timezone.utc).replace(tzinfo=None)
    return value


def _local_label(naive_utc: dt.datetime) -> str:
    local = naive_utc.replace(tzinfo=dt.timezone.utc).astimezone(_TASHKENT)
    return local.strftime("%d.%m.%Y, %H:%M")


def _to_out(v: models.ViewingRequest, request: Request, me: models.User) -> schemas.ViewingOut:
    cover = v.property.images[0].path if v.property.images else None
    return schemas.ViewingOut(
        id=v.id,
        property=schemas.ViewingPropertyOut(
            id=v.property.id,
            title=v.property.title,
            city=v.property.city,
            location=v.property.location,
            cover_url=absolute_url(request, cover),
        ),
        renter=owner_out(v.renter, request),
        owner=owner_out(v.owner, request),
        scheduled_at=v.scheduled_at,
        note=v.note,
        status=v.status,
        created_at=v.created_at,
        role="owner" if v.owner_id == me.id else "renter",
    )


async def _notify(db: Session, sender_id: int, receiver_id: int, property_id: int, text: str) -> None:
    """Drops a line into the chat so a viewing never lives only in its own tab."""
    message = models.Message(
        sender_id=sender_id, receiver_id=receiver_id, property_id=property_id, content=text
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    payload = message_payload(message)
    await manager.send_to_user(receiver_id, payload)
    await manager.send_to_user(sender_id, payload)


@router.post("", response_model=schemas.ViewingOut, status_code=201)
async def create_viewing(
    payload: schemas.ViewingCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    prop = db.query(models.Property).filter(models.Property.id == payload.property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="E'lon topilmadi")
    if prop.owner_id == current_user.id:
        raise HTTPException(status_code=400, detail="O'z e'loningizni ko'rishga yozila olmaysiz")
    if prop.status != "faol":
        raise HTTPException(status_code=400, detail="Bu e'lon allaqachon band")

    when = _naive_utc(payload.scheduled_at)
    now = utcnow()
    if when <= now:
        raise HTTPException(status_code=400, detail="Ko'rish vaqti kelajakda bo'lishi kerak")
    if when > now + dt.timedelta(days=MAX_DAYS_AHEAD):
        raise HTTPException(
            status_code=400, detail=f"Ko'rishni {MAX_DAYS_AHEAD} kundan ortiq oldin belgilab bo'lmaydi"
        )

    open_request = (
        db.query(models.ViewingRequest)
        .filter(
            models.ViewingRequest.property_id == prop.id,
            models.ViewingRequest.renter_id == current_user.id,
            models.ViewingRequest.status.in_(("kutilmoqda", "tasdiqlandi")),
        )
        .first()
    )
    if open_request:
        raise HTTPException(
            status_code=400, detail="Bu e'lon uchun so'rovingiz allaqachon yuborilgan"
        )

    viewing = models.ViewingRequest(
        property_id=prop.id,
        renter_id=current_user.id,
        owner_id=prop.owner_id,
        scheduled_at=when,
        note=payload.note.strip(),
    )
    db.add(viewing)
    db.commit()
    db.refresh(viewing)

    text = f"Ko'rish so'rovi: {_local_label(when)}."
    if viewing.note:
        text += f" {viewing.note}"
    await _notify(db, current_user.id, prop.owner_id, prop.id, text)
    return _to_out(viewing, request, current_user)


@router.get("/mine", response_model=list[schemas.ViewingOut])
def my_viewings(
    request: Request,
    role: str = Query(default="all", description="all | renter | owner"),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if role not in ("all", "renter", "owner"):
        raise HTTPException(status_code=422, detail="role must be all, renter or owner")

    query = db.query(models.ViewingRequest)
    if role == "renter":
        query = query.filter(models.ViewingRequest.renter_id == current_user.id)
    elif role == "owner":
        query = query.filter(models.ViewingRequest.owner_id == current_user.id)
    else:
        query = query.filter(
            or_(
                models.ViewingRequest.renter_id == current_user.id,
                models.ViewingRequest.owner_id == current_user.id,
            )
        )
    rows = query.order_by(models.ViewingRequest.scheduled_at.asc()).all()
    return [_to_out(v, request, current_user) for v in rows]


@router.patch("/{viewing_id}", response_model=schemas.ViewingOut)
async def update_viewing_status(
    viewing_id: int,
    payload: schemas.ViewingStatusUpdate,
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    viewing = db.query(models.ViewingRequest).filter(models.ViewingRequest.id == viewing_id).first()
    if not viewing or current_user.id not in (viewing.owner_id, viewing.renter_id):
        raise HTTPException(status_code=404, detail="So'rov topilmadi")

    new_status = payload.status
    is_owner = viewing.owner_id == current_user.id

    if new_status in ("tasdiqlandi", "rad_etildi"):
        if not is_owner:
            raise HTTPException(status_code=403, detail="Faqat e'lon egasi javob bera oladi")
        if viewing.status != "kutilmoqda":
            raise HTTPException(status_code=400, detail="Bu so'rovga allaqachon javob berilgan")
    elif new_status == "bekor_qilindi":
        if is_owner:
            raise HTTPException(status_code=403, detail="Faqat so'rov egasi bekor qila oladi")
        if viewing.status not in ("kutilmoqda", "tasdiqlandi"):
            raise HTTPException(status_code=400, detail="Bu so'rovni bekor qilib bo'lmaydi")
    else:
        raise HTTPException(status_code=400, detail="Bu holatga o'tkazib bo'lmaydi")

    viewing.status = new_status
    db.commit()
    db.refresh(viewing)

    when = _local_label(viewing.scheduled_at)
    texts = {
        "tasdiqlandi": f"Ko'rish tasdiqlandi: {when}. Kutaman!",
        "rad_etildi": f"Kechirasiz, {when} vaqtida ko'rish imkoni yo'q.",
        "bekor_qilindi": f"Ko'rish bekor qilindi: {when}.",
    }
    other_id = viewing.renter_id if is_owner else viewing.owner_id
    await _notify(db, current_user.id, other_id, viewing.property_id, texts[new_status])
    return _to_out(viewing, request, current_user)
