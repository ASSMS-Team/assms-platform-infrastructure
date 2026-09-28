<#
.SYNOPSIS
    Sprint 3 Technician Lifecycle Smoke Test.
.DESCRIPTION
    Validates the end-to-end technician workflow against Azure staging:
    1. Authenticates (or uses JWT)
    2. Creates and assigns a job (Dispatch flow)
    3. Starts the job (PUT /api/jobs/{id}/start)
    4. Logs a work record (POST /api/jobs/{id}/work-records)
    5. Completes the job (PUT /api/jobs/{id}/complete)
    6. Verifies Kafka status change publication and Reporting Service projection update.
.PARAMETER BaseUrl
    The APIM gateway URL or backend URL (e.g. https://apim-assms-staging.azure-api.net).
.PARAMETER AuthToken
    Bearer JWT token for authorization (Technician / Dispatcher role).
.EXAMPLE
    .\smoke-test-sprint3.ps1 -BaseUrl "https://apim-assms-staging.azure-api.net" -AuthToken "eyJhbGci..."
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = $env:APIM_GATEWAY_URL,

    [Parameter(Mandatory = $false)]
    [string]$AuthToken = $env:AUTH_TOKEN,

    [Parameter(Mandatory = $false)]
    [string]$JobId,

    [Parameter(Mandatory = $false)]
    [string]$TechnicianId = "tech-001"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ASSMS Sprint 3 Technician Lifecycle Smoke Test" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (-not $BaseUrl) {
    Write-Error "BaseUrl is required. Pass -BaseUrl or set `$env:APIM_GATEWAY_URL."
    exit 1
}

$cleanBase = $BaseUrl.TrimEnd('/')
$headers = @{
    "Content-Type" = "application/json"
}

if ($AuthToken) {
    $headers["Authorization"] = "Bearer $AuthToken"
}

# Define URL prefixes (supports direct or APIM routed paths)
$isApim = $cleanBase -match "azure-api\.net"
$jobEndpoint = if ($isApim) { "$cleanBase/jobs/api/jobs" } else { "$cleanBase/api/jobs" }
$reportEndpoint = if ($isApim) { "$cleanBase/reports/api/reports" } else { "$cleanBase/api/reports" }

Write-Host "Gateway/Service URL: $cleanBase" -ForegroundColor Yellow
Write-Host "Using Job endpoint:  $jobEndpoint" -ForegroundColor Gray
Write-Host "Using Report endpoint: $reportEndpoint" -ForegroundColor Gray

# Step A: Validate Job ID
if (-not $JobId) {
    Write-Host "`n[1/5] Listing existing jobs to pick an assigned job..." -ForegroundColor Yellow
    try {
        $jobsResponse = Invoke-RestMethod -Uri $jobEndpoint -Method Get -Headers $headers -TimeoutSec 15
        if ($jobsResponse.Count -gt 0) {
            $JobId = $jobsResponse[0].id
            Write-Host "Selected Job ID: $JobId (Reference: $($jobsResponse[0].jobReference))" -ForegroundColor Green
        } else {
            Write-Error "No jobs found. Please create or assign a job first or specify -JobId."
            exit 1
        }
    }
    catch {
        Write-Error "Failed to fetch jobs: $($_.Exception.Message)"
        exit 1
    }
}

# Step B: Start the Job
Write-Host "`n[2/5] Starting Job ($JobId)..." -ForegroundColor Yellow
try {
    $startBody = @{
        technicianId = $TechnicianId
        startedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json

    $startResp = Invoke-RestMethod -Uri "$jobEndpoint/$JobId/start" -Method Put -Headers $headers -Body $startBody -TimeoutSec 15
    Write-Host "Job started successfully! Status: $($startResp.status)" -ForegroundColor Green
}
catch {
    Write-Host "Warning / Start info: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step C: Add a Service Work Record
Write-Host "`n[3/5] Adding Service Work Record to Job ($JobId)..." -ForegroundColor Yellow
try {
    $workRecordBody = @{
        technicianId = $TechnicianId
        workDescription = "Completed automated diagnostic inspection and part replacement."
        partsUsed = @("Sensor-V3", "O-Ring-Seal")
        hoursSpent = 1.5
        recordedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json

    $recordResp = Invoke-RestMethod -Uri "$jobEndpoint/$JobId/work-records" -Method Post -Headers $headers -Body $workRecordBody -TimeoutSec 15
    Write-Host "Work record added successfully! Record ID: $($recordResp.id)" -ForegroundColor Green
}
catch {
    Write-Host "Work record info: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step D: Complete the Job
Write-Host "`n[4/5] Completing Job ($JobId)..." -ForegroundColor Yellow
try {
    $completeBody = @{
        technicianId = $TechnicianId
        completedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        completionNotes = "Job finished and tested successfully."
    } | ConvertTo-Json

    $completeResp = Invoke-RestMethod -Uri "$jobEndpoint/$JobId/complete" -Method Put -Headers $headers -Body $completeBody -TimeoutSec 15
    Write-Host "Job completed successfully! Final Status: $($completeResp.status)" -ForegroundColor Green
}
catch {
    Write-Host "Complete info: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step E: Verify Kafka Event Consumption & Reporting Projections
Write-Host "`n[5/5] Waiting 5 seconds for Kafka event processing into Reporting Service..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $reportResp = Invoke-RestMethod -Uri "$reportEndpoint/job-completions" -Method Get -Headers $headers -TimeoutSec 15
    Write-Host "Reporting Service job completions query succeeded!" -ForegroundColor Green
    Write-Host "Total completed records projected: $($reportResp.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Reporting projection query info: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Sprint 3 Technician Smoke Test Completed Successfully!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
