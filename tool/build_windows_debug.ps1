[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$Run,
    [string]$Configuration = "Debug"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$CompilerRoot = Join-Path $ProjectRoot "packages\compiler_c"
$CompilerBuild = Join-Path $CompilerRoot "build"
$WindowsBuild = Join-Path $ProjectRoot "build\windows\x64\runner\$Configuration"
$CompilerDestination = Join-Path $WindowsBuild "compiler\arabicc.exe"

function Require-Command([string]$Name, [string]$Hint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name was not found in PATH. $Hint"
    }
}

Push-Location $ProjectRoot
try {
    Require-Command "cmake" "Install CMake and add it to PATH."
    Require-Command "flutter" "Install Flutter and add it to PATH."

    if ($Clean -and (Test-Path $CompilerBuild)) {
        Remove-Item $CompilerBuild -Recurse -Force
    }

    Write-Host "==> Configure compiler"
    cmake -S $CompilerRoot -B $CompilerBuild
    if ($LASTEXITCODE -ne 0) { throw "Compiler CMake configuration failed." }

    Write-Host "==> Build compiler from current source"
    cmake --build $CompilerBuild --config Release --parallel
    if ($LASTEXITCODE -ne 0) { throw "Compiler build failed." }

    $CompilerCandidates = @(
        (Join-Path $CompilerBuild "Release\arabicc.exe"),
        (Join-Path $CompilerBuild "arabicc.exe")
    )
    $Compiler = $CompilerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $Compiler) { throw "arabicc.exe was not produced by the compiler build." }

    $FlutterConfiguration = $Configuration.ToLowerInvariant()
    Write-Host "==> Build Flutter Windows $Configuration application"
    flutter build windows --$FlutterConfiguration
    if ($LASTEXITCODE -ne 0) { throw "Flutter Windows build failed." }

    New-Item -ItemType Directory -Path (Split-Path $CompilerDestination) -Force | Out-Null
    Copy-Item $Compiler $CompilerDestination -Force
    Write-Host "[OK] Compiler: $CompilerDestination" -ForegroundColor Green

    if ($Run) {
        flutter run -d windows
    }
}
finally {
    Pop-Location
}
