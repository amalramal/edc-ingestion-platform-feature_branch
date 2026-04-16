#!/usr/bin/env python3
"""End-to-end local check: Compose stack → SFTPGo bootstrap → SFTP_ONLY ingestion → raw-layer S3 object.

Requires Docker, ``docker compose`` v2, and a copy of ``.env.example`` → ``.env`` (or equivalent).
Optional: ``boto3`` on the host to verify the Parquet object via LocalStack (``http://127.0.0.1:4566``).

Usage (repo root):

    python scripts/e2e_sftp_raw_layer.py

Environment:

    E2E_STUDY_ID   default ``B1791094``
    E2E_SKIP_UP     if ``1``, skip ``docker compose up`` (stack already running)
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
COMPOSE = ["docker", "compose", "-f", str(REPO / "docker-compose.yml")]


def _run(cmd: list[str], **kwargs: object) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=str(REPO), check=True, **kwargs)


def _wait_health(url: str, attempts: int = 45, delay_s: float = 2.0) -> None:
    last_err: str | None = None
    for _ in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                if r.status == 200:
                    return
        except OSError as e:
            last_err = str(e)
        time.sleep(delay_s)
    raise RuntimeError(f"Health check failed for {url!r}: {last_err}")


def _verify_s3(bucket: str, key: str) -> None:
    try:
        import boto3  # type: ignore[import-untyped]
    except ImportError:
        print("boto3 not installed; skip S3 head_object verify. Install boto3 or use:", flush=True)
        print(
            f"  aws --endpoint-url=http://127.0.0.1:4566 s3api head-object "
            f"--bucket {bucket} --key {key}",
            flush=True,
        )
        return
    client = boto3.client(
        "s3",
        endpoint_url="http://127.0.0.1:4566",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
    )
    client.head_object(Bucket=bucket, Key=key)
    print(f"S3 verify OK: s3://{bucket}/{key}", flush=True)


def main() -> int:
    study = os.environ.get("E2E_STUDY_ID", "B1791094").strip()
    skip_up = os.environ.get("E2E_SKIP_UP", "").strip() in ("1", "true", "yes")

    if not skip_up:
        _run([*COMPOSE, "up", "-d", "--build"])

    _run([*COMPOSE, "--profile", "bootstrap", "run", "--rm", "sftpgo_bootstrap"])

    _wait_health("http://127.0.0.1:8000/health")

    body = json.dumps({"studyId": study}).encode("utf-8")
    req = urllib.request.Request(
        "http://127.0.0.1:8000/tasks/ingestion/run",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            payload = json.load(resp)
    except urllib.error.HTTPError as e:
        print(e.read().decode(), file=sys.stderr)
        raise

    print(json.dumps(payload, indent=2), flush=True)

    if payload.get("ingestionStatus") == "FAILED":
        print("Ingestion reported FAILED", file=sys.stderr)
        return 1

    key = payload.get("rawLayerKey")
    bucket = payload.get("rawLayerBucket")
    if not key or not bucket:
        print("Missing rawLayerKey / rawLayerBucket in response", file=sys.stderr)
        return 1

    if payload.get("rowCount", 0) <= 0:
        print("rowCount is 0; no Parquet was written (expected for empty SFTP folder)", file=sys.stderr)
        return 1

    _verify_s3(str(bucket), str(key))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
