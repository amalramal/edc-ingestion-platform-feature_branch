"""Seed sponsor-scoped rule/mapping data from YAML.

Usage:
  poetry run python scripts/seed_sponsor.py --sponsor sponsor_demo --file seeds/sponsors/sponsor_demo/mappings.yaml
"""

from __future__ import annotations

import argparse
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml
from dotenv import load_dotenv
from sqlalchemy import text

# Host runs (``make seed-sponsor`` / Poetry) do not load ``.env`` automatically; Compose does.
load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from edc_ingestion.database import get_session  # noqa: E402
from edc_ingestion.models import MappingCategory  # noqa: E402


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed sponsor data from YAML.")
    parser.add_argument("--sponsor", required=True, help="Target sponsor schema (e.g. sponsor_demo).")
    parser.add_argument("--file", required=True, help="Path to YAML seed file.")
    return parser.parse_args()


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"Seed file not found: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Seed YAML root must be a mapping/dictionary.")
    return data


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _seed_eligibility(rows: list[dict[str, Any]], sponsor: str) -> None:
    if not rows:
        return
    now = _utc_now()
    with get_session(schema=sponsor) as session:
        for row in rows:
            params = {
                "ruleId": row["ruleId"],
                "studyId": row.get("studyId"),
                "columnName": row["columnName"],
                "operator": row["operator"],
                "expectedValue": row.get("expectedValue"),
                "rejectionReason": row["rejectionReason"],
                "ruleKind": row.get("ruleKind", "NON_BLOCKING"),
                "isActive": bool(row.get("isActive", True)),
                "createdBy": row.get("createdBy", "seed-sponsor"),
                "updatedBy": row.get("updatedBy"),
                "createdAt": now,
                "updatedAt": now,
            }
            session.execute(
                text(
                    """
                    INSERT INTO eligibility_rule
                    ("ruleId","studyId","columnName","operator","expectedValue","rejectionReason","ruleKind",
                     "isActive","createdBy","updatedBy","createdAt","updatedAt")
                    VALUES
                    (:ruleId,:studyId,:columnName,:operator,:expectedValue,:rejectionReason,:ruleKind,
                     :isActive,:createdBy,:updatedBy,:createdAt,:updatedAt)
                    ON CONFLICT ("ruleId")
                    DO UPDATE SET
                      "studyId" = EXCLUDED."studyId",
                      "columnName" = EXCLUDED."columnName",
                      "operator" = EXCLUDED."operator",
                      "expectedValue" = EXCLUDED."expectedValue",
                      "rejectionReason" = EXCLUDED."rejectionReason",
                      "ruleKind" = EXCLUDED."ruleKind",
                      "isActive" = EXCLUDED."isActive",
                      "updatedBy" = EXCLUDED."updatedBy",
                      "updatedAt" = EXCLUDED."updatedAt"
                    """
                ),
                params,
            )
        session.commit()


def _seed_data_column_mappings(category: MappingCategory, rows: list[dict[str, Any]], sponsor: str) -> None:
    if not rows:
        return
    now = _utc_now()
    mapping_type = category.value
    with get_session(schema=sponsor) as session:
        for row in rows:
            source_column = str(row["sourceColumn"])
            target_column = str(row["targetColumn"])
            description = row.get("description")
            created_by = row.get("createdBy", "seed-sponsor")
            updated_by = row.get("updatedBy")
            is_active = bool(row.get("isActive", True))

            existing = session.execute(
                text(
                    """
                    SELECT id FROM data_column_mapping
                    WHERE "type" = :mappingType AND "targetColumn" = :targetColumn
                    LIMIT 1
                    """
                ),
                {"mappingType": mapping_type, "targetColumn": target_column},
            ).scalar_one_or_none()

            if existing is None:
                session.execute(
                    text(
                        """
                        INSERT INTO data_column_mapping
                        ("type","sourceColumn","targetColumn","description","isActive","createdBy","updatedBy","createdAt","updatedAt")
                        VALUES
                        (:mappingType,:sourceColumn,:targetColumn,:description,:isActive,:createdBy,:updatedBy,:createdAt,:updatedAt)
                        """
                    ),
                    {
                        "mappingType": mapping_type,
                        "sourceColumn": source_column,
                        "targetColumn": target_column,
                        "description": description,
                        "isActive": is_active,
                        "createdBy": created_by,
                        "updatedBy": updated_by,
                        "createdAt": now,
                        "updatedAt": now,
                    },
                )
            else:
                session.execute(
                    text(
                        """
                        UPDATE data_column_mapping
                        SET "sourceColumn" = :sourceColumn,
                            "description" = :description,
                            "isActive" = :isActive,
                            "updatedBy" = :updatedBy,
                            "updatedAt" = :updatedAt
                        WHERE id = :id
                        """
                    ),
                    {
                        "id": existing,
                        "sourceColumn": source_column,
                        "description": description,
                        "isActive": is_active,
                        "updatedBy": updated_by,
                        "updatedAt": now,
                    },
                )
        session.commit()


def main() -> None:
    args = _parse_args()
    payload = _load_yaml(Path(args.file))

    eligibility = payload.get("eligibility_rule", [])
    if not isinstance(eligibility, list):
        raise ValueError("'eligibility_rule' must be a list.")
    _seed_eligibility(eligibility, sponsor=args.sponsor)

    sv = payload.get("subject_visit_column_mapping", [])
    if not isinstance(sv, list):
        raise ValueError("'subject_visit_column_mapping' must be a list.")
    _seed_data_column_mappings(MappingCategory.SUBJECT_VISIT, sv, sponsor=args.sponsor)

    sg = payload.get("subject_group_column_mapping", [])
    if not isinstance(sg, list):
        raise ValueError("'subject_group_column_mapping' must be a list.")
    _seed_data_column_mappings(MappingCategory.SUBJECT_GROUP, sg, sponsor=args.sponsor)

    misc = payload.get("misc_column_mapping", [])
    if not isinstance(misc, list):
        raise ValueError("'misc_column_mapping' must be a list.")
    _seed_data_column_mappings(MappingCategory.MISC, misc, sponsor=args.sponsor)

    print(f"Seed completed for schema '{args.sponsor}' from '{args.file}'.")


if __name__ == "__main__":
    main()
