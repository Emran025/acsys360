[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [string]$DartExecutable = "dart"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$temporaryRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } elseif ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$installRoot = Join-Path $temporaryRoot "acsys360 installer smoke-$PID"
if (Test-Path -LiteralPath $installRoot) {
    throw "Refusing to overwrite an existing installer test directory: $installRoot"
}

try {
    Write-Host "Installing $installer into temporary directory $installRoot"
    $LASTEXITCODE = 0
    & $installer /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- "/DIR=`"$installRoot`""
    $installerExitCode = $LASTEXITCODE
    if ($installerExitCode -ne 0) {
        throw "Silent installer exited with code $installerExitCode"
    }

    $application = Join-Path $installRoot "acsys360.exe"
    $compiler = Join-Path $installRoot "compiler\arabicc.exe"
    if (-not (Test-Path -LiteralPath $application -PathType Leaf)) {
        throw "Installed application is missing: $application"
    }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
        throw "Installed compiler is missing: $compiler"
    }

    & (Join-Path $PSScriptRoot "inspect_windows_bundle.ps1") -Executable $application
    $LASTEXITCODE = 0
    & $DartExecutable run tool/verify_compiler_bundle.dart --executable $compiler --native
    $compilerExitCode = $LASTEXITCODE
    if ($compilerExitCode -ne 0) {
        throw "Installed compiler build-and-run smoke test failed with exit code $compilerExitCode"
    }
    Write-Host "[OK] Installed Inno Setup bundle passed topology and native execution tests." -ForegroundColor Green
}
finally {
    $uninstaller = Join-Path $installRoot "unins000.exe"
    if (Test-Path -LiteralPath $uninstaller -PathType Leaf) {
        $LASTEXITCODE = 0
        & $uninstaller /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
        $uninstallerExitCode = $LASTEXITCODE
        if ($uninstallerExitCode -ne 0) {
            Write-Warning "Silent uninstall returned exit code $uninstallerExitCode"
        }
    }
    if (Test-Path -LiteralPath $installRoot) {
        Remove-Item -LiteralPath $installRoot -Recurse -Force
    }
}
