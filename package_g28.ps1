# ============================================================
# package_g28.ps1
# يقوم بتحزيم مشروع G28 بالكامل:
#   1. تحزيم الكود المصدري الحالي في G28-Code.zip (كأنه تم عمل clone نظيف)
#   2. أخذ أحدث إصدار لمثبت Windows (G28-E.exe)
#   3. تضمين تقرير المشروع (G28-Report.pdf)
#   4. تجميع الملفات الثلاثة معاً في ملف واحد مباشر: G28.zip
# ============================================================

param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "dist_g28"),
    [string]$WindowsInstallerSource = "C:\Users\Thinkpad\Downloads\Telegram Desktop\flutter\G28\G28-E.exe",
    [string]$PdfReportSource = "C:\Users\Thinkpad\Downloads\Telegram Desktop\flutter\G28\G28-Report.pdf"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     بدء تحزيم ملفات مشروع G28 الشاملة (G28.zip)     " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. إنشاء مجلد الإخراج
if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Write-Host "[1/4] تم تجهيز مجلد الإخراج: $OutputDir" -ForegroundColor Green

# 2. إنشاء G28-Code.zip من آخر commit نظيف
$codeZipPath = Join-Path $OutputDir "G28-Code.zip"
Write-Host "[2/4] جاري تحزيم الكود المصدري (G28-Code.zip)..." -ForegroundColor Yellow
& git archive --format=zip --prefix=acsys360/ HEAD -o $codeZipPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $codeZipPath)) {
    throw "فشل إنشاء G28-Code.zip بواسطة git archive"
}
$codeSize = (Get-Item $codeZipPath).Length / 1MB
Write-Host "      تم إنشاء G28-Code.zip بنجاح (الحجم: $([math]::Round($codeSize, 2)) MB)" -ForegroundColor Green

# 3. جلب G28-E.exe (مثبت Windows)
$installerDest = Join-Path $OutputDir "G28-E.exe"
Write-Host "[3/4] جاري تجهيز مثبت Windows (G28-E.exe)..." -ForegroundColor Yellow
if (Test-Path $WindowsInstallerSource) {
    Copy-Item -Path $WindowsInstallerSource -Destination $installerDest -Force
    $exeSize = (Get-Item $installerDest).Length / 1MB
    Write-Host "      تم نسخ G28-E.exe بنجاح من ($WindowsInstallerSource) (الحجم: $([math]::Round($exeSize, 2)) MB)" -ForegroundColor Green
} elseif (Test-Path (Join-Path $PSScriptRoot "dist\acsys360-windows-*-setup-x64.exe")) {
    $found = Get-ChildItem (Join-Path $PSScriptRoot "dist\acsys360-windows-*-setup-x64.exe") | Select-Object -First 1
    Copy-Item -Path $found.FullName -Destination $installerDest -Force
    Write-Host "      تم أخذ المثبت من dist/ وإعادة تسميته إلى G28-E.exe" -ForegroundColor Green
} else {
    Write-Warning "لم يتم العثور على مثبت Windows في المسار: $WindowsInstallerSource"
}

# 4. جلب G28-Report.pdf (تقرير المشروع)
$pdfDest = Join-Path $OutputDir "G28-Report.pdf"
Write-Host "[4/4] جاري تضمين تقرير المشروع (G28-Report.pdf)..." -ForegroundColor Yellow
if (Test-Path $PdfReportSource) {
    Copy-Item -Path $PdfReportSource -Destination $pdfDest -Force
    Write-Host "      تم نسخ G28-Report.pdf بنجاح من ($PdfReportSource)" -ForegroundColor Green
} elseif (Test-Path (Join-Path $PSScriptRoot "G28-Report.pdf")) {
    Copy-Item -Path (Join-Path $PSScriptRoot "G28-Report.pdf") -Destination $pdfDest -Force
    Write-Host "      تم أخذ G28-Report.pdf من جذر المستودع" -ForegroundColor Green
} else {
    Write-Warning "لم يتم العثور على ملف التقرير G28-Report.pdf"
}

# 5. ضغط الملفات الثلاثة معاً في ملف G28.zip
$g28ZipPath = Join-Path $PSScriptRoot "G28.zip"
if (Test-Path $g28ZipPath) {
    Remove-Item $g28ZipPath -Force
}

Write-Host "`nجاري تجميع الملفات الثلاثة في الحقيبة المباشرة G28.zip..." -ForegroundColor Cyan
$filesToCompress = @()
if (Test-Path $codeZipPath)   { $filesToCompress += $codeZipPath }
if (Test-Path $installerDest) { $filesToCompress += $installerDest }
if (Test-Path $pdfDest)       { $filesToCompress += $pdfDest }

Compress-Archive -Path $filesToCompress -DestinationPath $g28ZipPath -CompressionLevel Optimal
$finalSize = (Get-Item $g28ZipPath).Length / 1MB

Write-Host "====================================================" -ForegroundColor Green
Write-Host " ✅ تم إنشاء الحزمة الشاملة G28.zip بنجاح!" -ForegroundColor Green
Write-Host " المسار: $g28ZipPath" -ForegroundColor White
Write-Host " الحجم الإجمالي: $([math]::Round($finalSize, 2)) MB" -ForegroundColor White
Write-Host " محتويات الحزمة:" -ForegroundColor Yellow
Get-ChildItem $OutputDir | ForEach-Object {
    $s = $_.Length / 1MB
    Write-Host "   - $($_.Name) ($([math]::Round($s, 2)) MB)" -ForegroundColor Gray
}
Write-Host "====================================================" -ForegroundColor Green
