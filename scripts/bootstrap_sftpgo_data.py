#!/usr/bin/env python3
"""Copy study CSV trees from the repo into the SFTPGo data volume (compose service ``sftpgo``).

Expects ``docker compose`` (v2) on PATH and a running or previously started ``sftpgo`` stack so the
named volume ``sftpgo_srv`` exists. Run:

    docker compose --profile bootstrap run --rm sftpgo_bootstrap

Or from repo root after ``docker compose up -d sftpgo``:

    python scripts/bootstrap_sftpgo_data.py

Remote layout matches :func:`edc_ingestion.tasks.ingestion.adapters.sftp._remote_study_dir`:
``{SFTPGO_LANDING_PREFIX}/{studyId}/*.csv`` under the SFTP user's home (compose sets ``LANDING_PREFIX``
from env ``SFTPGO_LANDING_PREFIX``). S3 output uses ``S3_SFTP_LANDING_PREFIX``, not this path.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def main() -> int:
    root = _repo_root()
    src = Path(os.environ.get("EDC_SFTPGO_BOOTSTRAP_SRC", str(root / "input_files" / "by_study")))
    if not src.is_dir():
        print(f"bootstrap_sftpgo_data: skip — source directory missing: {src}", file=sys.stderr)
        return 0

    studies = [p for p in src.iterdir() if p.is_dir()]
    if not studies:
        print(f"bootstrap_sftpgo_data: no study subdirectories under {src}", file=sys.stderr)
        return 0

    compose_file = root / "docker-compose.yml"
    if not compose_file.is_file():
        print(f"bootstrap_sftpgo_data: {compose_file} not found", file=sys.stderr)
        return 1

    cmd = [
        "docker",
        "compose",
        "-f",
        str(compose_file),
        "--profile",
        "bootstrap",
        "run",
        "--rm",
        "sftpgo_bootstrap",
    ]
    print("Running:", " ".join(cmd))
    return subprocess.call(cmd, cwd=str(root))


if __name__ == "__main__":
    raise SystemExit(main())
