"""Ingestion task and source adapters."""

from __future__ import annotations

from .adapters import SFTPIngestor, SVDSApiIngestor
from .main import IngestionTask, run

__all__ = ["IngestionTask", "SFTPIngestor", "SVDSApiIngestor", "run"]
