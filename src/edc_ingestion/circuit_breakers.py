"""Process-wide circuit breakers for outbound SVDS HTTP and SFTP sessions."""

from __future__ import annotations

from edc_ingestion.circuit_breaker import CircuitBreaker
from edc_ingestion.config import settings

svds_http_breaker = CircuitBreaker(
    "svds_subject_visit_http",
    failure_threshold=settings.EDC_CIRCUIT_FAILURE_THRESHOLD,
    recovery_timeout_sec=float(settings.EDC_CIRCUIT_RECOVERY_SECONDS),
)

sftp_pull_breaker = CircuitBreaker(
    "sftp_study_pull",
    failure_threshold=settings.EDC_CIRCUIT_FAILURE_THRESHOLD,
    recovery_timeout_sec=float(settings.EDC_CIRCUIT_RECOVERY_SECONDS),
)
