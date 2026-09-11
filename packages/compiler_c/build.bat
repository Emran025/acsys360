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

where gcc >nul 2>&1 || (echo [ERROR] gcc not found! Please install GCC (via MSYS2 or MinGW). & popd & exit /b 1)
where bison >nul 2>&1 || (echo [ERROR] bison not found! Please install Bison (via MSYS2 or winflexbison). & popd & exit /b 1)
where flex >nul 2>&1 || (echo [ERROR] flex not found! Please install Flex (via MSYS2 or winflexbison). & popd & exit /b 1)

if not exist build mkdir build

echo [1/3] Running Bison...
if exist src\parser.y (
    bison -d -o src\parser.tab.c src\parser.y
)

echo [2/3] Running Flex...
if exist src\lexer.l (
    flex -o src\lexer.yy.c src\lexer.l
)

echo [3/3] Compiling C source files...
set SOURCES=src\main.c src\protocol.c src\ast.c
if exist src\parser.tab.c set SOURCES=!SOURCES! src\parser.tab.c
if exist src\lexer.yy.c set SOURCES=!SOURCES! src\lexer.yy.c

gcc -O2 -Wall -Wextra -Iinclude -Isrc !SOURCES! -o build\arabicc.exe
if %ERRORLEVEL% equ 0 (
    echo [OK] Build succeeded: build\arabicc.exe
) else (
    echo [ERROR] Build failed!
    popd
    exit /b %ERRORLEVEL%
)
popd
