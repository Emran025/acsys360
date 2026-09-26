@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"

where gcc >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "C:\msys64\ucrt64\bin\gcc.exe" (
        set "PATH=C:\msys64\ucrt64\bin;!PATH!"
    ) else if exist "C:\msys64\mingw64\bin\gcc.exe" (
        set "PATH=C:\msys64\mingw64\bin;!PATH!"
    )
)

where bison >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "C:\msys64\usr\bin\bison.exe" (
        set "PATH=C:\msys64\usr\bin;!PATH!"
    )
)

where flex >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "C:\msys64\usr\bin\flex.exe" (
        set "PATH=C:\msys64\usr\bin;!PATH!"
    )
)

where gcc >nul 2>&1 || (echo [ERROR] gcc not found! Please install GCC (via MSYS2 or MinGW). & call :EnsureNasmForMsys2 & popd & exit /b 1)
where bison >nul 2>&1 || (echo [ERROR] bison not found! Please install Bison (via MSYS2 or winflexbison). & popd & exit /b 1)
where flex >nul 2>&1 || (echo [ERROR] flex not found! Please install Flex (via MSYS2 or winflexbison). & popd & exit /b 1)

if not exist build mkdir build
if not exist build\generated mkdir build\generated

echo [1/3] Running Bison...
if exist src\parser.y (
    bison -d -Wno-other -Wno-conflicts-sr -o build\generated\parser.tab.c src\parser.y
)

echo [2/3] Running Flex...
if exist src\lexer.l (
    flex -o build\generated\lexer.yy.c src\lexer.l
)

echo [3/3] Compiling C source files...
set SOURCES=src/main.c src/protocol.c src/protocol/protocol_json.c src/protocol/protocol_request.c src/protocol/protocol_response.c src/driver/compiler_driver.c src/ir/typed_ir.c src/runtime/interpreter.c src/backend/artifact_builder.c src/backend/toolchain.c src/ast.c src/semantic.c src/ir/tac.c src/backend/x86_64/asm_x86_64.c
if exist build\generated\parser.tab.c set SOURCES=!SOURCES! build\generated\parser.tab.c
if exist build\generated\lexer.yy.c set SOURCES=!SOURCES! build\generated\lexer.yy.c

gcc -O2 -Wall -Wextra -Iinclude -Isrc -Ibuild\generated !SOURCES! -o build\arabicc.exe
if %ERRORLEVEL% equ 0 (
    echo [OK] Build succeeded: build\arabicc.exe

    rem === [SURGICAL ADD] Copy compiler into Flutter runner build dirs ===
    set "PROJECT_ROOT=%~dp0.."
    for %%C in (Debug Release) do (
        set "DEST_DIR=!PROJECT_ROOT!\build\windows\x64\runner\%%C\compiler"
        if exist "!DEST_DIR!" (
            copy /Y "build\arabicc.exe" "!DEST_DIR!\arabicc.exe" >nul
            if !ERRORLEVEL! equ 0 (
                echo [OK] Copied compiler to !DEST_DIR!\arabicc.exe
            ) else (
                echo [WARN] Failed to copy compiler to !DEST_DIR!
            )
        )
    )
    rem === [END SURGICAL ADD] ===
) else (
    echo [ERROR] Build failed!
    popd
    exit /b %ERRORLEVEL%
)
popd
exit /b 0

rem === [SURGICAL ADD] NASM helper (invoked only when gcc is missing) ===
:EnsureNasmForMsys2
set "MSYS_USR_BIN=C:\msys64\usr\bin"
set "MSYS_BASH=%MSYS_USR_BIN%\bash.exe"

rem Only act if MSYS2 is actually installed
if not exist "%MSYS_USR_BIN%" (
    echo [ERROR] NASM not found and MSYS2 is not installed at %MSYS_USR_BIN%.
    echo [ERROR] Please install NASM manually ^(https://www.nasm.us/^) and re-run the build.
    popd
    exit /b 1
)

rem Re-check NASM ^(maybe installed under ucrt64/mingw64^)
set "NASM_FOUND="
where nasm >nul 2>&1 && set "NASM_FOUND=1"
if not defined NASM_FOUND if exist "%MSYS_USR_BIN%\nasm.exe" set "NASM_FOUND=1"
if not defined NASM_FOUND if exist "C:\msys64\ucrt64\bin\nasm.exe" set "NASM_FOUND=1"
if not defined NASM_FOUND if exist "C:\msys64\mingw64\bin\nasm.exe" set "NASM_FOUND=1"

if defined NASM_FOUND (
    echo [OK] NASM found.
    exit /b 0
)

echo [WARN] NASM not found, but MSYS2 is installed at %MSYS_USR_BIN%
echo [WARN] This project needs NASM to assemble x86_64 output.

if not exist "%MSYS_BASH%" (
    echo [ERROR] Cannot find %MSYS_BASH% to install NASM.
    echo [ERROR] Please install NASM manually and re-run the build.
    popd
    exit /b 1
)

set "ANSWER="
set /p "ANSWER=Install NASM now via 'pacman -S --needed nasm'? [Y/n] "
if not defined ANSWER set "ANSWER=Y"

echo %ANSWER% | findstr /R /I "^y\(es\)\?$" >nul
if errorlevel 1 (
    echo [ERROR] NASM is required. Build aborted by user.
    popd
    exit /b 1
)

echo [INFO] Installing NASM via MSYS2 pacman...
"%MSYS_BASH%" -lc "pacman -S --needed --noconfirm nasm"
set "PACMAN_EXIT=%ERRORLEVEL%"

set "NASM_FOUND="
where nasm >nul 2>&1 && set "NASM_FOUND=1"
if not defined NASM_FOUND if exist "%MSYS_USR_BIN%\nasm.exe" set "NASM_FOUND=1"

if not "%PACMAN_EXIT%"=="0" goto :NasmInstallFailed
if not defined NASM_FOUND goto :NasmInstallFailed

echo [OK] NASM installed.
set "PATH=%MSYS_USR_BIN%;!PATH!"
exit /b 0

:NasmInstallFailed
echo [ERROR] NASM installation failed or NASM still not found. Aborting build.
popd
exit /b 1
rem === [END SURGICAL ADD] ===
