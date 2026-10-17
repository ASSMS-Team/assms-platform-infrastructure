$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$expected = @(
    'assms-platform-infrastructure',
    'assms-job-service',
    'assms-customer-asset-service',
    'assms-dispatch-service',
    'assms-reporting-service',
    'assms-frontend'
)

foreach ($name in $expected) {
    if (-not (Test-Path (Join-Path $workspace $name))) {
        throw "Repository checkout missing: $name"
    }
}
foreach ($command in 'python', 'git', 'node', 'npm', 'java', 'dotnet') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $command"
    }
}
if ($env:SONAR_TOKEN) {
    if (-not $env:SONAR_HOST_URL) { throw 'SONAR_HOST_URL is required when using SONAR_TOKEN.' }
    $serverUrl = $env:SONAR_HOST_URL
} else {
    $credentialPath = Join-Path $PSScriptRoot '.local/admin-credentials.json'
    if (-not (Test-Path -LiteralPath $credentialPath)) { throw 'SonarQube credentials are missing. Start-SonarQube.ps1 must initialize this runner first.' }
    $serverUrl = (Get-Content -LiteralPath $credentialPath -Raw | ConvertFrom-Json).url
}
$status = Invoke-RestMethod -Uri ($serverUrl.TrimEnd('/') + '/api/system/status') -TimeoutSec 15
if ($status.status -ne 'UP') { throw "SonarQube is $($status.status); start it before dispatching CI." }

Write-Output 'Six repository checkouts, required tools, SonarQube credentials and server status are present.'
