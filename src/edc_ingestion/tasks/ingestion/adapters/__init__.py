"""SFTP and SVDS HTTP ingest adapters."""

from __future__ import annotations

from .sftp import SftpFilePullRecord, SFTPIngestor
from .svds_api import SVDSApiIngestor

__all__ = ["SFTPIngestor", "SVDSApiIngestor", "SftpFilePullRecord"]
