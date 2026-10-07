#!/usr/bin/env node
// ==============================================================================
// MESH-AGENT.JS — Lightweight Remote Control Daemon for Multi-VM Mesh Workers
// Runs natively on Node.js without any npm dependencies.
// Repository: https://github.com/bluudzz/muse-multivm-mesh-tunnel
// ==============================================================================

const http = require('http');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = parseInt(process.env.MESH_AGENT_PORT || '20140', 10);
const AUTH_TOKEN = process.env.MESH_AUTH_TOKEN || '';
const WORKER_ID = process.env.WORKER_ID || 'unknown';

function verifyAuth(req, res) {
    if (!AUTH_TOKEN) return true; // If no token configured, allow (protected by reverse tunnel loopback)
    const authHeader = req.headers['authorization'] || '';
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const provided = match ? match[1].trim() : '';
    if (provided !== AUTH_TOKEN.trim()) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: 'Unauthorized: Invalid Mesh Auth Token' }));
        return false;
    }
    return true;
}

function parseJsonBody(req, callback) {
    let body = '';
    req.on('data', chunk => {
        body += chunk;
        if (body.length > 50 * 1024 * 1024) { // 50MB limit
            req.socket.destroy();
        }
    });
    req.on('end', () => {
        try {
            const data = body ? JSON.parse(body) : {};
            callback(null, data);
        } catch (err) {
            callback(err, null);
        }
    });
}

const server = http.createServer((req, res) => {
    // 1. Health check
    if (req.method === 'GET' && req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
            ok: true,
            role: 'mesh-agent',
            worker_id: WORKER_ID,
            hostname: os.hostname(),
            uptime: Math.floor(os.uptime()),
            loadavg: os.loadavg(),
            memory: {
                total: os.totalmem(),
                free: os.freemem()
            }
        }));
    }

    if (!verifyAuth(req, res)) return;

    // 2. Command execution
    if (req.method === 'POST' && req.url === '/exec') {
        parseJsonBody(req, (err, data) => {
            if (err || !data.command) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: 'Bad Request: "command" field is required' }));
            }

            const timeoutMs = parseInt(data.timeout || '60000', 10);
            exec(data.command, { timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024, shell: '/bin/bash' }, (error, stdout, stderr) => {
                res.writeHead(200, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({
                    ok: !error,
                    exitCode: error ? (error.code ?? 1) : 0,
                    stdout: stdout || '',
                    stderr: stderr || (error ? error.message : '')
                }));
            });
        });
        return;
    }

    // 3. Write file (push)
    if (req.method === 'POST' && req.url === '/file/write') {
        parseJsonBody(req, (err, data) => {
            if (err || !data.path || data.content === undefined) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: 'Bad Request: "path" and "content" are required' }));
            }

            try {
                const targetPath = data.path;
                fs.mkdirSync(path.dirname(targetPath), { recursive: true });
                const buf = Buffer.from(data.content, data.encoding || 'base64');
                fs.writeFileSync(targetPath, buf);
                if (data.mode) {
                    fs.chmodSync(targetPath, parseInt(data.mode, 8));
                }
                res.writeHead(200, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: true, path: targetPath, size: buf.length }));
            } catch (writeErr) {
                res.writeHead(500, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: writeErr.message }));
            }
        });
        return;
    }

    // 4. Read file (pull)
    if (req.method === 'GET' && req.url.startsWith('/file/read')) {
        const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
        const targetPath = parsedUrl.searchParams.get('path');
        if (!targetPath) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({ ok: false, error: 'Bad Request: "path" query parameter is required' }));
        }

        try {
            if (!fs.existsSync(targetPath)) {
                res.writeHead(404, { 'Content-Type': 'application/json' });
                return res.end(JSON.stringify({ ok: false, error: 'File not found' }));
            }
            const buf = fs.readFileSync(targetPath);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({
                ok: true,
                path: targetPath,
                size: buf.length,
                content: buf.toString('base64')
            }));
        } catch (readErr) {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            return res.end(JSON.stringify({ ok: false, error: readErr.message }));
        }
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: 'Endpoint not found' }));
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`[mesh-agent] Worker ${WORKER_ID} Control Daemon listening on 127.0.0.1:${PORT}`);
});
