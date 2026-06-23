@echo off
:: ═══════════════════════════════════════════════════════════════════
::  Movie Room Remote - Full Installer  |  LAZLAB Creations
::  Run as Administrator once.
::  Sets up PC Agent + local HTTP server as silent background services.
::  Access the remote at: http://YOUR_PC_IP:8181/theater-remote.html
:: ═══════════════════════════════════════════════════════════════════
title Movie Room - Installer
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Run as Administrator. Right-click and choose "Run as administrator".
    timeout /t 5 /nobreak >nul
    exit /b 1
)

echo.
echo  Movie Room Remote - Full Installer  ^|  LAZLAB Creations
echo  ══════════════════════════════════════════════════════════
echo.

set INSTALL_DIR=%~dp0
set AGENT_SCRIPT=%INSTALL_DIR%pc-agent.py
set SERVER_SCRIPT=%INSTALL_DIR%serve.py
set AGENT_SVC=MovieRoomPCAgent
set SERVER_SVC=MovieRoomServer
set NSSM_DIR=%INSTALL_DIR%nssm
set NSSM_EXE=%NSSM_DIR%\nssm.exe
set PORT=8181

:: ── Check Python ───────────────────────────────────────────────────
echo  [1/7] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  ERROR: Python not found. Install from python.org with "Add to PATH" checked.
    timeout /t 8 /nobreak >nul
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo         %%i

:: ── Find pc-agent.py ──────────────────────────────────────────────
echo.
echo  [2/7] Checking pc-agent.py...
if not exist "%AGENT_SCRIPT%" (
    for /d %%d in ("%INSTALL_DIR%*") do (
        if exist "%%d\pc-agent.py" (
            copy /y "%%d\pc-agent.py" "%AGENT_SCRIPT%" >nul
            echo         Found in subfolder - copied up
            goto :agent_found
        )
    )
    echo         ERROR: pc-agent.py not found. Download from Settings - Downloads in the app.
    timeout /t 10 /nobreak >nul
    exit /b 1
)
:agent_found
echo         pc-agent.py ready

:: ── Create serve.py (local HTTP server for the remote app) ─────────
echo.
echo  [3/7] Creating local HTTP server...
(
echo import http.server, os, sys
echo PORT = int(os.environ.get('MOVIE_ROOM_PORT', %PORT%^)^)
echo DIR  = os.path.dirname(os.path.abspath(__file__^)^)
echo os.chdir(DIR^)
echo class Handler(http.server.SimpleHTTPRequestHandler^):
echo     def log_message(self, fmt, *args^): pass
echo     def end_headers(self^):
echo         self.send_header('Access-Control-Allow-Origin','*'^)
echo         self.send_header('Access-Control-Allow-Private-Network','true'^)
echo         super(^).end_headers(^)
echo server = http.server.ThreadingHTTPServer(('0.0.0.0', PORT^), Handler^)
echo print(f'[Server] Movie Room serving on port {PORT}'^)
echo server.serve_forever(^)
) > "%SERVER_SCRIPT%"
echo         serve.py created

:: ── Install pyautogui ─────────────────────────────────────────────
echo.
echo  [4/7] Installing pyautogui...
python -m pip install pyautogui --quiet --disable-pip-version-check >nul 2>&1
if %errorlevel% equ 0 (echo         pyautogui ready) else (echo         WARNING: pyautogui failed - keystroke fallback will be used)

:: ── Windows Firewall ──────────────────────────────────────────────
echo.
echo  [5/7] Configuring Windows Firewall...
netsh advfirewall firewall delete rule name="%AGENT_SVC%" >nul 2>&1
netsh advfirewall firewall delete rule name="%SERVER_SVC%" >nul 2>&1
netsh advfirewall firewall add rule name="%AGENT_SVC%" dir=in action=allow protocol=TCP localport=9876 profile=private >nul
netsh advfirewall firewall add rule name="%SERVER_SVC%" dir=in action=allow protocol=TCP localport=%PORT% profile=private >nul
echo         Ports 9876 (agent) and %PORT% (server) allowed

:: ── Get Python paths ──────────────────────────────────────────────
for /f "usebackq tokens=*" %%i in (`where python`) do (
    set PYTHON_EXE=%%i
    goto :got_python
)
:got_python
set PYTHONW_EXE=!PYTHON_EXE:python.exe=pythonw.exe!
if not exist "!PYTHONW_EXE!" set PYTHONW_EXE=!PYTHON_EXE!

:: ── Download NSSM ─────────────────────────────────────────────────
echo.
echo  [6/7] Setting up background services...
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
    :: ── Install PC Agent service ──────────────────────────────────
    "%NSSM_EXE%" stop  %AGENT_SVC% >nul 2>&1
    "%NSSM_EXE%" remove %AGENT_SVC% confirm >nul 2>&1
    "%NSSM_EXE%" install %AGENT_SVC% "!PYTHON_EXE!" "%AGENT_SCRIPT%" >nul
    "%NSSM_EXE%" set %AGENT_SVC% AppDirectory "%INSTALL_DIR%" >nul
    "%NSSM_EXE%" set %AGENT_SVC% AppStdout "%INSTALL_DIR%agent.log" >nul
    "%NSSM_EXE%" set %AGENT_SVC% AppStderr "%INSTALL_DIR%agent.log" >nul
    "%NSSM_EXE%" set %AGENT_SVC% AppRotateFiles 1 >nul
    "%NSSM_EXE%" set %AGENT_SVC% AppRotateBytes 1048576 >nul
    "%NSSM_EXE%" set %AGENT_SVC% Start SERVICE_AUTO_START >nul
    "%NSSM_EXE%" start %AGENT_SVC% >nul
    :: ── Install HTTP Server service ───────────────────────────────
    "%NSSM_EXE%" stop  %SERVER_SVC% >nul 2>&1
    "%NSSM_EXE%" remove %SERVER_SVC% confirm >nul 2>&1
    "%NSSM_EXE%" install %SERVER_SVC% "!PYTHON_EXE!" "%SERVER_SCRIPT%" >nul
    "%NSSM_EXE%" set %SERVER_SVC% AppDirectory "%INSTALL_DIR%" >nul
    "%NSSM_EXE%" set %SERVER_SVC% AppStdout "%INSTALL_DIR%server.log" >nul
    "%NSSM_EXE%" set %SERVER_SVC% AppStderr "%INSTALL_DIR%server.log" >nul
    "%NSSM_EXE%" set %SERVER_SVC% AppRotateFiles 1 >nul
    "%NSSM_EXE%" set %SERVER_SVC% AppRotateBytes 1048576 >nul
    "%NSSM_EXE%" set %SERVER_SVC% Start SERVICE_AUTO_START >nul
    "%NSSM_EXE%" start %SERVER_SVC% >nul
    echo         Both services registered via NSSM (auto-start, no windows)
) else (
    :: Task Scheduler fallback
    schtasks /delete /tn "%AGENT_SVC%"  /f >nul 2>&1
    schtasks /delete /tn "%SERVER_SVC%" /f >nul 2>&1
    schtasks /create /tn "%AGENT_SVC%"  /tr "\"!PYTHONW_EXE!\" \"%AGENT_SCRIPT%\""  /sc ONLOGON /ru "%USERNAME%" /rl HIGHEST /f >nul
    schtasks /create /tn "%SERVER_SVC%" /tr "\"!PYTHONW_EXE!\" \"%SERVER_SCRIPT%\"" /sc ONLOGON /ru "%USERNAME%" /rl HIGHEST /f >nul
    start "" /b "!PYTHONW_EXE!" "%AGENT_SCRIPT%"
    start "" /b "!PYTHONW_EXE!" "%SERVER_SCRIPT%"
    echo         Both tasks registered via Task Scheduler (no windows)
)

:: ── Show result ────────────────────────────────────────────────────
echo.
echo  [7/7] Getting your PC IP address...
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set RAW=%%a
    set RAW=!RAW: =!
    if not "!RAW!"=="127.0.0.1" (
        echo  ┌─────────────────────────────────────────────────────┐
        echo  │  Remote URL:  http://!RAW!:%PORT%/theater-remote.html
        echo  │  PC Agent:    http://!RAW!:9876
        echo  └─────────────────────────────────────────────────────┘
    )
)
echo.
echo  Both services start automatically on login. No windows, no manual steps.
echo  Bookmark the Remote URL above on every device on your network.
echo.
echo  Closing in 15 seconds...
timeout /t 15 /nobreak >nul
exit /b 0
