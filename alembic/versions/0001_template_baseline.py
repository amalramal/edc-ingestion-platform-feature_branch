"""Initial tenant DDL from SQLModel (schema-per-sponsor).

Single baseline revision: includes unified ``data_column_mapping`` (no legacy
per-family mapping tables), ``sftp_file_read_log``, and related app tables.
Schema-only; use ``seed-sponsor`` for tenant data.

Revision ID: 0001
Revises:
Create Date: 2026-04-05
"""

from collections.abc import Sequence

from alembic import op
from sqlmodel import SQLModel

# Register all ORM tables on SQLModel.metadata (keep in sync with alembic/env.py).
from edc_ingestion.models import (  # noqa: F401
    DataColumnMapping,
    EligibilityRule,
    FileIngestionLog,
    SftpFileReadLog,
    SponsorIntegrationConfig,
    StudyConfig,
    SubjectRegistry,
    VisitScheduleCache,
)

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    SQLModel.metadata.create_all(bind, checkfirst=True)


def downgrade() -> None:
    bind = op.get_bind()
    SQLModel.metadata.drop_all(bind, checkfirst=True)
