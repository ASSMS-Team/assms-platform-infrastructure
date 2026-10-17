[CmdletBinding()]
param([int]$TimeoutSeconds = 600)

$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Start Docker Desktop and wait for the Linux engine, then retry.' }
    if (-not (Test-Path -LiteralPath '.env')) {
        $aseRandomBytes = New-Object byte[] 32
        $aseRng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $aseRng.GetBytes($aseRandomBytes) } finally { $aseRng.Dispose() }
        $aseDbPassword = -join ($aseRandomBytes | ForEach-Object { $_.ToString('x2') })
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), "SONAR_DB_PASSWORD=$aseDbPassword`n")
        Write-Host 'Created private database configuration.'
    }
    & docker compose --env-file .env -f compose.yaml config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose configuration validation failed.' }
    & docker compose --env-file .env -f compose.yaml up -d
    if ($LASTEXITCODE -ne 0) { throw 'SonarQube container startup failed. Inspect docker compose logs.' }
    $aseDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Write-Host 'Waiting for SonarQube to report UP...'
    while ((Get-Date) -lt $aseDeadline) {
        $aseStatus = $null
        try {
            $aseStatus = Invoke-RestMethod 'http://127.0.0.1:9000/api/system/status' -TimeoutSec 5
        } catch { }
        if ($aseStatus -and $aseStatus.status -eq 'UP') {
            Write-Host "SonarQube $($aseStatus.version) is UP at http://localhost:9000"
            & (Join-Path $PSScriptRoot 'Initialize-SonarQube.ps1')
            return
        }
        if ($aseStatus -and $aseStatus.status -eq 'DB_MIGRATION_NEEDED') {
            throw 'This image needs a database upgrade. Back up PostgreSQL, then complete the upgrade at http://localhost:9000/setup before retrying.'
        }
        Start-Sleep -Seconds 5
    }
    throw 'SonarQube did not become UP before the timeout. Inspect docker compose logs sonarqube.'
} finally { Pop-Location }
