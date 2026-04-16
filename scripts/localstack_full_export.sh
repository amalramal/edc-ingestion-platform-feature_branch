#!/usr/bin/env sh
# Print shell exports for localstack_full compose mode (run from repo root after terraform apply).
set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ARN=$(cd "$ROOT/terraform" && terraform output -raw state_machine_arn 2>/dev/null) || true
if [ -z "$ARN" ]; then
  echo "# No state_machine_arn in terraform output — run: cd terraform && terraform apply" >&2
  exit 1
fi
echo "export SFN_STATE_MACHINE_ARN=$ARN"
