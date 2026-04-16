@echo off
REM EDC Ingestion Platform — Windows entry points (see README).

setlocal enabledelayedexpansion

if "%SPONSOR%"=="" set SPONSOR=sponsor_demo
if "%SEED_FILE%"=="" (
  if not "%FILE%"=="" (
    set SEED_FILE=%FILE%
  ) else (
    set SEED_FILE=seeds/sponsors/%SPONSOR%/mappings.yaml
  )
)
if "%STUDY_ID%"=="" set STUDY_ID=B1791094
if "%SPONSOR_ID%"=="" set SPONSOR_ID=demo
if "%SOURCE_FILE%"=="" set SOURCE_FILE=incoming/sponsor_1/sample_edc.csv
if "%API_URL%"=="" set API_URL=http://localhost:8000
if "%AWS_REGION%"=="" set AWS_REGION=us-east-1
if "%ENV%"=="" set ENV=dev

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="install" goto install
if "%1"=="up" goto up
if "%1"=="load" goto load
if "%1"=="down" goto down
if "%1"=="restart" goto restart
if "%1"=="logs" goto logs
if "%1"=="migrate" goto migrate
if "%1"=="seed-sponsor" goto seed-sponsor
if "%1"=="health" goto health
if "%1"=="tf-init" goto tf-init
if "%1"=="tf-apply" goto tf-apply
if "%1"=="tf-destroy" goto tf-destroy
if "%1"=="localstack-full-print-env" goto localstack-full-print-env
if "%1"=="localstack-full-up" goto localstack-full-up
if "%1"=="localstack-full-down" goto localstack-full-down
if "%1"=="lint" goto lint
if "%1"=="fmt" goto fmt
if "%1"=="test" goto test
if "%1"=="aws-login" goto aws-login
if "%1"=="aws-build" goto aws-build
if "%1"=="aws-push" goto aws-push
if "%1"=="aws-tf-init" goto aws-tf-init
if "%1"=="aws-tf-apply" goto aws-tf-apply
if "%1"=="aws-tf-destroy" goto aws-tf-destroy
if "%1"=="aws-migrate" goto aws-migrate
if "%1"=="aws-trigger" goto aws-trigger
if "%1"=="aws-upload" goto aws-upload
if "%1"=="clean" goto clean
echo Unknown target: %1
goto help

:help
echo.
echo   --- Local: Docker (compose) ---
echo        install, up, load, down, restart, logs
echo   --- Local: DB and API ---
echo        migrate, seed-sponsor, health
echo   --- Local: Terraform -^> LocalStack ---
echo        tf-init, tf-apply, tf-destroy, localstack-full-print-env,
echo        localstack-full-up, localstack-full-down
echo   --- Local: quality ---
echo        lint, fmt, test
echo   --- AWS (ENV=dev^|uat^|prod, terraform\aws.%%ENV%%.tfvars if present) ---
echo        Images:  aws-login, aws-build, aws-push
echo        TF:      aws-tf-init, aws-tf-apply, aws-tf-destroy
echo        Runtime: aws-migrate, aws-trigger, aws-upload
echo   --- Other ---
echo        clean
echo.
echo   Example:  make.bat health
echo   Example:  make.bat load
echo   Example:  make.bat seed-sponsor SPONSOR=sponsor_demo FILE=seeds/sponsors/sponsor_demo/mappings.yaml
echo.
goto :eof

:install
poetry install --no-interaction
goto :eof

:up
docker compose up --build -d
echo   API: %API_URL%/docs
echo   SFTPGo: run  make.bat load  to copy input_files\by_study into the SFTP tree (not run by up).
goto :eof

:load
docker compose --profile bootstrap run --rm sftpgo_bootstrap
if errorlevel 1 exit /b 1
goto :eof

:down
docker compose down -v --remove-orphans
goto :eof

:restart
call :down
call :up
goto :eof

:logs
docker compose logs -f
goto :eof

:migrate
poetry run alembic -x schema=%SPONSOR% upgrade head
goto :eof

:seed-sponsor
poetry run python scripts/seed_sponsor.py --sponsor %SPONSOR% --file "%SEED_FILE%"
if errorlevel 1 exit /b 1
goto :eof

:health
curl -s %API_URL%/health | python -m json.tool
goto :eof

:tf-init
pushd terraform
terraform init
popd
goto :eof

:tf-apply
pushd terraform
if exist local.tfvars (
  terraform apply -var-file=local.tfvars -auto-approve
) else (
  terraform apply -auto-approve
)
popd
goto :eof

:tf-destroy
pushd terraform
terraform destroy -auto-approve
popd
goto :eof

:localstack-full-print-env
pushd terraform
terraform output -raw state_machine_arn
if errorlevel 1 (
  popd
  echo Run make tf-apply first.
  exit /b 1
)
popd
echo   CMD: set SFN_STATE_MACHINE_ARN=^<paste ARN from line above^>
goto :eof

:localstack-full-up
cd /d "%~dp0"
if not exist terraform\local.tfvars (
  echo Create terraform\local.tfvars ^(copy terraform\local.tfvars.example^)
  exit /b 1
)
docker compose up --build -d
call :tf-init
call :tf-apply
pushd terraform
for /f "usebackq delims=" %%a in (`terraform output -raw state_machine_arn 2^>nul`) do set SFN_STATE_MACHINE_ARN=%%a
popd
if "!SFN_STATE_MACHINE_ARN!"=="" (
  echo state_machine_arn is empty. LocalStack Community skips ECS/SFN — use make up for in-process mode, or LocalStack Pro with localstack_skip_ecs_and_sfn=false.
  exit /b 1
)
docker compose -f docker-compose.yml -f docker-compose.localstack-full.yml up --build -d
echo   %API_URL%/docs — POST /ingest 202 + execution ARN
goto :eof

:localstack-full-down
cd /d "%~dp0"
pushd terraform
if exist local.tfvars (
  terraform destroy -var-file=local.tfvars -auto-approve
) else (
  terraform destroy -auto-approve
)
popd
docker compose -f docker-compose.yml -f docker-compose.localstack-full.yml down -v --remove-orphans 2>nul
docker compose down -v --remove-orphans
if exist terraform\terraform.tfstate del /f /q terraform\terraform.tfstate
if exist terraform\terraform.tfstate.backup del /f /q terraform\terraform.tfstate.backup
if exist terraform\.terraform.tfstate.lock.info del /f /q terraform\.terraform.tfstate.lock.info
goto :eof

:lint
poetry run ruff check src\
if errorlevel 1 exit /b 1
poetry run mypy src\
if errorlevel 1 exit /b 1
goto :eof

:fmt
poetry run ruff format src\
if errorlevel 1 exit /b 1
poetry run ruff check --fix src\
if errorlevel 1 exit /b 1
goto :eof

:test
set MODIN_CPUS=1
poetry run pytest
goto :eof

:aws-login
for /f %%a in ('aws sts get-caller-identity --query Account --output text 2^>nul') do set AWS_ACCOUNT_ID=%%a
if "%AWS_ACCOUNT_ID%"=="" (
  echo aws sts get-caller-identity failed
  exit /b 1
)
set ECR_URI=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/edc-ingestion-platform
aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %ECR_URI%
goto :eof

:aws-build
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do set IMAGE_TAG=%%h
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
docker build -t edc-ingestion-platform:!IMAGE_TAG! -t edc-ingestion-platform:latest .
goto :eof

:aws-push
call :aws-login
call :aws-build
for /f %%a in ('aws sts get-caller-identity --query Account --output text 2^>nul') do set AWS_ACCOUNT_ID=%%a
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do set IMAGE_TAG=%%h
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
set ECR_URI=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/edc-ingestion-platform
docker tag edc-ingestion-platform:!IMAGE_TAG! %ECR_URI%:!IMAGE_TAG!
docker tag edc-ingestion-platform:latest %ECR_URI%:latest
docker push %ECR_URI%:!IMAGE_TAG!
docker push %ECR_URI%:latest
echo   %ECR_URI%:!IMAGE_TAG!
goto :eof

:aws-tf-init
pushd terraform
terraform init -reconfigure
popd
goto :eof

:aws-tf-apply
set AWSVF=aws.tfvars
if exist terraform\aws.%ENV%.tfvars set AWSVF=aws.%ENV%.tfvars
for /f %%a in ('aws sts get-caller-identity --query Account --output text 2^>nul') do set AWS_ACCOUNT_ID=%%a
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do set IMAGE_TAG=%%h
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
set ECR_URI=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/edc-ingestion-platform
pushd terraform
terraform apply -var-file=%AWSVF% -var="worker_image=%ECR_URI%:!IMAGE_TAG!" -var="publisher_image=%ECR_URI%:!IMAGE_TAG!"
popd
goto :eof

:aws-tf-destroy
set AWSVF=aws.tfvars
if exist terraform\aws.%ENV%.tfvars set AWSVF=aws.%ENV%.tfvars
for /f %%a in ('aws sts get-caller-identity --query Account --output text 2^>nul') do set AWS_ACCOUNT_ID=%%a
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do set IMAGE_TAG=%%h
if "!IMAGE_TAG!"=="" set IMAGE_TAG=latest
set ECR_URI=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com/edc-ingestion-platform
pushd terraform
terraform apply -destroy -var-file=%AWSVF% -var="worker_image=%ECR_URI%:!IMAGE_TAG!" -var="publisher_image=%ECR_URI%:!IMAGE_TAG!"
popd
goto :eof

:aws-migrate
if "%RDS_URL%"=="" (
    echo Usage: make aws-migrate RDS_URL=postgresql://...  ^(optional: SPONSOR=^)
    exit /b 1
)
set DATABASE_URL=%RDS_URL%
poetry run alembic -x schema=%SPONSOR% upgrade head
goto :eof

:aws-trigger
for /f %%s in ('cd terraform ^&^& terraform output -raw state_machine_arn 2^>nul') do set SFN_ARN=%%s
aws stepfunctions start-execution --state-machine-arn %SFN_ARN% --input "{\"study_id\":\"%STUDY_ID%\",\"sponsor_id\":\"%SPONSOR_ID%\"}" --region %AWS_REGION% | python -m json.tool
goto :eof

:aws-upload
if "%FILE%"=="" (
    echo Usage: make aws-upload FILE=path\to\file.csv
    exit /b 1
)
aws s3 cp %FILE% s3://edc-raw-layer/%SOURCE_FILE% --region %AWS_REGION%
goto :eof

:clean
for /d /r %%d in (__pycache__) do @if exist "%%d" rd /s /q "%%d"
for /d /r %%d in (.pytest_cache) do @if exist "%%d" rd /s /q "%%d"
for /d /r %%d in (.mypy_cache) do @if exist "%%d" rd /s /q "%%d"
for /d /r %%d in (.ruff_cache) do @if exist "%%d" rd /s /q "%%d"
del /s /q *.pyc 2>nul
echo Cleaned.
goto :eof
