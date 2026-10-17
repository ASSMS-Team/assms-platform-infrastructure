[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & docker compose --env-file .env -f compose.yaml stop
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop the SonarQube stack.' }
    Write-Host 'SonarQube stopped. Named volumes and saved analysis are retained.'
} finally { Pop-Location }
