'use strict';
const fs   = require('fs');
const path = require('path');
const os   = require('os');

const DATA_DIR  = path.join(os.homedir(), 'AppData', 'Roaming', 'XLTD_Vpn');
const PROFILES_FILE = path.join(DATA_DIR, 'windows-profiles.json');

function ensureDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

function load() {
  ensureDir();
  try {
    if (!fs.existsSync(PROFILES_FILE)) return [];
    return JSON.parse(fs.readFileSync(PROFILES_FILE, 'utf8')) || [];
  } catch { return []; }
}

function save(profiles) {
  ensureDir();
  const seen = new Set();
  const ordered = profiles.filter(p => {
    if (!p.link || seen.has(p.id)) return false;
    seen.add(p.id); return true;
  });
  fs.writeFileSync(PROFILES_FILE, JSON.stringify(ordered, null, 2), 'utf8');
  return ordered;
}

module.exports = { load, save, DATA_DIR };
