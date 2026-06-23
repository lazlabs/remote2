@echo off
:: ═══════════════════════════════════════════════════════════════════
::  Movie Room Remote - PC Agent Installer  |  LAZLAB Creations
::  Run as Administrator. Fully automated - no prompts.
:: ═══════════════════════════════════════════════════════════════════
title Movie Room - PC Agent Installer
setlocal EnableDelayedExpansion

:: ── Require Administrator ──────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator. Right-click and choose "Run as administrator".
    timeout /t 5 /nobreak >nul
    exit /b 1
)

echo.
echo  Movie Room Remote - PC Agent Setup  ^|  LAZLAB Creations
echo  ════════════════════════════════════════════════════════
echo.

set AGENT_NAME=MovieRoomPCAgent
set AGENT_DIR=%~dp0
set AGENT_SCRIPT=%AGENT_DIR%pc-agent.py
set NSSM_DIR=%AGENT_DIR%nssm
set NSSM_EXE=%NSSM_DIR%\nssm.exe

:: ── Check Python ───────────────────────────────────────────────────
echo  [1/6] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  ERROR: Python not found. Install from python.org with "Add to PATH" checked.
    timeout /t 8 /nobreak >nul
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo         %%i

:: ── Download pc-agent.py if missing ───────────────────────────────
echo.
echo  [2/6] Checking pc-agent.py...
if not exist "%AGENT_SCRIPT%" (
    echo         Not found - downloading from GitHub...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lazlabs/movieroom/main/pc-agent.py' -OutFile '%AGENT_SCRIPT%' -UseBasicParsing" >nul 2>&1
    if not exist "%AGENT_SCRIPT%" (
        echo         Could not auto-download. Please download pc-agent.py from the
        echo         Movie Room Remote app: Settings - Downloads - PC Agent
        timeout /t 8 /nobreak >nul
        exit /b 1
    )
    echo         Downloaded pc-agent.py
) else (
    echo         pc-agent.py found
)

:: ── Install pyautogui ─────────────────────────────────────────────
echo.
echo  [3/6] Installing pyautogui...
python -m pip install pyautogui --quiet --disable-pip-version-check >nul 2>&1
if %errorlevel% equ 0 (echo         pyautogui ready) else (echo         WARNING: pyautogui failed - keystroke fallback will be used)

:: ── Windows Firewall ──────────────────────────────────────────────
echo.
echo  [4/6] Configuring Windows Firewall...
netsh advfirewall firewall delete rule name="%AGENT_NAME%" >nul 2>&1
netsh advfirewall firewall add rule name="%AGENT_NAME%" dir=in action=allow protocol=TCP localport=9876 profile=private >nul
if %errorlevel% equ 0 (echo         Port 9876 allowed) else (echo         WARNING: Firewall rule failed)

:: ── Get Python path ────────────────────────────────────────────────
for /f "usebackq tokens=*" %%i in (`where python`) do (
    set PYTHON_EXE=%%i
    goto :got_python
)
:got_python

:: Find pythonw.exe (no-window version) alongside python.exe
set PYTHONW_EXE=!PYTHON_EXE:python.exe=pythonw.exe!
if not exist "!PYTHONW_EXE!" set PYTHONW_EXE=!PYTHON_EXE!

:: ── Register as background service ────────────────────────────────
echo.
echo  [5/6] Registering background service...

:: Try NSSM first
if not exist "%NSSM_EXE%" (
    mkdir "%NSSM_DIR%" >nul 2>&1
    powershell -Command "Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile '%NSSM_DIR%\nssm.zip' -UseBasicParsing" >nul 2>&1
    if exist "%NSSM_DIR%\nssm.zip" (
        powershell -Command "Expand-Archive -Path '%NSSM_DIR%\nssm.zip' -DestinationPath '%NSSM_DIR%\extracted' -Force" >nul 2>&1
        for /r "%NSSM_DIR%\extracted" %%f in (nssm.exe) do (
            echo "%%f" | findstr /i "win64" >nul 2>&1 && copy /y "%%f" "%NSSM_EXE%" >nul 2>&1
        )
        if not exist "%NSSM_EXE%" (
            for /r "%NSSM_DIR%\extracted" %%f in (nssm.exe) do copy /y "%%f" "%NSSM_EXE%" >nul 2>&1
        )
        del "%NSSM_DIR%\nssm.zip" >nul 2>&1
    )
)

if exist "%NSSM_EXE%" (
    :: Remove old service cleanly
    "%NSSM_EXE%" stop %AGENT_NAME% >nul 2>&1
    "%NSSM_EXE%" remove %AGENT_NAME% confirm >nul 2>&1
    :: Install new service
    "%NSSM_EXE%" install %AGENT_NAME% "!PYTHON_EXE!" "%AGENT_SCRIPT%" >nul
    "%NSSM_EXE%" set %AGENT_NAME% DisplayName "Movie Room PC Agent" >nul
    "%NSSM_EXE%" set %AGENT_NAME% Description "LAZLAB Movie Room Remote - PC control agent" >nul
    "%NSSM_EXE%" set %AGENT_NAME% AppDirectory "%AGENT_DIR%" >nul
    "%NSSM_EXE%" set %AGENT_NAME% AppStdout "%AGENT_DIR%agent.log" >nul
    "%NSSM_EXE%" set %AGENT_NAME% AppStderr "%AGENT_DIR%agent.log" >nul
    "%NSSM_EXE%" set %AGENT_NAME% AppRotateFiles 1 >nul
    "%NSSM_EXE%" set %AGENT_NAME% AppRotateBytes 1048576 >nul
    "%NSSM_EXE%" set %AGENT_NAME% Start SERVICE_AUTO_START >nul
    "%NSSM_EXE%" start %AGENT_NAME% >nul
    echo         Service registered via NSSM (auto-start, no window)
    echo         Log: %AGENT_DIR%agent.log
) else (
    :: Task Scheduler fallback
    schtasks /delete /tn "%AGENT_NAME%" /f >nul 2>&1
    schtasks /create /tn "%AGENT_NAME%" /tr "\"!PYTHONW_EXE!\" \"%AGENT_SCRIPT%\"" /sc ONLOGON /ru "%USERNAME%" /rl HIGHEST /f >nul
    :: Start now without a window
    start "" /b "!PYTHONW_EXE!" "%AGENT_SCRIPT%"
    echo         Task registered via Task Scheduler (no window)
)

:: ── Show result ────────────────────────────────────────────────────
echo.
echo  [6/6] Your PC IP address for the remote app:
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set RAW=%%a
    set RAW=!RAW: =!
    echo         http://!RAW!:9876
)
echo.
echo  Setup complete! In the app: Settings - Kodi ^& PC Agent
echo  Set PC Agent URL to the http address above.
echo  Agent runs silently in the background - no windows.
echo.
echo  Closing in 10 seconds...
timeout /t 10 /nobreak >nul
exit /b 0
