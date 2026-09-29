[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$DestinationDirectory = (New-Item -ItemType Directory -Path $DestinationDirectory -Force).FullName
$redistRoots = @()
if ($env:VCToolsRedistDir) {
    $redistRoots += $env:VCToolsRedistDir
}

$vswhereCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"),
    (Join-Path $env:ProgramFiles "Microsoft Visual Studio\Installer\vswhere.exe")
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
foreach ($vswhere in $vswhereCandidates) {
    $installations = @(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null)
    foreach ($installation in $installations) {
        if (-not [string]::IsNullOrWhiteSpace($installation)) {
            $redistRoots += Join-Path $installation "VC\Redist\MSVC"
        }
    }
}

$crtDirectories = @()
foreach ($root in ($redistRoots | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $root -PathType Container) {
        $crtDirectories += Get-ChildItem `
            -Path (Join-Path $root "*\x64\Microsoft.VC*.CRT") `
            -Directory `
            -ErrorAction SilentlyContinue
    }
}
$crtDirectories = @($crtDirectories | Sort-Object LastWriteTime -Descending)

if (-not $crtDirectories) {
    throw "Could not locate the x64 Microsoft Visual C++ redistributable files. Install the Visual Studio C++ build tools (including the x64/x86 C++ tools) or set VCToolsRedistDir."
}

$crtDirectory = $crtDirectories | Select-Object -First 1
$dlls = @(Get-ChildItem -LiteralPath $crtDirectory.FullName -Filter "*.dll" -File)
if (-not $dlls) {
    throw "The Visual C++ runtime directory is empty: $($crtDirectory.FullName)"
}
$destinations = @($DestinationDirectory)
$compilerDirectory = Join-Path $DestinationDirectory "compiler"
if (Test-Path -LiteralPath $compilerDirectory -PathType Container) {
    $destinations += $compilerDirectory
}
foreach ($destination in $destinations) {
    foreach ($dll in $dlls) {
        Copy-Item -LiteralPath $dll.FullName -Destination $destination -Force
    }
}

foreach ($required in @("vcruntime140.dll", "msvcp140.dll")) {
    foreach ($destination in $destinations) {
        $path = Join-Path $destination $required
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "The selected Visual C++ runtime is incomplete; required file is missing: $path"
        }
    }
}

Write-Host "Bundled $($dlls.Count) x64 Visual C++ runtime DLLs from $($crtDirectory.FullName) to: $($destinations -join ', ')"
