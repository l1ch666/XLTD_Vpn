'use strict';
// Port of CoreProcessManager.cs
const { spawn }    = require('child_process');
const path         = require('path');
const fs           = require('fs');
const os           = require('os');
const net          = require('net');
const { intParam, strParam, TRANSPORT_VP8, TRANSPORT_SEI, TRANSPORT_VIDEO } = require('./parser');

const RUNTIME_DIR = path.join(os.homedir(), 'AppData', 'Roaming', 'XLTD_Vpn', 'runtime');
const SOCKS_HOST  = '127.0.0.1';
const SOCKS_PORT  = 10808;
const DEFAULT_DNS = '1.1.1.1:53';

let proc     = null;
let logCb    = null;  // (line) => void
let exitCb   = null;  // (code) => void

function isRunning() { return proc && !proc.killed; }

function onLog(cb)  { logCb  = cb; }
function onExit(cb) { exitCb = cb; }

function publish(line) {
  if (line && logCb) logCb(line.trim());
}

// ── tool path resolution ──────────────────────────────────────────────────
function resolveToolPath(fileName) {
  // In dev: alongside main.js
  // In built app: resources/tools/
  const candidates = [
    path.join(__dirname, '..', 'tools', fileName),
    path.join(__dirname, '..', fileName),
    path.join(process.resourcesPath || '', 'tools', fileName),
    path.join(process.resourcesPath || '', fileName),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  throw new Error(`Missing ${fileName}. Place it next to the app or in tools/.`);
}

// ── YAML builder ──────────────────────────────────────────────────────────
function yaml(value) { return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"` }

function buildYaml(config, socksPort) {
  const isMtsLink = config.carrier === 'mtslink';
  const dns       = strParam(config, 'dns', DEFAULT_DNS);
  const dataDir   = path.join(path.dirname(resolveToolPath('olcrtc.exe')), 'data');
  const lines = [
    'mode: cnc',
    'auth:',
    `  provider: ${yaml(config.carrier)}`,
    'room:',
    `  id: ${yaml(config.roomId)}`,
    `  channel: ${yaml(config.clientId)}`,
    'crypto:',
    `  key: ${yaml(config.keyHex)}`,
    'net:',
    `  transport: ${yaml(config.transport)}`,
    `  dns: ${yaml(dns)}`,
    'socks:',
    `  host: ${yaml(SOCKS_HOST)}`,
    `  port: ${socksPort}`,
    'liveness:',
    `  interval: ${yaml(strParam(config, 'liveness-interval', isMtsLink ? '20s' : '10s'))}`,
    `  timeout: ${yaml(strParam(config, 'liveness-timeout',   isMtsLink ? '60s' : '5s'))}`,
    `  failures: ${intParam(config, 'liveness-failures', 3)}`,
  ];

  // transport-specific
  if (config.transport === TRANSPORT_VP8) {
    lines.push('vp8:');
    lines.push(`  fps: ${intParam(config, 'vp8-fps', intParam(config, 'fps', 25))}`);
    lines.push(`  batch_size: ${intParam(config, 'vp8-batch', intParam(config, 'batch', 1))}`);
  } else if (config.transport === TRANSPORT_SEI) {
    lines.push('sei:');
    lines.push(`  fps: ${intParam(config, 'fps', intParam(config, 'sei-fps', isMtsLink ? 30 : 60))}`);
    lines.push(`  batch_size: ${intParam(config, 'batch', intParam(config, 'sei-batch', isMtsLink ? 8 : 64))}`);
    lines.push(`  fragment_size: ${intParam(config, 'frag', intParam(config, 'sei-frag', isMtsLink ? 700 : 900))}`);
    lines.push(`  ack_timeout_ms: ${intParam(config, 'ack-ms', intParam(config, 'sei-ack-ms', isMtsLink ? 10000 : 2000))}`);
  } else if (config.transport === TRANSPORT_VIDEO) {
    lines.push('video:');
    lines.push(`  codec: ${yaml(strParam(config, 'video-codec', 'qrcode'))}`);
    lines.push(`  width: ${intParam(config, 'video-w', intParam(config, 'video-width', isMtsLink ? 640 : 1080))}`);
    lines.push(`  height: ${intParam(config, 'video-h', intParam(config, 'video-height', isMtsLink ? 360 : 1080))}`);
    lines.push(`  fps: ${intParam(config, 'video-fps', isMtsLink ? 15 : 60)}`);
    lines.push(`  bitrate: ${yaml(strParam(config, 'video-bitrate', isMtsLink ? '1200k' : '5000k'))}`);
    lines.push(`  hw: ${yaml(strParam(config, 'video-hw', 'none'))}`);
    lines.push(`  qr_size: ${intParam(config, 'video-qr-size', 0)}`);
    lines.push(`  qr_recovery: ${yaml(strParam(config, 'video-qr-recovery', 'low'))}`);
    lines.push(`  tile_module: ${intParam(config, 'video-tile-module', 4)}`);
    lines.push(`  tile_rs: ${intParam(config, 'video-tile-rs', 20)}`);
    try {
      lines.push(`ffmpeg: ${yaml(resolveToolPath('ffmpeg.exe'))}`);
    } catch {}
  }

  lines.push(`data: ${yaml(dataDir)}`);
  lines.push('debug: false');
  return lines.join('\n') + '\n';
}

// ── start ─────────────────────────────────────────────────────────────────
function start(config) {
  if (isRunning()) throw new Error('Core is already running');

  const exe = resolveToolPath('olcrtc.exe');
  if (!fs.existsSync(RUNTIME_DIR)) fs.mkdirSync(RUNTIME_DIR, { recursive: true });
  const configPath = path.join(RUNTIME_DIR, 'client.yaml');
  fs.writeFileSync(configPath, buildYaml(config, SOCKS_PORT), 'utf8');

  const env = { ...process.env, PION_LOG_DISABLE: 'all' };
  if (config.carrier === 'mtslink') {
    const mp = (k, def) => strParam(config, k, def);
    if (mp('mts-force-video', '1'))   env['MTS_FORCE_VIDEO']  = mp('mts-force-video', '1');
    if (mp('mts-peer-update', '1'))   env['MTS_PEER_UPDATE']  = mp('mts-peer-update', '1');
    if (mp('mts-silent-audio', '1'))  env['MTS_SILENT_AUDIO'] = mp('mts-silent-audio', '1');
    if (mp('mts-video-test', ''))     env['MTS_VIDEO_TEST']   = mp('mts-video-test', '');
    if (mp('mts-video-codec', ''))    env['MTS_VIDEO_CODEC']  = mp('mts-video-codec', '');
  }

  proc = spawn(exe, [configPath], {
    cwd: path.dirname(exe),
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true
  });

  proc.stdout.on('data', buf => buf.toString('utf8').split('\n').forEach(publish));
  proc.stderr.on('data', buf => buf.toString('utf8').split('\n').forEach(publish));
  proc.on('exit', code => {
    proc = null;
    if (exitCb) exitCb(code);
  });

  publish('olcrtc.exe started');
}

// ── stop ──────────────────────────────────────────────────────────────────
function stop() {
  if (proc) {
    try { proc.kill('SIGTERM'); } catch {}
    proc = null;
  }
}

// ── SOCKS handshake probe ─────────────────────────────────────────────────
function trySocksHandshake(port) {
  return new Promise(resolve => {
    const sock = net.createConnection({ host: SOCKS_HOST, port }, () => {
      sock.write(Buffer.from([0x05, 0x01, 0x00]));
      sock.once('data', buf => {
        sock.destroy();
        resolve(buf.length === 2 && buf[0] === 0x05 && buf[1] === 0x00);
      });
      setTimeout(() => { sock.destroy(); resolve(false); }, 2000);
    });
    sock.on('error', () => resolve(false));
    sock.setTimeout(2000, () => { sock.destroy(); resolve(false); });
  });
}

async function waitForSocks(timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!isRunning()) return false;
    if (await trySocksHandshake(SOCKS_PORT)) return true;
    await new Promise(r => setTimeout(r, 500));
  }
  return false;
}

module.exports = { start, stop, isRunning, waitForSocks, onLog, onExit, SOCKS_HOST, SOCKS_PORT };
