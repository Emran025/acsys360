# ============================================================
# make-release.ps1
# يُنشئ GitHub Release لمشروع G28 بالخطوات التالية:
#   1. يضيف G28-Report.pdf كـ artifact في git
#   2. ينشئ tag G28-v<version> على آخر commit
#   3. يرفع الـ tag إلى GitHub مما يُشغّل workflow package-release.yml
#      الذي يبني G28-E.exe + G28-Code.zip + يُصدر الـ Release تلقائياً
# ============================================================

param(
    [string]$Version = "",
    [string]$PdfSource = "C:\Users\Thinkpad\Downloads\Telegram Desktop\flutter\G28\G28-Report.pdf"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── تحديد الإصدار ───────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($Version)) {
    $pubspec = Get-Content pubspec.yaml -Raw
    if ($pubspec -match 'version:\s*([\d.]+)') {
        $Version = $Matches[1]
    } else {
        $Version = "1.0.0"
    }
}
$Tag = "G28-v$Version"
Write-Host "==> Tag: $Tag" -ForegroundColor Cyan

# ── نسخ الـ PDF ──────────────────────────────────────────────
$PdfDest = Join-Path $PSScriptRoot "G28-Report.pdf"

if (Test-Path $PdfSource) {
    Write-Host "==> Copying PDF from: $PdfSource" -ForegroundColor Cyan
    Copy-Item -Path $PdfSource -Destination $PdfDest -Force
    Write-Host "    Copied to: $PdfDest" -ForegroundColor Green
} elseif (Test-Path $PdfDest) {
    Write-Host "==> PDF already present at repo root." -ForegroundColor Yellow
} else {
    Write-Warning "PDF not found at '$PdfSource'. Release will be created without it."
    Write-Warning "Place G28-Report.pdf at the repo root and re-run, or continue anyway."
    $resp = Read-Host "Continue without PDF? (y/N)"
    if ($resp -notmatch '^[yY]') { exit 1 }
}

# ── إضافة الـ PDF إلى git إذا وُجد ──────────────────────────
if (Test-Path $PdfDest) {
    # تأكد من أن .gitignore لا يتجاهله
    $gitignore = Get-Content .gitignore -Raw -ErrorAction SilentlyContinue
    if ($gitignore -match '(?m)^\*\.pdf') {
        Write-Host "==> Removing *.pdf from .gitignore temporarily..." -ForegroundColor Yellow
        $gitignore = $gitignore -replace '(?m)^\*\.pdf\r?\n?', ''
        Set-Content .gitignore $gitignore -Encoding UTF8
    }
    git add "G28-Report.pdf" | Out-Null
    $status = git status --short G28-Report.pdf
    if ($status) {
        Write-Host "==> Committing G28-Report.pdf..." -ForegroundColor Cyan
        git commit -m "chore: add G28-Report.pdf for release $Tag"
    } else {
        Write-Host "==> G28-Report.pdf already committed." -ForegroundColor Yellow
    }
}

# ── التحقق من عدم وجود الـ tag مسبقاً ────────────────────────
$existingTag = git tag -l $Tag
if ($existingTag) {
    Write-Host "==> Tag $Tag already exists." -ForegroundColor Yellow
    $del = Read-Host "Delete and re-create it? (y/N)"
    if ($del -match '^[yY]') {
        git tag -d $Tag
        git push origin ":refs/tags/$Tag" --quiet
        Write-Host "    Deleted old tag." -ForegroundColor Green
    } else {
        Write-Host "Aborting – tag already exists." -ForegroundColor Red
        exit 1
    }
}

# ── إنشاء الـ tag ─────────────────────────────────────────────
Write-Host "==> Creating tag $Tag on HEAD..." -ForegroundColor Cyan
git tag -a $Tag -m "G28 Release $Version"
Write-Host "    Tag created." -ForegroundColor Green

# ── رفع الكل إلى GitHub ──────────────────────────────────────
Write-Host "==> Pushing commits and tag to origin..." -ForegroundColor Cyan
git push origin HEAD:main --quiet
git push origin $Tag
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Release workflow triggered!" -ForegroundColor Green
Write-Host " Tag: $Tag" -ForegroundColor Green
Write-Host ""
Write-Host " GitHub Actions سيقوم الآن بـ:" -ForegroundColor Cyan
Write-Host "   [1] بناء G28-E.exe (Windows installer)" -ForegroundColor White
Write-Host "   [2] تحزيم G28-Code.zip (source code)" -ForegroundColor White
Write-Host "   [3] نشر GitHub Release مع الملفات الثلاثة" -ForegroundColor White
Write-Host ""
Write-Host " تابع التقدم على:" -ForegroundColor Cyan
Write-Host "   https://github.com/Emran025/acsys360/actions" -ForegroundColor Yellow
Write-Host " الـ Release سيظهر على:" -ForegroundColor Cyan
Write-Host "   https://github.com/Emran025/acsys360/releases" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Green
