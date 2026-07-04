<#
.SYNOPSIS
    WealthAI Flutter Build Script (Isolated, no global installs)
.DESCRIPTION
    Analyzes and builds the Flutter web app. Assumes Flutter SDK is in PATH.
    If Flutter is not installed, provides download instructions.
.USAGE
    .\scripts\build-frontend.ps1           # Build web release
    .\scripts\build-frontend.ps1 -Analyze  # Run dart analysis only
    .\scripts\build-frontend.ps1 -Run      # Run dev server
    .\scripts\build-frontend.ps1 -Android  # Build Android APK
#>

param(
    [switch]$Analyze,
    [switch]$Run,
    [switch]$Android,
    [switch]$Test
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $ProjectRoot "apps\web"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  WealthAI Flutter Build" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check Flutter is available
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "Flutter: $flutterVersion" -ForegroundColor Gray
} catch {
    Write-Host "ERROR: Flutter SDK not found in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Flutter:" -ForegroundColor Yellow
    Write-Host "  1. Download from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor White
    Write-Host "  2. Extract to C:\flutter" -ForegroundColor White
    Write-Host "  3. Add C:\flutter\bin to your PATH" -ForegroundColor White
    Write-Host "  4. Run: flutter doctor" -ForegroundColor White
    exit 1
}

Push-Location $AppDir

# Get dependencies
Write-Host "[1/3] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "  Dependencies resolved" -ForegroundColor Green

if ($Analyze) {
    Write-Host "[2/3] Analyzing code..." -ForegroundColor Yellow
    flutter analyze
    Write-Host "[3/3] Checking format..." -ForegroundColor Yellow
    dart format --set-exit-if-changed lib/
    Pop-Location
    exit $LASTEXITCODE
}

if ($Test) {
    Write-Host "[2/3] Running tests..." -ForegroundColor Yellow
    flutter test --coverage
    Pop-Location
    exit $LASTEXITCODE
}

if ($Run) {
    Write-Host "Starting dev server on port 8080..." -ForegroundColor Yellow
    flutter run -d chrome --web-port 8080
    Pop-Location
    exit 0
}

if ($Android) {
    Write-Host "[2/3] Building Android APK..." -ForegroundColor Yellow
    flutter build apk --release
    $apkPath = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $size = (Get-Item $apkPath).Length / 1MB
        Write-Host "  APK built: $apkPath ($([math]::Round($size, 1)) MB)" -ForegroundColor Green
    }
    Pop-Location
    exit $LASTEXITCODE
}

# Default: Build web
Write-Host "[2/3] Building Flutter Web (release)..." -ForegroundColor Yellow
flutter build web --release --web-renderer canvaskit

if ($LASTEXITCODE -eq 0) {
    $buildDir = Join-Path $AppDir "build\web"
    Write-Host "[3/3] Build complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Output: $buildDir" -ForegroundColor White
    Write-Host "  Deploy: Copy build\web contents to any static host" -ForegroundColor Gray
    Write-Host ""

    # Calculate build size
    $totalSize = (Get-ChildItem $buildDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  Total build size: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Gray
} else {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
}

Pop-Location
