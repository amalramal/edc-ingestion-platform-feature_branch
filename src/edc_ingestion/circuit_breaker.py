"""Thread-safe circuit breaker for fragile outbound calls (HTTP, SFTP, …)."""

from __future__ import annotations

import threading
import time
from collections.abc import Callable
from typing import TypeVar

from edc_ingestion.logging_config import get_logger

logger = get_logger(__name__)
T = TypeVar("T")


class CircuitBreakerOpenError(RuntimeError):
    """Raised when the breaker is open and recovery time has not elapsed."""

    def __init__(self, name: str) -> None:
        super().__init__(f"Circuit breaker '{name}' is open")
        self.name = name


class CircuitBreaker:
    """Opens after ``failure_threshold`` failures; half-open probe after ``recovery_timeout_sec``."""

    def __init__(
        self,
        name: str,
        *,
        failure_threshold: int = 5,
        recovery_timeout_sec: float = 60.0,
    ) -> None:
        self._name = name
        self._failure_threshold = max(1, failure_threshold)
        self._recovery_timeout_sec = recovery_timeout_sec
        self._lock = threading.Lock()
        self._failures = 0
        self._state: str = "closed"  # closed | open | half_open
        self._opened_at: float = 0.0

    def call(self, fn: Callable[[], T]) -> T:
        with self._lock:
            now = time.monotonic()
            if self._state == "open":
                if now - self._opened_at < self._recovery_timeout_sec:
                    raise CircuitBreakerOpenError(self._name)
                self._state = "half_open"

        try:
            result = fn()
        except Exception:
            with self._lock:
                if self._state == "half_open":
                    self._state = "open"
                    self._opened_at = time.monotonic()
                    logger.warning("circuit_breaker_opened", name=self._name, reason="half_open_failure")
                else:
                    self._failures += 1
                    if self._failures >= self._failure_threshold:
                        self._state = "open"
                        self._opened_at = time.monotonic()
                        logger.warning(
                            "circuit_breaker_opened",
                            name=self._name,
                            failures=self._failures,
                        )
            raise

        with self._lock:
            self._failures = 0
            self._state = "closed"
        return result
