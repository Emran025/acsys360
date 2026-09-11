$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

$msysBin = "C:\msys64\usr\bin"
$gccBin = "C:\msys64\ucrt64\bin"
$env:PATH = "$gccBin;$msysBin;$env:PATH"

if (!(Test-Path "build")) { New-Item -ItemType Directory "build" | Out-Null }

if (Test-Path "src/parser.y") {
    Write-Host "[1/3] Running Bison..."
    & "$msysBin\bison.exe" -d -o "src/parser.tab.c" "src/parser.y"
}

if (Test-Path "src/lexer.l") {
    Write-Host "[2/3] Running Flex..."
    & "$msysBin\flex.exe" -o "src/lexer.yy.c" "src/lexer.l"
}

Write-Host "[3/3] Compiling C source files..."
$sources = @("src/main.c", "src/protocol.c", "src/ast.c")
if (Test-Path "src/parser.tab.c") { $sources += "src/parser.tab.c" }
if (Test-Path "src/lexer.yy.c") { $sources += "src/lexer.yy.c" }

& "$gccBin\gcc.exe" -O2 -Wall -Wextra -Iinclude -Isrc $sources -o "build/arabicc.exe"
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Build succeeded: build/arabicc.exe" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    Pop-Location
    exit $LASTEXITCODE
}
Pop-Location
