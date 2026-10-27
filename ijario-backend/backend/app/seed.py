"""Demo data, so a fresh install doesn't open to an empty app.

    python -m app.seed            # adds demo accounts + listings (only if there are no listings yet)
    python -m app.seed --force    # adds them even if listings already exist
    python -m app.seed --remove   # deletes the demo accounts and everything they own

These are SAMPLE listings with made-up owners and stock photos. Do not run this
against a production database that real people use.

Demo sign-ins (password for all: demo12345):
    demo.owner@ijario.uz     (a landlord with several listings)
    demo.agent@ijario.uz     (an agent)
    demo.renter@ijario.uz    (someone looking for a flat)
"""

from __future__ import annotations

import sys

from pathlib import Path

from fastapi import UploadFile
from sqlalchemy.orm import Session

from . import models
from .database import Base, SessionLocal, engine
from .migrate import ensure_columns
from .security import get_password_hash
from .utils.files import delete_upload, save_upload

# One photo per demo listing, in the same order as LISTINGS below.
# (Free Pexels photos, resized; see seed_assets/CREDITS.md.)
PHOTO_DIR = Path(__file__).parent / "seed_assets"

PASSWORD = "demo12345"

USERS = [
    ("demo.owner@ijario.uz", "Aziza Karimova", "+998901112233", "demo_owner"),
    ("demo.agent@ijario.uz", "Bobur Rahimov", "+998931112244", None),
    ("demo.renter@ijario.uz", "Dilnoza Yusupova", "+998971112255", None),
]

# (owner index, title, city, location, metro, price, currency, unit, deposit,
#  utilities, bedrooms, bathrooms, floor, area, renovation, amenities, student, owner_type)
LISTINGS = [
    (0, "Yorug' 2 xonali kvartira, metroga yaqin", "Toshkent", "Chilonzor", "Novza", 4_500_000, "UZS", "Oy", 4_500_000, False, 2, 1, 4, 58, "Yaxshi", ["Mebel", "Konditsioner", "Wi-Fi", "Muzlatgich"], False, "Egasi"),
    (0, "Talabalar uchun qulay 1 xonali", "Toshkent", "Mirzo Ulug'bek", None, 2_800_000, "UZS", "Oy", 0, True, 1, 1, 2, 32, "O'rtacha", ["Mebel", "Wi-Fi", "Kir yuvish mashinasi"], True, "Egasi"),
    (0, "Yunusobodda keng 3 xonali, evro ta'mir", "Toshkent", "Yunusobod", "Minor", 7_500_000, "UZS", "Oy", 7_500_000, False, 3, 2, 7, 96, "Evro ta'mir", ["Mebel", "Konditsioner", "Wi-Fi", "Lift", "Avtoturargoh", "Balkon"], False, "Egasi"),
    (1, "Mirobodda markazga yaqin 2 xonali", "Toshkent", "Mirobod", "Oybek", 450, "USD", "Oy", 450, False, 2, 1, 5, 64, "Evro ta'mir", ["Mebel", "Konditsioner", "Televizor", "Lift"], False, "Rieltor"),
    (1, "Sergelida yangi uy, 2 xonali", "Toshkent", "Sergeli", None, 3_200_000, "UZS", "Oy", 3_200_000, True, 2, 1, 9, 54, "Yaxshi", ["Mebel", "Muzlatgich", "Lift"], False, "Rieltor"),
    (0, "Kunlik ijara: shinam studiya", "Toshkent", "Shayxontohur", "Chorsu", 350_000, "UZS", "Kun", 0, True, 1, 1, 3, 30, "Evro ta'mir", ["Mebel", "Konditsioner", "Wi-Fi", "Televizor"], False, "Egasi"),
    (0, "Yakkasaroyda tinch ko'chada 2 xonali", "Toshkent", "Yakkasaroy", None, 4_800_000, "UZS", "Oy", 4_800_000, False, 2, 1, 3, 60, "Yaxshi", ["Mebel", "Wi-Fi", "Balkon"], False, "Egasi"),
    (1, "Uchtepada oilaga 3 xonali", "Toshkent", "Uchtepa", None, 3_900_000, "UZS", "Oy", 3_900_000, False, 3, 1, 2, 72, "O'rtacha", ["Muzlatgich", "Kir yuvish mashinasi"], False, "Rieltor"),
    (0, "Registon yaqinida mehmonxona uslubidagi xona", "Samarqand", "Registon atrofi", None, 2_200_000, "UZS", "Oy", 0, True, 1, 1, 1, 28, "Yaxshi", ["Mebel", "Konditsioner", "Wi-Fi"], True, "Egasi"),
    (0, "Buxoro markazida hovlili uy", "Buxoro", "Eski shahar", None, 3_500_000, "UZS", "Oy", 3_500_000, False, 3, 1, 1, 90, "O'rtacha", ["Mebel", "Konditsioner"], False, "Egasi"),
]


def seed(db: Session, force: bool = False) -> str:
    if not force and db.query(models.Property).count() > 0:
        return "Skipped: listings already exist (use --force to add demo data anyway)."

    users: list[models.User] = []
    for email, name, phone, telegram in USERS:
        user = db.query(models.User).filter(models.User.email == email).first()
        if not user:
            user = models.User(
                email=email,
                full_name=name,
                phone=phone,
                telegram=telegram,
                hashed_password=get_password_hash(PASSWORD),
            )
            db.add(user)
            db.flush()
        users.append(user)

    for index, (owner, title, city, location, metro, price, currency, unit, deposit, utilities,
                beds, baths, floor, area, renovation, amenities, student, owner_type) in enumerate(LISTINGS):
        prop = models.Property(
            owner_id=users[owner].id,
            title=title,
            description=f"{title}. Namuna e'lon (demo ma'lumot).",
            city=city,
            location=location,
            metro=metro,
            price=price,
            currency=currency,
            price_unit=unit,
            deposit=deposit,
            utilities_included=utilities,
            bedrooms=beds,
            bathrooms=baths,
            floor=floor,
            area=area,
            renovation=renovation,
            amenities=amenities,
            student_friendly=student,
            owner_type=owner_type,
        )
        db.add(prop)
        db.flush()  # we need prop.id to store its photo under properties/<id>/

        photo = PHOTO_DIR / f"demo-{index:02d}.jpg"
        if photo.exists():
            # Same code path as a real upload (local disk or Cloudflare R2).
            with photo.open("rb") as handle:
                upload = UploadFile(file=handle, filename=photo.name)
                path = save_upload(upload, f"properties/{prop.id}")
            db.add(models.PropertyImage(property_id=prop.id, path=path))
    db.commit()
    return f"Added {len(USERS)} demo accounts and {len(LISTINGS)} demo listings with photos. Password: {PASSWORD}"


def remove_demo(db: Session) -> str:
    """Deletes the demo accounts, their listings, and anything that points at
    them (messages, viewings, reports, bookmarks). Real users are untouched."""
    demo_emails = [email for email, *_ in USERS]
    users = db.query(models.User).filter(models.User.email.in_(demo_emails)).all()
    if not users:
        return "Nothing to remove: no demo accounts found."
    ids = [u.id for u in users]

    # Rows that reference the demo users from *other* people's data. Postgres
    # would cascade these itself; doing it explicitly keeps SQLite correct too.
    db.query(models.Message).filter(
        models.Message.sender_id.in_(ids) | models.Message.receiver_id.in_(ids)
    ).delete(synchronize_session=False)
    db.query(models.ViewingRequest).filter(
        models.ViewingRequest.renter_id.in_(ids) | models.ViewingRequest.owner_id.in_(ids)
    ).delete(synchronize_session=False)
    db.query(models.Report).filter(models.Report.reporter_id.in_(ids)).delete(synchronize_session=False)
    db.flush()

    demo_listings = db.query(models.Property).filter(models.Property.owner_id.in_(ids)).all()
    listings = len(demo_listings)
    for listing in demo_listings:
        for image in listing.images:
            delete_upload(image.path)  # photo files, so nothing is left on disk
    for user in users:
        db.delete(user)  # cascades to their listings, images and bookmarks
    db.commit()
    return f"Removed {len(users)} demo accounts and {listings} demo listings."


def main() -> None:
    Base.metadata.create_all(bind=engine)
    ensure_columns(engine)
    with SessionLocal() as db:
        if "--remove" in sys.argv:
            print(remove_demo(db))
        else:
            print(seed(db, force="--force" in sys.argv))


if __name__ == "__main__":
    main()
