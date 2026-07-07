#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Flutter development automation using Docker (no local Flutter needed).

.DESCRIPTION
    Usage:
      .\scripts\flutter.ps1 analyze     # Run dart analyzer
      .\scripts\flutter.ps1 test        # Run Flutter tests
      .\scripts\flutter.ps1 build-web   # Build web (release)
      .\scripts\flutter.ps1 build-apk   # Build Android APK (debug)
      .\scripts\flutter.ps1 pub-get     # Get dependencies
      .\scripts\flutter.ps1 format      # Format code
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("analyze","test","build-web","build-apk","pub-get","format")]
    [string]$Command = "analyze"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$FlutterImage = "ghcr.io/cirruslabs/flutter:3.24.0"

function Run-Flutter {
    param([string]$Cmd)
    Write-Host ">> Running: $Cmd" -ForegroundColor Cyan
    $output = docker run --rm `
        -v "${ProjectRoot}:/app" `
        -w /app/apps/web `
        $FlutterImage `
        sh -c "$Cmd 2>&1"
    $output | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host ">> FAILED with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host ">> Done." -ForegroundColor Green
}

switch ($Command) {
    "pub-get" {
        Run-Flutter "flutter pub get"
    }
    "analyze" {
        Run-Flutter "flutter pub get && (flutter analyze --no-fatal-infos || true)"
    }
    "test" {
        Run-Flutter "flutter pub get && flutter test"
    }
    "build-web" {
        Run-Flutter "flutter pub get && flutter build web --release"
    }
    "build-apk" {
        Run-Flutter "flutter pub get && flutter build apk --debug"
    }
    "format" {
        Run-Flutter "dart format ."
    }
}
