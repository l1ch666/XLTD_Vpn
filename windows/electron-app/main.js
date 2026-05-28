'use strict';
const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path    = require('path');
const core    = require('./services/core');
const proxy   = require('./services/proxy');
const profs   = require('./services/profiles');
const parser  = require('./services/parser');

const APP_VERSION = '0.6.0-beta';

let win = null;
let routeMode = 0;   // 0=SOCKS, 1=User Proxy, 2=Full Tunnel (future)
let connecting = false;

// ─── Window ───────────────────────────────────────────────────────────────
function createWindow() {
  win = new BrowserWindow({
    width:  1200,
    height: 780,
    minWidth:  940,
    minHeight: 620,
    frame: false,              // custom title bar
    transparent: false,
    backgroundColor: '#0E1014',
    show: false,
    icon: path.join(__dirname, 'assets', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    }
  });

  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  win.once('ready-to-show', () => {
    win.show();
  });

  win.on('closed', () => { win = null; });
}

// ─── App lifecycle ────────────────────────────────────────────────────────
app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  cleanup();
  app.quit();
});

app.on('before-quit', cleanup);

function cleanup() {
  try { proxy.restore(); } catch {}
  try { core.stop();    } catch {}
}

// ─── Core events → renderer ───────────────────────────────────────────────
core.onLog(line => {
  if (win && !win.isDestroyed()) win.webContents.send('core:log', line);
});

core.onExit(code => {
  connecting = false;
  try { proxy.restore(); } catch {}
  if (win && !win.isDestroyed())
    win.webContents.send('core:exited', code);
});

// ─── IPC handlers ─────────────────────────────────────────────────────────

// Window controls (frameless)
ipcMain.on('win:minimize', () => win?.minimize());
ipcMain.on('win:maximize', () => { win?.isMaximized() ? win.unmaximize() : win.maximize(); });
ipcMain.on('win:close',    () => win?.close());

// App info
ipcMain.handle('app:info', () => ({
  version:    APP_VERSION,
  socksHost:  core.SOCKS_HOST,
  socksPort:  core.SOCKS_PORT,
}));

// Profiles
ipcMain.handle('profiles:load',   () => profs.load());
ipcMain.handle('profiles:save',   (_e, profile) => {
  const list = profs.load();
  const idx = list.findIndex(p => p.id === profile.id);
  if (idx >= 0) list[idx] = profile; else list.push(profile);
  return profs.save(list);
});
ipcMain.handle('profiles:delete', (_e, id) => {
  const list = profs.load().filter(p => p.id !== id);
  return profs.save(list);
});

// Parse link (validate in main process)
ipcMain.handle('link:parse', (_e, raw) => {
  try {
    const cfg = parser.parse(raw);
    return { ok: true, config: cfg };
  } catch (e) {
    return { ok: false, error: e.message };
  }
});

// Route mode
ipcMain.handle('route:get', () => routeMode);
ipcMain.on('route:set', (_e, mode) => { routeMode = mode; });

// Connect / disconnect
ipcMain.handle('core:connect', async (_e, link) => {
  if (connecting) return { ok: false, error: 'already connecting' };
  connecting = true;
  try {
    let config;
    try { config = parser.parse(link); } catch (e) { connecting = false; return { ok: false, error: e.message }; }

    core.start(config);
    const ready = await core.waitForSocks(68000);
    connecting = false;
    if (!ready) {
      core.stop();
      return { ok: false, error: core.isRunning() ? 'SOCKS timeout — VPN core still running but SOCKS not ready' : 'Core exited before SOCKS ready' };
    }

    // Route mode side effects
    if (routeMode === 1) {
      try { proxy.apply(core.SOCKS_HOST, core.SOCKS_PORT); }
      catch (e) { return { ok: true, warning: 'Connected but proxy apply failed: ' + e.message }; }
    }

    return { ok: true };
  } catch (e) {
    connecting = false;
    try { proxy.restore(); } catch {}
    try { core.stop();    } catch {}
    return { ok: false, error: e.message };
  }
});

ipcMain.handle('core:disconnect', () => {
  connecting = false;
  try { proxy.restore(); } catch {}
  try { core.stop();    } catch {}
  return { ok: true };
});

ipcMain.handle('core:status', () => ({ running: core.isRunning() }));
