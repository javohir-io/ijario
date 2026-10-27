from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile
from sqlalchemy import case, or_
from sqlalchemy.orm import Session

from .. import models, schemas
from ..config import settings
from ..database import get_db
from ..deps import get_current_user, get_optional_user
from ..insights import compute_price_insight
from ..serializers import property_out
from ..utils.files import delete_upload, save_upload

router = APIRouter(prefix="/properties", tags=["Properties"])

SORTS = ("new", "cheap", "expensive", "area")


def _blank_to_none(value):
    """Treat an empty-string query param (e.g. '?min_price=' from a browser
    or a Postman param left checked-but-blank) the same as if it were
    omitted, instead of letting FastAPI raise a 422 trying to parse it."""
    return None if value in ("", None) else value


def _to_number(raw: str | None, cast, field_name: str):
    raw = _blank_to_none(raw)
    if raw is None:
        return None
    try:
        return cast(raw)
    except ValueError:
        raise HTTPException(status_code=422, detail=f"{field_name} must be a number")


@router.get("", response_model=schemas.PropertyListOut)
def list_properties(
    request: Request,
    q: str | None = Query(default=None, description="Search in title/location/metro"),
    city: str | None = None,
    location: str | None = None,
    min_price: str | None = Query(default=None, description="In UZS (USD listings are converted)"),
    max_price: str | None = Query(default=None, description="In UZS (USD listings are converted)"),
    price_unit: str | None = Query(default=None, description="'Oy' or 'Kun'"),
    min_bedrooms: str | None = Query(default=None),
    min_bathrooms: str | None = Query(default=None),
    min_area: str | None = Query(default=None),
    max_area: str | None = Query(default=None),
    renovation: str | None = None,
    amenities: str | None = Query(default=None, description="Comma-separated amenity names"),
    student_only: bool = False,
    owner_only: bool = Query(default=False, description="Only listings posted by the owner (no agent)"),
    near_metro: bool = False,
    utilities_included: bool = False,
    include_inactive: bool = False,
    sort: str = Query(default="new", description="new | cheap | expensive | area"),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: models.User | None = Depends(get_optional_user),
):
    city = _blank_to_none(city)
    location = _blank_to_none(location)
    renovation = _blank_to_none(renovation)
    amenities = _blank_to_none(amenities)
    price_unit = _blank_to_none(price_unit)
    q = _blank_to_none(q)

    min_price_n = _to_number(min_price, float, "min_price")
    max_price_n = _to_number(max_price, float, "max_price")
    min_bedrooms_n = _to_number(min_bedrooms, int, "min_bedrooms")
    min_bathrooms_n = _to_number(min_bathrooms, int, "min_bathrooms")
    min_area_n = _to_number(min_area, float, "min_area")
    max_area_n = _to_number(max_area, float, "max_area")

    if sort not in SORTS:
        raise HTTPException(status_code=422, detail=f"sort must be one of: {', '.join(SORTS)}")
    if price_unit is not None and price_unit not in schemas.PRICE_UNITS:
        raise HTTPException(status_code=422, detail="price_unit must be 'Oy' or 'Kun'")

    # Price expressed in UZS regardless of the listing's own currency, so the
    # filters and sorting below treat 300 USD and 3,600,000 UZS alike.
    price_uzs = case(
        (models.Property.currency == "USD", models.Property.price * settings.usd_to_uzs),
        else_=models.Property.price,
    )

    # For sorting only: a daily rate is compared as ~30 days, so "cheapest
    # first" doesn't put a 350,000 so'm/day flat above a 3,000,000/month one.
    price_sort = case((models.Property.price_unit == "Kun", price_uzs * 30), else_=price_uzs)

    query = db.query(models.Property)
    if not include_inactive:
        query = query.filter(models.Property.status == "faol")

    if q:
        like = f"%{q}%"
        query = query.filter(
            or_(
                models.Property.title.ilike(like),
                models.Property.location.ilike(like),
                models.Property.city.ilike(like),
                models.Property.metro.ilike(like),
            )
        )
    if city:
        query = query.filter(models.Property.city == city)
    if location:
        query = query.filter(models.Property.location == location)
    if price_unit:
        query = query.filter(models.Property.price_unit == price_unit)
    if min_price_n is not None:
        query = query.filter(price_uzs >= min_price_n)
    if max_price_n is not None:
        query = query.filter(price_uzs <= max_price_n)
    if min_bedrooms_n is not None:
        query = query.filter(models.Property.bedrooms >= min_bedrooms_n)
    if min_bathrooms_n is not None:
        query = query.filter(models.Property.bathrooms >= min_bathrooms_n)
    if min_area_n is not None:
        query = query.filter(models.Property.area >= min_area_n)
    if max_area_n is not None:
        query = query.filter(models.Property.area <= max_area_n)
    if renovation:
        query = query.filter(models.Property.renovation == renovation)
    if student_only:
        query = query.filter(models.Property.student_friendly.is_(True))
    if owner_only:
        query = query.filter(models.Property.owner_type == "Egasi")
    if near_metro:
        query = query.filter(models.Property.metro.isnot(None), models.Property.metro != "")
    if utilities_included:
        query = query.filter(models.Property.utilities_included.is_(True))

    if sort == "cheap":
        query = query.order_by(price_sort.asc(), models.Property.id.desc())
    elif sort == "expensive":
        query = query.order_by(price_sort.desc(), models.Property.id.desc())
    elif sort == "area":
        query = query.order_by(models.Property.area.desc(), models.Property.id.desc())
    else:
        query = query.order_by(models.Property.created_at.desc(), models.Property.id.desc())

    if amenities:
        # Amenities live in a JSON column, which can't be filtered portably in
        # SQL (SQLite vs Postgres). Filter in Python *before* paginating so
        # `total` and the page contents stay correct.
        wanted = {a.strip().lower() for a in amenities.split(",") if a.strip()}
        everything = [
            p for p in query.all() if wanted.issubset({a.lower() for a in (p.amenities or [])})
        ]
        total = len(everything)
        results = everything[skip : skip + limit]
    else:
        total = query.count()
        results = query.offset(skip).limit(limit).all()

    return schemas.PropertyListOut(
        total=total,
        items=[property_out(p, request, current_user) for p in results],
    )


# NOTE: declared before "/{property_id}" so "mine" isn't parsed as an id.
@router.get("/mine", response_model=schemas.PropertyListOut)
def my_properties(
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Every listing the current user posted — including ones marked 'band'."""
    results = (
        db.query(models.Property)
        .filter(models.Property.owner_id == current_user.id)
        .order_by(models.Property.created_at.desc(), models.Property.id.desc())
        .all()
    )
    return schemas.PropertyListOut(
        total=len(results),
        items=[property_out(p, request, current_user) for p in results],
    )


@router.get("/{property_id}", response_model=schemas.PropertyOut)
def get_property(
    property_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.User | None = Depends(get_optional_user),
):
    property_ = db.query(models.Property).filter(models.Property.id == property_id).first()
    if not property_:
        raise HTTPException(status_code=404, detail="E'lon topilmadi")

    # Count a view unless the owner is just looking at their own listing.
    if current_user is None or current_user.id != property_.owner_id:
        property_.views = (property_.views or 0) + 1
        db.commit()
        db.refresh(property_)

    insight = compute_price_insight(db, property_)
    return property_out(property_, request, current_user, insight)


@router.post("", response_model=schemas.PropertyOut, status_code=201)
def create_property(
    payload: schemas.PropertyCreate,
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    property_ = models.Property(owner_id=current_user.id, **payload.model_dump())
    db.add(property_)
    db.commit()
    db.refresh(property_)
    return property_out(property_, request, current_user)


def _get_owned_property(property_id: int, current_user: models.User, db: Session) -> models.Property:
    property_ = db.query(models.Property).filter(models.Property.id == property_id).first()
    if not property_:
        raise HTTPException(status_code=404, detail="E'lon topilmadi")
    if property_.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu e'lonni tahrirlash huquqingiz yo'q")
    return property_


@router.put("/{property_id}", response_model=schemas.PropertyOut)
def update_property(
    property_id: int,
    payload: schemas.PropertyUpdate,
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    property_ = _get_owned_property(property_id, current_user, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(property_, field, value)
    db.commit()
    db.refresh(property_)
    return property_out(property_, request, current_user)


@router.delete("/{property_id}", status_code=204)
def delete_property(
    property_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    property_ = _get_owned_property(property_id, current_user, db)
    for img in property_.images:
        delete_upload(img.path)
    db.delete(property_)
    db.commit()
    return None


@router.post("/{property_id}/images", response_model=schemas.PropertyOut)
def upload_property_images(
    property_id: int,
    request: Request,
    files: list[UploadFile] = File(...),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    property_ = _get_owned_property(property_id, current_user, db)
    for f in files:
        relative_path = save_upload(f, f"properties/{property_id}")
        db.add(models.PropertyImage(property_id=property_id, path=relative_path))
    db.commit()
    db.refresh(property_)
    return property_out(property_, request, current_user)


@router.delete("/{property_id}/images/{image_id}", response_model=schemas.PropertyOut)
def delete_property_image(
    property_id: int,
    image_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    property_ = _get_owned_property(property_id, current_user, db)
    image = next((img for img in property_.images if img.id == image_id), None)
    if not image:
        raise HTTPException(status_code=404, detail="Rasm topilmadi")

    delete_upload(image.path)
    db.delete(image)
    db.commit()
    db.refresh(property_)
    return property_out(property_, request, current_user)


@router.post("/{property_id}/save", response_model=schemas.SaveToggleOut)
def toggle_save(
    property_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    property_ = db.query(models.Property).filter(models.Property.id == property_id).first()
    if not property_:
        raise HTTPException(status_code=404, detail="E'lon topilmadi")

    link = (
        db.query(models.SavedProperty)
        .filter(
            models.SavedProperty.user_id == current_user.id,
            models.SavedProperty.property_id == property_id,
        )
        .first()
    )
    if link:
        db.delete(link)
        db.commit()
        return schemas.SaveToggleOut(saved=False)

    db.add(models.SavedProperty(user_id=current_user.id, property_id=property_id))
    db.commit()
    return schemas.SaveToggleOut(saved=True)


@router.post("/{property_id}/report", response_model=schemas.ReportOut, status_code=201)
def report_property(
    property_id: int,
    payload: schemas.ReportCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Flag a listing as fake / wrongly priced / already rented."""
    property_ = db.query(models.Property).filter(models.Property.id == property_id).first()
    if not property_:
        raise HTTPException(status_code=404, detail="E'lon topilmadi")
    if property_.owner_id == current_user.id:
        raise HTTPException(status_code=400, detail="O'z e'loningizga shikoyat qila olmaysiz")

    already = (
        db.query(models.Report)
        .filter(
            models.Report.property_id == property_id,
            models.Report.reporter_id == current_user.id,
        )
        .first()
    )
    if already:
        raise HTTPException(status_code=400, detail="Bu e'longa shikoyatingiz allaqachon qabul qilingan")

    report = models.Report(
        property_id=property_id,
        reporter_id=current_user.id,
        reason=payload.reason,
        details=payload.details,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report
