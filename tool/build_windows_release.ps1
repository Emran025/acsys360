[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipChecks,
    [switch]$SkipZip,
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$CompilerRoot = Join-Path $ProjectRoot "packages\compiler_c"
$CompilerBuild = Join-Path $CompilerRoot "build"
$FlutterRelease = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$BundleCompiler = Join-Path $FlutterRelease "compiler\arabicc.exe"
$OutputRoot = Join-Path $ProjectRoot $OutputDirectory
$ZipPath = Join-Path $OutputRoot "acsys360-windows-local.zip"

function Fail([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

function Require-Command([string]$Name, [string]$InstallHint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "$Name was not found in PATH. $InstallHint"
    }
}

function Invoke-Step([string]$Label, [scriptblock]$Action) {
    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Fail "$Label failed with exit code $LASTEXITCODE."
    }
}

Write-Host "acsys360 Windows release builder" -ForegroundColor Green
Write-Host "Project: $ProjectRoot"

Require-Command "flutter" "Install Flutter and add it to PATH."
Require-Command "dart" "Install Flutter; Dart is included with the Flutter SDK."
Require-Command "cmake" "Install CMake and add it to PATH."

$FlexCommand = Get-Command "win_flex" -ErrorAction SilentlyContinue
if (-not $FlexCommand) { $FlexCommand = Get-Command "flex" -ErrorAction SilentlyContinue }
$BisonCommand = Get-Command "win_bison" -ErrorAction SilentlyContinue
if (-not $BisonCommand) { $BisonCommand = Get-Command "bison" -ErrorAction SilentlyContinue }
if (-not $FlexCommand) {
    Fail "Flex was not found. Install winflexbison3 with Chocolatey or install Flex through MSYS2."
}
if (-not $BisonCommand) {
    Fail "Bison was not found. Install winflexbison3 with Chocolatey or install Bison through MSYS2."
}

Push-Location $ProjectRoot
try {
    if ($Clean) {
        Write-Host "Cleaning previous compiler and Windows release output..." -ForegroundColor Yellow
        if (Test-Path $CompilerBuild) { Remove-Item $CompilerBuild -Recurse -Force }
        if (Test-Path (Join-Path $ProjectRoot "build\windows")) {
            Remove-Item (Join-Path $ProjectRoot "build\windows") -Recurse -Force
        }
    }

    if (-not $SkipChecks) {
        Invoke-Step "Install Dart/Flutter dependencies" { flutter pub get }
        Invoke-Step "Format Dart sources" {
            dart format --output=none --set-exit-if-changed lib test packages/compiler_contracts/lib packages/compiler_contracts/test
        }
        Invoke-Step "Analyze Flutter project" { flutter analyze }
        Invoke-Step "Run Flutter tests" { flutter test }
    }

    Invoke-Step "Enable Windows desktop" { flutter config --enable-windows-desktop }

    Write-Host "`n==> Configure C compiler with CMake" -ForegroundColor Cyan
    & cmake -S $CompilerRoot -B $CompilerBuild
    if ($LASTEXITCODE -ne 0) {
        Fail "C compiler CMake configuration failed. Verify Visual Studio, Flex, and Bison installation."
    }

    Invoke-Step "Build C compiler (Release)" {
        & cmake --build $CompilerBuild --parallel --config Release
    }

    $CompilerCandidates = @(
        (Join-Path $CompilerBuild "Release\arabicc.exe"),
        (Join-Path $CompilerBuild "arabicc.exe")
    )
    $CompilerExe = $CompilerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $CompilerExe) {
        Fail "C compiler build completed but arabicc.exe was not found under $CompilerBuild."
    }

    Invoke-Step "Build Flutter Windows application (Release)" {
        & flutter build windows --release
    }

    if (-not (Test-Path $FlutterRelease)) {
        Fail "Flutter Release directory was not created: $FlutterRelease"
    }
    $AppExe = Join-Path $FlutterRelease "acsys360.exe"
    if (-not (Test-Path $AppExe)) {
        Fail "Flutter executable was not found: $AppExe"
    }

    $CompilerDestination = Join-Path $FlutterRelease "compiler"
    if (Test-Path $CompilerDestination) { Remove-Item $CompilerDestination -Recurse -Force }
    New-Item -ItemType Directory -Path $CompilerDestination -Force | Out-Null
    Copy-Item $CompilerExe $BundleCompiler -Force

    Invoke-Step "Run bundled compiler smoke test" {
        & dart run tool/verify_compiler_bundle.dart --executable $BundleCompiler
    }

    if (-not $SkipZip) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
        if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
        Write-Host "`n==> Create distributable ZIP" -ForegroundColor Cyan
        Compress-Archive -Path (Join-Path $FlutterRelease "*") -DestinationPath $ZipPath -CompressionLevel Optimal
        if (-not (Test-Path $ZipPath)) { Fail "ZIP creation failed: $ZipPath" }
        Write-Host "[OK] ZIP: $ZipPath" -ForegroundColor Green
    }

    Write-Host "`n[OK] Windows release build completed successfully." -ForegroundColor Green
    Write-Host "[OK] Application: $AppExe" -ForegroundColor Green
    Write-Host "[OK] Compiler:    $BundleCompiler" -ForegroundColor Green
}
finally {
    Pop-Location
}
