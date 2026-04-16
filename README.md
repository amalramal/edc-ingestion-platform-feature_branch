# EDC Ingestion Platform — **template repository**

This is a **skeleton** for the GxP-aware clinical EDC ingestion pipeline: same **layout, tooling, and IaC** as the full product, **without** proprietary application code (`models`, workers, ingestion logic). Use it to bootstrap a new GitHub org repo or teach structure.

## What is included

| Area | Contents |
|------|----------|
| **Python** | `pyproject.toml` + `poetry.lock`, `src/edc_ingestion/` package layout (`tasks/{ingestion,validation,publisher,common}/`), **minimal** `app.py` (`GET /health` only) |
| **DB** | `alembic.ini`, `alembic/env.py` (imports models), `alembic/versions/0001_template_baseline.py` (schema-only), and `scripts/seed_sponsor.py` + `seeds/sponsors/.../mappings.yaml` for sponsor data |
| **Docker** | `Dockerfile`, `docker-compose.yml`, `docker-compose.localstack-full.yml`, `.env.*.example` |
| **Build** | `Makefile`, `make.bat` |
| **IaC** | `terraform/` (`.tf`, `*.tfvars.example`, lock file) — no local secrets |
| **CI** | `.github/workflows/ci.yml` |
| **Tests** | `tests/test_health.py` (stub smoke test) |
| **Docs / samples** | `examples/`, `input_files/` (README + manifests; large `*.csv` samples are omitted) |
| **Scripts** | `scripts/` (e.g. OpenAPI generator) |

## What to add yourself

Copy or re-implement from your internal codebase: **`models.py`**, **`worker` / `publisher`**, **`source_client`**, **`column_mapping`**, **`tasks/**`**, full **`app.py`** routes, and a real **`0001_initial_schema`** (or equivalent) migration.

After you add modules, **uncomment / add model imports** in `alembic/env.py` so `SQLModel.metadata` is complete before running migrations.

## Quick start

```bash
make install
make lint
make test
```

**Windows:** `make.bat install`, `make.bat lint`, `make.bat test`, or `make.bat` for the target list.

## End-to-end local run (template)

Run the full local flow including sponsor onboarding and seed-data load.

### 0) Create local `.env` (never commit secrets)

```bash
cp .env.example .env
```

Windows:

```bat
copy .env.example .env
```

Set `POSTGRES_PASSWORD` in `.env` before running `make up`.

### 1) Start local services

```bash
make up
```

### 2) Apply schema migration for sponsor - Ideally for New sponsors only.

```bash
make migrate SPONSOR=sponsor_demo
```

### 3) Feed sponsor seed data (rules + mappings)

```bash
make seed-sponsor SPONSOR=sponsor_demo FILE=seeds/sponsors/sponsor_demo/mappings.yaml
```

### 4) Verify API is up

```bash
make health
```

### 5) Stop and clean local stack (when done)

```bash
make down
```

Windows (`make.bat`) equivalent:

```bat
make.bat up
make.bat migrate SPONSOR=sponsor_demo
make.bat seed-sponsor SPONSOR=sponsor_demo FILE=seeds/sponsors/sponsor_demo/mappings.yaml
make.bat health
make.bat down
```

### Make targets (`make help` / `make.bat`)

| Group | Targets |
|-------|---------|
| Dependencies | `install` |
| Docker | `up`, `down`, `restart`, `logs` |
| DB / API | `migrate`, `seed-sponsor`, `health` |
| Terraform → LocalStack | `tf-init`, `tf-apply`, `tf-destroy`, `localstack-full-print-env`, `localstack-full-up`, `localstack-full-down` |
| Quality | `lint`, `fmt`, `test`, `clean` |
| AWS (deploy / ops) | `aws-login`, `aws-build`, `aws-push`, `aws-tf-init`, `aws-tf-apply`, `aws-tf-destroy`, `aws-migrate`, `aws-trigger`, `aws-upload` |

**Docker (API only):** `make up` starts the stack; `make health` hits `GET /health` (`{"status":"ok"}` with the stub). The template app only registers `/health` until you add real routes.

**Sponsor seed data:** run migrations then seed sponsor-specific mappings/rules:

```bash
make migrate SPONSOR=sponsor_demo
make seed-sponsor SPONSOR=sponsor_demo FILE=seeds/sponsors/sponsor_demo/mappings.yaml
```

Windows:

```bat
make.bat migrate SPONSOR=sponsor_demo
make.bat seed-sponsor SPONSOR=sponsor_demo FILE=seeds/sponsors/sponsor_demo/mappings.yaml
```

## OpenAPI

```bash
poetry run python scripts/generate_openapi.py
```

## Licence

Use and modify per your organisation’s policy; template ships without proprietary business logic.
