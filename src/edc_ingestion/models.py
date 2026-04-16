"""ORM tables (tenant schema), API DTOs, and normalized column constants."""

from __future__ import annotations

import enum
from datetime import UTC, datetime
from uuid import UUID, uuid4

from pydantic import BaseModel
from pydantic import Field as PydanticField
from sqlalchemy import Boolean, Column, DateTime, Integer, String, Text, Uuid
from sqlmodel import Field, SQLModel


class IngestionStatus(str, enum.Enum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    INGESTED = "INGESTED"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class ProcessingStatus(str, enum.Enum):
    VALID = "VALID"
    SKIPPED = "SKIPPED"
    FAILED_ELIGIBILITY = "FAILED_ELIGIBILITY"
    FAILED_STRATA = "FAILED_STRATA"
    FAILED_IMMUTABILITY = "FAILED_IMMUTABILITY"


class RuleOperator(str, enum.Enum):
    EQUALS = "EQUALS"
    NOT_EQUALS = "NOT_EQUALS"
    IN = "IN"
    NOT_IN = "NOT_IN"
    GREATER_THAN = "GREATER_THAN"
    LESS_THAN = "LESS_THAN"
    IS_NOT_NULL = "IS_NOT_NULL"
    IS_NULL = "IS_NULL"


class RuleKind(str, enum.Enum):
    NON_BLOCKING = "NON_BLOCKING"
    BLOCKING = "BLOCKING"


class DataSource(str, enum.Enum):
    API = "API"
    SFTP = "SFTP"


class SubjectVisitSourceMode(str, enum.Enum):
    """API_FIRST: API visits + SFTP non-visit CSVs; on API failure, full SFTP folder."""

    API_FIRST = "API_FIRST"
    SFTP_ONLY = "SFTP_ONLY"
    API_ONLY = "API_ONLY"


class PipelineDepth(str, enum.Enum):
    RAW = "RAW"
    STAGE = "STAGE"
    PUBLISH = "PUBLISH"


class EdcEnvironment(str, enum.Enum):
    LOCAL_COMPOSE = "local-compose"
    LOCAL_LOCALSTACK = "local-localstack"
    DEV = "dev"
    UAT = "uat"
    PROD = "prod"


class LocalRuntimeMode(str, enum.Enum):
    COMPOSE = "compose"
    LOCALSTACK_FULL = "localstack_full"


class ArmResolutionMode(str, enum.Enum):
    FLAT_RATE = "FLAT_RATE"
    EDC_ONLY = "EDC_ONLY"
    IMPALA_GROUP_MAP_TO_ARM = "IMPALA_GROUP_MAP_TO_ARM"
    MANUAL_MAPPING = "MANUAL_MAPPING"
    IMPALA_BUDGET_ARM_FROM_COLUMN = "IMPALA_BUDGET_ARM_FROM_COLUMN"
    HYBRID = "HYBRID"


class PkPayMode(str, enum.Enum):
    PER_TIMEPOINT = "PER_TIMEPOINT"
    LUMP_SUM = "LUMP_SUM"
    IGNORE = "IGNORE"


class MappingCategory(str, enum.Enum):
    SUBJECT_VISIT = "subject_visit"
    SUBJECT_GROUP = "subject_group"
    MISC = "misc"


def data_source_as_str(data_source: DataSource | str) -> str:
    if isinstance(data_source, DataSource):
        return data_source.value
    return str(data_source)


def _utcnow() -> datetime:
    return datetime.now(UTC)


class FileIngestionLog(SQLModel, table=True):
    __tablename__ = "file_ingestion_log"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    run_id: UUID = Field(
        default_factory=uuid4,
        sa_column=Column("runId", Uuid(as_uuid=True), nullable=False, unique=True, index=True),
    )
    study_id: str = Field(sa_column=Column("studyId", String(64), nullable=False, index=True))
    sponsor_id: str = Field(sa_column=Column("sponsorId", String(128), nullable=False, index=True))
    data_source: DataSource = Field(sa_column=Column("dataSource", String(16), nullable=False))
    source_file_key: str | None = Field(default=None, sa_column=Column("sourceFileKey", String(512), nullable=True))
    staging_s3_key: str | None = Field(default=None, sa_column=Column("stagingS3Key", String(512), nullable=True))
    s3_raw_bucket: str | None = Field(default=None, sa_column=Column("s3RawBucket", String(128), nullable=True))
    s3_pipeline_staging_prefix: str | None = Field(
        default=None, sa_column=Column("s3PipelineStagingPrefix", String(256), nullable=True)
    )
    staging_s3_uri: str | None = Field(default=None, sa_column=Column("stagingS3Uri", String(1536), nullable=True))
    validated_valid_s3_key: str | None = Field(
        default=None, sa_column=Column("validatedValidS3Key", String(512), nullable=True)
    )
    validated_valid_s3_uri: str | None = Field(
        default=None, sa_column=Column("validatedValidS3Uri", String(1536), nullable=True)
    )
    validated_non_valid_s3_key: str | None = Field(
        default=None, sa_column=Column("validatedNonValidS3Key", String(512), nullable=True)
    )
    validated_non_valid_s3_uri: str | None = Field(
        default=None, sa_column=Column("validatedNonValidS3Uri", String(1536), nullable=True)
    )
    source_endpoint_url: str | None = Field(
        default=None, sa_column=Column("sourceEndpointUrl", String(1024), nullable=True)
    )
    status: IngestionStatus = Field(
        default=IngestionStatus.PENDING,
        sa_column=Column("status", String(16), nullable=False, index=True, server_default="PENDING"),
    )
    total_rows: int | None = Field(default=None, sa_column=Column("totalRows", Integer, nullable=True))
    valid_rows: int | None = Field(default=None, sa_column=Column("validRows", Integer, nullable=True))
    skipped_rows: int | None = Field(default=None, sa_column=Column("skippedRows", Integer, nullable=True))
    failure_reason: str | None = Field(default=None, sa_column=Column("failureReason", String(2048), nullable=True))
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true"))


class SftpFileReadLog(SQLModel, table=True):
    __tablename__ = "sftp_file_read_log"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    run_id: UUID = Field(sa_column=Column("runId", Uuid(as_uuid=True), nullable=False, index=True))
    study_id: str = Field(sa_column=Column("studyId", String(64), nullable=False, index=True))
    sponsor_id: str = Field(sa_column=Column("sponsorId", String(128), nullable=False, index=True))
    remote_path: str = Field(sa_column=Column("remotePath", String(1024), nullable=False))
    file_name: str = Field(sa_column=Column("fileName", String(512), nullable=False))
    mapping_category: MappingCategory = Field(
        sa_column=Column("mappingCategory", String(32), nullable=False, index=True),
    )
    file_name_hash: str = Field(sa_column=Column("fileNameHash", String(64), nullable=False))
    file_content_hash: str = Field(sa_column=Column("fileContentHash", String(64), nullable=False))
    source_created_at: datetime | None = Field(
        default=None, sa_column=Column("sourceCreatedAt", DateTime(timezone=True), nullable=True)
    )
    source_updated_at: datetime | None = Field(
        default=None, sa_column=Column("sourceUpdatedAt", DateTime(timezone=True), nullable=True)
    )
    source_accessed_at: datetime | None = Field(
        default=None, sa_column=Column("sourceAccessedAt", DateTime(timezone=True), nullable=True)
    )
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )


class SubjectRegistry(SQLModel, table=True):
    __tablename__ = "subject_registry"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    study_id: str = Field(sa_column=Column("studyId", String(64), nullable=False, index=True))
    site_id: str = Field(sa_column=Column("siteId", String(64), nullable=False, index=True))
    subject_id: str = Field(sa_column=Column("subjectId", String(64), nullable=False, index=True))
    assigned_budget_arm: str = Field(sa_column=Column("assignedBudgetArm", String(256), nullable=False))
    first_seen_run_id: UUID = Field(sa_column=Column("firstSeenRunId", Uuid(as_uuid=True), nullable=False))
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true"))


class EligibilityRule(SQLModel, table=True):
    __tablename__ = "eligibility_rule"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    rule_id: str = Field(sa_column=Column("ruleId", String(64), nullable=False, unique=True, index=True))
    study_id: str | None = Field(default=None, sa_column=Column("studyId", String(64), nullable=True, index=True))
    column_name: str = Field(sa_column=Column("columnName", String(128), nullable=False))
    operator: RuleOperator = Field(sa_column=Column("operator", String(32), nullable=False))
    expected_value: str | None = Field(default=None, sa_column=Column("expectedValue", String(512), nullable=True))
    rejection_reason: str = Field(sa_column=Column("rejectionReason", String(1024), nullable=False))
    rule_kind: RuleKind = Field(
        default=RuleKind.NON_BLOCKING,
        sa_column=Column("ruleKind", String(32), nullable=False, server_default="NON_BLOCKING"),
    )
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(
        default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true", index=True)
    )


class SponsorIntegrationConfig(SQLModel, table=True):
    __tablename__ = "sponsor_integration_config"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    subject_visit_api_base_url: str | None = Field(
        default=None,
        sa_column=Column("subjectVisitApiBaseUrl", String(1024), nullable=True),
    )
    oauth2_token_url: str | None = Field(default=None, sa_column=Column("oauth2TokenUrl", String(1024), nullable=True))
    oauth2_client_id: str | None = Field(default=None, sa_column=Column("oauth2ClientId", String(512), nullable=True))
    oauth2_client_secret: str | None = Field(
        default=None, sa_column=Column("oauth2ClientSecret", String(512), nullable=True)
    )
    milestone_api_base_url: str | None = Field(
        default=None, sa_column=Column("milestoneApiBaseUrl", String(1024), nullable=True)
    )
    milestone_detail_id: int | None = Field(default=None, sa_column=Column("milestoneDetailId", Integer, nullable=True))
    api_page_size: int | None = Field(default=None, sa_column=Column("apiPageSize", Integer, nullable=True))
    api_timeout_seconds: int | None = Field(default=None, sa_column=Column("apiTimeoutSeconds", Integer, nullable=True))
    sftp_landing_prefix: str | None = Field(
        default=None, sa_column=Column("sftpLandingPrefix", String(512), nullable=True)
    )
    alert_recipients: str | None = Field(default=None, sa_column=Column("alertRecipients", String(2048), nullable=True))
    subject_visit_source_mode: str | None = Field(
        default=None, sa_column=Column("subjectVisitSourceMode", String(32), nullable=True)
    )
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true"))


class StudyConfig(SQLModel, table=True):
    __tablename__ = "study_config"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    study_id: str = Field(sa_column=Column("studyId", String(64), nullable=False, unique=True, index=True))
    sponsor_id: str = Field(default="", sa_column=Column("sponsorId", String(128), nullable=False, server_default="''"))
    arm_resolution_mode: ArmResolutionMode = Field(sa_column=Column("armResolutionMode", String(32), nullable=False))
    edc_arm_column: str | None = Field(default=None, sa_column=Column("edcArmColumn", String(256), nullable=True))
    payable_subject_statuses: str | None = Field(
        default=None, sa_column=Column("payableSubjectStatuses", Text, nullable=True)
    )
    non_payable_subject_statuses: str | None = Field(
        default=None, sa_column=Column("nonPayableSubjectStatuses", Text, nullable=True)
    )
    pk_pay_mode: str | None = Field(default=None, sa_column=Column("pkPayMode", String(16), nullable=True))
    has_visit_contact_mode: bool = Field(
        default=False, sa_column=Column("hasVisitContactMode", Boolean, nullable=False, server_default="false")
    )
    impala_arm_column: str | None = Field(default=None, sa_column=Column("impalaArmColumn", String(128), nullable=True))
    impala_file_key: str | None = Field(default=None, sa_column=Column("impalaFileKey", String(512), nullable=True))
    manual_mapping_file_key: str | None = Field(
        default=None, sa_column=Column("manualMappingFileKey", String(512), nullable=True)
    )
    strata_to_arm_mapping: str | None = Field(default=None, sa_column=Column("strataToArmMapping", Text, nullable=True))
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true"))


class VisitScheduleCache(SQLModel, table=True):
    __tablename__ = "visit_schedule_cache"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    study_id: str = Field(sa_column=Column("studyId", String(64), nullable=False, index=True))
    visit_number: int | None = Field(default=None, sa_column=Column("visitNumber", Integer, nullable=True))
    visit_name: str | None = Field(default=None, sa_column=Column("visitName", String(256), nullable=True))
    optional_visit_flag: int | None = Field(default=None, sa_column=Column("optionalVisitFlag", Integer, nullable=True))
    form_name: str | None = Field(default=None, sa_column=Column("formName", String(256), nullable=True))
    procedure_name: str | None = Field(default=None, sa_column=Column("procedureName", String(256), nullable=True))
    fetched_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("fetchedAt", DateTime(timezone=True), nullable=False)
    )
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true"))


class DataColumnMapping(SQLModel, table=True):
    __tablename__ = "data_column_mapping"

    id: int | None = Field(default=None, sa_column=Column("id", Integer, primary_key=True, autoincrement=True))
    mapping_type: MappingCategory = Field(sa_column=Column("type", String(32), nullable=False, index=True))
    source_column: str = Field(sa_column=Column("sourceColumn", String(256), nullable=False))
    target_column: str = Field(sa_column=Column("targetColumn", String(256), nullable=False))
    description: str | None = Field(default=None, sa_column=Column("description", String(1024), nullable=True))
    created_at: datetime = Field(
        default_factory=_utcnow, sa_column=Column("createdAt", DateTime(timezone=True), nullable=False)
    )
    created_by: str | None = Field(default=None, sa_column=Column("createdBy", String(128), nullable=True))
    updated_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column("updatedAt", DateTime(timezone=True), nullable=False, onupdate=_utcnow),
    )
    updated_by: str | None = Field(default=None, sa_column=Column("updatedBy", String(128), nullable=True))
    is_active: bool = Field(
        default=True, sa_column=Column("isActive", Boolean, nullable=False, server_default="true", index=True)
    )


class ColumnMappingRead(BaseModel):
    id: int
    category: MappingCategory
    source_column: str
    target_column: str
    description: str | None = None
    is_active: bool
    created_by: str | None = None
    updated_by: str | None = None
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_row(cls, row: DataColumnMapping) -> ColumnMappingRead:
        if row.id is None:
            raise ValueError("DataColumnMapping row must be persisted (id not None).")
        return cls(
            id=row.id,
            category=row.mapping_type,
            source_column=row.source_column,
            target_column=row.target_column,
            description=row.description,
            is_active=row.is_active,
            created_by=row.created_by,
            updated_by=row.updated_by,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )


class ColumnMappingCreate(BaseModel):
    category: MappingCategory
    source_column: str
    target_column: str = PydanticField(description="Normalized target field name (camelCase API key).")
    description: str | None = None
    is_active: bool = True
    created_by: str | None = None


EDC_SOURCE_COLUMNS_UPPER: list[str] = [
    "STUDY_ID",
    "STUDY_SITE",
    "SUBJECT_ID",
    "SUBJECT_STATUS",
    "VISIT_NUMBER",
    "VISIT_NAME",
    "VISIT_DATE",
    "STUDY_FSFV",
    "FORM_NAME",
    "BLANK_FORM_INDICATOR",
    "COHORT",
    "STRATA",
    "FORM_NOTDONE_INDICATOR",
    "DATA_ENTRY_DATE",
    "PROCEDURE_NAME",
    "PROCEDURE_STATUS",
    "SUBEVENT_NUMBER",
    "ERRONEOUS",
    "VISIT_CONTACT_MODE",
    "SUBJECT_GROUP_IDENTIFIER",
    "START_DATETIME",
    "TIME_POST_DOSE",
    "PAYMENT_GROUP",
]


NORMALIZED_TARGET_COLUMNS: list[str] = [
    "studyId",
    "studySiteNumber",
    "subjectId",
    "subjectStatus",
    "subjectVisitNumber",
    "subjectVisitName",
    "subjectVisitDate",
    "study_fsfv",
    "formName",
    "blankFormIndicator",
    "cohort",
    "strata",
    "formNotDoneIndicator",
    "dateEntryDate",
    "procedureName",
    "procedureStatus",
    "subEventNumber",
    "erroneous",
    "visitContactMode",
    "subjectGroupIdentifier",
    "startDateTime",
    "timePostDose",
    "paymentGroup",
]

UPPER_TO_NORMALIZED_TARGET: dict[str, str] = dict(
    zip(EDC_SOURCE_COLUMNS_UPPER, NORMALIZED_TARGET_COLUMNS, strict=True),
)
