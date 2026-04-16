"""Normalize ingest frames: SFTP (UPPER + DB rules + standard map); API subject visits (targets already camelCase)."""

from __future__ import annotations

import modin.pandas as mpd
from sqlmodel import Session, select
from sqlmodel import col as sql_col

from edc_ingestion.database import get_session
from edc_ingestion.logging_config import get_logger
from edc_ingestion.models import (
    NORMALIZED_TARGET_COLUMNS,
    UPPER_TO_NORMALIZED_TARGET,
    DataColumnMapping,
    MappingCategory,
)

logger = get_logger(__name__)

_SUBJECT_GROUP_BUILTIN_UPPER: dict[str, str] = {
    "STUDY_SITE_NUMBER": "studySiteNumber",
    "SBJ_STR_STRATA_NUM": "strata",
    "SBJ_COH_COHORT_NUM": "cohort",
    "CREATION_TS": "dateEntryDate",
}


def load_column_mappings(session: Session, category: MappingCategory) -> dict[str, str]:
    stmt = select(DataColumnMapping).where(
        DataColumnMapping.mapping_type == category,
        sql_col(DataColumnMapping.is_active).is_(True),
    )
    rows = list(session.exec(stmt).all())
    out: dict[str, str] = {}
    for r in rows:
        src = (r.source_column or "").strip().upper()
        tgt = (r.target_column or "").strip()
        if src and tgt:
            out[src] = tgt
    logger.info("column_mappings_loaded", category=category.value, count=len(out))
    return out


def apply_db_column_rules(df: mpd.DataFrame, rules: dict[str, str]) -> mpd.DataFrame:
    if not rules:
        return df
    m: dict[str, str] = {}
    for c in list(df.columns):
        u = str(c).strip().upper()
        if u in rules:
            tgt = rules[u]
            if str(c) != tgt:
                m[str(c)] = tgt
    if not m:
        return df
    return df.rename(columns=m)


def _apply_subject_group_builtin_aliases(df: mpd.DataFrame) -> mpd.DataFrame:
    m: dict[str, str] = {}
    for c in list(df.columns):
        u = str(c).strip().upper()
        if u in _SUBJECT_GROUP_BUILTIN_UPPER:
            m[str(c)] = _SUBJECT_GROUP_BUILTIN_UPPER[u]
    return df.rename(columns=m) if m else df


def apply_direct_upper_to_normalized_target(df: mpd.DataFrame) -> mpd.DataFrame:
    m = {c: UPPER_TO_NORMALIZED_TARGET[c] for c in df.columns if c in UPPER_TO_NORMALIZED_TARGET}
    if not m:
        return df
    return df.rename(columns=m)


def ensure_normalized_columns(df: mpd.DataFrame) -> mpd.DataFrame:
    for col in NORMALIZED_TARGET_COLUMNS:
        if col not in df.columns:
            df[col] = ""
    return df


def normalize_api_subject_visit_dataframe(df: mpd.DataFrame) -> mpd.DataFrame:
    """SVDS JSON already uses ``NORMALIZED_TARGET_COLUMNS`` names."""
    return ensure_normalized_columns(df)


def normalize_ingest_dataframe(
    df: mpd.DataFrame,
    schema: str | None,
    *,
    mapping_category: MappingCategory = MappingCategory.SUBJECT_VISIT,
) -> mpd.DataFrame:
    if schema is not None:
        with get_session(schema) as session:
            rules = load_column_mappings(session, mapping_category)
        df = apply_db_column_rules(df, rules)
    if mapping_category == MappingCategory.SUBJECT_GROUP:
        df = _apply_subject_group_builtin_aliases(df)
    df = apply_direct_upper_to_normalized_target(df)
    return ensure_normalized_columns(df)


def restrict_to_normalized_target_schema(df: mpd.DataFrame) -> mpd.DataFrame:
    df = ensure_normalized_columns(df)
    return df[NORMALIZED_TARGET_COLUMNS]
