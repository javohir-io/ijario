"""Tests for the features added in Ijario 2.0."""

import datetime as dt

import pytest
from sqlalchemy import create_engine, inspect, text

from app.migrate import ensure_columns


def _payload(**overrides):
    payload = {
        "title": "Yorug' 2 xonali kvartira",
        "description": "Metroga yaqin",
        "city": "Toshkent",
        "location": "Yunusobod",
        "price": 4_000_000,
        "currency": "UZS",
        "price_unit": "Oy",
        "bedrooms": 2,
        "bathrooms": 1,
        "floor": 4,
        "area": 62,
        "renovation": "Yaxshi",
        "amenities": ["Wi-Fi", "Konditsioner"],
    }
    payload.update(overrides)
    return payload


def _create(client, headers, **overrides):
    r = client.post("/properties", json=_payload(**overrides), headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def _future(hours=48):
    return (dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=hours)).isoformat()


# ---------- accounts ----------

def test_admin_flag_is_exposed_to_the_app(client, register_user, make_admin):
    session = register_user(email="boss@example.com")
    assert session["user"]["is_admin"] is False
    make_admin("boss@example.com")

    me = client.get("/auth/me", headers=session["headers"]).json()
    assert me["is_admin"] is True  # regression: this used to always be False

    login = client.post("/auth/login", data={"username": "boss@example.com", "password": "testpass123"})
    assert login.json()["user"]["is_admin"] is True


def test_timestamps_carry_a_utc_marker(client, register_user):
    session = register_user()
    assert session["user"]["created_at"].endswith("Z")


def test_login_ignores_email_case(client, register_user):
    register_user(email="Aziza@Example.com")
    ok = client.post("/auth/login", data={"username": "AZIZA@example.COM", "password": "testpass123"})
    assert ok.status_code == 200
    assert ok.json()["user"]["email"] == "aziza@example.com"


@pytest.mark.parametrize(
    "raw",
    ["90 123 45 67", "+998 (90) 123-45-67", "998901234567", "+998901234567"],
)
def test_phone_is_normalised(client, register_user, raw):
    session = register_user(email=f"p{abs(hash(raw))}@example.com", phone=raw)
    assert session["user"]["phone"] == "+998901234567"


def test_bad_phone_is_rejected(client):
    r = client.post(
        "/auth/register",
        json={"full_name": "Test", "email": "x@example.com", "password": "secret1", "phone": "12345"},
    )
    assert r.status_code == 422


def test_profile_telegram_and_clearing_phone(client, register_user):
    session = register_user(phone="901234567")
    r = client.put(
        "/users/me",
        json={"telegram": "https://t.me/@ijario_uz".replace("@", "")},
        headers=session["headers"],
    )
    assert r.status_code == 200
    assert r.json()["telegram"] == "ijario_uz"

    cleared = client.put("/users/me", json={"phone": ""}, headers=session["headers"])
    assert cleared.json()["phone"] is None
    assert cleared.json()["telegram"] == "ijario_uz"  # untouched


def test_changing_to_a_taken_email_is_a_400_not_a_500(client, register_user):
    register_user(email="first@example.com")
    second = register_user(email="second@example.com")
    r = client.put("/users/me", json={"email": "first@example.com"}, headers=second["headers"])
    assert r.status_code == 400


# ---------- listings ----------

def test_new_listing_fields_round_trip(client, register_user):
    s = register_user()
    p = _create(
        client, s["headers"], metro="Novza", deposit=4_000_000, utilities_included=True, owner_type="Rieltor"
    )
    assert p["city"] == "Toshkent"
    assert p["currency"] == "UZS"
    assert p["metro"] == "Novza"
    assert p["utilities_included"] is True
    assert p["owner_type"] == "Rieltor"
    assert p["status"] == "faol"
    assert p["price_uzs"] == 4_000_000


def test_invalid_enums_are_rejected(client, register_user):
    s = register_user()
    assert client.post("/properties", json=_payload(currency="EUR"), headers=s["headers"]).status_code == 422
    assert client.post("/properties", json=_payload(owner_type="Boshqa"), headers=s["headers"]).status_code == 422


def test_usd_listings_compare_with_uzs_listings(client, register_user):
    s = register_user()
    _create(client, s["headers"], title="UZS arzon", price=2_000_000)
    _create(client, s["headers"], title="USD qimmat", price=500, currency="USD")  # 6,000,000 UZS
    _create(client, s["headers"], title="UZS o'rta", price=4_000_000)

    cheap_first = [p["title"] for p in client.get("/properties?sort=cheap").json()["items"]]
    assert cheap_first == ["UZS arzon", "UZS o'rta", "USD qimmat"]

    # 500 USD ~ 6,000,000 UZS, so a 5M cap must exclude it.
    capped = client.get("/properties?max_price=5000000").json()
    assert {p["title"] for p in capped["items"]} == {"UZS arzon", "UZS o'rta"}


def test_sorting_compares_daily_rates_as_monthly(client, register_user):
    s = register_user()
    _create(client, s["headers"], title="Kunlik 350k", price=350_000, price_unit="Kun")  # ~10.5M/month
    _create(client, s["headers"], title="Oylik 3M", price=3_000_000)
    _create(client, s["headers"], title="Oylik 6M", price=6_000_000)
    order = [p["title"] for p in client.get("/properties?sort=cheap").json()["items"]]
    assert order == ["Oylik 3M", "Oylik 6M", "Kunlik 350k"]


def test_filters_city_owner_metro_area(client, register_user):
    s = register_user()
    _create(client, s["headers"], title="Uy A", city="Toshkent", metro="Novza", area=40)
    _create(client, s["headers"], title="Uy B", city="Samarqand", location="Registon", owner_type="Rieltor", area=90)

    assert [p["title"] for p in client.get("/properties?city=Samarqand").json()["items"]] == ["Uy B"]
    assert [p["title"] for p in client.get("/properties?owner_only=true").json()["items"]] == ["Uy A"]
    assert [p["title"] for p in client.get("/properties?near_metro=true").json()["items"]] == ["Uy A"]
    assert [p["title"] for p in client.get("/properties?min_area=60").json()["items"]] == ["Uy B"]
    assert [p["title"] for p in client.get("/properties?q=novza").json()["items"]] == ["Uy A"]


def test_amenity_filter_paginates_correctly(client, register_user):
    s = register_user()
    for i in range(5):
        _create(client, s["headers"], title=f"Wifi {i}", amenities=["Wi-Fi"])
    for i in range(3):
        _create(client, s["headers"], title=f"Bare {i}", amenities=[])

    page = client.get("/properties?amenities=wi-fi&limit=2&skip=2").json()
    assert page["total"] == 5  # was wrong before: total ignored pagination
    assert len(page["items"]) == 2


def test_unknown_sort_is_rejected(client):
    assert client.get("/properties?sort=banana").status_code == 422


def test_band_listings_hide_from_search_but_stay_in_mine(client, register_user):
    s = register_user()
    p = _create(client, s["headers"], title="Band bo'ladi")
    r = client.put(f"/properties/{p['id']}", json={"status": "band"}, headers=s["headers"])
    assert r.status_code == 200 and r.json()["status"] == "band"

    assert client.get("/properties").json()["total"] == 0
    assert client.get("/properties?include_inactive=true").json()["total"] == 1
    mine = client.get("/properties/mine", headers=s["headers"]).json()
    assert mine["total"] == 1 and mine["items"][0]["status"] == "band"

    assert client.put(f"/properties/{p['id']}", json={"status": "boshqa"}, headers=s["headers"]).status_code == 422


def test_mine_requires_auth(client):
    assert client.get("/properties/mine").status_code == 401


def test_views_count_visitors_not_the_owner(client, register_user):
    owner = register_user(email="o@example.com")
    visitor = register_user(email="v@example.com")
    p = _create(client, owner["headers"])

    client.get(f"/properties/{p['id']}", headers=owner["headers"])
    assert client.get(f"/properties/{p['id']}", headers=owner["headers"]).json()["views"] == 0

    client.get(f"/properties/{p['id']}")  # anonymous
    seen = client.get(f"/properties/{p['id']}", headers=visitor["headers"]).json()
    assert seen["views"] == 2


def test_saves_count(client, register_user):
    owner = register_user(email="o2@example.com")
    fan = register_user(email="f2@example.com")
    p = _create(client, owner["headers"])
    client.post(f"/properties/{p['id']}/save", headers=fan["headers"])
    assert client.get(f"/properties/{p['id']}").json()["saves_count"] == 1


# ---------- price insight ----------

def test_price_insight_needs_enough_data(client, register_user):
    s = register_user()
    p = _create(client, s["headers"])
    assert client.get(f"/properties/{p['id']}").json()["price_insight"] is None


def test_price_insight_district_verdicts(client, register_user):
    s = register_user()
    for price in (3_800_000, 4_000_000, 4_200_000):
        _create(client, s["headers"], price=price)
    cheap = _create(client, s["headers"], price=3_000_000)
    fair = _create(client, s["headers"], price=4_050_000)
    dear = _create(client, s["headers"], price=5_500_000)

    c = client.get(f"/properties/{cheap['id']}").json()["price_insight"]
    assert c["verdict"] == "arzon" and c["scope"] == "tuman" and c["diff_percent"] < 0
    f = client.get(f"/properties/{fair['id']}").json()["price_insight"]
    assert f["verdict"] == "bozor_narxida"
    d = client.get(f"/properties/{dear['id']}").json()["price_insight"]
    assert d["verdict"] == "qimmat" and d["sample_size"] >= 3


def test_price_insight_skips_daily_rentals(client, register_user):
    s = register_user()
    for _ in range(6):
        _create(client, s["headers"], price_unit="Kun", price=300_000)
    p = _create(client, s["headers"], price_unit="Kun", price=300_000)
    assert client.get(f"/properties/{p['id']}").json()["price_insight"] is None


# ---------- viewings ----------

def _setup_viewing(client, register_user):
    owner = register_user(email="owner@example.com", full_name="Egasi")
    renter = register_user(email="renter@example.com", full_name="Ijarachi")
    prop = _create(client, owner["headers"])
    return owner, renter, prop


def test_viewing_happy_path_with_chat_message(client, register_user):
    owner, renter, prop = _setup_viewing(client, register_user)
    r = client.post(
        "/viewings",
        json={"property_id": prop["id"], "scheduled_at": _future(), "note": "Ikki kishi kelamiz"},
        headers=renter["headers"],
    )
    assert r.status_code == 201, r.text
    v = r.json()
    assert v["status"] == "kutilmoqda" and v["role"] == "renter"
    assert v["property"]["title"] == prop["title"]
    assert v["scheduled_at"].endswith("Z")

    chat = client.get(f"/messages/with/{renter['user']['id']}", headers=owner["headers"]).json()
    assert len(chat) == 1 and chat[0]["content"].startswith("Ko'rish so'rovi")
    assert chat[0]["property_id"] == prop["id"]

    # Renter cannot approve their own request…
    forbidden = client.patch(f"/viewings/{v['id']}", json={"status": "tasdiqlandi"}, headers=renter["headers"])
    assert forbidden.status_code == 403
    # …the owner can.
    ok = client.patch(f"/viewings/{v['id']}", json={"status": "tasdiqlandi"}, headers=owner["headers"])
    assert ok.status_code == 200 and ok.json()["status"] == "tasdiqlandi" and ok.json()["role"] == "owner"
    # And it can't be answered twice.
    again = client.patch(f"/viewings/{v['id']}", json={"status": "rad_etildi"}, headers=owner["headers"])
    assert again.status_code == 400

    cancelled = client.patch(f"/viewings/{v['id']}", json={"status": "bekor_qilindi"}, headers=renter["headers"])
    assert cancelled.json()["status"] == "bekor_qilindi"

    assert len(client.get("/viewings/mine?role=renter", headers=renter["headers"]).json()) == 1
    assert len(client.get("/viewings/mine?role=owner", headers=renter["headers"]).json()) == 0
    assert len(client.get("/viewings/mine", headers=owner["headers"]).json()) == 1


def test_viewing_validation(client, register_user):
    owner, renter, prop = _setup_viewing(client, register_user)
    past = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)).isoformat()
    far = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=90)).isoformat()

    def book(when, who=renter, pid=prop["id"]):
        return client.post(
            "/viewings", json={"property_id": pid, "scheduled_at": when}, headers=who["headers"]
        )

    assert book(past).status_code == 400
    assert book(far).status_code == 400
    assert book(_future(), who=owner).status_code == 400  # own listing
    assert book(_future(), pid=9999).status_code == 404
    assert book(_future()).status_code == 201
    assert book(_future(72)).status_code == 400  # one open request per listing

    client.put(f"/properties/{prop['id']}", json={"status": "band"}, headers=owner["headers"])
    other = register_user(email="late@example.com")
    assert book(_future(), who=other).status_code == 400  # already rented out


def test_decline_and_declined_can_be_rebooked(client, register_user):
    owner, renter, prop = _setup_viewing(client, register_user)
    v = client.post(
        "/viewings", json={"property_id": prop["id"], "scheduled_at": _future()}, headers=renter["headers"]
    ).json()
    client.patch(f"/viewings/{v['id']}", json={"status": "rad_etildi"}, headers=owner["headers"])
    again = client.post(
        "/viewings", json={"property_id": prop["id"], "scheduled_at": _future(96)}, headers=renter["headers"]
    )
    assert again.status_code == 201


def test_stranger_cannot_touch_a_viewing(client, register_user):
    owner, renter, prop = _setup_viewing(client, register_user)
    stranger = register_user(email="nosy@example.com")
    v = client.post(
        "/viewings", json={"property_id": prop["id"], "scheduled_at": _future()}, headers=renter["headers"]
    ).json()
    r = client.patch(f"/viewings/{v['id']}", json={"status": "tasdiqlandi"}, headers=stranger["headers"])
    assert r.status_code == 404


# ---------- reports ----------

def test_report_flow(client, register_user, make_admin):
    owner = register_user(email="own@example.com")
    reporter = register_user(email="rep@example.com")
    admin = register_user(email="adm@example.com")
    make_admin("adm@example.com")
    p = _create(client, owner["headers"])

    ok = client.post(f"/properties/{p['id']}/report", json={"reason": "aldamchi", "details": "Rasm boshqa"}, headers=reporter["headers"])
    assert ok.status_code == 201
    assert client.post(f"/properties/{p['id']}/report", json={"reason": "boshqa"}, headers=reporter["headers"]).status_code == 400
    assert client.post(f"/properties/{p['id']}/report", json={"reason": "aldamchi"}, headers=owner["headers"]).status_code == 400
    assert client.post(f"/properties/{p['id']}/report", json={"reason": "yomon"}, headers=reporter["headers"]).status_code == 422

    reports = client.get("/admin/reports", headers=admin["headers"]).json()
    assert len(reports) == 1 and reports[0]["reason"] == "aldamchi"
    assert client.get("/admin/reports", headers=reporter["headers"]).status_code == 403
    assert client.get("/admin/stats", headers=admin["headers"]).json()["total_reports"] == 1


# ---------- meta + migration ----------

def test_meta_endpoint(client):
    body = client.get("/meta").json()
    assert body["usd_to_uzs"] > 0 and body["api_version"]


def test_ensure_columns_upgrades_an_old_database(tmp_path):
    """A database created by OsonIjara 1.0 must keep working after the update."""
    engine = create_engine(f"sqlite:///{tmp_path / 'old.db'}")
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE users (id INTEGER PRIMARY KEY, email VARCHAR(180))"))
        conn.execute(
            text(
                "CREATE TABLE properties (id INTEGER PRIMARY KEY, title VARCHAR(200), price FLOAT, location VARCHAR(150), renovation VARCHAR(40))"
            )
        )
        conn.execute(text("INSERT INTO properties (id, title, price, location, renovation) VALUES (1, 'Eski uy', 100, 'Yunusobod', 'Ideal')"))

    added = ensure_columns(engine)
    assert "properties.city" in added and "users.telegram" in added

    cols = {c["name"] for c in inspect(engine).get_columns("properties")}
    assert {"city", "currency", "deposit", "utilities_included", "owner_type", "metro", "status", "views"} <= cols

    with engine.connect() as conn:
        row = conn.execute(
            text("SELECT city, currency, status, views, owner_type, renovation FROM properties")
        ).one()
    # old rows get sane defaults, and old renovation labels map to the new ones
    assert tuple(row) == ("Toshkent", "UZS", "faol", 0, "Egasi", "Evro ta'mir")

    assert ensure_columns(engine) == []  # idempotent


# ---------- privacy ----------

def test_anonymous_visitors_do_not_get_contact_details(client, register_user):
    owner = register_user(email="priv@example.com", phone="90 123 45 67")
    client.put("/users/me", json={"telegram": "priv_owner"}, headers=owner["headers"])
    p = _create(client, owner["headers"])

    anon = client.get(f"/properties/{p['id']}").json()["owner"]
    assert anon["phone"] is None and anon["telegram"] is None
    assert anon["full_name"]  # name stays visible

    listed = client.get("/properties").json()["items"][0]["owner"]
    assert listed["phone"] is None

    visitor = register_user(email="visitor@example.com")
    seen = client.get(f"/properties/{p['id']}", headers=visitor["headers"]).json()["owner"]
    assert seen["phone"] == "+998901234567" and seen["telegram"] == "priv_owner"


# ---------- demo data ----------

def test_seed_adds_demo_data_once(client, tmp_path, monkeypatch):
    from app import seed
    from app.config import settings
    from app.database import SessionLocal

    monkeypatch.setattr(settings, "upload_dir", str(tmp_path))  # don't write into ./uploads

    with SessionLocal() as db:
        assert "Added" in seed.seed(db)
        assert "Skipped" in seed.seed(db)

    body = client.get("/properties?limit=100").json()
    assert body["total"] == len(seed.LISTINGS)
    # every demo listing comes with a real photo that was saved to disk
    assert all(len(p["images"]) == 1 for p in body["items"])
    stored = sorted(tmp_path.rglob("*.jpg"))
    assert len(stored) == len(seed.LISTINGS) and all(f.stat().st_size > 10_000 for f in stored)
    login = client.post(
        "/auth/login", data={"username": "demo.owner@ijario.uz", "password": seed.PASSWORD}
    )
    assert login.status_code == 200


def test_seed_remove_deletes_only_demo_data(client, register_user, tmp_path, monkeypatch):
    from app import seed
    from app.config import settings
    from app.database import SessionLocal

    monkeypatch.setattr(settings, "upload_dir", str(tmp_path))

    real = register_user(email="real@example.com")
    client.post("/properties", json=_payload(title="Haqiqiy e'lon"), headers=real["headers"])

    with SessionLocal() as db:
        seed.seed(db, force=True)
        assert client.get("/properties?limit=100").json()["total"] == len(seed.LISTINGS) + 1
        assert len(list(tmp_path.rglob("*.jpg"))) == len(seed.LISTINGS)
        assert "Removed" in seed.remove_demo(db)
        assert "Nothing" in seed.remove_demo(db)  # idempotent
        assert list(tmp_path.rglob("*.jpg")) == []  # photo files are deleted too

    left = client.get("/properties?limit=100").json()
    assert [p["title"] for p in left["items"]] == ["Haqiqiy e'lon"]
    demo = client.post("/auth/login", data={"username": "demo.owner@ijario.uz", "password": seed.PASSWORD})
    assert demo.status_code == 401
    ok = client.post("/auth/login", data={"username": "real@example.com", "password": "testpass123"})
    assert ok.status_code == 200
