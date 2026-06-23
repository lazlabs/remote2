@echo off
:: Movie Room Remote - Uninstaller  |  LAZLAB Creations
title Movie Room - Uninstaller
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator required.
    timeout /t 4 /nobreak >nul
    exit /b 1
)

set AGENT_SVC=MovieRoomPCAgent
set SERVER_SVC=MovieRoomServer
set INSTALL_DIR=%~dp0
set NSSM_EXE=%INSTALL_DIR%nssm\nssm.exe

echo.
echo  Removing Movie Room Remote services...
echo.

if exist "%NSSM_EXE%" (
    "%NSSM_EXE%" stop   %AGENT_SVC%  >nul 2>&1
    "%NSSM_EXE%" remove %AGENT_SVC%  confirm >nul 2>&1
    "%NSSM_EXE%" stop   %SERVER_SVC% >nul 2>&1
    "%NSSM_EXE%" remove %SERVER_SVC% confirm >nul 2>&1
    echo  NSSM services removed
)

schtasks /delete /tn "%AGENT_SVC%"  /f >nul 2>&1
schtasks /delete /tn "%SERVER_SVC%" /f >nul 2>&1
echo  Scheduled tasks removed

for /f "tokens=2" %%i in ('tasklist /fi "imagename eq pythonw.exe" /fo list 2^>nul ^| findstr /i "PID"') do taskkill /pid %%i /f >nul 2>&1
for /f "tokens=2" %%i in ('tasklist /fi "imagename eq python.exe" /fo list 2^>nul ^| findstr /i "PID"') do taskkill /pid %%i /f >nul 2>&1

netsh advfirewall firewall delete rule name="%AGENT_SVC%"  >nul 2>&1
netsh advfirewall firewall delete rule name="%SERVER_SVC%" >nul 2>&1
echo  Firewall rules removed
echo.
echo  Done. Closing in 5 seconds...
timeout /t 5 /nobreak >nul
exit /b 0
