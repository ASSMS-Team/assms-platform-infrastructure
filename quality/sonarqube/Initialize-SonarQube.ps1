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

# The built-in Sonar way gate checks new code. A first baseline has no new-code
# period, so it can report OK without evaluating any condition. Use an explicit
# overall-code gate for this ASE baseline instead.
$aseGateName = 'ASSMS ASE baseline'
$aseGateConditions = @(
    @{ metric = 'coverage'; op = 'LT'; error = '35' },
    @{ metric = 'duplicated_lines_density'; op = 'GT'; error = '10' }
)
$aseGates = Invoke-AseSonarApi '/api/qualitygates/list'
if (@($aseGates.qualitygates | Where-Object name -eq $aseGateName).Count -eq 0) {
    Invoke-AseSonarApi '/api/qualitygates/create' 'Post' @{ name = $aseGateName } | Out-Null
    Write-Host "Created quality gate: $aseGateName"
}
$aseGatePath = '/api/qualitygates/show?name=' + [Uri]::EscapeDataString($aseGateName)
foreach ($aseExpected in $aseGateConditions) {
    $aseGate = Invoke-AseSonarApi $aseGatePath
    $aseMatches = @($aseGate.conditions | Where-Object metric -eq $aseExpected.metric)
    if ($aseMatches.Count -gt 1) { throw "Duplicate $($aseExpected.metric) quality-gate conditions." }
    if ($aseMatches.Count -eq 0) {
        Invoke-AseSonarApi '/api/qualitygates/create_condition' 'Post' @{
            gateName = $aseGateName; metric = $aseExpected.metric; op = $aseExpected.op; error = $aseExpected.error
        } | Out-Null
    } elseif ($aseMatches[0].op -ne $aseExpected.op -or [string]$aseMatches[0].error -ne $aseExpected.error) {
        Invoke-AseSonarApi '/api/qualitygates/update_condition' 'Post' @{
            id = $aseMatches[0].id; metric = $aseExpected.metric; op = $aseExpected.op; error = $aseExpected.error
        } | Out-Null
    }
}
$aseGate = Invoke-AseSonarApi $aseGatePath
foreach ($aseExpected in $aseGateConditions) {
    $aseMatches = @($aseGate.conditions | Where-Object {
        $_.metric -eq $aseExpected.metric -and $_.op -eq $aseExpected.op -and [string]$_.error -eq $aseExpected.error
    })
    if ($aseMatches.Count -ne 1) { throw "Quality gate condition $($aseExpected.metric) was not configured." }
}
foreach ($aseProject in $aseSelectedProjects) {
    Invoke-AseSonarApi '/api/qualitygates/select' 'Post' @{
        gateName = $aseGateName; projectKey = $aseProject.key
    } | Out-Null
    $aseProjectGate = Invoke-AseSonarApi ('/api/qualitygates/get_by_project?project=' + [Uri]::EscapeDataString($aseProject.key))
    if ($aseProjectGate.qualityGate.name -ne $aseGateName) {
        throw "Quality gate was not assigned to $($aseProject.key)."
    }
}
$aseStatus = Invoke-RestMethod 'http://127.0.0.1:9000/api/system/status' -TimeoutSec 10
@{
    verifiedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    status = $aseStatus.status
    version = $aseStatus.version
    administratorLoginVerified = $true
    projects = @($aseSelectedProjects | Select-Object key, name)
    qualityGate = @{ name = $aseGateName; conditions = $aseGateConditions }
    analysisExecuted = $false
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $aseLocalDirectory 'setup-verification.json') -Encoding UTF8
Write-Host "Administrator login verified; five ASE projects are ready. Credentials: $aseCredentialsPath"
Write-Host 'No source analysis has run yet.'
