[CmdletBinding()]
param(
    [ValidateSet('all', 'job', 'customer', 'dispatch', 'reporting', 'frontend')]
    [string]$Project = 'all',
    [string]$DotnetPath,
    [switch]$UseEnvironmentToken,
    [switch]$FailOnQualityGate,
    [switch]$DispatchIntegrationDatabase
)

$ErrorActionPreference = 'Stop'
$asePython = (Get-Command python -ErrorAction Stop).Source
$aseArguments = @((Join-Path $PSScriptRoot 'analyze.py'), '--project', $Project)
if ($DotnetPath) { $aseArguments += @('--dotnet', $DotnetPath) }
if ($UseEnvironmentToken) { $aseArguments += '--use-environment-token' }
if ($FailOnQualityGate) { $aseArguments += '--fail-on-quality-gate' }
if ($DispatchIntegrationDatabase) { $aseArguments += '--dispatch-integration-database' }
& $asePython @aseArguments
exit $LASTEXITCODE
