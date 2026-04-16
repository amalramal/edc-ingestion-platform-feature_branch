"""Structlog setup: JSON in non-TTY / ``LOG_FORMAT=json``, console otherwise."""

from __future__ import annotations

import logging
import os
import sys
import warnings
from typing import cast

import structlog

warnings.filterwarnings(
    "ignore",
    message=".*defaulting to pandas implementation.*",
    category=UserWarning,
)


def configure_logging(*, force_json: bool = False) -> None:
    """Configure structlog and stdlib logging (idempotent unless ``force_json`` upgrades output)."""
    done = getattr(configure_logging, "_done", False)
    if done and not force_json:
        return
    configure_logging._done = True  # type: ignore[attr-defined]

    log_level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    log_level = getattr(logging, log_level_name, logging.INFO)

    log_format = os.getenv("LOG_FORMAT", "").lower()
    # Fargate / ECS tasks expose this URI; prefer JSON logs for CloudWatch.
    on_ecs = bool(os.getenv("ECS_CONTAINER_METADATA_URI", "").strip())
    use_json = force_json or on_ecs or log_format == "json" or (log_format != "console" and not sys.stderr.isatty())

    shared_processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.UnicodeDecoder(),
    ]

    if use_json:
        renderer: structlog.types.Processor = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer(colors=True)

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.processors.format_exc_info,
            renderer,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    logging.basicConfig(
        format="%(message)s",
        level=log_level,
        stream=sys.stderr,
        force=True,
    )
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error", "sqlalchemy", "boto3", "botocore"):
        logging.getLogger(name).setLevel(max(log_level, logging.WARNING))

    for name in ("dask", "distributed", "distributed.nanny", "distributed.scheduler", "distributed.worker"):
        logging.getLogger(name).setLevel(logging.WARNING)


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Bound structlog logger (configures logging on first use)."""
    configure_logging()
    return cast(structlog.stdlib.BoundLogger, structlog.get_logger(name))
