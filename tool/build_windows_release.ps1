[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipChecks,
    [switch]$SkipInstaller,
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$CompilerRoot = Join-Path $ProjectRoot "packages\compiler_c"
$CompilerBuild = Join-Path $CompilerRoot "build"
$FlutterRelease = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$BundleCompiler = Join-Path $FlutterRelease "compiler\arabicc.exe"
$ToolchainRoot = $null
$OutputRoot = Join-Path $ProjectRoot $OutputDirectory
$InstallerScript = Join-Path $ProjectRoot "tool\packaging\acsys360-windows.iss"

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
Require-Command "ctest" "Install CMake and add its bin directory to PATH."
$FlutterVersionLine = (flutter --version 2>$null | Select-Object -First 1).Trim()
if ($FlutterVersionLine -notmatch '^Flutter 3\.44\.5(\s|$)') {
    Fail "Flutter 3.44.5 is required to match CI; found '$FlutterVersionLine'."
}
$VsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $VsWhere -PathType Leaf)) {
    Fail "Visual Studio C++ Build Tools were not found (missing vswhere.exe). Install Desktop development with C++."
}
$VsInstall = (& $VsWhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($VsInstall)) {
    Fail "Visual Studio is installed without the x86/x64 C++ tools component. Install Desktop development with C++."
}
Write-Host "Using Visual Studio: $VsInstall"

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
$GccCommand = @(Get-Command gcc.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notmatch "[\\/]Strawberry[\\/]" } | Select-Object -First 1)
if (-not $GccCommand) { Fail "GCC was not found in PATH. Install the MSYS2 UCRT64 x86_64 GCC toolchain." }
$NasmCommand = @(Get-Command nasm.exe -All -ErrorAction SilentlyContinue | Select-Object -First 1)
if (-not $NasmCommand) { Fail "NASM was not found in PATH. Install the MSYS2 UCRT64 NASM package." }

$GccTarget = (& $GccCommand.Source -dumpmachine | Select-Object -First 1).Trim()
if ($LASTEXITCODE -ne 0 -or $GccTarget -notmatch '^x86_64-w64-mingw32') {
    Fail "GCC must target x86_64-w64-mingw32 for the Windows native backend; found '$GccTarget' at $($GccCommand.Source)."
}
Write-Host "Using Flex: $($FlexCommand.Source)"
Write-Host "Using Bison: $($BisonCommand.Source)"
Write-Host "Using GCC: $($GccCommand.Source) ($GccTarget)"
Write-Host "Using NASM: $($NasmCommand.Source)"

$IsccPath = $null
if (-not $SkipInstaller) {
    $Iscc = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($Iscc) { $IsccPath = $Iscc.Source }
    if (-not $IsccPath) {
        $DefaultIscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
        if (Test-Path $DefaultIscc) { $IsccPath = $DefaultIscc }
    }
    if (-not $IsccPath) {
        Fail "Inno Setup 6 (ISCC.exe) was not found. Install Inno Setup or use -SkipInstaller to build without packaging."
    }
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
    & cmake -S $CompilerRoot -B $CompilerBuild `
        "-DFLEX_EXECUTABLE:FILEPATH=$($FlexCommand.Source)" `
        "-DBISON_EXECUTABLE:FILEPATH=$($BisonCommand.Source)"
    if ($LASTEXITCODE -ne 0) {
        Fail "C compiler CMake configuration failed. Verify Visual Studio, Flex, and Bison installation."
    }

    Invoke-Step "Build C compiler (Release)" {
        & cmake --build $CompilerBuild --parallel --config Release
    }
    Invoke-Step "Run C compiler tests" {
        & ctest --test-dir $CompilerBuild --config Release --output-on-failure
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
    Invoke-Step "Bundle x64 Visual C++ runtime" {
        & (Join-Path $PSScriptRoot "bundle_windows_vc_runtime.ps1") -DestinationDirectory $FlutterRelease
    }

    $BundledToolchain = Join-Path $FlutterRelease "toolchain\windows"
    Invoke-Step "Bundle and validate GCC/NASM toolchain" {
        & (Join-Path $PSScriptRoot "bundle_windows_toolchain.ps1") `
            -DestinationDirectory $BundledToolchain `
            -GccPath $GccCommand.Source `
            -NasmPath $NasmCommand.Source
    }

    Invoke-Step "Run bundled compiler smoke test" {
        & dart run tool/verify_compiler_bundle.dart --executable $BundleCompiler --native
    }
    Invoke-Step "Inspect complete Windows application bundle" {
        & (Join-Path $PSScriptRoot "inspect_windows_bundle.ps1") -Executable $AppExe
    }

    if (-not $SkipInstaller) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
        $Version = (Select-String -Path (Join-Path $ProjectRoot "pubspec.yaml") -Pattern '^version: ([0-9.]+)' ).Matches.Groups[1].Value
        Write-Host "`n==> Create Windows setup installer" -ForegroundColor Cyan
        & $IsccPath "/DAppVersion=$Version" "/DSourceDir=$FlutterRelease" "/DOutputDir=$OutputRoot" $InstallerScript
        if ($LASTEXITCODE -ne 0) { Fail "Inno Setup failed with exit code $LASTEXITCODE." }
        $Installer = Join-Path $OutputRoot "acsys360-windows-$Version-setup-x64.exe"
        if (-not (Test-Path $Installer)) { Fail "Installer was not created: $Installer" }
        Write-Host "[OK] Installer: $Installer" -ForegroundColor Green
    }

    Write-Host "`n[OK] Windows release build completed successfully." -ForegroundColor Green
    Write-Host "[OK] Application: $AppExe" -ForegroundColor Green
    Write-Host "[OK] Compiler:    $BundleCompiler" -ForegroundColor Green
}
finally {
    Pop-Location
}
