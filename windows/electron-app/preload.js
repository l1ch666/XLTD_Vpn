'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // Window controls
  minimize: ()      => ipcRenderer.send('win:minimize'),
  maximize: ()      => ipcRenderer.send('win:maximize'),
  close:    ()      => ipcRenderer.send('win:close'),

  // App
  getInfo: ()       => ipcRenderer.invoke('app:info'),

  // Profiles
  loadProfiles:   ()        => ipcRenderer.invoke('profiles:load'),
  saveProfile:    (p)       => ipcRenderer.invoke('profiles:save', p),
  deleteProfile:  (id)      => ipcRenderer.invoke('profiles:delete', id),

  // Link parser
  parseLink: (raw)          => ipcRenderer.invoke('link:parse', raw),

  // Route mode
  getRouteMode: ()          => ipcRenderer.invoke('route:get'),
  setRouteMode: (mode)      => ipcRenderer.send('route:set', mode),

  // VPN core
  connect:    (link)        => ipcRenderer.invoke('core:connect', link),
  disconnect: ()            => ipcRenderer.invoke('core:disconnect'),
  getStatus:  ()            => ipcRenderer.invoke('core:status'),

  // Events from main → renderer
  onCoreLog:    (cb) => {
    ipcRenderer.on('core:log',    (_e, line) => cb(line));
  },
  onCoreExited: (cb) => {
    ipcRenderer.on('core:exited', (_e, code) => cb(code));
  },
});
