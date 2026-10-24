'use strict';
// ICQuel WhatsApp bridge: JSON Lines over stdin/stdout, logs on stderr only.
// Usage: node bridge.js <dataDir> | node bridge.js --selftest
const fs = require('fs');
const path = require('path');
const readline = require('readline');

// stdout is reserved for the protocol
const realWrite = process.stdout.write.bind(process.stdout);
console.log = console.info = console.warn = (...a) => console.error(...a);
const emit = (o) => realWrite(JSON.stringify(o) + '\n');
const log = (...a) => console.error('[wa-bridge]', ...a);
const exit = (code) => realWrite('', () => process.exit(code));

process.on('uncaughtException', (e) => log('uncaught', e && e.stack || e));
process.on('unhandledRejection', (e) => log('unhandled', e && e.stack || e));

const MIME = {
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', heic: 'image/heic',
  gif: 'video/mp4', mp4: 'video/mp4', mov: 'video/quicktime', m4v: 'video/mp4', webm: 'video/webm',
  mp3: 'audio/mpeg', m4a: 'audio/mp4', ogg: 'audio/ogg', opus: 'audio/ogg; codecs=opus', wav: 'audio/wav', aac: 'audio/aac',
  pdf: 'application/pdf', txt: 'text/plain', zip: 'application/zip', doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xls: 'application/vnd.ms-excel', xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};
const IMG = ['jpg', 'jpeg', 'png', 'webp'], VID = ['mp4', 'mov', 'm4v', 'webm', 'gif'];

function lines(onLine, onEnd) {
  const rl = readline.createInterface({ input: process.stdin });
  rl.on('line', (l) => {
    l = l.trim();
    if (!l) return;
    let o;
    try { o = JSON.parse(l); } catch (e) { return log('bad json line ignored'); }
    if (!o || typeof o !== 'object') return log('non-object line ignored');
    try { onLine(o); } catch (e) { log('command error', e && e.stack || e); }
  });
  rl.on('close', onEnd);
}

function selftest() {
  const t0 = Date.now() + 1000;
  const send = (id) => emit({ type: 'sent', id: id || '', ok: true });
  lines((c) => {
    if (c.cmd === 'quit') return exit(0);
    if (Date.now() <= t0) {
      send(c.id);
      if (c.cmd === 'chats') emit({ type: 'chats', chats: [{ jid: '4915112345678@s.whatsapp.net', name: 'Test', group: false, last: 'hello', ts: 1700000000 }] });
    }
  }, () => {});
  emit({ type: 'qr', data: '2@selftest-qr-string' });
  emit({ type: 'ready', me: '4915100000000:1@s.whatsapp.net' });
  emit({ type: 'message', id: 'M1', jid: '4915112345678@s.whatsapp.net', from: '4915112345678@s.whatsapp.net', name: 'Test', text: 'hello from selftest', group: false, ts: 1700000000, fromMe: false, files: [] });
  emit({ type: 'message', id: 'M2', jid: '123-456@g.us', from: '4915112345678@s.whatsapp.net', name: 'Test', text: '', group: true, ts: 1700000001, fromMe: false, files: ['/tmp/selftest/media/pic.jpg'] });
  setTimeout(() => { emit({ type: 'closed', reason: 'selftest done', loggedOut: false }); exit(0); }, 1100);
}

async function main(dataDir) {
  const baileys = require('@whiskeysockets/baileys');
  const makeWASocket = baileys.default && baileys.default.default || baileys.default || baileys.makeWASocket;
  const { useMultiFileAuthState, DisconnectReason, downloadMediaMessage, normalizeMessageContent, fetchLatestBaileysVersion, Browsers } = baileys;
  const pino = require('pino');
  const logger = pino({ level: 'warn' }, pino.destination(2));
  const mediaDir = path.join(dataDir, 'media');
  const authDir = path.join(dataDir, 'auth');
  fs.mkdirSync(mediaDir, { recursive: true });

  const chats = new Map(); // jid -> {jid,name,group,last,ts}
  const names = new Map(); // jid -> name
  let sock = null, ready = false, quitting = false, retry = 0;

  const toNum = (t) => (t && typeof t === 'object' && 'toNumber' in t ? t.toNumber() : Number(t) || 0);
  const textOf = (m) => m && (m.conversation || (m.extendedTextMessage && m.extendedTextMessage.text) ||
    (m.imageMessage && m.imageMessage.caption) || (m.videoMessage && m.videoMessage.caption) ||
    (m.documentMessage && m.documentMessage.caption) || '') || '';
  function touchChat(jid, patch) {
    if (!jid || jid === 'status@broadcast') return;
    const c = chats.get(jid) || { jid, name: '', group: jid.endsWith('@g.us'), last: '', ts: 0 };
    Object.assign(c, patch);
    if (!c.name) c.name = names.get(jid) || '';
    chats.set(jid, c);
  }
  function noteMsg(msg) {
    const jid = msg.key && msg.key.remoteJid;
    const m = normalizeMessageContent(msg.message);
    const ts = toNum(msg.messageTimestamp);
    const c = chats.get(jid);
    if (c && ts && ts < c.ts) return;
    touchChat(jid, { last: textOf(m) || (m ? '[' + Object.keys(m)[0].replace('Message', '') + ']' : ''), ts });
    if (msg.pushName && !msg.key.fromMe && !jid.endsWith('@g.us')) { names.set(jid, msg.pushName); if (!chats.get(jid).name) chats.get(jid).name = msg.pushName; }
  }

  // WhatsApp addresses many chats by a "LID" (…@lid) instead of the phone number. Report the phone-number form as `jid` and the other as `alt`,
  // so the app can match a chat whichever form it saved.
  async function pnFor(jid, alt) {
    if (!jid || !jid.endsWith('@lid')) return null;
    if (alt && alt.endsWith('@s.whatsapp.net')) return alt.replace(/:\d+@/, '@');
    try {
      const lm = sock && sock.signalRepository && sock.signalRepository.lidMapping;
      const pn = lm && lm.getPNForLID ? await lm.getPNForLID(jid) : null;
      return pn ? String(pn).replace(/:\d+@/, '@') : null;
    } catch (e) { return null; }
  }
  async function handleMessage(msg) {
    const key = msg.key || {};
    const jid = key.remoteJid;
    if (!jid || jid === 'status@broadcast' || !msg.message) return;
    noteMsg(msg);
    const m = normalizeMessageContent(msg.message);
    if (!m || m.protocolMessage || m.reactionMessage || m.senderKeyDistributionMessage) return;
    const files = [];
    const kind = ['imageMessage', 'videoMessage', 'documentMessage', 'audioMessage', 'stickerMessage'].find((k) => m[k]);
    if (kind) {
      try {
        const buf = await downloadMediaMessage(msg, 'buffer', {}, { logger, reuploadRequest: sock.updateMediaMessage });
        const mt = m[kind];
        let ext = (mt.fileName && path.extname(mt.fileName).slice(1)) ||
          Object.keys(MIME).find((e) => MIME[e] === (mt.mimetype || '').split(';')[0] && e !== 'gif') || 'bin';
        const f = path.join(mediaDir, (key.id || Date.now()) + '.' + ext.toLowerCase().replace(/[^a-z0-9]/g, ''));
        fs.writeFileSync(f, buf);
        files.push(path.resolve(f));
      } catch (e) { log('media download failed', e && e.message); }
    }
    const group = jid.endsWith('@g.us');
    const pn = await pnFor(jid, key.remoteJidAlt);
    emit({
      type: 'message', id: key.id || '', jid: pn || jid, alt: pn ? jid : (key.remoteJidAlt || ''), from: key.fromMe ? (sock.user && sock.user.id) || '' : (key.participant || jid),
      name: msg.pushName || names.get(jid) || '', text: textOf(m), group, ts: toNum(msg.messageTimestamp) || Math.floor(Date.now() / 1000),
      fromMe: !!key.fromMe, files,
    });
  }

  async function connect() {
    const { state, saveCreds } = await useMultiFileAuthState(authDir);
    let version;
    try { version = (await fetchLatestBaileysVersion()).version; } catch (e) { log('version fetch failed, using default'); }
    sock = makeWASocket({ auth: state, logger, version, browser: Browsers ? Browsers.macOS('Desktop') : undefined, syncFullHistory: false, markOnlineOnConnect: false });
    const mine = sock;
    sock.ev.on('creds.update', saveCreds);
    sock.ev.on('connection.update', (u) => {
      if (mine !== sock) return;
      if (u.qr) emit({ type: 'qr', data: u.qr });
      if (u.connection === 'open') { ready = true; retry = 0; emit({ type: 'ready', me: (sock.user && sock.user.id) || '' }); }
      if (u.connection === 'close') {
        ready = false;
        if (quitting) return;
        const err = u.lastDisconnect && u.lastDisconnect.error;
        const code = err && err.output && err.output.statusCode;
        const reason = (err && err.message) || 'closed (' + code + ')';
        if (code === DisconnectReason.loggedOut) {
          fs.rmSync(authDir, { recursive: true, force: true });
          emit({ type: 'closed', reason: 'logged out', loggedOut: true });
          return exit(0);
        }
        const wait = code === DisconnectReason.restartRequired ? 0 : Math.min(30000, 2000 * 2 ** retry++);
        log('disconnected:', reason, '- reconnecting in', wait, 'ms');
        setTimeout(() => connect().catch((e) => { log('reconnect failed', e && e.message); emit({ type: 'closed', reason: String(e && e.message), loggedOut: false }); exit(1); }), wait);
      }
    });
    sock.ev.on('messaging-history.set', ({ chats: cs, contacts, messages }) => {
      (contacts || []).forEach((c) => { const n = c.name || c.notify; if (n) names.set(c.id, n); });
      (cs || []).forEach((c) => touchChat(c.id, { name: c.name || names.get(c.id) || '', ts: toNum(c.conversationTimestamp) || (chats.get(c.id) || {}).ts || 0 }));
      (messages || []).forEach((m) => { try { noteMsg(m); } catch (e) {} });
    });
    sock.ev.on('chats.upsert', (cs) => cs.forEach((c) => touchChat(c.id, { name: c.name || names.get(c.id) || '', ts: toNum(c.conversationTimestamp) || (chats.get(c.id) || {}).ts || 0 })));
    sock.ev.on('chats.update', (cs) => cs.forEach((c) => { if (c.id) touchChat(c.id, { ...(c.name ? { name: c.name } : {}), ...(c.conversationTimestamp ? { ts: toNum(c.conversationTimestamp) } : {}) }); }));
    sock.ev.on('contacts.upsert', (cs) => cs.forEach((c) => { const n = c.name || c.notify; if (n) { names.set(c.id, n); if (chats.has(c.id) && !chats.get(c.id).name) chats.get(c.id).name = n; } }));
    sock.ev.on('messages.upsert', ({ messages, type }) => {
      for (const m of messages) {
        if (type !== 'notify' && !(type === 'append' && m.key && m.key.fromMe)) { try { noteMsg(m); } catch (e) {} continue; }
        handleMessage(m).catch((e) => log('message error', e && e.message));
      }
    });
  }

  async function doSend(c) {
    if (!sock || !ready) throw new Error('not connected');
    if (!c.jid) throw new Error('missing jid');
    if (c.cmd === 'send') return sock.sendMessage(c.jid, { text: String(c.text || '') });
    const buf = fs.readFileSync(c.path);
    const ext = path.extname(c.path).slice(1).toLowerCase();
    const caption = c.caption || undefined;
    const mimetype = MIME[ext] || 'application/octet-stream';
    let content;
    if (IMG.includes(ext)) content = { image: buf, caption, mimetype };
    else if (VID.includes(ext)) content = { video: buf, caption, mimetype, ...(ext === 'gif' ? { gifPlayback: true } : {}) };
    else content = { document: buf, caption, mimetype, fileName: path.basename(c.path) };
    // ponytail: animated .gif sent raw as mp4 mimetype; WhatsApp expects mp4 so convert GIFs to mp4 in the app for best results
    return sock.sendMessage(c.jid, content);
  }

  async function shutdown(code) {
    quitting = true;
    try { sock && sock.end(undefined); } catch (e) {}
    exit(code);
  }

  let q = Promise.resolve(); // serialize commands so quit waits for pending sends
  lines((c) => { q = q.then(() => handle(c)).catch((e) => log('cmd error', e && e.message)); }, () => q.then(() => shutdown(0)));
  async function handle(c) {
    if (c.cmd === 'quit') return shutdown(0);
    if (c.cmd === 'chats') {
      const list = [...chats.values()].sort((a, b) => b.ts - a.ts).slice(0, 200).map((x) => ({ ...x, name: x.name || names.get(x.jid) || x.jid.split('@')[0] }));
      return emit({ type: 'chats', chats: list });
    }
    if (c.cmd === 'logout') {
      quitting = true;
      try { sock && await sock.logout(); } catch (e) { log('logout error', e && e.message); }
      fs.rmSync(authDir, { recursive: true, force: true });
      emit({ type: 'closed', reason: 'logged out', loggedOut: true });
      return exit(0);
    }
    if (c.cmd === 'send' || c.cmd === 'sendFile') {
      try { await doSend(c); emit({ type: 'sent', id: c.id || '', ok: true }); }
      catch (e) { emit({ type: 'sent', id: c.id || '', ok: false, error: String(e && e.message || e) }); }
    }
  }

  await connect();
}

const arg = process.argv[2];
if (arg === '--selftest') selftest();
else if (!arg) { log('usage: bridge.js <dataDir> | --selftest'); process.exit(2); }
else main(path.resolve(arg)).catch((e) => { emit({ type: 'closed', reason: String(e && e.message || e), loggedOut: false }); exit(1); });
