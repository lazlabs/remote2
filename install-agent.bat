@echo off
:: ═══════════════════════════════════════════════════════════════════
::  Movie Room Remote — PC Agent Installer
::  LAZLAB Creations
::  Run as Administrator. Sets up pc-agent.py as a hidden background
::  Windows service using NSSM (Non-Sucking Service Manager).
::  No console windows. Starts automatically on login.
:: ═══════════════════════════════════════════════════════════════════

title Movie Room — PC Agent Installer
setlocal EnableDelayedExpansion

:: ── Require Administrator ──────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: This installer must be run as Administrator.
    echo  Right-click install-agent.bat and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║   Movie Room Remote — PC Agent Setup     ║
echo  ║   LAZLAB Creations                       ║
echo  ╚══════════════════════════════════════════╝
echo.

set AGENT_NAME=MovieRoomPCAgent
set AGENT_DIR=%~dp0
set AGENT_SCRIPT=%AGENT_DIR%pc-agent.py
set NSSM_URL=https://nssm.cc/release/nssm-2.24.zip
set NSSM_DIR=%AGENT_DIR%nssm
set NSSM_EXE=%NSSM_DIR%\nssm.exe

:: ── Check pc-agent.py exists ───────────────────────────────────────
if not exist "%AGENT_SCRIPT%" (
    echo  ERROR: pc-agent.py not found in %AGENT_DIR%
    echo  Make sure install-agent.bat and pc-agent.py are in the same folder.
    echo.
    pause
    exit /b 1
)

:: ── Check Python ───────────────────────────────────────────────────
echo  [1/6] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  ERROR: Python not found in PATH.
    echo  Install Python from python.org and check "Add to PATH" during setup.
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo         %%i found
echo.

:: ── Install pyautogui ─────────────────────────────────────────────
echo  [2/6] Installing pyautogui...
python -m pip install pyautogui --quiet --disable-pip-version-check
if %errorlevel% equ 0 (
    echo         pyautogui ready
) else (
    echo         WARNING: pyautogui install failed. Keystroke fallback will be used.
)
echo.

:: ── Windows Firewall rule ─────────────────────────────────────────
echo  [3/6] Configuring Windows Firewall...
netsh advfirewall firewall delete rule name="%AGENT_NAME%" >nul 2>&1
netsh advfirewall firewall add rule name="%AGENT_NAME%" dir=in action=allow protocol=TCP localport=9876 profile=private >nul
if %errorlevel% equ 0 (
    echo         Firewall rule added for port 9876 (Private network)
) else (
    echo         WARNING: Could not add firewall rule. You may need to allow port 9876 manually.
)
echo.

:: ── Download NSSM if needed ───────────────────────────────────────
echo  [4/6] Setting up background service runner (NSSM)...
if not exist "%NSSM_EXE%" (
    echo         Downloading NSSM...
    mkdir "%NSSM_DIR%" >nul 2>&1
    :: Use PowerShell to download
    powershell -Command "Invoke-WebRequest -Uri '%NSSM_URL%' -OutFile '%NSSM_DIR%\nssm.zip' -UseBasicParsing" >nul 2>&1
    if exist "%NSSM_DIR%\nssm.zip" (
        powershell -Command "Expand-Archive -Path '%NSSM_DIR%\nssm.zip' -DestinationPath '%NSSM_DIR%\extracted' -Force" >nul 2>&1
        :: Find the 64-bit exe inside the zip
        for /r "%NSSM_DIR%\extracted" %%f in (nssm.exe) do (
            if "%%~pf" neq "" (
                echo "%%f" | findstr /i "win64" >nul && copy "%%f" "%NSSM_EXE%" >nul 2>&1
            )
        )
        :: Fallback: just grab whichever one we find
        if not exist "%NSSM_EXE%" (
            for /r "%NSSM_DIR%\extracted" %%f in (nssm.exe) do (
                copy "%%f" "%NSSM_EXE%" >nul 2>&1
            )
        )
        del "%NSSM_DIR%\nssm.zip" >nul 2>&1
    )
)

if exist "%NSSM_EXE%" (
    echo         NSSM ready
    set USE_NSSM=1
) else (
    echo         NSSM unavailable (no internet?). Using Task Scheduler fallback.
    set USE_NSSM=0
)
echo.

:: ── Stop existing service/task if running ─────────────────────────
echo  [5/6] Registering background service...
if "%USE_NSSM%"=="1" (
    "%NSSM_EXE%" stop %AGENT_NAME% >nul 2>&1
    "%NSSM_EXE%" remove %AGENT_NAME% confirm >nul 2>&1
    :: Get Python path
    for /f "tokens=*" %%i in ('where python') do set PYTHON_EXE=%%i & goto :got_python
    :got_python
    "%NSSM_EXE%" install %AGENT_NAME% "!PYTHON_EXE!" "%AGENT_SCRIPT%"
    "%NSSM_EXE%" set %AGENT_NAME% DisplayName "Movie Room PC Agent"
    "%NSSM_EXE%" set %AGENT_NAME% Description "LAZLAB Movie Room Remote - PC control agent"
    "%NSSM_EXE%" set %AGENT_NAME% AppDirectory "%AGENT_DIR%"
    "%NSSM_EXE%" set %AGENT_NAME% AppStdout "%AGENT_DIR%agent.log"
    "%NSSM_EXE%" set %AGENT_NAME% AppStderr "%AGENT_DIR%agent.log"
    "%NSSM_EXE%" set %AGENT_NAME% AppRotateFiles 1
    "%NSSM_EXE%" set %AGENT_NAME% AppRotateBytes 1048576
    "%NSSM_EXE%" set %AGENT_NAME% Start SERVICE_AUTO_START
    "%NSSM_EXE%" start %AGENT_NAME%
    echo         Service registered and started (NSSM)
    echo         Logs: %AGENT_DIR%agent.log
) else (
    :: Task Scheduler fallback — hidden window via pythonw
    schtasks /delete /tn "%AGENT_NAME%" /f >nul 2>&1
    for /f "tokens=*" %%i in ('where pythonw 2^>nul') do set PYTHONW_EXE=%%i
    if not defined PYTHONW_EXE (
        :: pythonw.exe is usually alongside python.exe
        for /f "tokens=*" %%i in ('where python') do set PYTHON_EXE=%%i
        set PYTHONW_EXE=!PYTHON_EXE:python.exe=pythonw.exe!
    )
    if exist "!PYTHONW_EXE!" (
        schtasks /create /tn "%AGENT_NAME%" /tr "\"!PYTHONW_EXE!\" \"%AGENT_SCRIPT%\"" /sc ONLOGON /ru "%USERNAME%" /rl HIGHEST /f >nul
        :: Start it now without a window
        start "" /b "!PYTHONW_EXE!" "%AGENT_SCRIPT%"
        echo         Task registered (Task Scheduler) — no console window
    ) else (
        :: Last resort: start minimised
        schtasks /create /tn "%AGENT_NAME%" /tr "python \"%AGENT_SCRIPT%\"" /sc ONLOGON /ru "%USERNAME%" /rl HIGHEST /f >nul
        start "" /min python "%AGENT_SCRIPT%"
        echo         Task registered (Task Scheduler) — minimised window
    )
)
echo.

:: ── Show PC IP ────────────────────────────────────────────────────
echo  [6/6] Your PC's local IP address:
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set IP=%%a
    set IP=!IP: =!
    echo         !IP!
)
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║  Setup complete!                                             ║
echo  ║                                                              ║
echo  ║  In the Movie Room Remote app:                               ║
echo  ║  Settings → Kodi ^& PC Agent → PC Agent URL                  ║
echo  ║  Set to:  http://YOUR_IP_ABOVE:9876                          ║
echo  ║                                                              ║
echo  ║  The agent runs silently in the background and starts        ║
echo  ║  automatically when you log in. No console windows.         ║
echo  ║                                                              ║
echo  ║  To uninstall: run uninstall-agent.bat as Administrator      ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
pause
exit /b 0
