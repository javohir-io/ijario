"""Tiny, idempotent schema upgrader.

The project creates tables with ``Base.metadata.create_all`` which never
alters a table that already exists. Ijario adds columns to tables that a
deployed database (e.g. on Neon) already has, so on startup we look for the
missing ones and add them with a plain ``ALTER TABLE ... ADD COLUMN``.

It only ever *adds* nullable-or-defaulted columns, so it is safe to run on
every start. When the schema starts changing in more complex ways, move to
Alembic.
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

# table -> [(column, SQL type, DEFAULT clause or None)]
_NEW_COLUMNS: dict[str, list[tuple[str, str, str | None]]] = {
    "users": [
        ("telegram", "VARCHAR(60)", None),
    ],
    "properties": [
        ("city", "VARCHAR(60)", "'Toshkent'"),
        ("currency", "VARCHAR(3)", "'UZS'"),
        ("deposit", "FLOAT", "0"),
        ("utilities_included", "BOOLEAN", "FALSE"),
        ("owner_type", "VARCHAR(10)", "'Egasi'"),
        ("metro", "VARCHAR(80)", None),
        ("status", "VARCHAR(10)", "'faol'"),
        ("views", "INTEGER", "0"),
    ],
}


# Old renovation labels -> the labels the app offers now.
_RENOVATION_RENAMES = {"Ideal": "Evro ta'mir", "Yomon": "Ta'mir talab"}


def ensure_columns(engine: Engine) -> list[str]:
    """Adds any missing columns. Returns the list of ``table.column`` added."""
    added: list[str] = []
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    with engine.begin() as conn:
        for table, columns in _NEW_COLUMNS.items():
            if table not in existing_tables:
                continue  # create_all will build it with every column
            present = {c["name"] for c in inspector.get_columns(table)}
            for name, sql_type, default in columns:
                if name in present:
                    continue
                clause = f" DEFAULT {default}" if default is not None else ""
                conn.execute(text(f'ALTER TABLE {table} ADD COLUMN {name} {sql_type}{clause}'))
                added.append(f"{table}.{name}")

        # Data tidy-up (idempotent): keep old listings filterable.
        if "properties" in existing_tables:
            for old, new in _RENOVATION_RENAMES.items():
                conn.execute(
                    text("UPDATE properties SET renovation = :new WHERE renovation = :old"),
                    {"new": new, "old": old},
                )
    return added
