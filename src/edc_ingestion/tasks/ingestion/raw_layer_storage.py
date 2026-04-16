"""Write normalized ingest frames to the raw S3 bucket as Parquet."""

from __future__ import annotations

import io
import re
from pathlib import PurePosixPath
from uuid import UUID

import modin.pandas as mpd
import pandas as pd

from edc_ingestion.aws_clients import get_s3_client
from edc_ingestion.config import settings
from edc_ingestion.logging_config import get_logger

logger = get_logger(__name__)

_SAFE_STEM = re.compile(r"[^A-Za-z0-9._-]+")


def normalized_ingest_s3_key(study_id: str, run_id: UUID, object_stem: str) -> str:
    """S3 key: ``…/{study}/normalized/{run_id}/{object_stem}.parquet`` under landing prefix."""
    stem = sanitize_parquet_object_stem(object_stem)
    pfx = settings.S3_SFTP_LANDING_PREFIX.strip().strip("/")
    mid = f"{study_id}/normalized/{run_id}/{stem}.parquet"
    if pfx:
        return f"{pfx}/{mid}"
    return mid


def sanitize_parquet_object_stem(source_label: str) -> str:
    """Derive a single path segment (no slashes) for the Parquet object name."""
    base = PurePosixPath(source_label.strip()).name
    stem = PurePosixPath(base).stem if base else ""
    stem = _SAFE_STEM.sub("_", stem).strip("._-") or "part"
    return stem[:200]


def allocate_unique_parquet_stem(source_label: str, used: set[str]) -> str:
    """Return a stem unique within ``used`` (mutates ``used``), for duplicate source basenames."""
    base = sanitize_parquet_object_stem(source_label)
    n = 0
    candidate = base
    while candidate in used:
        n += 1
        suffix = f"_{n}"
        candidate = f"{base[: max(1, 200 - len(suffix))]}{suffix}"
    used.add(candidate)
    return candidate


def parquet_bytes_from_modin(df: mpd.DataFrame | pd.DataFrame) -> bytes:
    """In-memory Parquet bytes (avoids Modin ``to_parquet`` path / EEXIST issues with Dask)."""
    buf = io.BytesIO()
    pdf = df.to_pandas() if hasattr(df, "to_pandas") else df
    pdf.to_parquet(buf, index=False, engine="pyarrow")
    return buf.getvalue()


def upload_normalized_parquet_to_raw(
    df: mpd.DataFrame,
    *,
    study_id: str,
    run_id: UUID,
    object_stem: str,
) -> tuple[str, str]:
    """Upload ``df`` as Parquet to ``S3_RAW_BUCKET``; return ``(key, s3_uri)``."""
    key = normalized_ingest_s3_key(study_id, run_id, object_stem)
    body = parquet_bytes_from_modin(df)
    bucket = settings.S3_RAW_BUCKET
    client = get_s3_client()
    client.put_object(Bucket=bucket, Key=key, Body=body, ContentType="application/vnd.apache.parquet")
    uri = f"s3://{bucket}/{key}"
    logger.info(
        "ingestion_raw_layer_uploaded",
        bucket=bucket,
        key=key,
        bytes=len(body),
        study_id=study_id,
        run_id=str(run_id),
    )
    return key, uri
