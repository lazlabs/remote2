@echo off
:: ═══════════════════════════════════════════════════════════════════
::  Movie Room Remote — PC Agent Uninstaller
::  LAZLAB Creations
:: ═══════════════════════════════════════════════════════════════════

title Movie Room — PC Agent Uninstaller
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator required.
    pause & exit /b 1
)

set AGENT_NAME=MovieRoomPCAgent
set AGENT_DIR=%~dp0
set NSSM_EXE=%AGENT_DIR%nssm\nssm.exe

echo.
echo  Stopping and removing Movie Room PC Agent...
echo.

:: Stop and remove NSSM service if present
if exist "%NSSM_EXE%" (
    "%NSSM_EXE%" stop %AGENT_NAME% >nul 2>&1
    "%NSSM_EXE%" remove %AGENT_NAME% confirm >nul 2>&1
    echo  Service removed (NSSM)
)

:: Remove Task Scheduler entry
schtasks /delete /tn "%AGENT_NAME%" /f >nul 2>&1
echo  Scheduled task removed

:: Kill any running python process running the agent
for /f "tokens=2" %%i in ('tasklist /fi "imagename eq python.exe" /fo list ^| findstr /i "PID"') do (
    wmic process %%i get CommandLine 2>nul | findstr /i "pc-agent" >nul
    if !errorlevel! equ 0 taskkill /pid %%i /f >nul 2>&1
)
for /f "tokens=2" %%i in ('tasklist /fi "imagename eq pythonw.exe" /fo list ^| findstr /i "PID"') do (
    taskkill /pid %%i /f >nul 2>&1
)

:: Remove firewall rule
netsh advfirewall firewall delete rule name="%AGENT_NAME%" >nul 2>&1
echo  Firewall rule removed

echo.
echo  Done. PC Agent has been fully uninstalled.
echo.
pause
exit /b 0
