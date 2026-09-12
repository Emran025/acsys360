$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

function Find-Tool($toolName, $fallbackPaths) {
    $cmd = Get-Command $toolName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($path in $fallbackPaths) {
        $fullPath = Join-Path $path "$toolName.exe"
        if (Test-Path $fullPath) { return $fullPath }
    }
    return $null
}

$msysFallbacks = @("C:\msys64\ucrt64\bin", "C:\msys64\usr\bin", "C:\msys64\mingw64\bin")
$gcc = Find-Tool "gcc" $msysFallbacks
$bison = Find-Tool "bison" @("C:\msys64\usr\bin", "C:\msys64\ucrt64\bin")
$flex = Find-Tool "flex" @("C:\msys64\usr\bin", "C:\msys64\ucrt64\bin")

if (-not $gcc) {
    Write-Host "[ERROR] gcc not found! Please install GCC (via MSYS2: pacman -S mingw-w64-ucrt-x86_64-gcc or MinGW)." -ForegroundColor Red
    Pop-Location
    exit 1
}
if (-not $bison) {
    Write-Host "[ERROR] bison not found! Please install Bison (via MSYS2: pacman -S bison or winflexbison)." -ForegroundColor Red
    Pop-Location
    exit 1
}
if (-not $flex) {
    Write-Host "[ERROR] flex not found! Please install Flex (via MSYS2: pacman -S flex or winflexbison)." -ForegroundColor Red
    Pop-Location
    exit 1
}

$bisonDir = Split-Path -Parent $bison
$gccDir = Split-Path -Parent $gcc
$env:PATH = "$gccDir;$bisonDir;$env:PATH"

if (!(Test-Path "build")) { New-Item -ItemType Directory "build" | Out-Null }

if (Test-Path "src/parser.y") {
    Write-Host "[1/3] Running Bison ($bison)..."
    & $bison -d -o "src/parser.tab.c" "src/parser.y"
}

if (Test-Path "src/lexer.l") {
    Write-Host "[2/3] Running Flex ($flex)..."
    & $flex -o "src/lexer.yy.c" "src/lexer.l"
}

Write-Host "[3/3] Compiling C source files with $gcc..."
$sources = @("src/main.c", "src/protocol.c", "src/ast.c", "src/semantic.c", "src/asm_x86_64.c")
if (Test-Path "src/parser.tab.c") { $sources += "src/parser.tab.c" }
if (Test-Path "src/lexer.yy.c") { $sources += "src/lexer.yy.c" }

& $gcc -O2 -Wall -Wextra -Iinclude -Isrc $sources -o "build/arabicc.exe"
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Build succeeded: build/arabicc.exe" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    Pop-Location
    exit $LASTEXITCODE
}
Pop-Location
