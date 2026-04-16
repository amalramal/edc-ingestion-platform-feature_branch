"""ECS-style logging helpers (JSON on Fargate when appropriate)."""

from __future__ import annotations

import os

import structlog

from edc_ingestion.logging_config import configure_logging, get_logger


def configure_task_logging(*, force_json: bool = False) -> None:
    env_console = os.getenv("LOG_FORMAT", "").lower() == "console"
    on_ecs = bool(os.getenv("ECS_CONTAINER_METADATA_URI", "").strip())
    use_json = force_json or (on_ecs and not env_console)
    configure_logging(force_json=use_json)


def get_task_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    configure_task_logging()
    return get_logger(name)


def bind_run_context(*, run_id: str | None = None, study_id: str | None = None, task: str | None = None) -> None:
    kwargs: dict[str, str] = {}
    if run_id:
        kwargs["run_id"] = run_id
    if study_id:
        kwargs["study_id"] = study_id
    if task:
        kwargs["task"] = task
    if kwargs:
        structlog.contextvars.bind_contextvars(**kwargs)
