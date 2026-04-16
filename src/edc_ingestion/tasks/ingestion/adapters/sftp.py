"""SFTP CSV pull adapter; remote layout follows ``SFTPGO_LANDING_PREFIX`` + study id."""

from __future__ import annotations

import fnmatch
import io
import posixpath
import stat
from dataclasses import dataclass
from datetime import UTC, datetime

import modin.pandas as mpd
import paramiko

from edc_ingestion.circuit_breakers import sftp_pull_breaker
from edc_ingestion.config import settings
from edc_ingestion.logging_config import get_logger
from edc_ingestion.tasks.common.base import BaseIngestor

logger = get_logger(__name__)

_CSV_GLOB = "*.csv"


@dataclass(frozen=True)
class SftpFilePullRecord:
    """One CSV pulled from SFTP: path, raw bytes (for hashing), parsed frame, and remote mtimes."""

    remote_path: str
    file_name: str
    raw_bytes: bytes
    df: mpd.DataFrame
    source_updated_at: datetime | None
    source_accessed_at: datetime | None
    source_created_at: datetime | None


def _sftp_attr_epoch_to_utc(seconds: float | int | None) -> datetime | None:
    if seconds is None:
        return None
    try:
        return datetime.fromtimestamp(float(seconds), tz=UTC)
    except (OSError, OverflowError, ValueError):
        return None


def _infer_csv_sep(raw: bytes) -> str:
    """Use ``|`` when the header has more pipes than commas (EDC pipe-delimited extracts)."""
    head = raw[:16_384].decode("utf-8", errors="replace").splitlines()
    if not head:
        return ","
    first = head[0]
    return "|" if first.count("|") > first.count(",") else ","


def _load_private_key(path: str, passphrase: str | None) -> paramiko.PKey:
    pw = passphrase or None
    for key_cls in (paramiko.Ed25519Key, paramiko.RSAKey, paramiko.ECDSAKey):
        try:
            return key_cls.from_private_key_file(path, password=pw)
        except paramiko.SSHException:
            continue
    raise ValueError(f"Unsupported or unreadable private key: {path}")


def _remote_study_dir(study_id: str) -> str:
    pfx = settings.SFTPGO_LANDING_PREFIX.strip().strip("/")
    if pfx:
        return posixpath.join(pfx, study_id)
    return study_id


class SFTPIngestor(BaseIngestor):
    """Paramiko SFTP: ``SFTP_HOST`` / ``SFTP_USER`` / ``SFTP_PASSWORD`` (+ optional key file)."""

    def fetch_csv_files(self, study_id: str) -> list[SftpFilePullRecord]:
        """Download each ``*.csv`` under the study folder; return metadata + dataframe per file."""
        host = settings.SFTP_HOST
        if not host:
            raise ValueError("SFTP_HOST is required for SFTP ingest.")
        user = settings.SFTP_USER
        if not user:
            raise ValueError("SFTP_USER is required for SFTP ingest.")

        port = settings.SFTP_PORT
        password = settings.SFTP_PASSWORD or None
        key_path = settings.SFTP_PRIVATE_KEY_PATH
        key_pass = settings.SFTP_PRIVATE_KEY_PASSPHRASE or None

        if not key_path and not password:
            raise ValueError("Set SFTP_PASSWORD and/or SFTP_PRIVATE_KEY_PATH for SFTP ingest.")

        remote_dir = _remote_study_dir(study_id)
        pkey = _load_private_key(key_path, key_pass) if key_path else None

        def _pull_files() -> list[SftpFilePullRecord]:
            logger.info(
                "sftp_connect_attempt",
                host=host,
                port=port,
                user=user,
                remote_dir=remote_dir,
                auth="key" if pkey else "password",
            )
            transport = paramiko.Transport((host, port))
            try:
                transport.connect(username=user, password=password, pkey=pkey)
                sftp = paramiko.SFTPClient.from_transport(transport)
                if sftp is None:
                    raise RuntimeError("SFTP client initialization failed.")
                try:
                    try:
                        attrs = sftp.listdir_attr(remote_dir)
                    except OSError:
                        logger.warning("sftp_study_dir_missing", remote_dir=remote_dir, study_id=study_id)
                        return []

                    names: list[str] = []
                    for f in attrs:
                        name = f.filename
                        full = posixpath.join(remote_dir, name)
                        try:
                            st = sftp.stat(full)
                        except OSError:
                            continue
                        if not stat.S_ISREG(st.st_mode):
                            continue
                        if fnmatch.fnmatch(name, _CSV_GLOB):
                            names.append(name)

                    if not names:
                        logger.info("sftp_no_matching_files", remote_dir=remote_dir, pattern=_CSV_GLOB)
                        return []

                    out: list[SftpFilePullRecord] = []
                    for name in sorted(names):
                        remote_path = posixpath.join(remote_dir, name)
                        logger.info("sftp_download_start", path=remote_path)
                        try:
                            st = sftp.stat(remote_path)
                        except OSError:
                            st = None
                        src_upd = _sftp_attr_epoch_to_utc(getattr(st, "st_mtime", None) if st else None)
                        src_acc = _sftp_attr_epoch_to_utc(getattr(st, "st_atime", None) if st else None)
                        with sftp.open(remote_path, "rb") as rf:
                            raw = rf.read()
                        sep = _infer_csv_sep(raw)
                        df_file = mpd.read_csv(io.BytesIO(raw), sep=sep)
                        logger.info("sftp_csv_sep", path=remote_path, sep=repr(sep), columns=len(df_file.columns))
                        out.append(
                            SftpFilePullRecord(
                                remote_path=remote_path,
                                file_name=name,
                                raw_bytes=raw,
                                df=df_file,
                                source_updated_at=src_upd,
                                source_accessed_at=src_acc,
                                source_created_at=None,
                            )
                        )
                        logger.info(
                            "sftp_download_done",
                            path=remote_path,
                            rows=len(df_file),
                            columns=len(df_file.columns),
                        )

                    logger.info(
                        "sftp_ingest_complete",
                        study_id=study_id,
                        files=len(out),
                        rows=sum(len(rec.df) for rec in out),
                    )
                    return out
                finally:
                    sftp.close()
            finally:
                transport.close()

        return sftp_pull_breaker.call(_pull_files)

    def fetch_data(self, study_id: str) -> mpd.DataFrame:
        chunks = self.fetch_csv_files(study_id)
        if not chunks:
            return mpd.DataFrame()
        frames = [rec.df for rec in chunks]
        out = mpd.concat(frames, ignore_index=True) if len(frames) > 1 else frames[0]
        logger.info(
            "sftp_fetch_data_concat",
            study_id=study_id,
            files=len(frames),
            rows=len(out),
            columns=len(out.columns),
        )
        return out
