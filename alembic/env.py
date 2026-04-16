"""
Alembic Environment Configuration — Schema-per-Sponsor Multi-Tenancy.

Supports dynamic schema targeting via ``alembic -x schema=<name> upgrade head``.
DSN comes from ``DATABASE_URL`` when set (e.g. Compose), else from ``POSTGRES_*`` via
``edc_ingestion.config.resolve_database_url``.
"""

from __future__ import annotations

import os
import re
from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool, text
from sqlmodel import SQLModel

# Import all models so SQLModel.metadata is fully populated.
from edc_ingestion.config import resolve_database_url
from edc_ingestion.models import (  # noqa: F401
    DataColumnMapping,
    EligibilityRule,
    FileIngestionLog,
    SftpFileReadLog,
    SponsorIntegrationConfig,
    StudyConfig,
    SubjectRegistry,
    VisitScheduleCache,
)

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = SQLModel.metadata

_DATABASE_URL: str = resolve_database_url() or (config.get_main_option("sqlalchemy.url", "") or "")

_SAFE_SCHEMA_RE = re.compile(r"^[a-z][a-z0-9_]{0,62}$")

# Must match the default in each revision's ``_target_schema()`` (e.g. 0001).
_DEFAULT_TENANT_SCHEMA = "sponsor_demo"


def _get_target_schema() -> str:
    """
    Tenant schema for this migration run.

    Pass explicitly: ``alembic -x schema=sponsor_acme upgrade head``

    If omitted, defaults to ``sponsor_demo`` (same as revision scripts).  Running
    bare ``alembic upgrade head`` therefore still creates the demo tenant schema —
    not only ``public``.
    """
    raw: str | None = context.get_x_argument(as_dictionary=True).get("schema")
    if raw is None:
        return os.getenv("ALEMBIC_SCHEMA", _DEFAULT_TENANT_SCHEMA)
    if not _SAFE_SCHEMA_RE.match(raw):
        raise ValueError(f"Invalid schema name '{raw}'.")
    return raw


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode — emit SQL without a live DB."""
    schema = _get_target_schema()
    context.configure(
        url=_DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        version_table_schema=schema,
    )
    with context.begin_transaction():
        context.execute(f"SET search_path TO {schema}, public")
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations against a live Postgres instance."""
    connectable = create_engine(_DATABASE_URL, poolclass=pool.NullPool)
    schema = _get_target_schema()

    with connectable.connect() as connection:
        connection.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema}"))
        connection.commit()
        connection.execute(text(f"SET search_path TO {schema}, public"))
        connection.execute(text("COMMIT"))

        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            version_table_schema=schema,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
