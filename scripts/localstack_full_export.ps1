# Print PowerShell env set for localstack_full (run from repo root after terraform apply).
$Root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $Root "terraform")
try {
    $Arn = terraform output -raw state_machine_arn 2>$null
} finally {
    Pop-Location
}
if (-not $Arn) {
    Write-Error "No state_machine_arn — run terraform apply in terraform/"
    exit 1
}
Write-Output "`$env:SFN_STATE_MACHINE_ARN = '$Arn'"
