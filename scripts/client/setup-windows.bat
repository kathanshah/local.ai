@echo off
:: Stocky AI -- Windows Client Setup Launcher
:: Double-click this file to run the setup script.
:: It launches PowerShell with the correct execution policy.

echo.
echo ========================================
echo   Stocky AI -- Windows Client Setup
echo ========================================
echo.
echo Starting setup...
echo.

:: Get the directory where this .bat file lives
set "SCRIPT_DIR=%~dp0"

:: Launch PowerShell with Bypass policy, run the .ps1 script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-windows.ps1"

:: If PowerShell itself fails to launch, pause here
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Setup finished with errors. See above for details.
    echo.
    pause
)
