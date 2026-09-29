[CmdletBinding()]
param(
    [string]$ExpectedFlutterVersion = "3.44.5",
    [switch]$SkipInstaller,
    [switch]$Doctor
)

$ErrorActionPreference = "Continue"
Set-StrictMode -Version Latest
$failures = [System.Collections.Generic.List[string]]::new()

function Report([string]$Name, [string]$Path, [string]$Version, [bool]$Required = $true) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -eq "missing") {
        $state = if ($Required) { "MISSING" } else { "optional/missing" }
        Write-Host ("{0,-12} {1,-48} {2}" -f $Name, $state, "-") -ForegroundColor $(if ($Required) { "Red" } else { "Yellow" })
        if ($Required) { $failures.Add("$Name is missing") }
        return
    }
    Write-Host ("{0,-12} {1,-48} {2}" -f $Name, $Path, $Version) -ForegroundColor Green
}

function Find-Command([string[]]$Names) {
    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command -and $command.Source) { return $command.Source }
    }
    return "missing"
}

Write-Host "acsys360 Windows environment doctor"
Write-Host "Expected Flutter: $ExpectedFlutterVersion"
Write-Host ""
Write-Host ("{0,-12} {1,-48} {2}" -f "Tool", "Path", "Version")
Write-Host ("{0,-12} {1,-48} {2}" -f "----", "----", "-------")

$flutter = Find-Command @("flutter.bat", "flutter")
$dart = Find-Command @("dart.exe", "dart")
$cmake = Find-Command @("cmake.exe", "cmake")
$ctest = Find-Command @("ctest.exe", "ctest")
$flex = Find-Command @("win_flex.exe", "flex.exe", "win_flex", "flex")
$bison = Find-Command @("win_bison.exe", "bison.exe", "win_bison", "bison")
$gcc = Find-Command @("gcc.exe", "gcc")
$nasm = "missing"
if ($gcc -ne "missing") {
    $nasmBesideGcc = Join-Path (Split-Path -Parent $gcc) "nasm.exe"
    if (Test-Path -LiteralPath $nasmBesideGcc -PathType Leaf) {
        $nasm = (Resolve-Path -LiteralPath $nasmBesideGcc).Path
    }
}
if ($nasm -eq "missing") { $nasm = Find-Command @("nasm.exe", "nasm") }
$iscc = Find-Command @("ISCC.exe")

$flutterVersion = if ($flutter -ne "missing") { ((& $flutter --version 2>$null | Select-Object -First 1) -join "").Trim() } else { "missing" }
$dartVersion = if ($dart -ne "missing") { ((& $dart --version 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$cmakeVersion = if ($cmake -ne "missing") { ((& $cmake --version 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$ctestVersion = if ($ctest -ne "missing") { ((& $ctest --version 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$flexVersion = if ($flex -ne "missing") { ((& $flex --version 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$bisonVersion = if ($bison -ne "missing") { ((& $bison --version 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$gccVersion = if ($gcc -ne "missing") { ((& $gcc --version 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$nasmVersion = if ($nasm -ne "missing") { ((& $nasm -v 2>&1 | Select-Object -First 1) -join "").Trim() } else { "missing" }
$isccVersion = if ($iscc -ne "missing") { "Inno Setup compiler" } else { "missing" }

Report "Flutter" $flutter $flutterVersion
Report "Dart" $dart $dartVersion
Report "CMake" $cmake $cmakeVersion
Report "CTest" $ctest $ctestVersion
Report "Flex" $flex $flexVersion
Report "Bison" $bison $bisonVersion
Report "GCC" $gcc $gccVersion
Report "NASM" $nasm $nasmVersion
Report "Inno Setup" $iscc $isccVersion (-not $SkipInstaller)

if ($flutter -ne "missing" -and $flutterVersion -notmatch "Flutter $([regex]::Escape($ExpectedFlutterVersion))(\s|$)") {
    $failures.Add("Flutter version does not match $ExpectedFlutterVersion")
}
if ($gcc -ne "missing") {
    $gccTarget = ((& $gcc -dumpmachine 2>&1 | Select-Object -First 1) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or $gccTarget -notmatch '^x86_64-w64-mingw32') {
        $failures.Add("GCC must target x86_64-w64-mingw32 (found '$gccTarget')")
    } else {
        Write-Host "GCC target: $gccTarget"
    }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
    $failures.Add("Visual Studio C++ Build Tools (vswhere / x64 C++ tools) were not found")
} else {
    $vsInstall = ((& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null | Select-Object -First 1) -join "").Trim()
    if (-not $vsInstall) {
        $failures.Add("Visual Studio is installed without the x86/x64 C++ build tools component")
    } else {
        Write-Host "Visual Studio: $vsInstall"
    }
}

if ($Doctor -and $flutter -ne "missing") {
    Write-Host "`nflutter doctor -v"
    & $flutter doctor -v
}

if ($failures.Count -gt 0) {
    Write-Host "`nEnvironment is not release-ready:" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" -ForegroundColor Red }
    exit 1
}
Write-Host "`n[OK] Windows release prerequisites are available." -ForegroundColor Green
