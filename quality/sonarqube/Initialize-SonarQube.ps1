[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$aseLocalDirectory = Join-Path $PSScriptRoot '.local'
$aseCredentialsPath = Join-Path $aseLocalDirectory 'admin-credentials.json'
New-Item -ItemType Directory -Force -Path $aseLocalDirectory | Out-Null
if (-not (Test-Path -LiteralPath $aseCredentialsPath)) {
    $aseBytes = New-Object byte[] 24
    $aseRng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $aseRng.GetBytes($aseBytes) } finally { $aseRng.Dispose() }
    $asePassword = 'AsE!' + (-join ($aseBytes | ForEach-Object { $_.ToString('x2') })) + 'q9'
    @{ url = 'http://localhost:9000'; username = 'admin'; password = $asePassword } |
        ConvertTo-Json | Set-Content -LiteralPath $aseCredentialsPath -Encoding UTF8
}
$aseCredentials = Get-Content -LiteralPath $aseCredentialsPath -Raw | ConvertFrom-Json
$aseAuthBytes = [Text.Encoding]::UTF8.GetBytes("admin:$($aseCredentials.password)")
$aseHeaders = @{ Authorization = 'Basic ' + [Convert]::ToBase64String($aseAuthBytes) }
function Invoke-AseSonarApi {
    param([string]$Path, [string]$Method = 'Get', [hashtable]$Body = @{})
    Invoke-RestMethod -Uri "http://127.0.0.1:9000$Path" -Headers $aseHeaders -Method $Method -Body $Body -TimeoutSec 30
}
$aseValid = $false
try { $aseValid = (Invoke-AseSonarApi '/api/authentication/validate').valid } catch { }
if (-not $aseValid) {
    $aseDefaultHeaders = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('admin:admin')) }
    try {
        Invoke-RestMethod -Uri 'http://127.0.0.1:9000/api/users/change_password' -Method Post -Headers $aseDefaultHeaders -Body @{
            login = 'admin'; previousPassword = 'admin'; password = $aseCredentials.password
        } -TimeoutSec 30 | Out-Null
    } catch { throw 'Admin initialization failed. Keep .local/admin-credentials.json and check whether this server already has a different admin password.' }
    if (-not (Invoke-AseSonarApi '/api/authentication/validate').valid) { throw 'Administrator login verification failed.' }
    Write-Host 'Replaced the default administrator password.'
}
$aseRepositories = @('assms-customer-asset-service', 'assms-job-service', 'assms-dispatch-service', 'assms-reporting-service', 'assms-frontend')
foreach ($aseRepository in $aseRepositories) {
    $aseKey = "ase-$aseRepository"
    $aseExisting = Invoke-AseSonarApi "/api/projects/search?q=$aseRepository&ps=100"
    if (@($aseExisting.components | Where-Object key -eq $aseKey).Count -eq 0) {
        Invoke-AseSonarApi '/api/projects/create' 'Post' @{ project = $aseKey; name = $aseRepository; visibility = 'private' } | Out-Null
        Write-Host "Created empty analysis project: $aseRepository"
    }
}
$aseProjects = Invoke-AseSonarApi '/api/projects/search?ps=100'
$aseSelectedProjects = @($aseProjects.components | Where-Object { $_.key -in @($aseRepositories | ForEach-Object { "ase-$_" }) })
if ($aseSelectedProjects.Count -ne 5) { throw 'The server did not return all five expected ASE projects.' }
$aseStatus = Invoke-RestMethod 'http://127.0.0.1:9000/api/system/status' -TimeoutSec 10
@{
    verifiedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = $aseStatus.status
    version = $aseStatus.version
    administratorLoginVerified = $true
    projects = @($aseSelectedProjects | Select-Object key, name)
    analysisExecuted = $false
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $aseLocalDirectory 'setup-verification.json') -Encoding UTF8
Write-Host "Administrator login verified; five ASE projects are ready. Credentials: $aseCredentialsPath"
Write-Host 'No source analysis has run yet.'
