# ============================================================
# package_g28.ps1
# Packages G28 project into G28.zip containing:
#   1. G28-Code.zip (clean git archive)
#   2. G28-E.exe (Windows installer)
#   3. G28-Report.pdf (Project Report)
# ============================================================

param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "dist_g28"),
    [string]$WindowsInstallerSource = "C:\Users\Thinkpad\Downloads\Telegram Desktop\flutter\G28\G28-E.exe",
    [string]$PdfReportSource = "C:\Users\Thinkpad\Downloads\Telegram Desktop\flutter\G28\G28-Report.pdf"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     Starting G28 Package Assembly (G28.zip)        " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Setup output directory
if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Write-Host "[1/4] Output folder prepared: $OutputDir" -ForegroundColor Green

# 2. Build G28-Code.zip via git archive
$codeZipPath = Join-Path $OutputDir "G28-Code.zip"
Write-Host "[2/4] Archiving source code (G28-Code.zip)..." -ForegroundColor Yellow
& git archive --format=zip --prefix=acsys360/ HEAD -o $codeZipPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $codeZipPath)) {
    throw "Failed to create G28-Code.zip with git archive"
}
$codeSize = (Get-Item $codeZipPath).Length / 1MB
Write-Host "      Created G28-Code.zip successfully ($([math]::Round($codeSize, 2)) MB)" -ForegroundColor Green

# 3. Copy G28-E.exe
$installerDest = Join-Path $OutputDir "G28-E.exe"
Write-Host "[3/4] Preparing Windows installer (G28-E.exe)..." -ForegroundColor Yellow
if (Test-Path $WindowsInstallerSource) {
    Copy-Item -Path $WindowsInstallerSource -Destination $installerDest -Force
    $exeSize = (Get-Item $installerDest).Length / 1MB
    Write-Host "      Copied G28-E.exe from: $WindowsInstallerSource ($([math]::Round($exeSize, 2)) MB)" -ForegroundColor Green
} elseif (Test-Path (Join-Path $PSScriptRoot "G28-E.exe")) {
    Copy-Item -Path (Join-Path $PSScriptRoot "G28-E.exe") -Destination $installerDest -Force
    Write-Host "      Copied G28-E.exe from repo root" -ForegroundColor Green
} else {
    Write-Warning "Windows installer G28-E.exe was not found at $WindowsInstallerSource"
}

# 4. Copy G28-Report.pdf
$pdfDest = Join-Path $OutputDir "G28-Report.pdf"
Write-Host "[4/4] Including project report (G28-Report.pdf)..." -ForegroundColor Yellow
if (Test-Path $PdfReportSource) {
    Copy-Item -Path $PdfReportSource -Destination $pdfDest -Force
    Write-Host "      Copied G28-Report.pdf from: $PdfReportSource" -ForegroundColor Green
} elseif (Test-Path (Join-Path $PSScriptRoot "G28-Report.pdf")) {
    Copy-Item -Path (Join-Path $PSScriptRoot "G28-Report.pdf") -Destination $pdfDest -Force
    Write-Host "      Copied G28-Report.pdf from repo root" -ForegroundColor Green
} else {
    Write-Warning "G28-Report.pdf was not found"
}

# 5. Compress all three files into G28.zip
$g28ZipPath = Join-Path $PSScriptRoot "G28.zip"
if (Test-Path $g28ZipPath) {
    Remove-Item $g28ZipPath -Force
}

Write-Host "`nCompressing all 3 files into G28.zip..." -ForegroundColor Cyan
$filesToCompress = @()
if (Test-Path $codeZipPath)   { $filesToCompress += $codeZipPath }
if (Test-Path $installerDest) { $filesToCompress += $installerDest }
if (Test-Path $pdfDest)       { $filesToCompress += $pdfDest }

Compress-Archive -Path $filesToCompress -DestinationPath $g28ZipPath -CompressionLevel Optimal
$finalSize = (Get-Item $g28ZipPath).Length / 1MB

Write-Host "====================================================" -ForegroundColor Green
Write-Host " [SUCCESS] G28.zip created successfully!" -ForegroundColor Green
Write-Host " Location: $g28ZipPath" -ForegroundColor White
Write-Host " Total Size: $([math]::Round($finalSize, 2)) MB" -ForegroundColor White
Write-Host " Package Contents:" -ForegroundColor Yellow
Get-ChildItem $OutputDir | ForEach-Object {
    $s = $_.Length / 1MB
    Write-Host "   - $($_.Name) ($([math]::Round($s, 2)) MB)" -ForegroundColor Gray
}
Write-Host "====================================================" -ForegroundColor Green
