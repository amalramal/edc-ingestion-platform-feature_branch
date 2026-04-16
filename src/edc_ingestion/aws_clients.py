"""Shared boto3 clients; ``AWS_ENDPOINT_URL`` selects LocalStack when set."""

from __future__ import annotations

from typing import Any

import boto3

from edc_ingestion.config import settings


def _client_kwargs() -> dict[str, Any]:
    kwargs: dict[str, Any] = {"region_name": settings.AWS_REGION}
    if settings.AWS_ENDPOINT_URL:
        kwargs["endpoint_url"] = settings.AWS_ENDPOINT_URL
    return kwargs


def get_s3_client() -> Any:
    return boto3.client("s3", **_client_kwargs())


def get_sns_client() -> Any:
    return boto3.client("sns", **_client_kwargs())


def get_stepfunctions_client() -> Any:
    return boto3.client("stepfunctions", **_client_kwargs())
