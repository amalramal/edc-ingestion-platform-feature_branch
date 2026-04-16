"""FastAPI entrypoint: local health and task triggers (same modules as ECS)."""

from __future__ import annotations

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

from edc_ingestion import __version__
from edc_ingestion.models import SubjectVisitSourceMode

app = FastAPI(
    title="EDC Ingestion Platform",
    description="Local HTTP triggers use the same task entrypoints as ECS.",
    version=__version__,
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


class IngestionRunRequest(BaseModel):
    study_id: str = Field(alias="studyId", description="Step Functions input uses camelCase studyId.")
    subject_visit_source_mode: SubjectVisitSourceMode | None = Field(
        default=None,
        alias="subjectVisitSourceMode",
        description=(
            "Optional override: API_FIRST (API visits + SFTP subject_group/misc; full SFTP if API fails), "
            "SFTP_ONLY, API_ONLY. If omitted, uses tenant DB config then EDC_SUBJECT_VISIT_SOURCE_MODE."
        ),
    )

    model_config = {"populate_by_name": True}


@app.post("/tasks/ingestion/run")
def run_ingestion_local(req: IngestionRunRequest) -> dict[str, object]:
    """Trigger ingestion; response ``runId`` is used with GET ``/tasks/ingestion/raw-preview``."""
    from edc_ingestion.tasks.ingestion.main import run as run_ingestion

    return run_ingestion(
        req.study_id,
        subject_visit_source_mode=req.subject_visit_source_mode,
    )


@app.get("/tasks/ingestion/raw-preview")
def raw_layer_preview(
    study_id: str = Query(..., alias="studyId", description="Study id (same as ingest input)."),
    run_id: str = Query(..., alias="runId", description="Ingestion run UUID from the run response."),
    limit: int = Query(10, ge=1, le=100, description="Max rows to return per Parquet object."),
) -> dict[str, object]:
    """After POST ``/tasks/ingestion/run`` completes, read normalized Parquet previews from the raw bucket.

    Use the same ``studyId`` and the ``runId`` UUID returned by the run endpoint.
    """
    from edc_ingestion.raw_layer_preview import preview_normalized_run_parquets

    try:
        out = preview_normalized_run_parquets(study_id, run_id, limit=limit)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"S3 or Parquet read failed: {exc}") from exc

    if out["parquetCount"] == 0:
        raise HTTPException(
            status_code=404,
            detail=f"No Parquet objects under prefix s3://{out['bucket']}/{out['prefix']}",
        )
    return out
