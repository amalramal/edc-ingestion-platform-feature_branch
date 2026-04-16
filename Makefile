# EDC Ingestion Platform — targets grouped: local Docker, local API/TF, quality, AWS (ENV), clean.
#   make help  — same order as below.  Windows: make.bat (CRLF).  See README.

.DEFAULT_GOAL := help
SHELL := /bin/bash

COMPOSE    := docker compose
SPONSOR    ?= sponsor_demo
SEED_FILE  ?= $(if $(FILE),$(FILE),seeds/sponsors/$(SPONSOR)/mappings.yaml)
STUDY_ID   ?= B1791094
SPONSOR_ID ?= demo
SOURCE_FILE ?= incoming/sponsor_1/sample_edc.csv
API_URL    := http://localhost:8000

AWS_REGION     ?= us-east-1
# AWS deploy tier: terraform/aws.<ENV>.tfvars when present, else terraform/aws.tfvars
ENV            ?= dev
ifeq ($(wildcard terraform/aws.$(ENV).tfvars),)
AWS_VAR_FILE   := terraform/aws.tfvars
else
AWS_VAR_FILE   := terraform/aws.$(ENV).tfvars
endif
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REPO       ?= edc-ingestion-platform
ECR_URI         = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO)
IMAGE_TAG      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")
SFN_ARN        ?= $(shell cd terraform && terraform output -raw state_machine_arn 2>/dev/null)
# Required for aws-migrate: make aws-migrate RDS_URL=postgresql://...
RDS_URL        ?=

.PHONY: help
help: ## List targets.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Local — Docker (compose mode: in-process /ingest; S3/SNS via LocalStack in stack)
# =============================================================================

.PHONY: install
install: ## Install dependencies (Poetry).
	poetry install --no-interaction

.PHONY: up
up: ## Start stack (compose mode — in-process /ingest).
	$(COMPOSE) up --build -d
	@echo "  API: $(API_URL)/docs"
	@echo "  SFTPGo: run \`make load\` to copy input_files/by_study into the SFTP tree (not run by up)."

.PHONY: load
load: ## Copy input_files/by_study → SFTPGo volume (user edc; needs up + study folders).
	$(COMPOSE) --profile bootstrap run --rm sftpgo_bootstrap

.PHONY: down
down: ## Stop containers and remove volumes.
	$(COMPOSE) down -v --remove-orphans

.PHONY: restart
restart: down up ## Rebuild from clean containers.

.PHONY: logs
logs: ## Tail all container logs.
	$(COMPOSE) logs -f

# =============================================================================
# Local — DB & HTTP API (requires API up for health)
# =============================================================================

.PHONY: migrate
migrate: ## Alembic upgrade for SPONSOR schema (default sponsor_demo).
	poetry run alembic -x schema=$(SPONSOR) upgrade head

.PHONY: seed-sponsor
seed-sponsor: ## Seed sponsor-specific rules/mappings (SPONSOR=..., FILE=...).
	poetry run python scripts/seed_sponsor.py --sponsor $(SPONSOR) --file "$(SEED_FILE)"

.PHONY: health
health: ## GET /health (stub app).
	@curl -s $(API_URL)/health | python -m json.tool

# =============================================================================
# Local — Terraform → LocalStack (terraform/local.tfvars; Step Functions profile if ARN exists)
# =============================================================================

.PHONY: tf-init
tf-init: ## terraform init (terraform/).
	cd terraform && terraform init

.PHONY: tf-apply
tf-apply: ## terraform apply (uses terraform/local.tfvars if file exists).
	@if [ -f terraform/local.tfvars ]; then \
		cd terraform && terraform apply -var-file=local.tfvars -auto-approve; \
	else \
		cd terraform && terraform apply -auto-approve; \
	fi

.PHONY: tf-destroy
tf-destroy: ## terraform destroy (local state; no -var-file unless you add it).
	cd terraform && terraform destroy -auto-approve

.PHONY: localstack-full-print-env
localstack-full-print-env: ## Print: export SFN_STATE_MACHINE_ARN=… (after tf-apply).
	@cd terraform && terraform output -raw state_machine_arn 2>/dev/null | sed 's/^/export SFN_STATE_MACHINE_ARN=/' \
		|| { echo "Run make tf-apply first (state_machine_arn missing)." >&2; exit 1; }

.PHONY: localstack-full-up
localstack-full-up: ## One-shot: up + tf-init + tf-apply + localstack-full compose (needs terraform/local.tfvars).
	@test -f terraform/local.tfvars || { echo "Create terraform/local.tfvars (cp terraform/local.tfvars.example terraform/local.tfvars)" >&2; exit 1; }
	$(COMPOSE) up --build -d
	$(MAKE) tf-init
	$(MAKE) tf-apply
	@SFN=$$(cd terraform && terraform output -raw state_machine_arn) && \
		if [ -z "$$SFN" ]; then echo "state_machine_arn empty (Community: no ECS/SFN). Use make up for in-process mode, or LocalStack Pro + localstack_skip_ecs_and_sfn=false." >&2; exit 1; fi && \
		SFN_STATE_MACHINE_ARN=$$SFN $(COMPOSE) -f docker-compose.yml -f docker-compose.localstack-full.yml up --build -d
	@echo "  $(API_URL)/docs — POST /ingest → 202 + execution ARN"

.PHONY: localstack-full-down
localstack-full-down: ## Destroy LocalStack TF (local.tfvars if present), compose down -v, rm tfstate + lock.
	@if [ -f terraform/local.tfvars ]; then \
		(cd terraform && terraform destroy -var-file=local.tfvars -auto-approve) || true; \
	else \
		(cd terraform && terraform destroy -auto-approve) || true; \
	fi
	$(COMPOSE) -f docker-compose.yml -f docker-compose.localstack-full.yml down -v --remove-orphans 2>/dev/null || true
	$(COMPOSE) down -v --remove-orphans
	rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup terraform/.terraform.tfstate.lock.info

# =============================================================================
# Local — quality
# =============================================================================

.PHONY: lint
lint: ## ruff + mypy.
	poetry run ruff check src/
	poetry run mypy src/

.PHONY: fmt
fmt: ## ruff format + fix.
	poetry run ruff format src/
	poetry run ruff check --fix src/

.PHONY: test
test: ## Pytest (unit tests; optional tests/integration excluded by pyproject).
	MODIN_CPUS=1 poetry run pytest

# =============================================================================
# AWS — ENV=dev|uat|prod + AWS_REGION (terraform/aws.<ENV>.tfvars if present; ECR in that region)
# =============================================================================

.PHONY: aws-login
aws-login: ## ECR docker login.
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(ECR_URI)

.PHONY: aws-build
aws-build: ## docker build (tagged for ECR repo name).
	docker build -t $(ECR_REPO):$(IMAGE_TAG) -t $(ECR_REPO):latest .

.PHONY: aws-push
aws-push: aws-login aws-build ## Tag and push to ECR.
	docker tag $(ECR_REPO):$(IMAGE_TAG) $(ECR_URI):$(IMAGE_TAG)
	docker tag $(ECR_REPO):latest $(ECR_URI):latest
	docker push $(ECR_URI):$(IMAGE_TAG)
	docker push $(ECR_URI):latest
	@echo "  $(ECR_URI):$(IMAGE_TAG)"

.PHONY: aws-tf-init
aws-tf-init: ## terraform init -reconfigure (terraform/).
	cd terraform && terraform init -reconfigure

.PHONY: aws-tf-apply
aws-tf-apply: ## terraform apply ($(AWS_VAR_FILE) + ECR worker/publisher images).
	cd terraform && terraform apply -var-file=$(AWS_VAR_FILE) \
		-var="worker_image=$(ECR_URI):$(IMAGE_TAG)" \
		-var="publisher_image=$(ECR_URI):$(IMAGE_TAG)"

.PHONY: aws-tf-destroy
aws-tf-destroy: ## terraform destroy (same var-file as aws-tf-apply).
	cd terraform && terraform apply -destroy -var-file=$(AWS_VAR_FILE) \
		-var="worker_image=$(ECR_URI):$(IMAGE_TAG)" \
		-var="publisher_image=$(ECR_URI):$(IMAGE_TAG)"

.PHONY: aws-migrate
aws-migrate: ## Alembic on RDS (RDS_URL=postgresql://…).
	@test -n "$(RDS_URL)" || (echo "Usage: make aws-migrate RDS_URL=postgresql://..." >&2; exit 1)
	DATABASE_URL=$(RDS_URL) poetry run alembic -x schema=$(SPONSOR) upgrade head

.PHONY: aws-trigger
aws-trigger: ## Start Step Functions execution on AWS (study_id/sponsor_id).
	@aws stepfunctions start-execution \
		--state-machine-arn $(SFN_ARN) \
		--input '{"study_id":"$(STUDY_ID)","sponsor_id":"$(SPONSOR_ID)"}' \
		--region $(AWS_REGION) | python -m json.tool

.PHONY: aws-upload
aws-upload: ## S3 cp FILE to raw bucket key SOURCE_FILE (FILE=… required).
	@test -n "$(FILE)" || (echo "Usage: make aws-upload FILE=path/to.csv" && exit 1)
	aws s3 cp $(FILE) s3://edc-raw-layer/$(SOURCE_FILE) --region $(AWS_REGION)

# =============================================================================
# Other
# =============================================================================

.PHONY: clean
clean: ## Remove __pycache__, pytest/mypy/ruff caches.
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
