'use strict';
/* ═══════════════════════════════════════════════════════════════════════
   XLTD VPN — renderer (app.js)
   All UI logic lives here. State is minimal and explicit.
═══════════════════════════════════════════════════════════════════════ */

// ── State ─────────────────────────────────────────────────────────────────
const state = {
  tab:        'home',
  profiles:   [],
  selected:   null,        // active profile id (connected / editing)
  connected:  false,
  connecting: false,
  routeMode:  0,           // 0=SOCKS, 1=UserProxy, 2=Tunnel
  info:       { version: '', socksHost: '127.0.0.1', socksPort: 10808 },
  rx: 0, tx: 0, lat: 0, upSec: 0,
  logs:       [],          // { ts, tag, msg, level }
  miniLogs:   [],
  uptimeTimer: null,
};

// ── Boot ──────────────────────────────────────────────────────────────────
async function boot() {
  state.info     = await api.getInfo();
  state.profiles = await api.loadProfiles();
  state.routeMode= await api.getRouteMode();

  document.getElementById('appVer').textContent = 'v' + state.info.version;
  document.getElementById('railSocks').textContent =
    state.info.socksHost + ':' + state.info.socksPort;

  // Core event listeners
  api.onCoreLog(handleCoreLog);
  api.onCoreExited(handleCoreExited);

  renderPage();
}

// ── Tab routing ───────────────────────────────────────────────────────────
function switchTab(tab) {
  state.tab = tab;
  document.querySelectorAll('.railitem').forEach(el => {
    el.classList.toggle('active', el.dataset.tab === tab);
  });
  renderPage();
}

function renderPage() {
  const main = document.getElementById('main');
  main.innerHTML = '';
  switch (state.tab) {
    case 'home':     buildHome(main);     break;
    case 'profiles': buildProfiles(main); break;
    case 'traffic':  buildTraffic(main);  break;
    case 'settings': buildSettings(main); break;
    case 'log':      buildLog(main);      break;
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  HOME PAGE
// ═════════════════════════════════════════════════════════════════════════
function buildHome(root) {
  // ── Status hero ──
  root.appendChild(buildStatusRow());

  // ── Two columns: profiles + mini log ──
  const two = el('div', 'two-col');

  // Left: profiles
  const profCard = card();
  profCard.appendChild(cardHead('ПРОФИЛИ', '+ добавить', () => switchTab('profiles')));
  const listEl = buildProfileList(true);
  listEl.style.maxHeight = '260px';
  profCard.appendChild(listEl);
  two.appendChild(profCard);

  // Right: mini log
  const logCard = card();
  logCard.appendChild(cardHead('СОБЫТИЯ', 'все →', () => switchTab('log')));
  const mlEl = el('div', 'log-box mini-log');
  mlEl.id = 'miniLog';
  mlEl.style.maxHeight = '260px';
  state.miniLogs.slice(-60).forEach(l => mlEl.appendChild(renderLogLine(l)));
  mlEl.scrollTop = 99999;
  logCard.appendChild(mlEl);
  two.appendChild(logCard);

  root.appendChild(two);

  // ── Route + connect bar ──
  root.appendChild(buildRouteRow());
}

function buildStatusRow() {
  const row = el('div', 'status-row');

  const left = el('div', 'status-left');

  // Badge
  const badge = el('div', 'status-badge' +
    (state.connected ? ' connected' : state.connecting ? ' connecting' : ''));
  badge.id = 'statusBadge';
  const dot  = el('span', 'dot'); badge.appendChild(dot);
  const txt  = el('span');
  txt.id = 'statusTxt';
  txt.textContent = state.connected ? 'CONNECTED' : state.connecting ? 'CONNECTING...' : 'DISCONNECTED';
  badge.appendChild(txt);
  left.appendChild(badge);

  // Speed
  const speed = el('div', 'status-speed');
  speed.innerHTML = `<span class="arrow">↓</span>
    <span class="val" id="speedVal">${state.connected ? formatSpeed(state.rx) : '—'}</span>
    <span class="unit">${state.connected ? speedUnit(state.rx) : ''}</span>`;
  left.appendChild(speed);

  // Context line
  const line = el('div', 'status-line');
  line.id = 'statusLine';
  const prof = activeProfile();
  line.innerHTML = prof
    ? `<b>${esc(prof.carrier)}</b> · ${esc(prof.transport)} · ${esc(prof.name || 'Profile')}`
    : 'Выберите профиль и нажмите Connect';
  left.appendChild(line);

  row.appendChild(left);

  // Right: session + connect btn
  const right = el('div', 'status-right');

  const sess = el('div', 'status-sess');
  sess.id = 'sessionInfo';
  if (state.connected) {
    sess.innerHTML = `SOCKS <b>${state.info.socksHost}:${state.info.socksPort}</b>`;
  } else {
    sess.textContent = 'SOCKS ' + state.info.socksHost + ':' + state.info.socksPort;
  }
  right.appendChild(sess);

  const btn = el('button', 'pill-btn' + (state.connected ? ' danger' : ''));
  btn.id = 'connectBtn';
  btn.textContent = state.connected ? 'Отключить' : 'Connect';
  btn.disabled = state.connecting;
  btn.addEventListener('click', toggleConnect);
  right.appendChild(btn);

  row.appendChild(right);
  return row;
}

function buildRouteRow() {
  const row = el('div', 'route-row');

  const label = el('span', 'route-label');
  label.textContent = 'Маршрут';
  row.appendChild(label);

  const chips = el('div', 'route-chips');
  const modes = ['SOCKS Only', 'User Proxy (β)', 'Full Tunnel (β)'];
  modes.forEach((m, i) => {
    const c = el('div', 'route-chip' + (state.routeMode === i ? ' on' : ''));
    c.textContent = m;
    c.addEventListener('click', () => {
      state.routeMode = i;
      api.setRouteMode(i);
      chips.querySelectorAll('.route-chip').forEach((ch, j) =>
        ch.classList.toggle('on', j === i));
    });
    chips.appendChild(c);
  });
  row.appendChild(chips);

  const hint = el('div', 'route-hint');
  hint.textContent = state.routeMode === 2 ? 'Требуются права администратора' : '';
  row.appendChild(hint);

  return row;
}

// ═════════════════════════════════════════════════════════════════════════
//  PROFILES PAGE
// ═════════════════════════════════════════════════════════════════════════
function buildProfiles(root) {
  root.appendChild(pageHead('Профили', 'MANAGE'));

  const list = card();
  list.style.flex = '0 0 auto';
  list.appendChild(cardHead('ВСЕ ПРОФИЛИ', null, null));
  list.appendChild(buildProfileList(false));
  root.appendChild(list);

  root.appendChild(buildEditorCard());
}

function buildProfileList(compact) {
  const ul = el('ul', 'profile-list');
  if (state.profiles.length === 0) {
    const empty = el('div', 'empty-state');
    empty.innerHTML = `<svg viewBox="0 0 24 24"><path d="M8 6h13M8 12h13M8 18h5"/></svg>
      <span>Нет профилей</span>
      <span style="color:var(--dim)">Нажмите + добавить</span>`;
    ul.appendChild(empty);
    return ul;
  }
  state.profiles.forEach(p => {
    const li = el('li', 'profile-item' + (state.selected === p.id ? ' active' : ''));
    li.innerHTML = `<span class="indicator"></span>
      <div class="info">
        <div class="p-name">${esc(p.name || 'Без названия')}</div>
        <div class="p-meta">${esc(p.carrier || '—')} · ${esc(p.transport || '—')}</div>
      </div>`;
    li.addEventListener('click', () => selectProfile(p, li));
    ul.appendChild(li);
  });
  return ul;
}

function buildEditorCard() {
  const c = card();
  c.appendChild(cardHead('РЕДАКТОР', null, null));

  const nameGroup = el('div', 'input-group');
  const nameLabel = el('label', 'input-label'); nameLabel.textContent = 'Название'; nameGroup.appendChild(nameLabel);
  const nameInput = el('input'); nameInput.type = 'text'; nameInput.id = 'ed-name';
  nameInput.placeholder = 'Название профиля'; nameGroup.appendChild(nameInput);
  c.appendChild(nameGroup);

  const linkGroup = el('div', 'input-group');
  linkGroup.style.marginTop = '10px';
  const linkLabel = el('label', 'input-label'); linkLabel.textContent = 'Ссылка olcrtc://'; linkGroup.appendChild(linkLabel);
  const linkInput = el('textarea'); linkInput.id = 'ed-link';
  linkInput.placeholder = 'olcrtc://carrier?transport<params>@room#64hexkey$comment';
  linkGroup.appendChild(linkInput);
  c.appendChild(linkGroup);

  // Fill editor with selected profile
  const prof = state.profiles.find(p => p.id === state.selected);
  if (prof) {
    nameInput.value = prof.name || '';
    linkInput.value = prof.link || '';
  }

  const actions = el('div', 'editor-actions');

  const newBtn = el('button', 'pill-btn secondary sm');
  newBtn.textContent = 'Новый';
  newBtn.addEventListener('click', () => { state.selected = null; nameInput.value = ''; linkInput.value = ''; });
  actions.appendChild(newBtn);

  if (state.selected) {
    const delBtn = el('button', 'pill-btn danger sm');
    delBtn.textContent = 'Удалить';
    delBtn.addEventListener('click', () => deleteProfile(state.selected));
    actions.appendChild(delBtn);
  }

  const saveBtn = el('button', 'pill-btn sm');
  saveBtn.textContent = 'Сохранить';
  saveBtn.addEventListener('click', () => saveProfileFromEditor(nameInput.value, linkInput.value));
  actions.appendChild(saveBtn);

  c.appendChild(actions);
  return c;
}

// ═════════════════════════════════════════════════════════════════════════
//  TRAFFIC PAGE
// ═════════════════════════════════════════════════════════════════════════
function buildTraffic(root) {
  root.appendChild(pageHead('Трафик', 'LIVE METRICS'));

  // 4 metric cards
  const grid = el('div', 'metrics-grid');
  grid.id = 'metricsGrid';
  grid.appendChild(metricCard('↓ ВХОДЯЩИЙ',  '—', '', 'metricRx'));
  grid.appendChild(metricCard('↑ ИСХОДЯЩИЙ', '—', '', 'metricTx'));
  grid.appendChild(metricCard('ЗАДЕРЖКА',    '—', '', 'metricLat'));
  grid.appendChild(metricCard('АПТАЙМ',      '—', '', 'metricUp'));
  root.appendChild(grid);

  // Full log
  const logCard = card();
  logCard.style.flex = '1';
  logCard.style.minHeight = '0';
  logCard.style.display = 'flex';
  logCard.style.flexDirection = 'column';
  logCard.appendChild(cardHead('RUNTIME LOG', null, null));
  const logBox = el('div', 'log-box flex-1');
  logBox.id = 'logBoxTraffic';
  logBox.style.maxHeight = '420px';
  state.logs.forEach(l => logBox.appendChild(renderLogLine(l)));
  logBox.scrollTop = 99999;
  logCard.appendChild(logBox);
  root.appendChild(logCard);
}

function metricCard(label, val, sub, id) {
  const c = el('div', 'metric-card');
  const l = el('div', 'metric-label'); l.textContent = label; c.appendChild(l);
  const v = el('div', 'metric-val');   v.id = id; v.textContent = val; c.appendChild(v);
  if (sub) { const s = el('div', 'metric-sub'); s.textContent = sub; c.appendChild(s); }
  const sp = el('div', 'spark');
  for (let i = 0; i < 8; i++) sp.appendChild(el('span'));
  c.appendChild(sp);
  return c;
}

// ═════════════════════════════════════════════════════════════════════════
//  SETTINGS PAGE
// ═════════════════════════════════════════════════════════════════════════
function buildSettings(root) {
  root.appendChild(pageHead('Настройки', 'CONFIGURATION'));

  const c = card();
  c.appendChild(cardHead('ROUTE MODE', null, null));

  const desc = el('p');
  desc.style.color = 'var(--muted)';
  desc.style.fontSize = '12px';
  desc.style.marginBottom = '14px';
  desc.textContent = 'Выберите режим маршрутизации до подключения.';
  c.appendChild(desc);

  const chips = el('div', 'chips flex-col gap-8');
  const modes = [
    { id: 0, name: 'SOCKS Only',         desc: 'Только SOCKS5 прокси на 127.0.0.1:10808. Настройте браузер вручную.' },
    { id: 1, name: 'Windows User Proxy (β)', desc: 'Автоматически устанавливает SOCKS прокси в настройках Windows.' },
    { id: 2, name: 'Full Tunnel / Wintun (β)', desc: 'TUN-адаптер, весь трафик через VPN. Требует прав администратора.' },
  ];
  modes.forEach(m => {
    const row = el('div', 'flex gap-12');
    row.style.padding = '12px 14px';
    row.style.borderRadius = '10px';
    row.style.border = '1px solid ' + (state.routeMode === m.id ? 'var(--primary)' : 'var(--border)');
    row.style.background = state.routeMode === m.id ? 'var(--surface2)' : 'transparent';
    row.style.cursor = 'pointer';
    row.style.transition = 'all .12s';

    const dot = el('span');
    dot.style.cssText = 'width:14px;height:14px;border-radius:50%;border:2px solid var(--border2);flex-shrink:0;margin-top:2px;';
    if (state.routeMode === m.id) {
      dot.style.background = 'var(--primary)';
      dot.style.border = '2px solid var(--primary)';
      dot.style.boxShadow = '0 0 8px var(--primary)';
    }
    row.appendChild(dot);

    const info = el('div', 'flex-col gap-4');
    const name = el('span'); name.textContent = m.name;
    name.style.cssText = 'font-weight:600;color:' + (state.routeMode === m.id ? 'var(--text)' : 'var(--text2)') + ';';
    const d = el('span'); d.textContent = m.desc;
    d.style.cssText = 'font-size:11.5px;color:var(--muted);line-height:1.4;';
    info.appendChild(name); info.appendChild(d);
    row.appendChild(info);

    row.addEventListener('click', () => {
      state.routeMode = m.id;
      api.setRouteMode(m.id);
      renderPage();
    });
    chips.appendChild(row);
  });
  c.appendChild(chips);
  root.appendChild(c);
}

// ═════════════════════════════════════════════════════════════════════════
//  LOG PAGE
// ═════════════════════════════════════════════════════════════════════════
function buildLog(root) {
  root.appendChild(pageHead('Лог', 'RUNTIME LOG'));
  const c = card();
  c.style.flex = '1';
  c.style.minHeight = '0';
  c.style.display = 'flex';
  c.style.flexDirection = 'column';
  c.appendChild(cardHead('СОБЫТИЯ', null, null));
  const logBox = el('div', 'log-box flex-1');
  logBox.id = 'logBoxFull';
  logBox.style.maxHeight = 'calc(100vh - 220px)';
  state.logs.forEach(l => logBox.appendChild(renderLogLine(l)));
  logBox.scrollTop = 99999;
  c.appendChild(logBox);
  root.appendChild(c);
}

// ═════════════════════════════════════════════════════════════════════════
//  CONNECT / DISCONNECT
// ═════════════════════════════════════════════════════════════════════════
async function toggleConnect() {
  if (state.connecting) return;

  if (state.connected) {
    await api.disconnect();
    state.connected = false;
    stopUptimeTimer();
    updateHeroUI();
    appendLog('status', 'Disconnected');
    return;
  }

  const prof = activeProfile();
  if (!prof) {
    toast('Выберите профиль', true);
    return;
  }

  state.connecting = true;
  updateHeroUI();
  appendLog('status', 'Connecting... ' + prof.carrier + ' · ' + prof.transport);

  const result = await api.connect(prof.link);

  state.connecting = false;
  if (result.ok) {
    state.connected = true;
    startUptimeTimer();
    appendLog('ok', 'Connected ✓ SOCKS ready');
    if (result.warning) appendLog('warn', result.warning);
  } else {
    state.connected = false;
    appendLog('error', 'Connection failed: ' + result.error);
    toast('Ошибка: ' + result.error, true);
  }
  updateHeroUI();
}

function handleCoreLog(line) {
  if (!line || /^\s*$/.test(line)) return;
  // Filter noise
  if (/\[ice\] TRACE:|DTLS TRACE:|sctp TRACE:|sctp DEBUG:|Failed to ping without candidate|wsasendto/.test(line)) return;

  const lower = line.toLowerCase();
  let level = 'default';
  if (/error|failed|timeout/.test(lower)) level = 'error';
  else if (/warn|warning/.test(lower))    level = 'warn';
  else if (/socks5 server listening|connected|ready/.test(lower)) level = 'ok';

  appendLog(null, line, level);
}

function handleCoreExited(code) {
  const wasConnected = state.connected;
  state.connected  = false;
  state.connecting = false;
  stopUptimeTimer();
  appendLog('warn', `Core exited (${code ?? '?'})`);
  if (wasConnected) toast('VPN core остановлен', true);
  updateHeroUI();
}

// ═════════════════════════════════════════════════════════════════════════
//  PROFILE ACTIONS
// ═════════════════════════════════════════════════════════════════════════
function selectProfile(prof, liEl) {
  state.selected = prof.id;
  document.querySelectorAll('.profile-item').forEach(el => el.classList.remove('active'));
  if (liEl) liEl.classList.add('active');
  if (state.tab === 'profiles') renderPage();
}

async function saveProfileFromEditor(name, link) {
  const parsed = await api.parseLink(link);
  if (!parsed.ok) { toast('Ошибка: ' + parsed.error, true); return; }
  const cfg = parsed.config;
  const id  = state.selected || ('p' + Date.now());
  const profileName = name.trim() ||
    (cfg.comment && cfg.comment !== 'direct' ? cfg.comment : `${cfg.carrier} | ${cfg.transport}`);
  const profile = {
    id,
    name:      profileName,
    link:      link.trim(),
    carrier:   cfg.carrier,
    transport: cfg.transport,
  };
  state.profiles = await api.saveProfile(profile);
  state.selected  = id;
  toast('Профиль сохранён');
  renderPage();
}

async function deleteProfile(id) {
  state.profiles = await api.deleteProfile(id);
  if (state.selected === id) state.selected = null;
  toast('Профиль удалён');
  renderPage();
}

function activeProfile() {
  if (state.selected) return state.profiles.find(p => p.id === state.selected) || null;
  return state.profiles[0] || null;
}

// ═════════════════════════════════════════════════════════════════════════
//  LOG HELPERS
// ═════════════════════════════════════════════════════════════════════════
function appendLog(tag, msg, level = 'default') {
  const ts = new Date().toTimeString().slice(0, 8);
  const entry = { ts, tag, msg, level };
  state.logs.push(entry);
  if (state.logs.length > 2000) state.logs.shift();
  state.miniLogs.push(entry);
  if (state.miniLogs.length > 200) state.miniLogs.shift();

  // Update visible log boxes
  const logLine = renderLogLine(entry);
  appendToLogBox('logBoxTraffic', logLine);
  appendToLogBox('logBoxFull',    renderLogLine(entry));
  appendToLogBox('miniLog',       renderLogLine(entry));

  // Update traffic badge
  const badge = document.getElementById('badgeStatus');
  if (badge && level === 'ok') badge.textContent = '●';
}

function appendToLogBox(id, lineEl) {
  const box = document.getElementById(id);
  if (!box) return;
  box.appendChild(lineEl);
  if (box.scrollTop + box.clientHeight >= box.scrollHeight - 60)
    box.scrollTop = box.scrollHeight;
  // Trim DOM
  while (box.children.length > 500) box.removeChild(box.firstChild);
}

function renderLogLine(entry) {
  const div = el('div', 'log-line ' + (entry.level || ''));
  const ts  = el('span', 'ts'); ts.textContent = entry.ts; div.appendChild(ts);
  if (entry.tag) { const t = el('span', 'tag'); t.textContent = '[' + entry.tag + ']'; div.appendChild(t); }
  const m = el('span', 'msg'); m.textContent = entry.msg; div.appendChild(m);
  return div;
}

// ═════════════════════════════════════════════════════════════════════════
//  HERO UI UPDATE (after connect/disconnect)
// ═════════════════════════════════════════════════════════════════════════
function updateHeroUI() {
  if (state.tab !== 'home') return;
  // Re-render home to reflect connection state
  renderPage();
}

// ═════════════════════════════════════════════════════════════════════════
//  UPTIME TIMER
// ═════════════════════════════════════════════════════════════════════════
function startUptimeTimer() {
  state.upSec = 0;
  stopUptimeTimer();
  state.uptimeTimer = setInterval(() => {
    state.upSec++;
    const el = document.getElementById('metricUp');
    if (el) el.textContent = formatUptime(state.upSec);
  }, 1000);
}
function stopUptimeTimer() {
  if (state.uptimeTimer) { clearInterval(state.uptimeTimer); state.uptimeTimer = null; }
  state.upSec = 0;
}

// ═════════════════════════════════════════════════════════════════════════
//  DOM / STYLE HELPERS
// ═════════════════════════════════════════════════════════════════════════
function el(tag, cls = '') {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  return e;
}

function card() {
  return el('div', 'card');
}

function cardHead(title, action, onAction) {
  const h = el('div', 'card-head');
  const t = el('span', 'title'); t.textContent = title; h.appendChild(t);
  if (action && onAction) {
    const a = el('span', 'action'); a.textContent = action;
    a.addEventListener('click', onAction); h.appendChild(a);
  }
  return h;
}

function pageHead(title, sub) {
  const h = el('div', 'page-head');
  const t = el('h2'); t.textContent = title; h.appendChild(t);
  const s = el('span', 'sub'); s.textContent = sub; h.appendChild(s);
  return h;
}

function esc(str) {
  return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function toast(msg, isError = false) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'show' + (isError ? ' error' : '');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.className = ''; }, 3200);
}

// ═════════════════════════════════════════════════════════════════════════
//  FORMATTING
// ═════════════════════════════════════════════════════════════════════════
function formatSpeed(bps) {
  if (bps >= 1e6) return (bps / 1e6).toFixed(2);
  if (bps >= 1e3) return (bps / 1e3).toFixed(1);
  return String(bps);
}
function speedUnit(bps) {
  if (bps >= 1e6) return 'MB/s';
  if (bps >= 1e3) return 'KB/s';
  return 'B/s';
}
function formatUptime(sec) {
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  if (h > 0) return `${h}h ${m.toString().padStart(2,'0')}m`;
  return `${m}:${s.toString().padStart(2,'0')}`;
}

// ── Start ──────────────────────────────────────────────────────────────────
boot().catch(e => console.error('Boot failed:', e));
