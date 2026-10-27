"""ORM -> API schema conversion shared by every router."""

from __future__ import annotations

from fastapi import Request

from . import models, schemas
from .config import settings
from .deps import absolute_url


def price_in_uzs(price: float, currency: str) -> float:
    """Normalises a price to UZS so mixed-currency listings can be compared."""
    return round(price * settings.usd_to_uzs) if currency == "USD" else price


def owner_out(
    user: models.User, request: Request, reveal_contact: bool = True
) -> schemas.OwnerOut:
    """``reveal_contact=False`` hides phone and Telegram (used for anonymous
    visitors, so listings can't be scraped for phone numbers)."""
    return schemas.OwnerOut(
        id=user.id,
        full_name=user.full_name,
        phone=user.phone if reveal_contact else None,
        telegram=user.telegram if reveal_contact else None,
        avatar_url=absolute_url(request, user.avatar_path),
    )


def user_out(user: models.User, request: Request) -> schemas.UserOut:
    return schemas.UserOut(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        phone=user.phone,
        telegram=user.telegram,
        avatar_url=absolute_url(request, user.avatar_path),
        is_admin=bool(user.is_admin),  # was missing before: the app never saw admins
        created_at=user.created_at,
    )


def property_out(
    property_: models.Property,
    request: Request,
    current_user: models.User | None,
    insight: schemas.PriceInsight | None = None,
) -> schemas.PropertyOut:
    is_saved = False
    if current_user is not None:
        is_saved = any(link.user_id == current_user.id for link in property_.saved_by)

    return schemas.PropertyOut(
        id=property_.id,
        title=property_.title,
        description=property_.description,
        city=property_.city or "Toshkent",
        location=property_.location,
        metro=property_.metro,
        price=property_.price,
        currency=property_.currency or "UZS",
        price_unit=property_.price_unit,
        deposit=property_.deposit or 0,
        utilities_included=bool(property_.utilities_included),
        bedrooms=property_.bedrooms,
        bathrooms=property_.bathrooms,
        floor=property_.floor,
        area=property_.area,
        renovation=property_.renovation,
        amenities=property_.amenities or [],
        student_friendly=property_.student_friendly,
        owner_type=property_.owner_type or "Egasi",
        status=property_.status or "faol",
        views=property_.views or 0,
        saves_count=len(property_.saved_by),
        price_uzs=price_in_uzs(property_.price, property_.currency or "UZS"),
        created_at=property_.created_at,
        owner=owner_out(property_.owner, request, reveal_contact=current_user is not None),
        images=[
            schemas.PropertyImageOut(id=img.id, url=absolute_url(request, img.path))
            for img in property_.images
        ],
        is_saved=is_saved,
        price_insight=insight,
    )
