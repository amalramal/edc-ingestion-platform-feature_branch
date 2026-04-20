# =============================================================================
# EDC Ingestion Platform — Multi-stage Production Container (Poetry)
# =============================================================================
# Stage 1 (builder): Install Poetry, export a locked requirements.txt,
#                     and pip-install into an isolated prefix.
# Stage 2 (runtime): Copy only the installed packages and application code
#                     into a minimal, non-root, read-only-compatible image.
#
# Poetry itself is NOT present in the runtime image.
# =============================================================================

# ---------------------------------------------------------------------------
# Build stage — export locked requirements.txt from Poetry
# ---------------------------------------------------------------------------
FROM python:3.13-slim-bookworm AS builder

ENV POETRY_VERSION=2.3.2 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_NO_INTERACTION=1

RUN pip install --no-cache-dir "poetry==${POETRY_VERSION}" poetry-plugin-export

WORKDIR /build

COPY pyproject.toml poetry.lock* ./

# Export a deterministic requirements.txt from the lock file.
# If no lock file exists yet (first build), let Poetry resolve first.
RUN poetry lock 2>/dev/null; \
    poetry export --format requirements.txt --output requirements.txt --without-hashes

# ---------------------------------------------------------------------------
# Runtime stage — install deps from requirements.txt, copy app
# ---------------------------------------------------------------------------
FROM python:3.13.11-slim AS runtime

RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser

WORKDIR /app

COPY --from=builder /build/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini ./
COPY alembic/ ./alembic/
COPY src/ ./src/

# src-layout package: not pip-installed; expose so `edc_ingestion` imports work for
# Alembic (env.py), uvicorn, and `python -m edc_ingestion.*` ECS entrypoints.
ENV PYTHONPATH=/app/src

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["uvicorn", "edc_ingestion.app:app", "--host", "0.0.0.0", "--port", "8000"]
