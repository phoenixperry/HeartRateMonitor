# Running the OSC monitor

The whole thing lives in this folder on disk:

```
/Users/phoenixperry/Documents/GitHub/beat_piece/HeartRateMonitor/osc-monitor/
```

It is a small Node app: a UDP listener on port **8000** (where the Swift HeartRateMonitor app sends OSC) that forwards every packet to the browser over a WebSocket, plus a static HTML page served on port **9000**.

---

## One-time setup

```bash
cd /Users/phoenixperry/Documents/GitHub/beat_piece/HeartRateMonitor/osc-monitor
npm install
```

Installs the only dependency (`ws`). You only need to do this once, or whenever you reclone the repo.

---

## Start the server

```bash
cd /Users/phoenixperry/Documents/GitHub/beat_piece/HeartRateMonitor/osc-monitor
npm start
```

You should see:

```
▶ Web UI:   http://localhost:9000
▶ Listening for OSC on UDP 8000 …
```

Then open the page:

```bash
open http://localhost:9000
```

Click **▶ Start audio** in the page (browsers require a user gesture before audio plays).

---

## Stop the server

In the terminal where it's running, press `Ctrl + C`.

If you can't find the terminal (e.g. you started it in the background), kill it by port:

```bash
lsof -i :9000 -t | xargs kill
lsof -i :8000 -t | xargs kill
```

The first frees the web port; the second frees the UDP port.

---

## Run on different ports

Override with env vars if 8000 or 9000 is in use:

```bash
OSC_PORT=8001 WEB_PORT=9001 npm start
```

The web page will follow whichever port it's served from — no extra config needed.

---

## Common issues

- **The browser shows "disconnected — retrying"** → the Node server isn't running. Start it.
- **The page loads but no OSC arrives** → something else owns UDP 8000. Stop the other app, or run the monitor on a different port and re-point the Swift app there.
- **No sound after clicking Start audio** → the browser blocked the audio context until you interacted. Click anywhere in the page once, then click Start audio again.
- **"npm: command not found"** → install Node from https://nodejs.org, or `brew install node` if you use Homebrew.

---

## Wiping the saved patch

The page auto-saves your synth + FX settings to `localStorage`. To start fresh, open the browser console (Cmd + Option + I) and run:

```js
localStorage.removeItem('beat_piece_osc_monitor_patch_v1');
location.reload();
```
