OSC Monitor
===========

A pass-through viewer for the OSC stream the HeartRateMonitor macOS app sends
to UDP `127.0.0.1:8000`. A tiny Node bridge listens on that port, parses each
OSC packet, and forwards it to a browser over WebSocket. The browser page
shows three live player cards (BPM, freshness, heartbeat ring), a scrolling
raw-message log, and a soft drone pad with one tone per player.

What plays
----------
- A continuous low drone — slow LFO on amplitude, heavy reverb.
- Player 1 → low bass sine (C2).
- Player 2 → mid triangle pad (G3).
- Player 3 → high sine bell (E5).

Each player voice fades in when its OSC stream is alive (any
`/player/N/bpm` message in the last 4 s) and fades out when it goes quiet.

Run
---
```
cd osc-monitor
npm install      # once
npm start
```

Open http://localhost:9000 and click **Start audio** (browsers require a user
gesture before any audio plays).

Caveats
-------
- Only one process can own UDP 8000. While the monitor runs, other OSC
  consumers on that port (SuperCollider, Max, etc.) will not receive packets.
  Stop the monitor to release the port.
- The bridge parses the OSC subset HeartRateMonitor actually sends
  (string address, type tag, `i`/`f`/`s` args). Bundles aren't used by this
  app, so they aren't parsed.

Environment overrides
---------------------
- `OSC_PORT` — UDP port to listen on (default 8000)
- `WEB_PORT` — HTTP/WS port for the browser (default 9000)
