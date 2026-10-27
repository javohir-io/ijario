from __future__ import annotations

import datetime as dt
from typing import Annotated

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    PlainSerializer,
    field_validator,
)

from .utils.phone import normalize_phone, normalize_telegram


def to_utc_z(value: dt.datetime) -> str:
    """Naive datetimes in the database are UTC. Send them with an explicit
    'Z' so clients (which parse a bare ISO string as *local* time) show the
    right clock time."""
    if value.tzinfo is not None:
        value = value.astimezone(dt.timezone.utc).replace(tzinfo=None)
    return value.isoformat(timespec="seconds") + "Z"


UTCDateTime = Annotated[
    dt.datetime, PlainSerializer(to_utc_z, return_type=str, when_used="json")
]

CURRENCIES = ("UZS", "USD")
PRICE_UNITS = ("Kun", "Oy")
OWNER_TYPES = ("Egasi", "Rieltor")
LISTING_STATUSES = ("faol", "band")
VIEWING_STATUSES = ("kutilmoqda", "tasdiqlandi", "rad_etildi", "bekor_qilindi")
REPORT_REASONS = ("aldamchi", "narx_notogri", "allaqachon_band", "boshqa")


def _one_of(allowed: tuple[str, ...], label: str):
    def check(value: str | None) -> str | None:
        if value is not None and value not in allowed:
            raise ValueError(f"{label}: {', '.join(allowed)} dan biri bo'lishi kerak")
        return value

    return check


# ---------- Auth / Users ----------

class UserCreate(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    phone: str | None = None

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return normalize_phone(v)


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    email: EmailStr | None = None
    phone: str | None = None
    telegram: str | None = None
    password: str | None = Field(default=None, min_length=6, max_length=128)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return normalize_phone(v)

    @field_validator("telegram")
    @classmethod
    def _telegram(cls, v: str | None) -> str | None:
        return normalize_telegram(v)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    email: str
    phone: str | None = None
    telegram: str | None = None
    avatar_url: str | None = None
    is_admin: bool = False
    created_at: UTCDateTime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- Properties ----------

class PropertyImageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    url: str


class PropertyBase(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    description: str = ""
    city: str = Field(default="Toshkent", min_length=1, max_length=60)
    location: str = Field(min_length=1, max_length=150)
    metro: str | None = Field(default=None, max_length=80)
    price: float = Field(ge=0)
    currency: str = "UZS"
    price_unit: str = "Oy"
    deposit: float = Field(ge=0, default=0)
    utilities_included: bool = False
    bedrooms: int = Field(ge=0, le=20, default=1)
    bathrooms: int = Field(ge=0, le=20, default=1)
    floor: int = Field(ge=0, le=200, default=1)
    area: float = Field(ge=0, default=0)
    renovation: str = "O'rtacha"
    amenities: list[str] = []
    student_friendly: bool = False
    owner_type: str = "Egasi"

    @field_validator("currency")
    @classmethod
    def _currency(cls, v: str) -> str:
        return _one_of(CURRENCIES, "currency")(v)  # type: ignore[return-value]

    @field_validator("price_unit")
    @classmethod
    def _validate_unit(cls, v: str) -> str:
        return _one_of(PRICE_UNITS, "price_unit")(v)  # type: ignore[return-value]

    @field_validator("owner_type")
    @classmethod
    def _owner_type(cls, v: str) -> str:
        return _one_of(OWNER_TYPES, "owner_type")(v)  # type: ignore[return-value]

    @field_validator("metro")
    @classmethod
    def _metro(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None


class PropertyCreate(PropertyBase):
    pass


class PropertyUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    city: str | None = None
    location: str | None = None
    metro: str | None = None
    price: float | None = Field(default=None, ge=0)
    currency: str | None = None
    price_unit: str | None = None
    deposit: float | None = Field(default=None, ge=0)
    utilities_included: bool | None = None
    bedrooms: int | None = None
    bathrooms: int | None = None
    floor: int | None = None
    area: float | None = None
    renovation: str | None = None
    amenities: list[str] | None = None
    student_friendly: bool | None = None
    owner_type: str | None = None
    status: str | None = None

    @field_validator("currency")
    @classmethod
    def _currency(cls, v: str | None) -> str | None:
        return _one_of(CURRENCIES, "currency")(v)

    @field_validator("price_unit")
    @classmethod
    def _unit(cls, v: str | None) -> str | None:
        return _one_of(PRICE_UNITS, "price_unit")(v)

    @field_validator("owner_type")
    @classmethod
    def _owner_type(cls, v: str | None) -> str | None:
        return _one_of(OWNER_TYPES, "owner_type")(v)

    @field_validator("status")
    @classmethod
    def _status(cls, v: str | None) -> str | None:
        return _one_of(LISTING_STATUSES, "status")(v)

    @field_validator("metro")
    @classmethod
    def _metro(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        return v or None


class OwnerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    full_name: str
    phone: str | None = None
    telegram: str | None = None
    avatar_url: str | None = None


class PriceInsight(BaseModel):
    """How a monthly price compares with similar active listings.

    Only produced when there are enough comparable listings — we never
    guess. ``verdict`` is one of: arzon, bozor_narxida, qimmat."""

    median: float
    currency: str
    diff_percent: int  # negative = cheaper than the median
    sample_size: int
    scope: str  # "tuman" (same district) | "shahar" (whole city)
    verdict: str


class PropertyOut(PropertyBase):
    id: int
    created_at: UTCDateTime
    owner: OwnerOut
    images: list[PropertyImageOut] = []
    is_saved: bool = False
    status: str = "faol"
    views: int = 0
    saves_count: int = 0
    price_uzs: float = 0
    price_insight: PriceInsight | None = None


class PropertyListOut(BaseModel):
    total: int
    items: list[PropertyOut]


class SaveToggleOut(BaseModel):
    saved: bool


class ReportCreate(BaseModel):
    reason: str
    details: str = Field(default="", max_length=1000)

    @field_validator("reason")
    @classmethod
    def _reason(cls, v: str) -> str:
        return _one_of(REPORT_REASONS, "reason")(v)  # type: ignore[return-value]


class ReportOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    property_id: int
    reporter_id: int
    reason: str
    details: str
    created_at: UTCDateTime


# ---------- Messages / Chat ----------

class MessageCreate(BaseModel):
    receiver_id: int
    content: str = Field(min_length=1, max_length=2000)
    property_id: int | None = None


class MessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_id: int
    receiver_id: int
    property_id: int | None = None
    content: str
    is_read: bool
    created_at: UTCDateTime


class ConversationOut(BaseModel):
    """One row per person you've exchanged messages with, for a chat list."""
    other_user: OwnerOut
    last_message: MessageOut
    unread_count: int


# ---------- Viewings ----------

class ViewingCreate(BaseModel):
    property_id: int
    scheduled_at: dt.datetime
    note: str = Field(default="", max_length=500)


class ViewingStatusUpdate(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def _status(cls, v: str) -> str:
        return _one_of(VIEWING_STATUSES, "status")(v)  # type: ignore[return-value]


class ViewingPropertyOut(BaseModel):
    id: int
    title: str
    city: str
    location: str
    cover_url: str | None = None


class ViewingOut(BaseModel):
    id: int
    property: ViewingPropertyOut
    renter: OwnerOut
    owner: OwnerOut
    scheduled_at: UTCDateTime
    note: str
    status: str
    created_at: UTCDateTime
    # Which side the current person is on: "renter" | "owner"
    role: str


# ---------- Meta / Admin ----------

class MetaOut(BaseModel):
    usd_to_uzs: float
    api_version: str


class AdminStatsOut(BaseModel):
    total_users: int
    total_properties: int
    active_properties: int = 0
    total_messages: int
    total_saved: int
    total_viewings: int = 0
    total_reports: int = 0
