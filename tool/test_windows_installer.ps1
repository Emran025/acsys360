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
$programFilesRoots = @(
    $programFiles,
    ${env:ProgramFiles(x86)}
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
$installRoot = Join-Path $programFiles "acsys360"
foreach ($root in $programFilesRoots) {
    $existingInstall = Join-Path $root "acsys360"
    if (Test-Path -LiteralPath $existingInstall) {
        throw "Refusing to overwrite an existing installer test directory: $existingInstall"
    }
}

try {
    Write-Host "Installing $installer into temporary directory $installRoot"
    $LASTEXITCODE = 0
    & $installer /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
    $installerExitCode = $LASTEXITCODE
    if ($installerExitCode -ne 0) {
        throw "Silent installer exited with code $installerExitCode"
    }

    $installedRoots = @(
        foreach ($root in $programFilesRoots) {
            $candidate = Join-Path $root "acsys360"
            if (Test-Path -LiteralPath (Join-Path $candidate "acsys360.exe")) {
                $candidate
            }
        }
    )
    if ($installedRoots.Count -ne 1) {
        throw "Expected exactly one installed acsys360 directory under Program Files roots, found: $($installedRoots -join ', ')"
    }
    $installRoot = $installedRoots[0]

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
