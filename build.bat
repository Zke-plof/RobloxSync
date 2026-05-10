@echo off
echo Building Roblox Sync...

REM Check if Rust is installed
where cargo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Rust is not installed. Please run install-rust.ps1 first
    pause
    exit /b 1
)

REM Build the project
echo Building Rust binary...
cargo build --release

if %ERRORLEVEL% EQU 0 (
    echo ✅ Build successful!
    echo Binary location: target\release\roblox-sync.exe
    echo.
    echo To test:
    echo   target\release\roblox-sync.exe --help
    echo.
    echo To create a test project:
    echo   target\release\roblox-sync.exe init TestGame
    echo   cd TestGame
    echo   ..\target\release\roblox-sync.exe serve
) else (
    echo ❌ Build failed!
    pause
    exit /b 1
)

pause
