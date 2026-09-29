[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,
    [string]$GccPath = "",
    [string]$NasmPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-ToolPath([string]$Name, [string]$ExplicitPath) {
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "$Name executable does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $command = Get-Command $Name -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -and $_.Source -notmatch "[\\/]Strawberry[\\/]" } |
        Select-Object -First 1
    if (-not $command) {
        throw "$Name was not found in PATH. Install the MSYS2 UCRT64 toolchain."
    }
    return $command.Source
}

$gcc = Resolve-ToolPath "gcc.exe" $GccPath
$gccBin = Split-Path -Parent $gcc
if (-not [string]::IsNullOrWhiteSpace($NasmPath)) {
    $nasm = Resolve-ToolPath "nasm.exe" $NasmPath
} else {
    $nasmBesideGcc = Join-Path $gccBin "nasm.exe"
    if (Test-Path -LiteralPath $nasmBesideGcc -PathType Leaf) {
        $nasm = (Resolve-Path -LiteralPath $nasmBesideGcc).Path
    } else {
        $nasm = Resolve-ToolPath "nasm.exe" ""
    }
}
$targetOutput = & $gcc -dumpmachine
$gccTargetSucceeded = $?
$target = ($targetOutput | Select-Object -First 1).Trim()
if (-not $gccTargetSucceeded -or $target -notmatch '^x86_64-w64-mingw32') {
    throw "GCC must target x86_64-w64-mingw32; found '$target' at $gcc."
}

$gccRoot = Split-Path -Parent $gccBin
foreach ($requiredDirectory in @("bin", "include", "lib")) {
    $path = Join-Path $gccRoot $requiredDirectory
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "The discovered GCC prefix is incomplete; missing $path"
    }
}

$DestinationDirectory = [System.IO.Path]::GetFullPath($DestinationDirectory)
if (Test-Path -LiteralPath $DestinationDirectory) {
    Remove-Item -LiteralPath $DestinationDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
Copy-Item -Path (Join-Path $gccRoot "*") -Destination $DestinationDirectory -Recurse -Force

$destinationBin = Join-Path $DestinationDirectory "bin"
Copy-Item -LiteralPath $nasm -Destination (Join-Path $destinationBin "nasm.exe") -Force
foreach ($tool in @("gcc.exe", "nasm.exe")) {
    $path = Join-Path $destinationBin $tool
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Bundled tool is missing: $path"
    }
}
foreach ($file in @("crt2.o", "crtbegin.o", "libmingw32.a", "libgcc.a", "libmsvcrt.a", "libkernel32.a")) {
    $found = Get-ChildItem -Path $DestinationDirectory -Recurse -File -Filter $file -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $found) {
        throw "Bundled GCC prefix is missing required linker file: $file"
    }
}

$gccVersionOutput = & $gcc --version
$gccVersionSucceeded = $?
$nasmVersionOutput = & $nasm -v
$nasmVersionSucceeded = $?
if (-not $gccVersionSucceeded) { throw "GCC could not run: $gcc" }
if (-not $nasmVersionSucceeded) { throw "NASM could not run: $nasm" }

$manifest = [ordered]@{
    gccTarget = $target
    gccVersion = (($gccVersionOutput | Select-Object -First 1) -join "").Trim()
    nasmVersion = (($nasmVersionOutput | Select-Object -First 1) -join "").Trim()
    bundledAtUtc = [DateTime]::UtcNow.ToString("o")
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $DestinationDirectory "acsys360-toolchain-manifest.json") -Encoding UTF8
Write-Host "Bundled GCC $target and NASM into $DestinationDirectory"
Write-Host "  GCC:  $gcc"
Write-Host "  NASM: $nasm"
