// muse-bridge: OpenAI-compatible API -> local mailbox -> Muse worker agent.
// Listens on 127.0.0.1 only. Auth via bridge_key in config.json.
// POST /v1/chat/completions writes queue/req-<uuid>.json, then long-polls
// for queue/resp-<uuid>.json (written by the worker: {"content": "..."}).
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const CONFIG_PATH = '/home/hatch/muse-bridge/config.json';
const QUEUE_DIR = '/home/hatch/workspace/9router-bridge/queue';
const POLL_MS = 500;
const WAIT_MAX_MS = 900000;
const STALE_MS = 30 * 60 * 1000;

const loadConfig = () => JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

const MODELS = [
  { id: 'muse-spark-1.3', object: 'model', owned_by: 'muse-mailbox', created: 1788000000 },
];

function send(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

const reqPath = uuid => path.join(QUEUE_DIR, `req-${uuid}.json`);
const respPath = uuid => path.join(QUEUE_DIR, `resp-${uuid}.json`);
const claimPath = uuid => path.join(QUEUE_DIR, `req-${uuid}.json.claimed`);

function sweepStale() {
  try {
    const now = Date.now();
    for (const f of fs.readdirSync(QUEUE_DIR)) {
      const p = path.join(QUEUE_DIR, f);
      try {
        if (now - fs.statSync(p).mtimeMs > STALE_MS) fs.unlinkSync(p);
      } catch {}
    }
  } catch {}
}

function completionObject(uuid, model, content) {
  return {
    id: 'chatcmpl-' + uuid.replace(/-/g, ''),
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
    usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
  };
}

function sendStream(res, uuid, model, content) {
  res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
  const chunk = {
    id: 'chatcmpl-' + uuid.replace(/-/g, ''),
    object: 'chat.completion.chunk',
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [{ index: 0, delta: { role: 'assistant', content }, finish_reason: null }],
  };
  res.write(`data: ${JSON.stringify(chunk)}\n\n`);
  const done = { ...chunk, choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] };
  res.write(`data: ${JSON.stringify(done)}\n\n`);
  res.write('data: [DONE]\n\n');
  res.end();
}

async function waitForResponse(uuid) {
  const deadline = Date.now() + WAIT_MAX_MS;
  while (Date.now() < deadline) {
    try {
      const raw = fs.readFileSync(respPath(uuid), 'utf8');
      const parsed = JSON.parse(raw);
      if (typeof parsed.content === 'string') return parsed.content;
    } catch {}
    await new Promise(r => setTimeout(r, POLL_MS));
  }
  return null;
}

const server = http.createServer(async (req, res) => {
  try {
    const cfg = loadConfig();
    const url = new URL(req.url, 'http://x');

    if (url.pathname === '/health' && req.method === 'GET') {
      let depth = 0;
      try {
        depth = fs.readdirSync(QUEUE_DIR).filter(f => f.startsWith('req-') && f.endsWith('.json')).length;
      } catch {}
      return send(res, 200, { ok: true, mode: 'mailbox', queue_depth: depth });
    }
    if (url.pathname.startsWith('/v1/')) {
      const auth = req.headers['authorization'] || '';
      if (!cfg.bridge_key || auth !== `Bearer ${cfg.bridge_key}`) {
        return send(res, 401, { error: { message: 'invalid bridge key', type: 'auth_error' } });
      }
    }
    if (url.pathname === '/v1/models' && req.method === 'GET') {
      return send(res, 200, { object: 'list', data: MODELS });
    }
    if (url.pathname === '/v1/chat/completions' && req.method === 'POST') {
      sweepStale();
      let body;
      try { body = JSON.parse(await readBody(req)); }
      catch { return send(res, 400, { error: { message: 'invalid JSON body', type: 'invalid_request' } }); }

      const uuid = crypto.randomUUID();
      const envelope = {
        uuid,
        ts: new Date().toISOString(),
        model: body.model || 'muse-spark-1.3',
        messages: Array.isArray(body.messages) ? body.messages : [],
      };
      try {
        const lastUser = envelope.messages.filter(m => m.role === 'user').pop();
        fs.appendFileSync('/home/hatch/muse-bridge/requests.log',
          JSON.stringify({ ts: new Date().toISOString(), uuid, stream: !!body.stream,
            n_messages: envelope.messages.length,
            last_user: (lastUser && typeof lastUser.content === 'string' ? lastUser.content.slice(0, 120) : null) }) + '\n');
      } catch {}
      fs.mkdirSync(QUEUE_DIR, { recursive: true });
      const tmp = reqPath(uuid) + '.tmp';
      fs.writeFileSync(tmp, JSON.stringify(envelope));
      fs.renameSync(tmp, reqPath(uuid));

      let closed = false;
      req.on('close', () => { closed = true; });
      const content = await waitForResponse(uuid);
      try { fs.unlinkSync(reqPath(uuid)); } catch {}
      try { fs.unlinkSync(respPath(uuid)); } catch {}
      try { fs.unlinkSync(claimPath(uuid)); } catch {}
      if (closed) return;
      if (content === null) {
        return send(res, 504, { error: { message: 'mailbox timeout: no worker response in 900s', type: 'timeout' } });
      }
      if (body.stream) return sendStream(res, uuid, envelope.model, content);
      return send(res, 200, completionObject(uuid, envelope.model, content));
    }
    return send(res, 404, { error: { message: 'not found', type: 'not_found' } });
  } catch (e) {
    return send(res, 500, { error: { message: 'bridge error: ' + e.message, type: 'server_error' } });
  }
});

const cfg0 = loadConfig();
server.listen(cfg0.port || 20129, '127.0.0.1', () => {
  console.log(`muse-bridge (mailbox mode) listening on 127.0.0.1:${cfg0.port || 20129}`);
});
