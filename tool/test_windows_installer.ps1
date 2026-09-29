[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [string]$DartExecutable = "dart"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$programFiles = if ($env:ProgramFiles) { $env:ProgramFiles } else { throw "ProgramFiles environment variable is missing." }
$installRoot = Join-Path $programFiles "acsys360"
$installerLog = Join-Path ([System.IO.Path]::GetTempPath()) "acsys360-installer-smoke-$PID.log"
if (Test-Path -LiteralPath $installRoot) {
    throw "Refusing to overwrite an existing installer test directory: $installRoot"
}

try {
    Write-Host "Installing $installer into $installRoot"
    $installerArguments = @(
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/SP-",
        "/DIR=`"$installRoot`"",
        "/LOG=`"$installerLog`""
    ) -join ' '
    $installerProcess = Start-Process -FilePath $installer -ArgumentList $installerArguments -Wait -PassThru
    if ($installerProcess.ExitCode -ne 0) {
        throw "Silent installer exited with code $($installerProcess.ExitCode). Log: $installerLog"
    }

    $application = Join-Path $installRoot "acsys360.exe"
    $compiler = Join-Path $installRoot "compiler\arabicc.exe"
    if (-not (Test-Path -LiteralPath $application -PathType Leaf)) {
        $log = if (Test-Path -LiteralPath $installerLog) { Get-Content -LiteralPath $installerLog -Raw } else { "<installer log missing>" }
        throw "Installed application is missing: $application`nInstaller log:`n$log"
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
        # The uninstaller may already have removed individual toolchain files.
        # Ignore stale per-file misses and retry while Windows releases handles.
        $cleanupAttempt = 0
        while ((Test-Path -LiteralPath $installRoot) -and $cleanupAttempt -lt 3) {
            Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction SilentlyContinue
            $cleanupAttempt++
            if (Test-Path -LiteralPath $installRoot) {
                Start-Sleep -Seconds 2
            }
        }
        if (Test-Path -LiteralPath $installRoot) {
            $remainingItems = @(
                Get-ChildItem -LiteralPath $installRoot -Force -ErrorAction SilentlyContinue |
                    Select-Object -First 20 -ExpandProperty FullName
            )
            $remainingText = $remainingItems -join [Environment]::NewLine
            throw "Failed to remove installer test directory: $installRoot`nRemaining items:`n$remainingText"
        }
    }
    if (Test-Path -LiteralPath $installerLog) {
        Remove-Item -LiteralPath $installerLog -Force
    }
}
