"""Small normalisers for contact fields."""

from __future__ import annotations

import re

_PHONE_ERROR = "Telefon raqami noto'g'ri. Namuna: +998 90 123 45 67"
_TELEGRAM_RE = re.compile(r"^[A-Za-z0-9_]{4,32}$")


def normalize_phone(value: str | None) -> str | None:
    """Returns ``+998XXXXXXXXX`` for any reasonable way of writing an
    Uzbek number ("90 123 45 67", "+998 (90) 123-45-67", "998901234567"),
    ``None`` for blank input, and raises ``ValueError`` for anything else."""
    if value is None:
        return None
    digits = re.sub(r"\D", "", value)
    if not digits:
        return None
    if len(digits) == 9:
        digits = "998" + digits
    if len(digits) == 12 and digits.startswith("998"):
        return "+" + digits
    raise ValueError(_PHONE_ERROR)


def normalize_telegram(value: str | None) -> str | None:
    """Accepts ``@name``, ``name`` or ``https://t.me/name``; stores ``name``."""
    if value is None:
        return None
    cleaned = value.strip()
    for prefix in ("https://t.me/", "http://t.me/", "t.me/"):
        if cleaned.lower().startswith(prefix):
            cleaned = cleaned[len(prefix):]
    cleaned = cleaned.lstrip("@").strip()
    if not cleaned:
        return None
    if not _TELEGRAM_RE.match(cleaned):
        raise ValueError("Telegram nomi noto'g'ri. Namuna: @ijario")
    return cleaned
