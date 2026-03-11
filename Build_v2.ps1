
$ErrorActionPreference = "Stop"

Write-Host "--- Starting Build Process (FRB v2) ---" -ForegroundColor Cyan

Write-Host "[1/4] Checking dependencies..." -ForegroundColor Yellow
$tools = @("flutter", "cargo", "flutter_rust_bridge_codegen")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Required tool '$tool' not found in PATH."
        exit 1
    }
}

Write-Host "[2/4] Generating bridge code..." -ForegroundColor Yellow
flutter_rust_bridge_codegen generate

Write-Host "[3/4] Compiling Rust library (release)..." -ForegroundColor Yellow
Push-Location native
cargo build --release
Pop-Location

Write-Host "[4/4] Deploying artifact..." -ForegroundColor Yellow
$source = "native\target\release\rustnithm_native.dll"
$destination = ".\rustnithm_native.dll"

if (Test-Path $source) {
    Copy-Item -Path $source -Destination $destination -Force
    Write-Host "SUCCESS: Artifact copied to root." -ForegroundColor Green
} else {
    Write-Error "Build failed: $source not found. Please check 'native\Cargo.toml' package name."
    exit 1
}

Write-Host "--- Build Complete ---" -ForegroundColor Cyan