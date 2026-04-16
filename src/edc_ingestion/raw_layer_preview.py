"""Read sample rows from normalized ingest Parquet objects under a run prefix in the raw bucket."""

from __future__ import annotations

import io
import json
from typing import Any
from uuid import UUID

import pandas as pd

from edc_ingestion.aws_clients import get_s3_client
from edc_ingestion.config import settings


def _landing_normalized_run_prefix(study_id: str, run_id: UUID) -> str:
    pfx = settings.S3_SFTP_LANDING_PREFIX.strip().strip("/")
    mid = f"{study_id.strip()}/normalized/{run_id}/"
    return f"{pfx}/{mid}" if pfx else mid


def _safe_study_id(study_id: str) -> str:
    s = study_id.strip()
    if not s or "/" in s or "\\" in s or ".." in s:
        raise ValueError("Invalid studyId.")
    return s


def list_parquet_keys_for_run(study_id: str, run_id: UUID) -> tuple[str, list[str]]:
    """Return ``(s3_prefix, keys)`` for all ``.parquet`` objects under the run folder."""
    prefix = _landing_normalized_run_prefix(study_id, run_id)
    client = get_s3_client()
    bucket = settings.S3_RAW_BUCKET
    keys: list[str] = []
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents") or []:
            k = obj.get("Key") or ""
            if k.lower().endswith(".parquet"):
                keys.append(k)
    keys.sort()
    return prefix, keys


def preview_normalized_run_parquets(study_id: str, run_id_str: str, *, limit: int = 10) -> dict[str, Any]:
    """
    Download each Parquet under ``{landing}/{study}/normalized/{runId}/`` and return the first ``limit`` rows.

    Row values are JSON-friendly (ISO dates, no numpy scalars).
    """
    study = _safe_study_id(study_id)
    try:
        rid = UUID(run_id_str.strip())
    except ValueError as exc:
        raise ValueError("runId must be a UUID.") from exc

    if limit < 1 or limit > 100:
        raise ValueError("limit must be between 1 and 100.")

    prefix, keys = list_parquet_keys_for_run(study, rid)
    bucket = settings.S3_RAW_BUCKET
    client = get_s3_client()

    objects_out: list[dict[str, Any]] = []
    for key in keys:
        body = client.get_object(Bucket=bucket, Key=key)["Body"].read()
        df = pd.read_parquet(io.BytesIO(body))
        head = df.head(limit)
        rows_raw = head.to_json(orient="records", date_format="iso")
        rows: list[dict[str, Any]] = json.loads(rows_raw)
        name = key.rsplit("/", maxsplit=1)[-1]
        objects_out.append(
            {
                "key": key,
                "filename": name,
                "totalRowsInFile": len(df),
                "columns": list(df.columns),
                "previewRowCount": len(rows),
                "rows": rows,
            }
        )

    return {
        "studyId": study,
        "runId": str(rid),
        "bucket": bucket,
        "prefix": prefix,
        "parquetCount": len(objects_out),
        "objects": objects_out,
    }
