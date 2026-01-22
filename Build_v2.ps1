# Flutter Rust Bridge v2 构建脚本

$ErrorActionPreference = "Stop"

Write-Host "--- Starting Build Process (FRB v2) ---" -ForegroundColor Cyan

# 1. 环境检查
Write-Host "[1/4] Checking dependencies..." -ForegroundColor Yellow
$tools = @("flutter", "cargo", "flutter_rust_bridge_codegen")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Required tool '$tool' not found in PATH."
        exit 1
    }
}

# 2. 生成桥接代码 (FRB v2 简化模式)
Write-Host "[2/4] Generating bridge code..." -ForegroundColor Yellow
# v2 会自动寻找当前目录或 native 目录下的 flutter_rust_bridge.yaml
flutter_rust_bridge_codegen generate

# 3. 编译 Rust 动态库
Write-Host "[3/4] Compiling Rust library (release)..." -ForegroundColor Yellow
# 进入 native 目录执行编译，确保路径正确
Push-Location native
cargo build --release
Pop-Location

# 4. 部署生成产物
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