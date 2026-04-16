"""SVDS subject-visit API adapter (OAuth2 + httpx), guarded by :data:`svds_http_breaker`."""

from __future__ import annotations

import time
from typing import Any
from urllib.parse import urljoin

import httpx
import modin.pandas as mpd

from edc_ingestion.circuit_breakers import svds_http_breaker
from edc_ingestion.config import settings
from edc_ingestion.logging_config import get_logger
from edc_ingestion.tasks.common.base import BaseIngestor

logger = get_logger(__name__)

# Query shape for SVDS paging (no extra env surface; override in code if vendor differs).
# CORDIS / MuleSoft expects ``page`` >= 1 (not zero-based).
_PAGE_PARAM = "page"
_PAGE_SIZE_PARAM = "pageSize"
_MAX_PAGES = 2000


def _extract_page_rows(payload: Any) -> list[Any]:
    if isinstance(payload, list):
        return payload
    if not isinstance(payload, dict):
        return []
    for key in ("content", "data", "subjectVisits", "items", "records", "results"):
        block = payload.get(key)
        if isinstance(block, list):
            return block
    embedded = payload.get("_embedded")
    if isinstance(embedded, dict):
        for key in ("subjectVisits", "content", "data"):
            block = embedded.get(key)
            if isinstance(block, list):
                return block
    page = payload.get("page")
    if isinstance(page, dict):
        for key in ("content", "data"):
            block = page.get(key)
            if isinstance(block, list):
                return block
    return []


def _page_has_more(payload: dict[str, Any], page_number: int, row_count: int, page_size: int) -> bool:
    """``page_number`` is 1-based (matches the query param sent to the API)."""
    if row_count == 0:
        return False
    if row_count < page_size:
        return False
    if payload.get("last") is False:
        return True
    if payload.get("last") is True:
        return False
    total_pages = payload.get("totalPages")
    if isinstance(total_pages, int):
        return page_number < total_pages
    page_obj = payload.get("page")
    if isinstance(page_obj, dict):
        tp = page_obj.get("totalPages")
        if isinstance(tp, int):
            return page_number < tp
    return True


class SVDSApiIngestor(BaseIngestor):
    """OAuth2 client_credentials + paginated ``GET …/study/{studyId}/subjectVisits``."""

    def __init__(self) -> None:
        self._access_token: str | None = None
        self._token_deadline: float = 0.0

    def _post_token(self, client: httpx.Client) -> str:
        now = time.monotonic()
        cached = self._access_token
        if cached is not None and now < self._token_deadline:
            return cached

        url = settings.EDC_OAUTH2_TOKEN_URL.strip()
        if not url:
            raise ValueError("EDC_OAUTH2_TOKEN_URL is required for SVDS API ingest.")

        cid = settings.EDC_OAUTH2_CLIENT_ID.strip()
        secret = settings.EDC_OAUTH2_CLIENT_SECRET.strip()
        if not cid or not secret:
            raise ValueError("EDC_OAUTH2_CLIENT_ID and EDC_OAUTH2_CLIENT_SECRET are required for SVDS API ingest.")

        data = {
            "grant_type": "client_credentials",
            "client_id": cid,
            "client_secret": secret,
        }
        logger.info("svds_oauth_token_request", token_url=url)
        resp = client.post(
            url,
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=float(settings.EDC_OAUTH2_TIMEOUT_SECONDS),
        )
        resp.raise_for_status()
        body = resp.json()
        raw_tok = body.get("access_token") if isinstance(body, dict) else None
        if not isinstance(raw_tok, str):
            raise RuntimeError("OAuth token response missing string field 'access_token'.")
        token: str = raw_tok
        expires_in = 300
        if isinstance(body, dict):
            raw_exp = body.get("expires_in")
            if isinstance(raw_exp, (int, float)):
                expires_in = int(raw_exp)
        self._access_token = token
        self._token_deadline = time.monotonic() + max(30, expires_in - 30)
        logger.info("svds_oauth_token_ok", expires_in=expires_in)
        return token

    def _ensure_token(self, client: httpx.Client) -> str:
        return svds_http_breaker.call(lambda: self._post_token(client))

    def fetch_data(self, study_id: str) -> mpd.DataFrame:
        base = settings.EDC_SUBJECT_VISIT_API_BASE_URL.strip().rstrip("/")
        if not base:
            raise ValueError("EDC_SUBJECT_VISIT_API_BASE_URL is required for SVDS API ingest.")

        visit_path = f"study/{study_id}/subjectVisits"
        page_size = max(1, settings.EDC_SUBJECT_VISIT_PAGE_SIZE)
        all_rows: list[Any] = []
        timeout = float(settings.EDC_API_TIMEOUT_SECONDS)

        with httpx.Client() as client:
            token = self._ensure_token(client)
            page_number = 1
            while True:
                url = urljoin(base + "/", visit_path)
                params: dict[str, Any] = {_PAGE_SIZE_PARAM: page_size, _PAGE_PARAM: page_number}
                logger.info(
                    "svds_subject_visits_request",
                    study_id=study_id,
                    page=page_number,
                    page_size=page_size,
                )

                def _get_page(
                    _url: str = url,
                    _params: dict[str, Any] = params,
                    _token: str = token,
                    _timeout: float = timeout,
                ) -> Any:
                    r = client.get(
                        _url,
                        params=_params,
                        headers={"Authorization": f"Bearer {_token}"},
                        timeout=_timeout,
                    )
                    if r.is_error:
                        preview = (r.text or "")[:4096]
                        logger.warning(
                            "svds_subject_visits_http_error",
                            study_id=study_id,
                            status_code=r.status_code,
                            url=str(r.request.url),
                            body_preview=preview or None,
                        )
                    r.raise_for_status()
                    return r.json()

                payload = svds_http_breaker.call(_get_page)

                if isinstance(payload, list):
                    all_rows.extend(payload)
                    logger.info("svds_subject_visits_array_body", study_id=study_id, rows=len(payload))
                    break
                rows = _extract_page_rows(payload)
                all_rows.extend(rows)
                logger.info(
                    "svds_subject_visits_page",
                    study_id=study_id,
                    page=page_number,
                    rows_in_page=len(rows),
                    rows_total=len(all_rows),
                )
                meta = payload if isinstance(payload, dict) else {}
                if not _page_has_more(meta, page_number, len(rows), page_size):
                    break
                page_number += 1
                if page_number > _MAX_PAGES:
                    logger.warning("svds_max_pages_reached", study_id=study_id, max_pages=_MAX_PAGES)
                    break

        if not all_rows:
            logger.info("svds_subject_visits_empty", study_id=study_id)
            return mpd.DataFrame()

        df = mpd.json_normalize(all_rows)
        logger.info("svds_subject_visits_loaded", study_id=study_id, columns=len(df.columns), rows=len(df))
        return df
