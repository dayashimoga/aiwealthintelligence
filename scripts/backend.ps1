#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Backend development automation script using Python virtual environment.
    Creates venv, installs deps, runs the requested command, and optionally tears down.

.DESCRIPTION
    Usage:
      .\scripts\backend.ps1 verify      # Verify app loads
      .\scripts\backend.ps1 test        # Run pytest with coverage
      .\scripts\backend.ps1 lint        # Run ruff linter
      .\scripts\backend.ps1 format      # Run ruff formatter
      .\scripts\backend.ps1 serve       # Start uvicorn dev server
      .\scripts\backend.ps1 migrate     # Run alembic migrations
      .\scripts\backend.ps1 shell       # Open Python shell in venv
      .\scripts\backend.ps1 setup       # Just create/update venv
      .\scripts\backend.ps1 teardown    # Remove venv completely
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("verify","test","lint","format","serve","migrate","shell","setup","teardown")]
    [string]$Command = "verify"
)

$ErrorActionPreference = "Stop"
$ApiDir = Join-Path $PSScriptRoot ".." "services" "api"
$VenvDir = Join-Path $ApiDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts" "python.exe"
$VenvPip = Join-Path $VenvDir "Scripts" "pip.exe"

function Ensure-Venv {
    if (-not (Test-Path $VenvPython)) {
        Write-Host ">> Creating virtual environment..." -ForegroundColor Cyan
        python -m venv $VenvDir
        & $VenvPip install --upgrade pip --quiet
        Write-Host ">> Installing dependencies..." -ForegroundColor Cyan
        & $VenvPip install -e "$ApiDir[dev]" --quiet
        Write-Host ">> Venv ready." -ForegroundColor Green
    } else {
        Write-Host ">> Venv exists at $VenvDir" -ForegroundColor DarkGray
    }
}

function Teardown-Venv {
    if (Test-Path $VenvDir) {
        Write-Host ">> Removing virtual environment..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $VenvDir
        Write-Host ">> Venv removed." -ForegroundColor Green
    } else {
        Write-Host ">> No venv to remove." -ForegroundColor DarkGray
    }
}

Push-Location $ApiDir
try {
    switch ($Command) {
        "setup" {
            Ensure-Venv
        }
        "teardown" {
            Teardown-Venv
        }
        "verify" {
            Ensure-Venv
            Write-Host ">> Verifying app loads..." -ForegroundColor Cyan
            & $VenvPython -c "from app.main import app; print('FastAPI app loaded successfully')"
        }
        "test" {
            Ensure-Venv
            Write-Host ">> Running tests with coverage..." -ForegroundColor Cyan
            $env:APP_ENV = "development"
            $env:DATABASE_URL = "sqlite+aiosqlite:///:memory:"
            $env:JWT_SECRET_KEY = "test-secret-key-for-dev"
            $env:AI_API_KEY = "test-key"
            & $VenvPython -m pytest --cov=app --cov-report=term-missing -v $args
        }
        "lint" {
            Ensure-Venv
            Write-Host ">> Running linter..." -ForegroundColor Cyan
            & $VenvPython -m ruff check .
        }
        "format" {
            Ensure-Venv
            Write-Host ">> Running formatter..." -ForegroundColor Cyan
            & $VenvPython -m ruff format .
        }
        "serve" {
            Ensure-Venv
            Write-Host ">> Starting dev server..." -ForegroundColor Cyan
            & $VenvPython -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
        }
        "migrate" {
            Ensure-Venv
            Write-Host ">> Running migrations..." -ForegroundColor Cyan
            & $VenvPython -m alembic upgrade head
        }
        "shell" {
            Ensure-Venv
            & $VenvPython
        }
    }
} finally {
    Pop-Location
}
