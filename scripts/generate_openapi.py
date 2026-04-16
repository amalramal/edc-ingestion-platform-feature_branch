"""Emit OpenAPI 3 schema from the FastAPI app (writes openapi_spec.json at repo root).

Run from repository root::

    poetry run python scripts/generate_openapi.py

Or::

    PYTHONPATH=src python scripts/generate_openapi.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    src = ROOT / "src"
    if src.is_dir() and str(src) not in sys.path:
        sys.path.insert(0, str(src))

    from edc_ingestion.app import app  # noqa: PLC0415 — after sys.path

    out = ROOT / "openapi_spec.json"
    spec = app.openapi()
    out.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
