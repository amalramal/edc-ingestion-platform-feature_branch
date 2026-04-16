"""Reusable database session helpers for ECS task workers."""

from __future__ import annotations

from collections.abc import Generator
from contextlib import contextmanager

from sqlmodel import Session

from edc_ingestion.database import get_session as _tenant_session


@contextmanager
def tenant_session(schema: str) -> Generator[Session, None, None]:
    """Yield a SQLModel session with ``search_path`` set to the sponsor schema."""
    with _tenant_session(schema) as session:
        yield session
