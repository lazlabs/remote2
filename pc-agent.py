"""
Movie Room Remote — PC Agent
Runs as a tiny local HTTP server on the gaming PC.
The theater remote POSTs to this to launch apps, send keystrokes, etc.

Setup:
  1. Install Python 3.x (already on most Windows machines)
  2. pip install pyautogui   (for keyboard/mouse control)
  3. Run:  python pc-agent.py
     Or use install-agent.bat to register as a startup task.

Default port: 9876
Set PC_AGENT_PORT environment variable to override.
"""

import http.server
import json
import os
import subprocess
import sys
import threading
import time

PORT = int(os.environ.get('PC_AGENT_PORT', 9876))

# ── APP COMMANDS ────────────────────────────────────────────────────────────
# Map command strings (sent from the remote) to what actually runs on Windows.
# Customize these paths to match your PC setup.
APP_MAP = {
    'kodi':    r'C:\Program Files\Kodi\Kodi.exe',
    'chrome':  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'firefox': r'C:\Program Files\Mozilla Firefox\firefox.exe',
    'vlc':     r'C:\Program Files\VideoLAN\VLC\vlc.exe',
    # Phone mirror apps — uncomment whichever you use:
    # 'mirror':  r'C:\Program Files\scrcpy\scrcpy.exe',          # scrcpy (Android)
    # 'mirror':  r'C:\Program Files\ApowerMirror\ApowerMirror.exe',
    # 'mirror':  r'C:\Program Files\LonelyScreen\LonelyScreen.exe',  # AirPlay receiver
    'mirror':  r'C:\Program Files\scrcpy\scrcpy.exe',
    'steam':   r'C:\Program Files (x86)\Steam\steam.exe',
    'plex':    r'C:\Program Files\Plex\Plex.exe',
    'spotify': r'C:\Users\{}\AppData\Roaming\Spotify\Spotify.exe'.format(os.environ.get('USERNAME','')),
}

# ── KEYBOARD MAP (for key: commands from d-pad) ─────────────────────────────
KEY_MAP = {
    'UP':        'up',
    'DOWN':      'down',
    'LEFT':      'left',
    'RIGHT':     'right',
    'RETURN':    'enter',
    'BACKSPACE': 'backspace',
    'SUPER':     'win',
    'F12':       'f12',
    'ESCAPE':    'esc',
    'SPACE':     'space',
}


class AgentHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Only log errors, not every request
        if '4' in str(args[1] if len(args) > 1 else '') or '5' in str(args[1] if len(args) > 1 else ''):
            print(f'[Agent] {fmt % args}')

    def send_json(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(body))
        # Allow requests from the local network (the remote app)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if self.path == '/ping':
            self.send_json(200, {'status': 'ok', 'agent': 'movie-room-pc-agent', 'version': '1.0'})
        else:
            self.send_json(404, {'error': 'not found'})

    def do_POST(self):
        if self.path != '/run':
            self.send_json(404, {'error': 'not found'})
            return

        length = int(self.headers.get('Content-Length', 0))
        try:
            body = json.loads(self.rfile.read(length))
            command = body.get('command', '').strip()
        except Exception:
            self.send_json(400, {'error': 'invalid json'})
            return

        result = self.handle_command(command)
        self.send_json(200, result)

    def handle_command(self, command):
        print(f'[Agent] Command: {command}')

        # ── key: prefix → send keystroke ──────────────────────────────────
        if command.startswith('key:'):
            key = command[4:].strip()
            mapped = KEY_MAP.get(key, key.lower())
            try:
                import pyautogui
                pyautogui.press(mapped)
                return {'ok': True, 'action': 'key', 'key': mapped}
            except ImportError:
                # Fallback: use PowerShell to send key
                ps = f'$wsh = New-Object -ComObject WScript.Shell; $wsh.SendKeys("{{{mapped.upper()}}}")'
                subprocess.Popen(['powershell', '-Command', ps], shell=True)
                return {'ok': True, 'action': 'key_ps', 'key': mapped}

        # ── type: prefix → type text ───────────────────────────────────────
        if command.startswith('type:'):
            text = command[5:]
            try:
                import pyautogui
                time.sleep(0.1)
                pyautogui.typewrite(text, interval=0.03)
                return {'ok': True, 'action': 'type', 'text': text}
            except ImportError:
                # PowerShell fallback
                safe = text.replace("'", "''")
                ps = f"$wsh = New-Object -ComObject WScript.Shell; $wsh.SendKeys('{safe}')"
                subprocess.Popen(['powershell', '-Command', ps], shell=True)
                return {'ok': True, 'action': 'type_ps', 'text': text}

        # ── volume: prefix → system volume ────────────────────────────────
        if command.startswith('volume:'):
            try:
                level = int(command.split(':')[1])
                # Requires nircmd: https://www.nirsoft.net/utils/nircmd.html
                subprocess.Popen(['nircmd', 'setsysvolume', str(int(level / 100 * 65535))])
                return {'ok': True, 'action': 'volume', 'level': level}
            except Exception as e:
                return {'ok': False, 'error': str(e)}

        # ── named app → launch ─────────────────────────────────────────────
        if command in APP_MAP:
            path = APP_MAP[command]
            if not os.path.exists(path):
                # Try launching by name (may be in PATH or Windows Store)
                try:
                    subprocess.Popen([command], shell=True)
                    return {'ok': True, 'action': 'launch_shell', 'command': command}
                except Exception as e:
                    return {'ok': False, 'error': f'Not found at {path}: {e}'}
            try:
                subprocess.Popen([path])
                return {'ok': True, 'action': 'launch', 'app': command, 'path': path}
            except Exception as e:
                return {'ok': False, 'error': str(e)}

        # ── arbitrary shell command (use with care) ────────────────────────
        if command.startswith('shell:'):
            cmd = command[6:]
            try:
                subprocess.Popen(cmd, shell=True)
                return {'ok': True, 'action': 'shell', 'command': cmd}
            except Exception as e:
                return {'ok': False, 'error': str(e)}

        return {'ok': False, 'error': f'Unknown command: {command}'}


def main():
    server = http.server.ThreadingHTTPServer(('0.0.0.0', PORT), AgentHandler)
    print(f'[Agent] Movie Room PC Agent running on http://0.0.0.0:{PORT}')
    print(f'[Agent] Local IP: check ipconfig for your 192.168.x.x address')
    print(f'[Agent] Press Ctrl+C to stop')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n[Agent] Stopped.')
        server.shutdown()


if __name__ == '__main__':
    main()
