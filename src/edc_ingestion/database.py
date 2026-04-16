"""SQLAlchemy engine and session factory from ``settings``."""

from __future__ import annotations

import re
from collections.abc import Generator
from contextlib import contextmanager

from sqlalchemy import text
from sqlmodel import Session, create_engine

from edc_ingestion.config import settings
from edc_ingestion.logging_config import get_logger

logger = get_logger(__name__)

engine = create_engine(
    settings.DATABASE_URL,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    pool_pre_ping=True,
    echo=False,
)

# Strict allow-list: only lowercase alphanumeric plus underscores.
_SAFE_SCHEMA_RE = re.compile(r"^[a-z][a-z0-9_]{0,62}$")


def _validate_schema_name(schema: str) -> str:
    """Reject schema names outside ``^[a-z][a-z0-9_]{0,62}$`` (SQL identifier safety)."""
    if not _SAFE_SCHEMA_RE.match(schema):
        raise ValueError(
            f"Invalid schema name '{schema}'. "
            "Must be lowercase alphanumeric + underscores, starting with a letter, max 63 chars."
        )
    return schema


@contextmanager
def get_session(schema: str | None = None) -> Generator[Session, None, None]:
    """Session with optional ``SET search_path`` to a tenant schema; rolls back on exception."""
    with Session(engine) as session:
        if schema is not None:
            safe_schema = _validate_schema_name(schema)
            session.execute(text(f"SET search_path TO {safe_schema}, public"))
            logger.debug("search_path_set", schema=safe_schema)
        try:
            yield session
        except Exception:
            session.rollback()
            logger.debug("session_rolled_back", schema=schema)
            raise
