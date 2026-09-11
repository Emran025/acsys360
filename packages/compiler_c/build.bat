@echo off
setlocal
pushd "%~dp0"
set MSYS_BIN=C:\msys64\usr\bin
set GCC_BIN=C:\msys64\ucrt64\bin
set PATH=%GCC_BIN%;%MSYS_BIN%;%PATH%

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
if exist src\parser.tab.c set SOURCES=%SOURCES% src\parser.tab.c
if exist src\lexer.yy.c set SOURCES=%SOURCES% src\lexer.yy.c

gcc -O2 -Wall -Wextra -Iinclude -Isrc %SOURCES% -o build\arabicc.exe
if %ERRORLEVEL% equ 0 (
    echo [OK] Build succeeded: build\arabicc.exe
) else (
    echo [ERROR] Build failed!
    popd
    exit /b %ERRORLEVEL%
)
popd
