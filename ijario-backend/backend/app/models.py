from __future__ import annotations

import datetime as dt

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> dt.datetime:
    """Naive UTC "now" (the columns are timezone-naive; the API adds the 'Z')."""
    return dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    full_name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(180), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    phone: Mapped[str | None] = mapped_column(String(40), nullable=True)
    telegram: Mapped[str | None] = mapped_column(String(60), nullable=True)
    avatar_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow)

    properties: Mapped[list["Property"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    saved: Mapped[list["SavedProperty"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class Property(Base):
    __tablename__ = "properties"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))

    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    city: Mapped[str] = mapped_column(String(60), default="Toshkent", index=True)
    # District (tuman) for big cities, neighbourhood / area elsewhere.
    location: Mapped[str] = mapped_column(String(150), index=True)
    metro: Mapped[str | None] = mapped_column(String(80), nullable=True)

    price: Mapped[float] = mapped_column(Float, default=0)
    currency: Mapped[str] = mapped_column(String(3), default="UZS")  # "UZS" | "USD"
    price_unit: Mapped[str] = mapped_column(String(10), default="Oy")  # "Kun" | "Oy"
    deposit: Mapped[float] = mapped_column(Float, default=0)
    utilities_included: Mapped[bool] = mapped_column(Boolean, default=False)

    bedrooms: Mapped[int] = mapped_column(Integer, default=1)
    bathrooms: Mapped[int] = mapped_column(Integer, default=1)
    floor: Mapped[int] = mapped_column(Integer, default=1)
    area: Mapped[float] = mapped_column(Float, default=0)
    renovation: Mapped[str] = mapped_column(String(40), default="O'rtacha")
    amenities: Mapped[list] = mapped_column(JSON, default=list)
    student_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    owner_type: Mapped[str] = mapped_column(String(10), default="Egasi")  # "Egasi" | "Rieltor"

    status: Mapped[str] = mapped_column(String(10), default="faol", index=True)  # "faol" | "band"
    views: Mapped[int] = mapped_column(Integer, default=0)

    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow)

    owner: Mapped["User"] = relationship(back_populates="properties")
    images: Mapped[list["PropertyImage"]] = relationship(
        back_populates="property", cascade="all, delete-orphan", order_by="PropertyImage.id"
    )
    saved_by: Mapped[list["SavedProperty"]] = relationship(
        back_populates="property", cascade="all, delete-orphan"
    )
    viewings: Mapped[list["ViewingRequest"]] = relationship(
        back_populates="property", cascade="all, delete-orphan"
    )
    reports: Mapped[list["Report"]] = relationship(
        back_populates="property", cascade="all, delete-orphan"
    )


class PropertyImage(Base):
    __tablename__ = "property_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    property_id: Mapped[int] = mapped_column(ForeignKey("properties.id", ondelete="CASCADE"))
    path: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow)

    property: Mapped["Property"] = relationship(back_populates="images")


class SavedProperty(Base):
    """Bookmark join table between a user and a property."""

    __tablename__ = "saved_properties"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow)

    user: Mapped["User"] = relationship(back_populates="saved")
    property: Mapped["Property"] = relationship(back_populates="saved_by")


class Message(Base):
    """A single direct message between two users (optionally about a
    particular listing, for context — e.g. tapping "Xabar" on a property)."""

    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    receiver_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    property_id: Mapped[int | None] = mapped_column(
        ForeignKey("properties.id", ondelete="SET NULL"), nullable=True
    )
    content: Mapped[str] = mapped_column(Text)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow, index=True)


class ViewingRequest(Base):
    """A renter asking to see a flat at a given time ("Ko'rish so'rovi").

    status: kutilmoqda (pending) -> tasdiqlandi (confirmed) | rad_etildi (declined)
            and the renter can bekor_qilindi (cancel) a pending/confirmed one.
    """

    __tablename__ = "viewing_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), index=True
    )
    renter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    scheduled_at: Mapped[dt.datetime] = mapped_column(DateTime)  # naive UTC
    note: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(14), default="kutilmoqda", index=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow)

    property: Mapped["Property"] = relationship(back_populates="viewings")
    renter: Mapped["User"] = relationship(foreign_keys=[renter_id])
    owner: Mapped["User"] = relationship(foreign_keys=[owner_id])


class Report(Base):
    """A complaint about a listing (fake, wrong price, already rented...)."""

    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), index=True
    )
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(40))
    details: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=utcnow)

    property: Mapped["Property"] = relationship(back_populates="reports")
    reporter: Mapped["User"] = relationship(foreign_keys=[reporter_id])
