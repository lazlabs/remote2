# Movie Room Remote
**LAZLAB Creations** — Single-file PWA theater remote for Home Assistant.

## Files
| File | Purpose |
|------|---------|
| `theater-remote.html` | Main app — the only file you edit/deploy |
| `manifest.json` | PWA manifest |
| `sw.js` | Service worker (offline cache) |
| `icon.svg` | App icon |
| `icon-192.svg` | App icon 192px |
| `index.html` | Redirect to app |
| `_headers` | Netlify/GitHub Pages CORS headers |
| `theater-scripts.yaml` | HA scripts — paste into Home Assistant |
| `movie-room-config.json` | Config import template |

## Quick Start
1. Paste `theater-scripts.yaml` scripts into HA (Settings → Automations & Scenes → Scripts)
2. Open `theater-remote.html` in a browser or serve locally:
   ```
   python -m http.server 8080
   ```
3. Go to `http://<your-pc-ip>:8080/theater-remote.html`
4. Tap ⚙️ → fill in your entity IDs → Save → Bake & deploy

## PC Agent
Download `pc-agent.py` and `install-agent.bat` from Settings → Downloads inside the app.
Run `install-agent.bat` as Administrator once to register it as a startup task and open the firewall.

## Deployment
Push all files to a GitHub repo, enable GitHub Pages on the `main` branch root.
The app will be available at `https://<username>.github.io/<repo>/`
