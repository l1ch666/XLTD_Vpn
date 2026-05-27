'use strict';
// Port of OlcUriParser.cs

const TRANSPORT_DATA  = 'datachannel';
const TRANSPORT_VP8   = 'vp8channel';
const TRANSPORT_SEI   = 'seichannel';
const TRANSPORT_VIDEO = 'videochannel';
const SCHEME = 'olcrtc://';

function normalizeTransport(v) {
  switch ((v || '').trim().toLowerCase()) {
    case 'data': case 'dc': case 'data_channel': case 'data-channel': return TRANSPORT_DATA;
    case 'vp8':  case 'vp8_channel':  case 'vp8-channel':             return TRANSPORT_VP8;
    case 'sei':  case 'sei_channel':  case 'sei-channel':              return TRANSPORT_SEI;
    case 'video': case 'vid': case 'video_channel': case 'video-channel':
    case 'videochannel':                                                return TRANSPORT_VIDEO;
    default: return v.trim().toLowerCase();
  }
}

function parseParams(raw) {
  const out = {};
  if (!raw) return out;
  for (const pair of raw.split('&').filter(Boolean)) {
    const eq = pair.indexOf('=');
    const key = decodeURIComponent(eq >= 0 ? pair.slice(0, eq) : pair).trim().toLowerCase();
    const val = eq >= 0 ? decodeURIComponent(pair.slice(eq + 1)).trim() : '';
    if (key) out[key] = val;
  }
  return out;
}

function parseTransportSpec(spec) {
  if (!spec) throw new Error('transport is empty');
  const open = spec.indexOf('<');
  if (open < 0) return { transport: spec, params: {} };
  const close = spec.lastIndexOf('>');
  if (close < open || close !== spec.length - 1)
    throw new Error('bad transport params: expected transport<key=value&...>');
  return { transport: spec.slice(0, open).trim(), params: parseParams(spec.slice(open + 1, close).trim()) };
}

function parseTail(rawTail) {
  if (!rawTail) throw new Error('missing keyHex');
  const percent = rawTail.indexOf('%');
  const dollar  = rawTail.indexOf('$');
  let key, client = '', comment = '';
  if (percent >= 0 && (dollar < 0 || percent < dollar)) {
    key = rawTail.slice(0, percent);
    if (dollar > percent) { client = rawTail.slice(percent + 1, dollar); comment = rawTail.slice(dollar + 1); }
    else                   { client = rawTail.slice(percent + 1); }
  } else if (dollar >= 0) {
    key = rawTail.slice(0, dollar); comment = rawTail.slice(dollar + 1);
  } else { key = rawTail; }
  return {
    keyHex:   decodeURIComponent(key),
    clientId: decodeURIComponent(client),
    comment:  decodeURIComponent(comment)
  };
}

function extractUri(raw) {
  const value = raw.trim();
  const start = value.toLowerCase().indexOf(SCHEME);
  if (start < 0) return value;
  const sub = value.slice(start).trim();
  const lineEnd = sub.search(/[\r\n]/);
  return lineEnd >= 0 ? sub.slice(0, lineEnd).trim() : sub;
}

function parse(raw) {
  if (!raw || !raw.trim()) throw new Error('empty link');
  const value = extractUri(raw);
  if (!value.toLowerCase().startsWith(SCHEME)) throw new Error('link must start with olcrtc://');
  const body = value.slice(SCHEME.length);
  const q    = body.indexOf('?');
  const at   = q >= 0 ? body.indexOf('@', q + 1) : -1;
  const hash = at >= 0 ? body.indexOf('#', at + 1) : -1;
  if (q <= 0)    throw new Error('missing carrier or ?');
  if (at <= q)   throw new Error('missing transport or @');
  if (hash <= at) throw new Error('missing roomId or #');

  const carrier = decodeURIComponent(body.slice(0, q)).trim().toLowerCase();
  const { transport: rawT, params } = parseTransportSpec(body.slice(q + 1, at).trim());
  const transport = normalizeTransport(rawT);
  if (![TRANSPORT_DATA, TRANSPORT_VP8, TRANSPORT_SEI, TRANSPORT_VIDEO].includes(transport))
    throw new Error('unsupported transport: use datachannel, vp8channel, seichannel or videochannel');

  const roomId = decodeURIComponent(body.slice(at + 1, hash)).trim();
  const tail   = parseTail(body.slice(hash + 1));
  const clientId = tail.clientId.trim() ||
    params['client-id'] || params['clientid'] || params['client'] || 'default';

  if (!carrier)  throw new Error('carrier is empty');
  if (!transport) throw new Error('transport is empty');
  if (!roomId && carrier !== 'jazz') throw new Error('roomId is empty');
  if (!clientId)  throw new Error('clientId is empty');
  if (tail.keyHex.length !== 64) throw new Error('keyHex must be 64 hex chars');
  if (!/^[0-9a-fA-F]{64}$/.test(tail.keyHex)) throw new Error('keyHex is not hex');

  return { carrier, transport, roomId, keyHex: tail.keyHex, clientId, comment: tail.comment, params };
}

function intParam(config, key, def = 0) {
  const v = config.params[key];
  const n = parseInt(v, 10);
  return isNaN(n) ? def : n;
}

function strParam(config, key, def = '') {
  return config.params[key] !== undefined ? config.params[key] : def;
}

module.exports = { parse, intParam, strParam, TRANSPORT_DATA, TRANSPORT_VP8, TRANSPORT_SEI, TRANSPORT_VIDEO };
