$ErrorActionPreference = 'Stop'
$runs = Join-Path $PSScriptRoot '.local\analysis-runs'
if (-not (Test-Path $runs)) {
    Write-Output 'No analysis summary was produced.'
    exit 0
}
$latest = Get-ChildItem $runs -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latest) {
    Write-Output 'No analysis summary was produced.'
    exit 0
}
$reportPath = Join-Path $latest.FullName 'summary.json'
if (-not (Test-Path $reportPath)) { exit 0 }
$report = Get-Content $reportPath -Raw | ConvertFrom-Json
$lines = @(
    '## ASE code quality',
    '',
    "Analysis succeeded: $($report.allAnalysesSucceeded). Quality gates passed: $($report.allQualityGatesPassed).",
    '',
    '| Repository | Tests passed | Coverage | Gate | Status |',
    '|---|---:|---:|---|---|'
)
foreach ($entry in $report.projects.PSObject.Properties) {
    $item = $entry.Value
    $testCount = if ($item.tests) { $item.tests.passed } else { '-' }
    $coverage = if ($item.metrics -and $item.metrics.coverage) { "$($item.metrics.coverage)%" } else { '-' }
    $gate = if ($item.qualityGate) { $item.qualityGate } else { '-' }
    $lines += "| $($entry.Name) | $testCount | $coverage | $gate | $($item.status) |"
}
if ($env:GITHUB_STEP_SUMMARY) {
    $lines | Add-Content $env:GITHUB_STEP_SUMMARY
}
$lines | Write-Output
