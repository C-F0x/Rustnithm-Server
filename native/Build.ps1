# Build script for Flutter Rust Bridge

$ErrorActionPreference = "Stop"

Write-Host "--- Starting Build Process ---" -ForegroundColor Cyan

# 1. Environment Check
Write-Host "[1/4] Checking dependencies..." -ForegroundColor Yellow
$tools = @("flutter", "cargo", "flutter_rust_bridge_codegen")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Required tool '$tool' not found in PATH."
        exit 1
    }
}

# 2. Code Generation
Write-Host "[2/4] Generating bridge code..." -ForegroundColor Yellow
flutter_rust_bridge_codegen --rust-input src/api.rs --dart-output ../lib/bridge_generated.dart

# 3. Rust Compilation
Write-Host "[3/4] Compiling Rust library (release)..." -ForegroundColor Yellow
cargo build --release

# 4. Deployment
Write-Host "[4/4] Deploying artifact..." -ForegroundColor Yellow
$source = "target\release\rustnithm_native.dll"
$destination = ".\rustnithm_native.dll"

if (Test-Path $source) {
    Copy-Item -Path $source -Destination $destination -Force
    Write-Host "SUCCESS: Artifact copied to root." -ForegroundColor Green
} else {
    Write-Error "Build failed: $source not found."
    exit 1
}

Write-Host "--- Build Complete ---" -ForegroundColor Cyan