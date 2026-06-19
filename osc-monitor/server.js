// UDP → WebSocket bridge.
// Listens for OSC on UDP 8000 (where the Swift app sends), parses the
// minimal subset of OSC the app uses, forwards each packet to any
// connected browser as JSON. The browser page is served from the same
// HTTP port that hosts the WebSocket.

import dgram from 'node:dgram';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const UDP_PORT  = parseInt(process.env.OSC_PORT ?? '8000', 10);
const HTTP_PORT = parseInt(process.env.WEB_PORT ?? '9000', 10);

// --- static HTTP server (just serves index.html and friends) ---

const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.js':   'text/javascript; charset=utf-8',
    '.css':  'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
};

const httpServer = http.createServer((req, res) => {
    const urlPath = req.url === '/' ? '/index.html' : req.url.split('?')[0];
    const filePath = path.join(__dirname, urlPath);

    // Refuse anything that climbs out of the directory.
    if (!filePath.startsWith(__dirname)) {
        res.writeHead(403).end('Forbidden');
        return;
    }

    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404).end('Not found');
            return;
        }
        res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath)] ?? 'application/octet-stream' });
        res.end(data);
    });
});

const wss = new WebSocketServer({ server: httpServer });

httpServer.listen(HTTP_PORT, () => {
    console.log(`▶ Web UI:   http://localhost:${HTTP_PORT}`);
});

// --- UDP listener ---

const udp = dgram.createSocket('udp4');

udp.on('message', (msg, rinfo) => {
    try {
        const parsed = parseOSC(msg);
        const event = {
            t:       Date.now(),
            from:    `${rinfo.address}:${rinfo.port}`,
            address: parsed.address,
            args:    parsed.args,
        };
        const payload = JSON.stringify(event);
        for (const client of wss.clients) {
            if (client.readyState === 1) client.send(payload);
        }
    } catch (e) {
        console.error('OSC parse failed:', e.message, msg);
    }
});

udp.on('error', (e) => console.error('UDP error:', e));

udp.bind(UDP_PORT, () => {
    console.log(`▶ Listening for OSC on UDP ${UDP_PORT} (any consumer on this port will be displaced while the monitor runs)`);
});

// --- minimal OSC parser ---
// Handles OSC strings, type tag, and the int/float/string types this app uses.
// Bundles are not used by HeartRateMonitor's NativeOSCManager, so we don't parse them.

function parseOSC(buffer) {
    let offset = 0;

    const addrRead = readOSCString(buffer, offset);
    const address = addrRead.string;
    offset = addrRead.next;

    const tagRead = readOSCString(buffer, offset);
    const typeTag = tagRead.string;
    offset = tagRead.next;

    const args = [];
    for (let i = 1; i < typeTag.length; i++) {
        switch (typeTag[i]) {
            case 'i': args.push(buffer.readInt32BE(offset)); offset += 4; break;
            case 'f': args.push(buffer.readFloatBE(offset)); offset += 4; break;
            case 's': {
                const s = readOSCString(buffer, offset);
                args.push(s.string);
                offset = s.next;
                break;
            }
            // Unknown types: stop parsing args; better to surface what we have.
            default: i = typeTag.length;
        }
    }
    return { address, typeTag, args };
}

function readOSCString(buffer, offset) {
    let end = offset;
    while (end < buffer.length && buffer[end] !== 0) end++;
    const string = buffer.slice(offset, end).toString('utf8');
    // Strings are null-terminated and padded to 4-byte boundary.
    const consumed = (end - offset) + 1;
    const padded = Math.ceil(consumed / 4) * 4;
    return { string, next: offset + padded };
}
