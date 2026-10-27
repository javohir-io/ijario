"""Price insight: is this monthly rent cheap, fair or expensive?

We compare against *active listings that look alike* (same city, currency
and number of rooms), preferring the same district. If there are not enough
comparable listings we return ``None`` — an honest "not enough data" beats a
made-up number."""

from __future__ import annotations

import statistics

from sqlalchemy.orm import Session

from . import models, schemas

MIN_DISTRICT_SAMPLE = 3
MIN_CITY_SAMPLE = 5
# Within +-8% of the median counts as "bozor narxida" (fair market price).
FAIR_BAND_PERCENT = 8


def _verdict(diff_percent: float) -> str:
    if diff_percent <= -FAIR_BAND_PERCENT:
        return "arzon"
    if diff_percent >= FAIR_BAND_PERCENT:
        return "qimmat"
    return "bozor_narxida"


def compute_price_insight(db: Session, prop: models.Property) -> schemas.PriceInsight | None:
    if prop.price_unit != "Oy" or prop.price <= 0:
        return None

    base = db.query(models.Property.price, models.Property.location).filter(
        models.Property.id != prop.id,
        models.Property.status == "faol",
        models.Property.price_unit == "Oy",
        models.Property.price > 0,
        models.Property.city == prop.city,
        models.Property.currency == prop.currency,
        models.Property.bedrooms == prop.bedrooms,
    )
    rows = base.all()

    district = [price for price, location in rows if location == prop.location]
    if len(district) >= MIN_DISTRICT_SAMPLE:
        sample, scope = district, "tuman"
    elif len(rows) >= MIN_CITY_SAMPLE:
        sample, scope = [price for price, _ in rows], "shahar"
    else:
        return None

    median = statistics.median(sample)
    if median <= 0:
        return None
    diff = (prop.price - median) / median * 100
    return schemas.PriceInsight(
        median=round(median),
        currency=prop.currency,
        diff_percent=int(round(diff)),
        sample_size=len(sample),
        scope=scope,
        verdict=_verdict(diff),
    )
