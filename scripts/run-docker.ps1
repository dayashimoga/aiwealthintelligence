<#
.SYNOPSIS
    WealthAI Full Stack Setup Script (Docker-based)
.DESCRIPTION
    Builds and runs the entire WealthAI stack using Docker Compose.
    No local installations required beyond Docker Desktop.
.USAGE
    .\scripts\run-docker.ps1              # Start all services
    .\scripts\run-docker.ps1 -Down        # Stop all services
    .\scripts\run-docker.ps1 -Build       # Rebuild and start
    .\scripts\run-docker.ps1 -Observability  # Include monitoring stack
#>

param(
    [switch]$Down,
    [switch]$Build,
    [switch]$Observability,
    [switch]$Logs
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  WealthAI Docker Manager" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check Docker is available
try {
    docker --version | Out-Null
} catch {
    Write-Host "ERROR: Docker is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Check Docker is running
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker daemon is not running. Start Docker Desktop first." -ForegroundColor Red
    exit 1
}

Push-Location $ProjectRoot

if ($Down) {
    Write-Host "Stopping all services..." -ForegroundColor Yellow
    docker compose down --remove-orphans
    Write-Host "All services stopped." -ForegroundColor Green
    Pop-Location
    exit 0
}

if ($Logs) {
    docker compose logs -f --tail=100
    Pop-Location
    exit 0
}

# Build and start
$composeArgs = @("compose", "up", "-d")

if ($Build) {
    $composeArgs += "--build"
}

if ($Observability) {
    $composeArgs += "--profile"
    $composeArgs += "observability"
}

Write-Host "Starting services..." -ForegroundColor Yellow
docker @composeArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n Services running:" -ForegroundColor Green
    Write-Host "  API:         http://localhost:8000" -ForegroundColor White
    Write-Host "  Swagger:     http://localhost:8000/api/docs" -ForegroundColor White
    Write-Host "  PostgreSQL:  localhost:5432" -ForegroundColor White
    Write-Host "  Redis:       localhost:6379" -ForegroundColor White
    if ($Observability) {
        Write-Host "  Prometheus:  http://localhost:9090" -ForegroundColor White
        Write-Host "  Grafana:     http://localhost:3001 (admin/admin)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  Run '.\scripts\run-docker.ps1 -Logs' to view logs" -ForegroundColor Gray
    Write-Host "  Run '.\scripts\run-docker.ps1 -Down' to stop" -ForegroundColor Gray
} else {
    Write-Host "ERROR: Failed to start services" -ForegroundColor Red
}

Pop-Location
