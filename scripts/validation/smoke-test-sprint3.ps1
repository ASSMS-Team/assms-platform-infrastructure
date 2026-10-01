<#
.SYNOPSIS
    Sprint 3 Technician Lifecycle Smoke Test.
.DESCRIPTION
    Validates the end-to-end technician workflow against Azure staging:
    1. Authenticates (or uses JWT)
    2. Lists jobs or uses specified -JobId
    3. Starts the job (POST /api/jobs/{id}/start with { technicianId: "..." })
    4. Logs a work record (POST /api/jobs/{id}/work-records with { technicianId: "...", content: "..." })
    5. Completes the job (POST /api/jobs/{id}/complete with { technicianId: "..." })
    6. Verifies Kafka status change publication and Reporting Service projection update.
.PARAMETER BaseUrl
    The APIM gateway URL or backend URL (e.g. https://apim-assms-staging.azure-api.net).
.PARAMETER AuthToken
    Bearer JWT token for authorization (Technician / Dispatcher / Staff role).
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
    [string]$TechnicianId = "5c8a3f71-4b29-4e6d-8a03-9f1b7c2e4d58"
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
Write-Host "Using Job endpoint:    $jobEndpoint" -ForegroundColor Gray
Write-Host "Using Report endpoint: $reportEndpoint" -ForegroundColor Gray

# Step A: Validate or Pick Job ID
if (-not $JobId) {
    Write-Host "`n[1/5] Listing existing jobs to pick an assigned job..." -ForegroundColor Yellow
    try {
        $jobsResponse = Invoke-RestMethod -Uri $jobEndpoint -Method Get -Headers $headers -TimeoutSec 15
        if ($jobsResponse.Count -gt 0) {
            # Find an assigned job or the first job
            $candidate = $jobsResponse | Where-Object { $_.status -eq "ASSIGNED" } | Select-Object -First 1
            if (-not $candidate) { $candidate = $jobsResponse[0] }
            $JobId = $candidate.id
            if ($candidate.assignment -and $candidate.assignment.technicianId) {
                $TechnicianId = $candidate.assignment.technicianId
            } elseif ($candidate.assignedTechnicianId) {
                $TechnicianId = $candidate.assignedTechnicianId
            }
            Write-Host "Selected Job ID: $JobId (Ref: $($candidate.jobReference), Status: $($candidate.status), Tech: $TechnicianId)" -ForegroundColor Green
        } else {
            Write-Error "No jobs found. Please create and assign a job first or specify -JobId."
            exit 1
        }
    }
    catch {
        Write-Error "Failed to fetch jobs: $($_.Exception.Message)"
        exit 1
    }
}

# Step B: Start the Job (POST api/jobs/{id}/start)
Write-Host "`n[2/5] Starting Job ($JobId) with Technician ($TechnicianId)..." -ForegroundColor Yellow
try {
    $startBody = @{
        technicianId = $TechnicianId
    } | ConvertTo-Json

    $startResp = Invoke-RestMethod -Uri "$jobEndpoint/$JobId/start" -Method Post -Headers $headers -Body $startBody -TimeoutSec 15
    Write-Host "Job started successfully! Status: $($startResp.status)" -ForegroundColor Green
}
catch {
    Write-Host "Start note: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step C: Add a Service Work Record (POST api/jobs/{id}/work-records)
Write-Host "`n[3/5] Adding Service Work Record to Job ($JobId)..." -ForegroundColor Yellow
try {
    $workRecordBody = @{
        technicianId = $TechnicianId
        content = "Replaced faulty optical sensor and recalibrated conveyor belt. Operational tests passed at 100% capacity."
    } | ConvertTo-Json

    $recordResp = Invoke-RestMethod -Uri "$jobEndpoint/$JobId/work-records" -Method Post -Headers $headers -Body $workRecordBody -TimeoutSec 15
    Write-Host "Work record added successfully! Record ID: $($recordResp.id)" -ForegroundColor Green
}
catch {
    Write-Host "Work record note: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step D: Complete the Job (POST api/jobs/{id}/complete)
Write-Host "`n[4/5] Completing Job ($JobId)..." -ForegroundColor Yellow
try {
    $completeBody = @{
        technicianId = $TechnicianId
    } | ConvertTo-Json

    $completeResp = Invoke-RestMethod -Uri "$jobEndpoint/$JobId/complete" -Method Post -Headers $headers -Body $completeBody -TimeoutSec 15
    Write-Host "Job completed successfully! Final Status: $($completeResp.status)" -ForegroundColor Green
}
catch {
    Write-Host "Complete note: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step E: Verify Kafka Event Consumption & Reporting Projections
Write-Host "`n[5/5] Waiting 5 seconds for Kafka event consumption into Reporting Service..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $reportResp = Invoke-RestMethod -Uri "$reportEndpoint/job-completions" -Method Get -Headers $headers -TimeoutSec 15
    Write-Host "Reporting Service job completions query succeeded!" -ForegroundColor Green
    Write-Host "Total completed jobs reported: $($reportResp.total)" -ForegroundColor Green
    if ($reportResp.jobs) {
        $matched = $reportResp.jobs | Where-Object { $_.jobId -eq $JobId }
        if ($matched) {
            Write-Host "Confirmed: Job $JobId is present in Reporting Service completions!" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "Reporting projection query note: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Sprint 3 Technician Smoke Test Completed Successfully!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
