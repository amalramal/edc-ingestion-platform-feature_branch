"""Study-level raw ingest: SFTP and/or SVDS API → normalized Parquet in the raw bucket."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from typing import Any
from uuid import UUID, uuid4

import modin.pandas as mpd
from sqlmodel import Session, select
from sqlmodel import col as sql_col

from edc_ingestion.column_mapping import (
    normalize_api_subject_visit_dataframe,
    normalize_ingest_dataframe,
    restrict_to_normalized_target_schema,
)
from edc_ingestion.config import settings
from edc_ingestion.logging_config import configure_logging, get_logger
from edc_ingestion.models import (
    DataSource,
    FileIngestionLog,
    IngestionStatus,
    MappingCategory,
    SftpFileReadLog,
    SponsorIntegrationConfig,
    StudyConfig,
    SubjectVisitSourceMode,
)
from edc_ingestion.tasks.common.base import BaseTask
from edc_ingestion.tasks.ingestion.adapters import SftpFilePullRecord, SFTPIngestor, SVDSApiIngestor
from edc_ingestion.tasks.ingestion.raw_layer_storage import (
    allocate_unique_parquet_stem,
    upload_normalized_parquet_to_raw,
)

logger = get_logger(__name__)

_API_RAW_LABEL = "subject_visits.csv"


@dataclass
class IngestRawChunk:
    source_label: str
    df: mpd.DataFrame
    data_source: DataSource
    sftp: SftpFilePullRecord | None = None


def _mapping_category_from_source_label(source_label: str) -> MappingCategory:
    compact = source_label.lower().replace("_", "").replace("-", "")
    if "subjectgrp" in compact:
        return MappingCategory.SUBJECT_GROUP
    if "subjectvisit" in compact:
        return MappingCategory.SUBJECT_VISIT
    return MappingCategory.MISC


def _raw_source_endpoint(data_source: DataSource) -> str | None:
    if data_source == DataSource.SFTP:
        return settings.SFTP_HOST or None
    return settings.EDC_SUBJECT_VISIT_API_BASE_URL or None


def _audit_ingestion_log(
    *,
    run_id: UUID,
    study_id: str,
    sid: str,
    data_source: DataSource,
    staging_key: str | None,
    staging_uri: str | None,
    status: IngestionStatus,
    out_rows: int,
    failure_reason: str | None,
) -> FileIngestionLog:
    return FileIngestionLog(
        run_id=run_id,
        study_id=study_id,
        sponsor_id=sid,
        data_source=data_source,
        staging_s3_key=staging_key,
        s3_raw_bucket=settings.S3_RAW_BUCKET,
        s3_pipeline_staging_prefix=settings.S3_PIPELINE_STAGING_PREFIX,
        staging_s3_uri=staging_uri,
        source_endpoint_url=_raw_source_endpoint(data_source),
        status=status,
        total_rows=out_rows,
        failure_reason=failure_reason,
        created_by="ingestion-task",
    )


def _ingestion_api_payload(
    *,
    study_id: str,
    sponsor_schema: str,
    mode: SubjectVisitSourceMode,
    data_source: DataSource,
    run_id: UUID,
    df_norm: mpd.DataFrame,
    out_rows: int,
    status: IngestionStatus,
    staging_key: str | None,
    staging_uri: str | None,
    staging_keys: list[str],
    staging_uris: list[str],
    failure_reason: str | None = None,
) -> dict[str, Any]:
    out: dict[str, Any] = {
        "studyId": study_id,
        "sponsorSchema": sponsor_schema,
        "subjectVisitSourceMode": mode.name,
        "dataSource": data_source.value,
        "runId": str(run_id),
        "rowCount": out_rows,
        "columnCount": len(df_norm.columns),
        "columns": list(df_norm.columns),
        "ingestionStatus": status.value,
        "rawLayerBucket": settings.S3_RAW_BUCKET,
        "rawLayerKey": staging_key,
        "rawLayerUri": staging_uri,
    }
    if staging_keys:
        out["rawLayerKeys"] = staging_keys
        out["rawLayerUris"] = staging_uris
    if failure_reason:
        out["failureReason"] = failure_reason
    return out


def _coerce_subject_visit_mode(raw: str | None) -> SubjectVisitSourceMode:
    s = (raw or SubjectVisitSourceMode.SFTP_ONLY.name).strip().upper()
    for m in SubjectVisitSourceMode:
        if m.name == s:
            return m
    logger.warning("unknown_subject_visit_source_mode", value=raw, fallback=SubjectVisitSourceMode.SFTP_ONLY.name)
    return SubjectVisitSourceMode.SFTP_ONLY


def _resolve_subject_visit_mode(session: Session) -> SubjectVisitSourceMode:
    stmt = select(SponsorIntegrationConfig).where(sql_col(SponsorIntegrationConfig.is_active).is_(True)).limit(1)
    row = session.exec(stmt).first()
    raw = (row.subject_visit_source_mode if row else None) or settings.EDC_SUBJECT_VISIT_SOURCE_MODE
    return _coerce_subject_visit_mode(raw)


def _uppercase_column_names(df: mpd.DataFrame) -> mpd.DataFrame:
    mapping = {c: str(c).strip().upper() for c in df.columns}
    return df.rename(columns=mapping)


def _fetch_raw_chunks(
    study_id: str,
    mode: SubjectVisitSourceMode,
) -> tuple[list[IngestRawChunk], DataSource]:
    if mode == SubjectVisitSourceMode.SFTP_ONLY:
        recs = SFTPIngestor().fetch_csv_files(study_id)
        return (
            [IngestRawChunk(source_label=r.file_name, df=r.df, data_source=DataSource.SFTP, sftp=r) for r in recs],
            DataSource.SFTP,
        )
    if mode == SubjectVisitSourceMode.API_ONLY:
        df = SVDSApiIngestor().fetch_data(study_id)
        return (
            [IngestRawChunk(source_label=_API_RAW_LABEL, df=df, data_source=DataSource.API, sftp=None)],
            DataSource.API,
        )
    try:
        df = SVDSApiIngestor().fetch_data(study_id)
        chunks: list[IngestRawChunk] = [
            IngestRawChunk(source_label=_API_RAW_LABEL, df=df, data_source=DataSource.API, sftp=None)
        ]
        added = 0
        skipped_visit = 0
        try:
            recs = SFTPIngestor().fetch_csv_files(study_id)
        except Exception as sftp_exc:
            logger.warning(
                "ingestion_api_first_sftp_supplement_failed",
                study_id=study_id,
                error=str(sftp_exc),
            )
            recs = []
        for r in recs:
            if _mapping_category_from_source_label(r.file_name) == MappingCategory.SUBJECT_VISIT:
                skipped_visit += 1
                continue
            chunks.append(
                IngestRawChunk(
                    source_label=r.file_name,
                    df=r.df,
                    data_source=DataSource.SFTP,
                    sftp=r,
                )
            )
            added += 1
        logger.info(
            "ingestion_api_first_sftp_supplement",
            study_id=study_id,
            sftp_files_added=added,
            sftp_subject_visit_files_skipped=skipped_visit,
        )
        return chunks, DataSource.API
    except Exception as exc:
        logger.warning("ingestion_api_first_failed_fallback_sftp", study_id=study_id, error=str(exc))
        recs = SFTPIngestor().fetch_csv_files(study_id)
        return (
            [IngestRawChunk(source_label=r.file_name, df=r.df, data_source=DataSource.SFTP, sftp=r) for r in recs],
            DataSource.SFTP,
        )


def _build_sftp_file_read_logs(
    *,
    run_id: UUID,
    study_id: str,
    sponsor_id: str,
    chunks: list[IngestRawChunk],
) -> list[SftpFileReadLog]:
    rows: list[SftpFileReadLog] = []
    for ch in chunks:
        if ch.sftp is None:
            continue
        sp = ch.sftp
        rows.append(
            SftpFileReadLog(
                run_id=run_id,
                study_id=study_id,
                sponsor_id=sponsor_id,
                remote_path=sp.remote_path,
                file_name=sp.file_name,
                mapping_category=_mapping_category_from_source_label(sp.file_name),
                file_name_hash=hashlib.sha256(sp.file_name.encode("utf-8")).hexdigest(),
                file_content_hash=hashlib.sha256(sp.raw_bytes).hexdigest(),
                source_created_at=sp.source_created_at,
                source_updated_at=sp.source_updated_at,
                source_accessed_at=sp.source_accessed_at,
            )
        )
    return rows


class IngestionTask(BaseTask):
    def __init__(
        self,
        study_id: str,
        sponsor_schema: str | None = None,
        *,
        subject_visit_source_mode: SubjectVisitSourceMode | None = None,
    ) -> None:
        super().__init__(study_id, sponsor_schema=sponsor_schema)
        self._subject_visit_source_mode_override = subject_visit_source_mode

    def run(self) -> dict[str, Any]:
        configure_logging()
        run_id = uuid4()
        logger.info(
            "ingestion_task_start",
            study_id=self.study_id,
            sponsor_schema=self.sponsor_schema,
            run_id=str(run_id),
        )

        with self.db_session() as session:
            sc = session.exec(select(StudyConfig).where(StudyConfig.study_id == self.study_id).limit(1)).first()
            if sc is None:
                logger.warning("study_config_missing", study_id=self.study_id)
            mode = (
                self._subject_visit_source_mode_override
                if self._subject_visit_source_mode_override is not None
                else _resolve_subject_visit_mode(session)
            )
            sid = (
                sc.sponsor_id.strip() if sc and sc.sponsor_id and sc.sponsor_id.strip() else ""
            ) or self.sponsor_schema

        chunks, data_source = _fetch_raw_chunks(self.study_id, mode)
        rows_fetched = sum(len(ch.df) for ch in chunks)
        sftp_audit_rows: list[SftpFileReadLog] = _build_sftp_file_read_logs(
            run_id=run_id,
            study_id=self.study_id,
            sponsor_id=sid,
            chunks=chunks,
        )
        logger.info(
            "ingestion_fetched",
            study_id=self.study_id,
            rows=rows_fetched,
            files=len(chunks),
            data_source=data_source.value,
        )

        staging_keys: list[str] = []
        staging_uris: list[str] = []
        stem_used: set[str] = set()
        df_norm: mpd.DataFrame = mpd.DataFrame()
        out_rows = 0

        for chunk in chunks:
            source_label = chunk.source_label
            df = chunk.df
            if len(df) == 0:
                continue
            map_cat = _mapping_category_from_source_label(source_label)
            if chunk.data_source == DataSource.API and map_cat == MappingCategory.SUBJECT_VISIT:
                part = normalize_api_subject_visit_dataframe(df)
            else:
                df_u = _uppercase_column_names(df)
                part = normalize_ingest_dataframe(
                    df_u,
                    self.sponsor_schema,
                    mapping_category=map_cat,
                )
            part = restrict_to_normalized_target_schema(part)
            if len(part) == 0:
                continue
            out_rows += len(part)
            df_norm = part
            object_stem = allocate_unique_parquet_stem(source_label, stem_used)
            try:
                sk, su = upload_normalized_parquet_to_raw(
                    part,
                    study_id=self.study_id,
                    run_id=run_id,
                    object_stem=object_stem,
                )
                staging_keys.append(sk)
                staging_uris.append(su)
            except Exception as exc:
                logger.exception("ingestion_raw_layer_upload_failed", study_id=self.study_id, run_id=str(run_id))
                fr = str(exc)
                log_row = _audit_ingestion_log(
                    run_id=run_id,
                    study_id=self.study_id,
                    sid=sid,
                    data_source=data_source,
                    staging_key=staging_keys[0] if staging_keys else None,
                    staging_uri=staging_uris[0] if staging_uris else None,
                    status=IngestionStatus.FAILED,
                    out_rows=out_rows,
                    failure_reason=fr,
                )
                with self.db_session() as session:
                    session.add(log_row)
                    for sftp_row in sftp_audit_rows:
                        session.add(sftp_row)
                    session.commit()
                return _ingestion_api_payload(
                    study_id=self.study_id,
                    sponsor_schema=self.sponsor_schema,
                    mode=mode,
                    data_source=data_source,
                    run_id=run_id,
                    df_norm=part,
                    out_rows=out_rows,
                    status=IngestionStatus.FAILED,
                    staging_key=staging_keys[0] if staging_keys else None,
                    staging_uri=staging_uris[0] if staging_uris else None,
                    staging_keys=staging_keys,
                    staging_uris=staging_uris,
                    failure_reason=fr,
                )

        logger.info(
            "ingestion_firewall_applied",
            study_id=self.study_id,
            columns=len(df_norm.columns),
            rows=out_rows,
            parquet_objects=len(staging_keys),
        )

        staging_key: str | None = staging_keys[0] if staging_keys else None
        staging_uri: str | None = staging_uris[0] if staging_uris else None
        status = IngestionStatus.INGESTED if staging_keys else IngestionStatus.COMPLETED

        log_row = _audit_ingestion_log(
            run_id=run_id,
            study_id=self.study_id,
            sid=sid,
            data_source=data_source,
            staging_key=staging_key,
            staging_uri=staging_uri,
            status=status,
            out_rows=out_rows,
            failure_reason=None,
        )
        with self.db_session() as session:
            session.add(log_row)
            for sftp_row in sftp_audit_rows:
                session.add(sftp_row)
            session.commit()

        return _ingestion_api_payload(
            study_id=self.study_id,
            sponsor_schema=self.sponsor_schema,
            mode=mode,
            data_source=data_source,
            run_id=run_id,
            df_norm=df_norm,
            out_rows=out_rows,
            status=status,
            staging_key=staging_key,
            staging_uri=staging_uri,
            staging_keys=staging_keys,
            staging_uris=staging_uris,
        )


def run(
    study_id: str,
    *,
    sponsor_schema: str | None = None,
    subject_visit_source_mode: SubjectVisitSourceMode | None = None,
) -> dict[str, Any]:
    """Single-study ingest (CLI, FastAPI, ECS). Optional ``subject_visit_source_mode`` overrides DB/env."""
    resolved = (sponsor_schema or os.getenv("EDC_SPONSOR_SCHEMA", "") or "").strip()
    if not resolved:
        raise ValueError("sponsor_schema argument or EDC_SPONSOR_SCHEMA environment variable is required.")
    return IngestionTask(
        study_id.strip(),
        sponsor_schema=resolved,
        subject_visit_source_mode=subject_visit_source_mode,
    ).run()
