"""Abstract base classes for Step Functions-driven ECS tasks and data ingestors."""

from __future__ import annotations

import os
from abc import ABC, abstractmethod
from collections.abc import Generator
from contextlib import contextmanager
from typing import Any

import modin.pandas as mpd
from sqlmodel import Session

from edc_ingestion.tasks.common.session import tenant_session


class BaseIngestor(ABC):
    """Strategy interface: pull raw subject-visit shaped rows into a Modin DataFrame."""

    @abstractmethod
    def fetch_data(self, study_id: str) -> mpd.DataFrame:
        """Return a dataframe of raw extract rows (columns as returned by the source)."""


class BaseTask(ABC):
    """Shared context: study id, tenant schema, and transactional DB access."""

    def __init__(self, study_id: str, sponsor_schema: str | None = None) -> None:
        self.study_id = study_id.strip()
        if not self.study_id:
            raise ValueError("study_id must be non-empty")
        self.sponsor_schema = (sponsor_schema or os.getenv("EDC_SPONSOR_SCHEMA", "") or "").strip()
        if not self.sponsor_schema:
            raise ValueError(
                "sponsor_schema is required (constructor argument or EDC_SPONSOR_SCHEMA environment variable).",
            )

    @contextmanager
    def db_session(self) -> Generator[Session, None, None]:
        """Yield a session scoped to :attr:`sponsor_schema`."""
        with tenant_session(self.sponsor_schema) as session:
            yield session

    @abstractmethod
    def run(self) -> dict[str, Any]:
        """Execute the unit of work; return a JSON-serializable dict for orchestration."""
