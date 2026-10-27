from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from . import schemas
from .config import settings
from .database import Base, engine
from .migrate import ensure_columns
from .routers import admin, auth, messages, properties, users, viewings

Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)

API_VERSION = "2.0.0"

app = FastAPI(
    title="Ijario API",
    description="Backend for Ijario — a rental marketplace for Uzbekistan.",
    version=API_VERSION,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # dev-friendly; tighten this before shipping to production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(properties.router)
app.include_router(messages.router)
app.include_router(viewings.router)
app.include_router(admin.router)


@app.on_event("startup")
def on_startup() -> None:
    # Simple MVP approach: create tables directly from the models.
    # Swap this for Alembic migrations once the schema needs to evolve safely.
    Base.metadata.create_all(bind=engine)
    # create_all never alters existing tables; add any columns introduced
    # since the database was first created (safe to run on every start).
    ensure_columns(engine)


@app.get("/")
def health_check():
    return {"message": "Ijario API ishlayapti", "docs": "/docs"}


@app.get("/meta", response_model=schemas.MetaOut, tags=["Meta"])
def meta():
    """Small bits of server config the app needs (currently the USD->UZS
    rate used to compare listings priced in different currencies)."""
    return schemas.MetaOut(usd_to_uzs=settings.usd_to_uzs, api_version=API_VERSION)
