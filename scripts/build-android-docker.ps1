<#
.SYNOPSIS
    Builds the Flutter Android APK using a Docker container.
.DESCRIPTION
    This script builds a custom Android build environment inside Docker,
    mounts the local codebase, and executes the build commands.
    This avoids installing Java or the Android SDK on your local machine.
.USAGE
    .\scripts\build-android-docker.ps1
#>

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  WealthAI Docker Android Builder" -ForegroundColor Cyan
Write-Host "  (Isolated Containerized Build)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check Docker is running
try {
    docker info 2>&1 | Out-Null
} catch {
    Write-Host "ERROR: Docker daemon is not running or Docker is not installed." -ForegroundColor Red
    exit 1
}

# Step 1: Build the docker builder image
Write-Host "[1/3] Building Android Builder Docker Image (this may take a few minutes initially)..." -ForegroundColor Yellow
docker build -t wealthai-android-builder -f "$ProjectRoot\infra\docker\Dockerfile.android" "$ProjectRoot"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build Android Builder Docker image." -ForegroundColor Red
    exit 1
}
Write-Host "  Android Builder image built successfully." -ForegroundColor Green

# Step 2: Run the build inside the container
Write-Host "[2/3] Building Android APK and App Bundle (AAB) inside Docker..." -ForegroundColor Yellow

# We mount the entire project root to /app so that relative assets/files and packages work correctly.
# The outputs will naturally compile into local mounted paths:
#   APK: apps/web/build/app/outputs/flutter-apk/
#   AAB: apps/web/build/app/outputs/bundle/release/
docker run --rm -v "${ProjectRoot}:/app" wealthai-android-builder bash -c "cd /app/apps/web && if [ ! -d android ]; then echo 'Android folder missing. Initializing Android platform...'; flutter create --platforms=android .; fi && flutter pub get && flutter build apk --release && flutter build appbundle --release"

$buildExitCode = $LASTEXITCODE

# Step 3: Check build result
Write-Host "[3/3] Verifying Android Builds..." -ForegroundColor Yellow

$apkPath = "$ProjectRoot\apps\web\build\app\outputs\flutter-apk\app-release.apk"
$aabPath = "$ProjectRoot\apps\web\build\app\outputs\bundle\release\app-release.aab"

if ($buildExitCode -eq 0 -and (Test-Path $apkPath) -and (Test-Path $aabPath)) {
    $apkSize = (Get-Item $apkPath).Length / 1MB
    $aabSize = (Get-Item $aabPath).Length / 1MB
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "  APK Location: $apkPath" -ForegroundColor White
    Write-Host "  APK Size:     $([math]::Round($apkSize, 1)) MB" -ForegroundColor White
    Write-Host "  AAB Location: $aabPath" -ForegroundColor White
    Write-Host "  AAB Size:     $([math]::Round($aabSize, 1)) MB" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: Android build failed inside container (Exit Code: $buildExitCode)." -ForegroundColor Red
}

exit $buildExitCode
