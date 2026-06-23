@echo off
:: Movie Room Remote - PC Agent Uninstaller  |  LAZLAB Creations
title Movie Room - PC Agent Uninstaller
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator required.
    timeout /t 4 /nobreak >nul
    exit /b 1
)

set AGENT_NAME=MovieRoomPCAgent
set AGENT_DIR=%~dp0
set NSSM_EXE=%AGENT_DIR%nssm\nssm.exe

echo.
echo  Removing Movie Room PC Agent...

if exist "%NSSM_EXE%" (
    "%NSSM_EXE%" stop %AGENT_NAME% >nul 2>&1
    "%NSSM_EXE%" remove %AGENT_NAME% confirm >nul 2>&1
    echo  Service removed (NSSM)
)

schtasks /delete /tn "%AGENT_NAME%" /f >nul 2>&1
echo  Scheduled task removed

for /f "tokens=2" %%i in ('tasklist /fi "imagename eq pythonw.exe" /fo list 2^>nul ^| findstr /i "PID"') do (
    taskkill /pid %%i /f >nul 2>&1
)
for /f "tokens=2" %%i in ('tasklist /fi "imagename eq python.exe" /fo list 2^>nul ^| findstr /i "PID"') do (
    taskkill /pid %%i /f >nul 2>&1
)

netsh advfirewall firewall delete rule name="%AGENT_NAME%" >nul 2>&1
echo  Firewall rule removed
echo.
echo  Done. Closing in 5 seconds...
timeout /t 5 /nobreak >nul
exit /b 0
