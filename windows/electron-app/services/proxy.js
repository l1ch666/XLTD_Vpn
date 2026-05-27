'use strict';
// Windows proxy management via reg.exe (mirrors WindowsProxyManager.cs)
const { execSync, execFileSync } = require('child_process');

const REG_PATH = 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings';
let snapshot = null;

function regQuery(name) {
  try {
    const out = execFileSync('reg', ['query', REG_PATH, '/v', name], { encoding: 'utf8' });
    const m = out.match(/REG_\w+\s+(.+)/);
    return m ? m[1].trim() : null;
  } catch { return null; }
}

function regSet(name, type, value) {
  execFileSync('reg', ['add', REG_PATH, '/v', name, '/t', type, '/d', String(value), '/f']);
}

function regDelete(name) {
  try { execFileSync('reg', ['delete', REG_PATH, '/v', name, '/f']); } catch {}
}

function refreshIE() {
  try {
    // INTERNET_OPTION_SETTINGS_CHANGED=39, INTERNET_OPTION_REFRESH=37
    const code = `
      $sig='[DllImport("wininet.dll")]public static extern bool InternetSetOption(IntPtr h,int d,IntPtr b,int l);';
      $t=Add-Type -MemberDefinition $sig -Name WinInet -Namespace P -PassThru;
      $t::InternetSetOption([IntPtr]::Zero,39,[IntPtr]::Zero,0);
      $t::InternetSetOption([IntPtr]::Zero,37,[IntPtr]::Zero,0)`;
    execFileSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', code]);
  } catch {}
}

function apply(host, port) {
  snapshot = {
    enable:   regQuery('ProxyEnable'),
    server:   regQuery('ProxyServer'),
    override: regQuery('ProxyOverride')
  };
  regSet('ProxyEnable',   'REG_DWORD',  '1');
  regSet('ProxyServer',   'REG_SZ',     `socks=${host}:${port}`);
  regSet('ProxyOverride', 'REG_SZ',     '<local>');
  refreshIE();
}

function restore() {
  if (!snapshot) return;
  const { enable, server, override } = snapshot;
  snapshot = null;

  if (enable  != null) regSet('ProxyEnable',   'REG_DWORD', enable);   else regDelete('ProxyEnable');
  if (server  != null) regSet('ProxyServer',   'REG_SZ',    server);   else regDelete('ProxyServer');
  if (override != null) regSet('ProxyOverride', 'REG_SZ',   override); else regDelete('ProxyOverride');
  refreshIE();
}

module.exports = { apply, restore };
