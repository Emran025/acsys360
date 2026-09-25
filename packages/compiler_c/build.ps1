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
# === [SURGICAL ADD] NASM helper (invoked only when gcc is missing) ===
function Ensure-NasmForMsys2 {
    $msysUsrBin = "C:\msys64\usr\bin"
    $msysBash   = Join-Path $msysUsrBin "bash.exe"

    # Only act if MSYS2 is actually installed
    if (-not (Test-Path $msysUsrBin)) {
        Write-Host "[ERROR] NASM not found and MSYS2 is not installed at $msysUsrBin." -ForegroundColor Red
        Write-Host "[ERROR] Please install NASM manually (https://www.nasm.us/) and re-run the build." -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # Re-check NASM (maybe installed under ucrt64/mingw64)
    $nasm = Find-Tool "nasm" @($msysUsrBin, "C:\msys64\ucrt64\bin", "C:\msys64\mingw64\bin")
    if ($nasm) {
        Write-Host "[OK] NASM found: $nasm" -ForegroundColor Green
        return
    }

    Write-Host "[WARN] NASM not found, but MSYS2 is installed at $msysUsrBin" -ForegroundColor Yellow
    Write-Host "[WARN] This project needs NASM to assemble x86_64 output." -ForegroundColor Yellow

    if (-not (Test-Path $msysBash)) {
        Write-Host "[ERROR] Cannot find $msysBash to install NASM." -ForegroundColor Red
        Write-Host "[ERROR] Please install NASM manually and re-run the build." -ForegroundColor Red
        Pop-Location
        exit 1
    }

    $answer = Read-Host "Install NASM now via 'pacman -S --needed nasm'? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = "Y" }

    if ($answer -notmatch '^(?i)y(es)?$') {
        Write-Host "[ERROR] NASM is required. Build aborted by user." -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Write-Host "[INFO] Installing NASM via MSYS2 pacman..." -ForegroundColor Cyan
    & $msysBash -lc "pacman -S --needed --noconfirm nasm"
    $pacmanExit = $LASTEXITCODE

    $nasm = Find-Tool "nasm" @($msysUsrBin, "C:\msys64\ucrt64\bin", "C:\msys64\mingw64\bin")
    if ($pacmanExit -ne 0 -or -not $nasm) {
        Write-Host "[ERROR] NASM installation failed or NASM still not found. Aborting build." -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Write-Host "[OK] NASM installed: $nasm" -ForegroundColor Green
    $env:PATH = "$msysUsrBin;$env:PATH"
}

if (-not $gcc) {
    Write-Host "[ERROR] gcc not found! Please install GCC (via MSYS2: pacman -S mingw-w64-ucrt-x86_64-gcc or MinGW)." -ForegroundColor Red
    # === [SURGICAL ADD] When gcc is missing, also verify NASM via MSYS2 ===
    Ensure-NasmForMsys2
    Write-Host "[ERROR] gcc is still required. Please install GCC and re-run the build." -ForegroundColor Red
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
    & $bison -d -Wno-other -Wno-conflicts-sr -o "src/parser.tab.c" "src/parser.y"
}

if (Test-Path "src/lexer.l") {
    Write-Host "[2/3] Running Flex ($flex)..."
    & $flex -o "src/lexer.yy.c" "src/lexer.l"
}

Write-Host "[3/3] Compiling C source files with $gcc..."
$sources = @("src/main.c", "src/protocol.c", "src/ast.c", "src/semantic.c", "src/tac.c", "src/asm_x86_64.c")
if (Test-Path "src/parser.tab.c") { $sources += "src/parser.tab.c" }
if (Test-Path "src/lexer.yy.c") { $sources += "src/lexer.yy.c" }

& $gcc -O2 -Wall -Wextra -Iinclude -Isrc $sources -o "build/arabicc.exe"
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Build succeeded: build/arabicc.exe" -ForegroundColor Green
    $projectRoot = Split-Path -Parent $scriptDir
    foreach ($configuration in @("Debug", "Release")) {
        $destination = Join-Path $projectRoot "build\windows\x64\runner\$configuration\compiler\arabicc.exe"
        $destinationDirectory = Split-Path -Parent $destination
        if (Test-Path $destinationDirectory) {
            Copy-Item "build/arabicc.exe" $destination -Force
            Write-Host "[OK] Copied compiler to $destination" -ForegroundColor Green
        }
    }
} else {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    Pop-Location
    exit $LASTEXITCODE
}
Pop-Location
