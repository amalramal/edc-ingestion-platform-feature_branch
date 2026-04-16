"""Environment-backed :class:`Settings`.

Variable names match ``.env.example`` only (no alternate env keys in code).
"""

from __future__ import annotations

import os
from urllib.parse import quote_plus

from edc_ingestion.logging_config import get_logger
from edc_ingestion.models import EdcEnvironment, LocalRuntimeMode, PipelineDepth

logger = get_logger(__name__)

# Unset ``EDC_SUBJECT_VISIT_SOURCE_MODE`` → use below. API_ONLY = SVDS (e.g. C4221015); SFTP_ONLY = files e.g. B1791094.
_DEFAULT_SUBJECT_VISIT_SOURCE_MODE = "API_ONLY"


def parse_edc_environment(value: str | None) -> EdcEnvironment:
    """Parse ``EDC_ENVIRONMENT``; must match :class:`EdcEnvironment` ``.value``."""
    if value is None or not str(value).strip():
        return EdcEnvironment.LOCAL_COMPOSE
    raw = str(value).strip().lower().replace("_", "-")
    for m in EdcEnvironment:
        if m.value == raw:
            return m
    logger.warning("invalid_edc_environment", value=value, fallback=EdcEnvironment.LOCAL_COMPOSE.value)
    return EdcEnvironment.LOCAL_COMPOSE


def parse_pipeline_depth(value: str | None) -> PipelineDepth:
    """Parse ``EDC_PIPELINE_DEPTH``; empty → ``PUBLISH``."""
    if value is None or not str(value).strip():
        return PipelineDepth.PUBLISH
    raw = str(value).strip().upper().replace("-", "_")
    for m in PipelineDepth:
        if m.name == raw or m.value == raw:
            return m
    logger.warning("invalid_pipeline_depth", value=value, fallback=PipelineDepth.PUBLISH.value)
    return PipelineDepth.PUBLISH


def normalize_local_runtime_mode(raw: str | None) -> LocalRuntimeMode:
    """Map ``LOCAL_RUNTIME_MODE`` to :class:`LocalRuntimeMode`."""
    v = (raw or "").strip().lower().replace("-", "_")
    if v in ("localstack_full", "full"):
        return LocalRuntimeMode.LOCALSTACK_FULL
    return LocalRuntimeMode.COMPOSE


def resolve_database_url() -> str:
    """Prefer ``DATABASE_URL``; else build from ``POSTGRES_*``."""
    explicit = (os.getenv("DATABASE_URL") or "").strip()
    if explicit:
        return explicit
    user = os.getenv("POSTGRES_USER", "edc_user")
    password = os.getenv("POSTGRES_PASSWORD", "change_me")
    db = os.getenv("POSTGRES_DB", "edc_platform")
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    return f"postgresql://{quote_plus(user)}:{quote_plus(password)}@{host}:{port}/{db}"


class Settings:
    """Attributes mirror keys in ``.env.example`` (single source of truth)."""

    EDC_ENVIRONMENT: str = (os.getenv("EDC_ENVIRONMENT") or EdcEnvironment.LOCAL_COMPOSE.value).strip()

    DATABASE_URL: str = resolve_database_url()
    DB_POOL_SIZE: int = int(os.getenv("DB_POOL_SIZE", "5"))
    DB_MAX_OVERFLOW: int = int(os.getenv("DB_MAX_OVERFLOW", "10"))

    AWS_ENDPOINT_URL: str | None = os.getenv("AWS_ENDPOINT_URL")
    AWS_REGION: str = os.getenv("AWS_DEFAULT_REGION", "us-east-1")

    S3_RAW_BUCKET: str = os.getenv("S3_RAW_BUCKET", "edc-raw-layer")
    S3_DROP_BUCKET: str = os.getenv("S3_DROP_BUCKET", "edc-drop-site")
    S3_SFTP_LANDING_PREFIX: str = os.getenv("S3_SFTP_LANDING_PREFIX", "sftp-landing/")
    SFTPGO_LANDING_PREFIX: str = os.getenv("SFTPGO_LANDING_PREFIX", "input-files/")
    S3_PARTIAL_API_STASH_PREFIX: str = os.getenv(
        "S3_PARTIAL_API_STASH_PREFIX",
        "partial-api-pulls/",
    )
    S3_PIPELINE_STAGING_PREFIX: str = os.getenv(
        "S3_PIPELINE_STAGING_PREFIX",
        "pipeline-staging/",
    )
    S3_PIPELINE_STATE_PREFIX: str = os.getenv(
        "S3_PIPELINE_STATE_PREFIX",
        "pipeline-state/",
    )

    SNS_ALERT_TOPIC_ARN: str = os.getenv(
        "SNS_ALERT_TOPIC_ARN",
        "arn:aws:sns:us-east-1:000000000000:edc-pipeline-alerts",
    )

    EDC_SUBJECT_VISIT_API_BASE_URL: str = os.getenv("EDC_SUBJECT_VISIT_API_BASE_URL") or ""
    EDC_OAUTH2_TOKEN_URL: str = os.getenv("EDC_OAUTH2_TOKEN_URL") or ""
    EDC_OAUTH2_CLIENT_ID: str = os.getenv("EDC_OAUTH2_CLIENT_ID") or ""
    EDC_OAUTH2_CLIENT_SECRET: str = os.getenv("EDC_OAUTH2_CLIENT_SECRET") or ""
    EDC_SUBJECT_VISIT_PAGE_SIZE: int = int(os.getenv("EDC_SUBJECT_VISIT_PAGE_SIZE", "500"))
    EDC_API_TIMEOUT_SECONDS: int = int(os.getenv("EDC_API_TIMEOUT_SECONDS", "300"))
    EDC_OAUTH2_TIMEOUT_SECONDS: int = int(os.getenv("EDC_OAUTH2_TIMEOUT_SECONDS", "120"))
    EDC_CIRCUIT_FAILURE_THRESHOLD: int = int(os.getenv("EDC_CIRCUIT_FAILURE_THRESHOLD", "5"))
    EDC_CIRCUIT_RECOVERY_SECONDS: int = int(os.getenv("EDC_CIRCUIT_RECOVERY_SECONDS", "60"))
    EDC_SUBJECT_VISIT_SOURCE_MODE: str = (
        os.getenv("EDC_SUBJECT_VISIT_SOURCE_MODE") or ""
    ).strip() or _DEFAULT_SUBJECT_VISIT_SOURCE_MODE

    EDC_PIPELINE_DEPTH: str = (os.getenv("EDC_PIPELINE_DEPTH") or PipelineDepth.PUBLISH.value).strip()

    LOCAL_RUNTIME_MODE: str = (os.getenv("LOCAL_RUNTIME_MODE") or LocalRuntimeMode.COMPOSE.value).strip()

    SFTP_HOST: str = (os.getenv("SFTP_HOST") or "").strip()
    SFTP_PORT: int = int(os.getenv("SFTP_PORT") or "22")
    SFTP_USER: str = (os.getenv("SFTP_USER") or "").strip()
    SFTP_PASSWORD: str = os.getenv("SFTP_PASSWORD") or ""
    SFTP_PRIVATE_KEY_PATH: str = (os.getenv("SFTP_PRIVATE_KEY_PATH") or "").strip()
    SFTP_PRIVATE_KEY_PASSPHRASE: str = os.getenv("SFTP_PRIVATE_KEY_PASSPHRASE") or ""


settings = Settings()


def get_edc_environment() -> EdcEnvironment:
    return parse_edc_environment(settings.EDC_ENVIRONMENT)


def get_local_runtime_mode() -> LocalRuntimeMode:
    return normalize_local_runtime_mode(settings.LOCAL_RUNTIME_MODE)


def get_pipeline_depth() -> PipelineDepth:
    return parse_pipeline_depth(settings.EDC_PIPELINE_DEPTH)
