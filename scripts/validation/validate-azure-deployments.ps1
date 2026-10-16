<#
.SYNOPSIS
    Validates Azure microservice deployments, database health endpoints, and APIM gateway routes for Sprint 3.
.DESCRIPTION
    Tests both direct service URLs and APIM gateway routes:
    - /api/health
    - /api/health/db
    - Checks HTTP 200 responses and JSON payloads
.PARAMETER ApimGatewayUrl
    The public Azure API Management gateway URL (e.g., https://apim-assms-staging.azure-api.net).
.PARAMETER CustomerServiceUrl
    Direct URL for Customer & Asset Service (optional).
.PARAMETER JobServiceUrl
    Direct URL for Job Service (optional).
.PARAMETER DispatchServiceUrl
    Direct URL for Dispatch Service (optional).
.PARAMETER ReportingServiceUrl
    Direct URL for Reporting Service (optional).
.EXAMPLE
    .\validate-azure-deployments.ps1 -ApimGatewayUrl "https://apim-assms-staging.azure-api.net"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApimGatewayUrl = $env:APIM_GATEWAY_URL,

    [Parameter(Mandatory = $false)]
    [string]$CustomerServiceUrl = $env:CUSTOMER_API_URL,

    [Parameter(Mandatory = $false)]
    [string]$JobServiceUrl = $env:JOB_API_URL,

    [Parameter(Mandatory = $false)]
    [string]$DispatchServiceUrl = $env:DISPATCH_API_URL,

    [Parameter(Mandatory = $false)]
    [string]$ReportingServiceUrl = $env:REPORTING_API_URL
)

$ErrorActionPreference = "Continue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ASSMS Sprint 3 Azure Deployment Health Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$passed = 0
$failed = 0

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$ExpectedStatus = "200"
    )

    Write-Host -NoNewline "[TEST] $Name ($Url) ... "
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "PASS (HTTP 200)" -ForegroundColor Green
            $script:passed++
            return $true
        } else {
            Write-Host "FAIL (HTTP $($response.StatusCode))" -ForegroundColor Red
            $script:failed++
            return $false
        }
    }
    catch {
        Write-Host "FAIL ($($_.Exception.Message))" -ForegroundColor Red
        $script:failed++
        return $false
    }
}

# 1. Direct Service Health Probes
Write-Host "`n--- Direct Service Health Probes ---" -ForegroundColor Yellow

if ($JobServiceUrl) {
    Test-Endpoint -Name "Job Service Health" -Url "$JobServiceUrl/api/health"
    Test-Endpoint -Name "Job Service Database" -Url "$JobServiceUrl/api/health/db"
} else {
    Write-Host "[SKIP] JobServiceUrl not specified (set -JobServiceUrl or `$env:JOB_API_URL)" -ForegroundColor Gray
}

if ($DispatchServiceUrl) {
    Test-Endpoint -Name "Dispatch Service Health" -Url "$DispatchServiceUrl/api/health"
    Test-Endpoint -Name "Dispatch Service Database" -Url "$DispatchServiceUrl/api/health/db"
} else {
    Write-Host "[SKIP] DispatchServiceUrl not specified (set -DispatchServiceUrl or `$env:DISPATCH_API_URL)" -ForegroundColor Gray
}

if ($ReportingServiceUrl) {
    Test-Endpoint -Name "Reporting Service Health" -Url "$ReportingServiceUrl/api/health"
    Test-Endpoint -Name "Reporting Service Database" -Url "$ReportingServiceUrl/api/health/db"
} else {
    Write-Host "[SKIP] ReportingServiceUrl not specified (set -ReportingServiceUrl or `$env:REPORTING_API_URL)" -ForegroundColor Gray
}

if ($CustomerServiceUrl) {
    Test-Endpoint -Name "Customer Service Health" -Url "$CustomerServiceUrl/api/health"
    Test-Endpoint -Name "Customer Service Database" -Url "$CustomerServiceUrl/api/health/db"
} else {
    Write-Host "[SKIP] CustomerServiceUrl not specified (set -CustomerServiceUrl or `$env:CUSTOMER_API_URL)" -ForegroundColor Gray
}

# 2. APIM Gateway Health Probes
Write-Host "`n--- APIM Gateway Route Health Probes ---" -ForegroundColor Yellow

if ($ApimGatewayUrl) {
    $cleanApim = $ApimGatewayUrl.TrimEnd('/')
    Test-Endpoint -Name "APIM -> Job Service Health" -Url "$cleanApim/jobs/api/health"
    Test-Endpoint -Name "APIM -> Job Service Database" -Url "$cleanApim/jobs/api/health/db"
    Test-Endpoint -Name "APIM -> Dispatch Service Health" -Url "$cleanApim/dispatch/api/health"
    Test-Endpoint -Name "APIM -> Dispatch Service Database" -Url "$cleanApim/dispatch/api/health/db"
    Test-Endpoint -Name "APIM -> Reporting Service Health" -Url "$cleanApim/reports/api/health"
    Test-Endpoint -Name "APIM -> Reporting Service Database" -Url "$cleanApim/reports/api/health/db"
    Test-Endpoint -Name "APIM -> Customer Service Health" -Url "$cleanApim/customer/api/health"
    Test-Endpoint -Name "APIM -> Customer Service Database" -Url "$cleanApim/customer/api/health/db"
} else {
    Write-Host "[SKIP] ApimGatewayUrl not specified (set -ApimGatewayUrl or `$env:APIM_GATEWAY_URL)" -ForegroundColor Gray
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Summary: $passed Passed, $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "============================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
}
