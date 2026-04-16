"""EDC Ingestion Platform application package."""

from __future__ import annotations

from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("edc-ingestion-platform")
except PackageNotFoundError:  # e.g. running from a bare checkout without install
    __version__ = "0.0.0"

__all__ = ["__version__"]
