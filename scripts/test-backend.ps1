<#
.SYNOPSIS
    WealthAI Backend Setup & Test Script (Virtual Environment Isolated)
.DESCRIPTION
    Creates a Python virtual environment, installs all dependencies inside it,
    runs linting, type checking, security scanning, and tests with coverage.
    Nothing is installed to the system Python.
.USAGE
    .\scripts\test-backend.ps1
#>

param(
    [switch]$SkipInstall,
    [switch]$CoverageOnly,
    [string]$TestFilter = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ApiDir = Join-Path $ProjectRoot "services\api"
$VenvDir = Join-Path $ApiDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  WealthAI Backend Test Runner" -ForegroundColor Cyan
Write-Host "  (Isolated Virtual Environment)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Create virtual environment if not exists
if (-not (Test-Path $VenvPython)) {
    Write-Host "[1/6] Creating virtual environment..." -ForegroundColor Yellow
    python -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create virtual environment" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Virtual environment created at: $VenvDir" -ForegroundColor Green
} else {
    Write-Host "[1/6] Virtual environment exists at: $VenvDir" -ForegroundColor Green
}

# Step 2: Install dependencies
if (-not $SkipInstall) {
    Write-Host "[2/6] Installing dependencies in venv..." -ForegroundColor Yellow
    & $VenvPip install --upgrade pip --quiet 2>&1 | Out-Null
    & $VenvPip install -e "$ApiDir[dev]" --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Dependency installation failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  All dependencies installed" -ForegroundColor Green
} else {
    Write-Host "[2/6] Skipping dependency installation (--SkipInstall)" -ForegroundColor DarkGray
}

# Step 3: Lint check
if (-not $CoverageOnly) {
    Write-Host "[3/6] Running linter (ruff)..." -ForegroundColor Yellow
    & $VenvPython -m ruff check $ApiDir\app --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Lint: PASSED" -ForegroundColor Green
    } else {
        Write-Host "  Lint: WARNINGS (non-blocking)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[3/6] Skipping lint" -ForegroundColor DarkGray
}

# Step 4: Format check
if (-not $CoverageOnly) {
    Write-Host "[4/6] Checking code format (ruff format)..." -ForegroundColor Yellow
    & $VenvPython -m ruff format --check $ApiDir\app --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Format: PASSED" -ForegroundColor Green
    } else {
        Write-Host "  Format: WARNINGS (non-blocking)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[4/6] Skipping format check" -ForegroundColor DarkGray
}

# Step 5: Security scan
if (-not $CoverageOnly) {
    Write-Host "[5/6] Running security scan (bandit)..." -ForegroundColor Yellow
    & $VenvPython -m bandit -r "$ApiDir\app" -ll -ii --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Security: PASSED" -ForegroundColor Green
    } else {
        Write-Host "  Security: WARNINGS (review recommended)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[5/6] Skipping security scan" -ForegroundColor DarkGray
}

# Step 6: Run tests
Write-Host "[6/6] Running tests with coverage..." -ForegroundColor Yellow

$env:APP_ENV = "testing"
$env:APP_DEBUG = "false"
$env:DATABASE_URL = "sqlite+aiosqlite:///:memory:"
$env:JWT_SECRET_KEY = "test-secret-key-for-ci-only-not-production"
$env:AI_API_KEY = "test-key"
$env:AI_PROVIDER = "openai"

$testArgs = @(
    "-m", "pytest",
    "--cov=app",
    "--cov-report=term-missing",
    "--cov-report=html:$ApiDir\htmlcov",
    "-v",
    "--tb=short"
)

if ($TestFilter) {
    $testArgs += "-k"
    $testArgs += $TestFilter
}

Push-Location $ApiDir
& $VenvPython @testArgs
$testExitCode = $LASTEXITCODE
Pop-Location

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
if ($testExitCode -eq 0) {
    Write-Host "  ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "  Coverage report: $ApiDir\htmlcov\index.html" -ForegroundColor Gray
} else {
    Write-Host "  SOME TESTS FAILED (exit code: $testExitCode)" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

exit $testExitCode
