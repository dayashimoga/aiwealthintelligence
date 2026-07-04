<#
.SYNOPSIS
    WealthAI Complete Setup Script
.DESCRIPTION
    Master setup script that initializes the entire project:
    1. Creates Python virtual environment with all backend deps
    2. Runs backend tests
    3. Sets up Flutter frontend
    4. Optionally starts Docker services
    
    NOTHING is installed to the system — all isolated in venv/docker.
.USAGE
    .\scripts\setup.ps1              # Full setup
    .\scripts\setup.ps1 -BackendOnly # Backend only
    .\scripts\setup.ps1 -DockerOnly  # Docker services only
#>

param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$DockerOnly
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host @"

 __        __         _ _   _      _    ___ 
 \ \      / /__  __ _| | |_| |__  / \  |_ _|
  \ \ /\ / / _ \/ _` | | __| '_ \/ _ \  | | 
   \ V  V /  __/ (_| | | |_| | |/ ___ \ | | 
    \_/\_/ \___|\__,_|_|\__|_| /_/   \_\___|
                                              
    AI Wealth Intelligence Platform
    Setup Script (Fully Isolated)

"@ -ForegroundColor Magenta

# ==========================================
# Backend Setup (Virtual Environment)
# ==========================================
if (-not $FrontendOnly -and -not $DockerOnly) {
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host "  BACKEND SETUP" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    $ApiDir = Join-Path $ProjectRoot "services\api"
    $VenvDir = Join-Path $ApiDir ".venv"
    $VenvPython = Join-Path $VenvDir "Scripts\python.exe"
    $VenvPip = Join-Path $VenvDir "Scripts\pip.exe"

    # Check Python
    try {
        $pyVersion = python --version 2>&1
        Write-Host "  Python: $pyVersion" -ForegroundColor Gray
    } catch {
        Write-Host "  ERROR: Python not found. Install from https://python.org" -ForegroundColor Red
        if (-not $BackendOnly) { goto frontend }
        exit 1
    }

    # Create venv
    if (-not (Test-Path $VenvPython)) {
        Write-Host "  Creating virtual environment..." -ForegroundColor Yellow
        python -m venv $VenvDir
        Write-Host "  Virtual environment created" -ForegroundColor Green
    } else {
        Write-Host "  Virtual environment exists" -ForegroundColor Green
    }

    # Install deps
    Write-Host "  Installing dependencies (this may take a few minutes)..." -ForegroundColor Yellow
    & $VenvPip install --upgrade pip --quiet 2>&1 | Out-Null
    & $VenvPip install -e "$ApiDir[dev]" --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Some dependencies may have failed" -ForegroundColor DarkYellow
    }

    # Create .env from example if not exists
    $envFile = Join-Path $ProjectRoot ".env"
    $envExample = Join-Path $ProjectRoot ".env.example"
    if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
        Copy-Item $envExample $envFile
        Write-Host "  Created .env from .env.example" -ForegroundColor Green
    }

    # Run tests
    Write-Host "  Running tests..." -ForegroundColor Yellow
    $env:APP_ENV = "testing"
    $env:DATABASE_URL = "sqlite+aiosqlite:///:memory:"
    $env:JWT_SECRET_KEY = "test-secret-key"
    $env:AI_API_KEY = "test-key"

    Push-Location $ApiDir
    & $VenvPython -m pytest --tb=short -q 2>&1
    $testResult = $LASTEXITCODE
    Pop-Location

    if ($testResult -eq 0) {
        Write-Host "  Tests: PASSED" -ForegroundColor Green
    } else {
        Write-Host "  Tests: SOME FAILURES (exit: $testResult)" -ForegroundColor DarkYellow
    }

    Write-Host ""
}

# ==========================================
# Frontend Setup (Flutter)
# ==========================================
:frontend
if (-not $BackendOnly -and -not $DockerOnly) {
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host "  FRONTEND SETUP" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    $AppDir = Join-Path $ProjectRoot "apps\web"

    try {
        $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
        Write-Host "  Flutter: $flutterVersion" -ForegroundColor Gray

        Push-Location $AppDir
        Write-Host "  Getting dependencies..." -ForegroundColor Yellow
        flutter pub get 2>&1 | Out-Null
        Write-Host "  Dependencies resolved" -ForegroundColor Green
        Pop-Location
    } catch {
        Write-Host "  Flutter SDK not found (install from https://flutter.dev)" -ForegroundColor DarkYellow
        Write-Host "  Skipping frontend setup" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# ==========================================
# Docker Setup
# ==========================================
if ($DockerOnly -or (-not $BackendOnly -and -not $FrontendOnly)) {
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host "  DOCKER SERVICES" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    try {
        docker --version 2>&1 | Out-Null
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Push-Location $ProjectRoot
            Write-Host "  Starting Docker services..." -ForegroundColor Yellow
            docker compose up -d 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Docker services running" -ForegroundColor Green
            }
            Pop-Location
        } else {
            Write-Host "  Docker daemon not running — skipping" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "  Docker not installed — skipping" -ForegroundColor DarkGray
        Write-Host "  Install from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Gray
    }
}

# ==========================================
# Summary
# ==========================================
Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host ""
Write-Host "  Quick Start Commands:" -ForegroundColor White
Write-Host "    Backend:  .\scripts\test-backend.ps1" -ForegroundColor Gray
Write-Host "    Frontend: .\scripts\build-frontend.ps1 -Run" -ForegroundColor Gray
Write-Host "    Docker:   .\scripts\run-docker.ps1" -ForegroundColor Gray
Write-Host "    Tests:    .\scripts\test-backend.ps1 -SkipInstall" -ForegroundColor Gray
Write-Host ""
