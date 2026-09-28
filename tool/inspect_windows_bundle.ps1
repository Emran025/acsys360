[CmdletBinding()]
param(
    [string]$Executable = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Executable)) {
    $Executable = Join-Path (Get-Location) "acsys360.exe"
}
$appRoot = (Resolve-Path (Split-Path -Parent $Executable)).Path
$compiler = Join-Path $appRoot "compiler\arabicc.exe"
$toolchain = Join-Path $appRoot "toolchain\windows\bin"
$gcc = Join-Path $toolchain "gcc.exe"
$nasm = Join-Path $toolchain "nasm.exe"

Write-Host "acsys360 installation root: $appRoot"
Write-Host "compiler:                    $compiler"
Write-Host "ACSYS360_TOOLCHAIN_DIR:      $toolchain"
Write-Host "GCC:                         $gcc"
Write-Host "NASM:                        $nasm"

$missing = @(
    @(
        @{ Name = "application"; Path = $Executable },
        @{ Name = "compiler"; Path = $compiler },
        @{ Name = "gcc"; Path = $gcc },
        @{ Name = "nasm"; Path = $nasm }
    ) | Where-Object { -not (Test-Path -LiteralPath $_.Path -PathType Leaf) }
)

if ($missing.Count -gt 0) {
    foreach ($item in $missing) {
        Write-Error "Missing $($item.Name): $($item.Path)"
    }
    exit 1
}

$env:ACSYS360_TOOLCHAIN_DIR = $toolchain
$env:ACSYS360_TOOLCHAIN_ONLY = "1"
$env:Path = "$toolchain;$env:Path"
Write-Host "[OK] Installed bundle topology is complete."
Write-Host "[OK] The compiler must resolve tools beside the executable, not from C:\msys64."
