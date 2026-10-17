[CmdletBinding()]
param(
    [ValidateRange(0, 100)][double]$MinimumCoverage = 35,
    [ValidateRange(0, 100)][double]$MaximumDuplication = 10
)

$ErrorActionPreference = 'Stop'
$runs = Join-Path $PSScriptRoot '.local/analysis-runs'
if (-not (Test-Path -LiteralPath $runs)) { throw 'No analysis run exists.' }
$latest = Get-ChildItem -LiteralPath $runs -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latest) { throw 'No analysis run exists.' }
$report = Get-Content -LiteralPath (Join-Path $latest.FullName 'summary.json') -Raw | ConvertFrom-Json
if (-not $report.allAnalysesSucceeded) { throw 'One or more analyses failed.' }
if (-not $report.allQualityGatesPassed) { throw 'One or more SonarQube quality gates failed.' }

$failures = @()
foreach ($entry in $report.projects.PSObject.Properties) {
    $coverage = 0.0
    $duplication = 0.0
    if (-not [double]::TryParse([string]$entry.Value.metrics.coverage, [ref]$coverage)) {
        $failures += "$($entry.Name): coverage is missing"
        continue
    }
    if (-not [double]::TryParse([string]$entry.Value.metrics.duplicated_lines_density, [ref]$duplication)) {
        $failures += "$($entry.Name): duplication is missing"
        continue
    }
    Write-Output "$($entry.Name): coverage $coverage%; duplication $duplication%."
    if ($coverage -lt $MinimumCoverage) { $failures += "$($entry.Name): coverage below $MinimumCoverage%" }
    if ($duplication -gt $MaximumDuplication) { $failures += "$($entry.Name): duplication above $MaximumDuplication%" }
}
if ($failures.Count) { throw ($failures -join '; ') }
Write-Output "ASE metric floor passed: coverage >= $MinimumCoverage%, duplication <= $MaximumDuplication%."
