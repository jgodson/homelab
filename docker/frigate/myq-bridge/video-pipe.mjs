import fs from "node:fs";
import http from "node:http";

const listenHost = process.env.MYQ_VIDEO_PIPE_HOST || "0.0.0.0";
const listenPort = Number(process.env.MYQ_VIDEO_PIPE_PORT || 8091);
const sources = new Map([
  ["opener", process.env.MYQ_OPENER_PIPE || "/android-files/myq-opener.h264.pipe"],
  ["keypad", process.env.MYQ_KEYPAD_PIPE || "/android-files/myq-keypad.h264.pipe"]
].map(([name, filename]) => [name, {
  name,
  filename,
  clients: new Map(),
  buffer: Buffer.alloc(0),
  sps: null,
  pps: null,
  bytes: 0,
  chunks: 0,
  lastDataAt: 0,
  connected: false
}]));

function findStartCode(buffer, from = 0) {
  for (let index = from; index + 3 <= buffer.length; index += 1) {
    if (buffer[index] !== 0 || buffer[index + 1] !== 0) continue;
    if (buffer[index + 2] === 1) return { index, length: 3 };
    if (index + 3 < buffer.length && buffer[index + 2] === 0 && buffer[index + 3] === 1) {
      return { index, length: 4 };
    }
  }
  return null;
}

function writeClient(source, response, data) {
  if (response.destroyed || response.writableEnded) {
    source.clients.delete(response);
    return false;
  }
  response.write(data);
  if (response.writableLength <= 8 * 1024 * 1024) return true;
  source.clients.delete(response);
  response.destroy();
  return false;
}

function emitNal(source, nal, startCodeLength) {
  const type = nal[startCodeLength] & 0x1f;
  if (type === 7) source.sps = Buffer.from(nal);
  if (type === 8) source.pps = Buffer.from(nal);

  for (const [response, state] of source.clients) {
    if (!state.headersSent) {
      if (!source.sps || !source.pps) continue;
      if (!writeClient(source, response, source.sps)) continue;
      if (!writeClient(source, response, source.pps)) continue;
      state.headersSent = true;
      if (type === 7 || type === 8) continue;
    }
    writeClient(source, response, nal);
  }
}

function parseChunk(source, chunk) {
  source.buffer = Buffer.concat([source.buffer, chunk]);
  let first = findStartCode(source.buffer);
  if (!first) {
    if (source.buffer.length > 3) source.buffer = source.buffer.subarray(-3);
    return;
  }
  if (first.index > 0) source.buffer = source.buffer.subarray(first.index);

  while (true) {
    first = findStartCode(source.buffer);
    const next = findStartCode(source.buffer, first.length);
    if (!next) break;
    emitNal(source, source.buffer.subarray(0, next.index), first.length);
    source.buffer = source.buffer.subarray(next.index);
  }
}

function openSource(source) {
  const input = fs.createReadStream(source.filename);
  input.on("open", () => { source.connected = true; });
  input.on("data", chunk => {
    source.bytes += chunk.length;
    source.chunks += 1;
    source.lastDataAt = Date.now();
    parseChunk(source, chunk);
  });
  const reopen = error => {
    source.connected = false;
    source.buffer = Buffer.alloc(0);
    if (error && error.code !== "EINTR") console.error(`${source.name} pipe: ${error.message}`);
    setTimeout(() => openSource(source), 1_000).unref();
  };
  input.once("error", reopen);
  input.once("end", () => reopen());
}

for (const source of sources.values()) openSource(source);

function sendJson(response, status, value) {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
    "cache-control": "no-store"
  });
  response.end(body);
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${request.headers.host || "localhost"}`);
  if (url.pathname === "/health") {
    const now = Date.now();
    const ok = [...sources.values()].every(
      source => source.connected && source.lastDataAt > 0 && now - source.lastDataAt < 30_000
    );
    return sendJson(response, ok ? 200 : 503, {
      ok,
      streams: Object.fromEntries([...sources].map(([name, source]) => [name, {
        connected: source.connected,
        clients: source.clients.size,
        bytes: source.bytes,
        chunks: source.chunks,
        lastDataAgeMs: source.lastDataAt ? now - source.lastDataAt : null
      }]))
    });
  }

  const match = url.pathname.match(/^\/(opener|keypad)\.h264$/);
  if (!match) return sendJson(response, 404, { error: "Not found" });
  const source = sources.get(match[1]);
  response.writeHead(200, {
    "content-type": "video/h264",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff"
  });
  const state = { headersSent: false };
  source.clients.set(response, state);
  if (source.sps && source.pps) {
    if (writeClient(source, response, source.sps) && writeClient(source, response, source.pps)) {
      state.headersSent = true;
    }
  }
  const remove = () => source.clients.delete(response);
  request.once("close", remove);
  response.once("close", remove);
});

server.listen(listenPort, listenHost, () => {
  console.log(`myQ H.264 pipe server listening at http://${listenHost}:${listenPort}`);
});

function shutdown() {
  for (const source of sources.values()) {
    for (const client of source.clients.keys()) client.destroy();
  }
  server.close(() => process.exit(0));
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
