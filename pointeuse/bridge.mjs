#!/usr/bin/env node
/**
 * Passerelle POINTEUSE ZKTeco (K50 Pro…) → Supabase.
 *
 * Protocole « Attendance PUSH » (ADMS) fourni avec le SDK ZKTeco : la pointeuse
 * appelle elle-même ce serveur HTTP (Menu › COMM › Serveur Cloud / ADMS) :
 *   GET  /iclock/cdata?SN=…&options=all   → initialisation (on renvoie la config)
 *   POST /iclock/cdata?SN=…&table=ATTLOG  → pointages  « PIN \t AAAA-MM-JJ HH:MM:SS \t état \t mode … »
 *   GET  /iclock/getrequest?SN=…          → la pointeuse demande nos commandes
 *   POST /iclock/devicecmd?SN=…           → résultat des commandes
 *
 * Les pointages sont enregistrés dans Supabase via les RPC pointeuse_* (jeton
 * secret). En cas d'erreur réseau on répond une erreur à la pointeuse : elle
 * garde les pointages en mémoire et les renvoie plus tard — rien n'est perdu.
 *
 * Lancement : node pointeuse/bridge.mjs   (ou lancer-pointeuse.bat)
 * Aucune dépendance : Node 18+ suffit.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const CONFIG_FILE = path.join(HERE, 'config.json');
const LOG_FILE = path.join(HERE, 'bridge.log');

// ---------------------------------------------------------------- config --
function readEnv(file) {
  const out = {};
  if (!fs.existsSync(file)) return out;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) out[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return out;
}

const env = readEnv(path.join(ROOT, '.env'));
const defaults = { port: 8090, token: '', timezone: 1, supabaseUrl: '', supabaseAnonKey: '' };
let config = { ...defaults };
if (fs.existsSync(CONFIG_FILE)) {
  config = { ...defaults, ...JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8')) };
} else {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(defaults, null, 2));
}
const SUPABASE_URL = config.supabaseUrl || env.VITE_SUPABASE_URL;
const SUPABASE_KEY = config.supabaseAnonKey || env.VITE_SUPABASE_ANON_KEY;

// ------------------------------------------------------------------- log --
const recent = [];
function log(...args) {
  const line = `[${new Date().toLocaleString('fr-FR')}] ${args.join(' ')}`;
  console.log(line);
  recent.push(line);
  if (recent.length > 200) recent.shift();
  try {
    fs.appendFileSync(LOG_FILE, line + '\n');
    if (fs.statSync(LOG_FILE).size > 5_000_000) fs.renameSync(LOG_FILE, LOG_FILE + '.old');
  } catch { /* ignore */ }
}

if (!SUPABASE_URL || !SUPABASE_KEY) {
  log('ERREUR : VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY introuvables dans .env');
  process.exit(1);
}
if (!config.token) {
  log('ATTENTION : aucun jeton dans pointeuse/config.json — copiez-le depuis l\'application (Pointage › Connexion).');
}

// -------------------------------------------------------------- supabase --
async function rpc(fn, args) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(args),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${fn} → ${res.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

// --------------------------------------------------------------- devices --
const lastBeat = new Map(); // sn → ms
async function heartbeat(sn, ip, extra = {}) {
  const now = Date.now();
  if (!extra.force && now - (lastBeat.get(sn) ?? 0) < 60_000) return;
  lastBeat.set(sn, now);
  try {
    await rpc('pointeuse_heartbeat', {
      p_token: config.token, p_sn: sn, p_ip: ip ?? null,
      p_info: extra.info ?? null, p_push_version: extra.pushver ?? null,
    });
  } catch (e) {
    log('Heartbeat échoué :', e.message);
  }
}

const stats = { punches: 0, lastPunch: '', devices: new Map() };

// ------------------------------------------------------------------ http --
function reply(res, body, status = 200) {
  res.writeHead(status, {
    'Content-Type': 'text/plain',
    'Content-Length': Buffer.byteLength(body),
    Pragma: 'no-cache',
    'Cache-Control': 'no-store',
    Connection: 'close',
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function optionsFor(sn) {
  return [
    `GET OPTION FROM: ${sn}`,
    'ATTLOGStamp=None',
    'OPERLOGStamp=9999',
    'ATTPHOTOStamp=None',
    'ErrorDelay=30',
    'Delay=10',
    'TransTimes=00:00;14:05',
    'TransInterval=1',
    'TransFlag=TransData AttLog OpLog EnrollUser ChgUser EnrollFP ChgFP',
    `TimeZone=${config.timezone}`,
    'Realtime=1',
    'Encrypt=None',
    'ServerVer=2.2.14',
    'PushProtVer=2.2.14',
  ].join('\n') + '\n';
}

/** « 1\t2026-10-11 08:02:11\t0\t1\t0… » → objets */
function parseAttlog(body) {
  const rows = [];
  for (const raw of body.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const f = line.split('\t');
    const pin = (f[0] ?? '').trim();
    const t = (f[1] ?? '').trim();
    if (!pin || !/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$/.test(t)) continue;
    rows.push({ pin, t, status: Number(f[2]) || 0, verify: Number(f[3]) || 0 });
  }
  return rows;
}

function statusPage() {
  const devs = [...stats.devices.entries()]
    .map(([sn, d]) => `<li><b>${sn}</b> — ${d.ip} — vue ${new Date(d.at).toLocaleString('fr-FR')}</li>`)
    .join('') || '<li>Aucune pointeuse connectée pour le moment</li>';
  return `<!doctype html><meta charset="utf-8"><title>Passerelle pointeuse</title>
<style>body{font-family:system-ui;margin:24px;background:#111;color:#eee}pre{background:#000;padding:12px;font-size:12px;white-space:pre-wrap}b{color:#f55}</style>
<h2>Passerelle pointeuse ZKTeco → Adel Papier</h2>
<p>Port ${config.port} · jeton ${config.token ? 'configuré ✔' : '<b>MANQUANT</b>'} · ${stats.punches} pointage(s) reçu(s) ${stats.lastPunch ? '· dernier : ' + stats.lastPunch : ''}</p>
<ul>${devs}</ul><pre>${recent.slice(-60).reverse().join('\n').replace(/</g, '&lt;')}</pre>
<script>setTimeout(()=>location.reload(),5000)</script>`;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');
  const p = url.pathname.toLowerCase();
  const sn = url.searchParams.get('SN') ?? url.searchParams.get('sn') ?? '';
  const ip = (req.socket.remoteAddress ?? '').replace('::ffff:', '');
  if (sn) stats.devices.set(sn, { ip, at: Date.now() });

  try {
    // ---- initialisation
    if (p === '/iclock/cdata' && req.method === 'GET') {
      log(`Pointeuse ${sn} (${ip}) connectée — pushver=${url.searchParams.get('pushver') ?? '?'}`);
      await heartbeat(sn, ip, { force: true, pushver: url.searchParams.get('pushver') });
      return reply(res, optionsFor(sn));
    }

    // ---- données envoyées par la pointeuse
    if (p === '/iclock/cdata' && req.method === 'POST') {
      const table = (url.searchParams.get('table') ?? '').toUpperCase();
      const body = await readBody(req);
      if (table === 'ATTLOG') {
        const rows = parseAttlog(body);
        if (rows.length) {
          const inserted = await rpc('pointeuse_push_logs', { p_token: config.token, p_sn: sn, p_rows: rows });
          stats.punches += rows.length;
          const last = rows[rows.length - 1];
          stats.lastPunch = `PIN ${last.pin} à ${last.t}`;
          log(`${rows.length} pointage(s) reçu(s) de ${sn} (${inserted} nouveau(x)) — dernier : PIN ${last.pin} ${last.t}`);
        }
        return reply(res, `OK: ${rows.length}\n`);
      }
      // OPERLOG / USERINFO / BIODATA / ATTPHOTO… : accusé de réception
      const n = body.split(/\r?\n/).filter((l) => l.trim()).length;
      if (table === 'OPERLOG' && /USER PIN=/.test(body)) log(`Pointeuse ${sn} : employé(s) modifié(s) sur l'appareil`);
      return reply(res, `OK: ${n}\n`);
    }

    // ---- la pointeuse demande des commandes
    if (p === '/iclock/getrequest') {
      const info = url.searchParams.get('INFO');
      await heartbeat(sn, ip, info ? { force: true, info } : {});
      if (!config.token) return reply(res, 'OK');
      let cmds = [];
      try {
        cmds = (await rpc('pointeuse_take_commands', { p_token: config.token, p_sn: sn })) ?? [];
      } catch (e) {
        log('Lecture des commandes échouée :', e.message);
      }
      if (!cmds.length) return reply(res, 'OK');
      for (const c of cmds) log(`→ commande #${c.id} envoyée : ${c.command.replace(/\t/g, ' ')}`);
      return reply(res, cmds.map((c) => `C:${c.id}:${c.command}`).join('\n') + '\n');
    }

    // ---- résultat des commandes
    if (p === '/iclock/devicecmd') {
      const body = await readBody(req);
      for (const line of body.split(/\r?\n/)) {
        const q = new URLSearchParams(line.trim());
        const id = Number(q.get('ID'));
        if (!id) continue;
        const ret = Number(q.get('Return') ?? 0);
        log(`← commande #${id} ${q.get('CMD') ?? ''} : ${ret >= 0 ? 'OK' : 'erreur ' + ret}`);
        try {
          await rpc('pointeuse_command_result', { p_token: config.token, p_id: id, p_return: ret });
        } catch (e) {
          log('Résultat de commande non enregistré :', e.message);
        }
      }
      return reply(res, 'OK');
    }

    if (p === '/iclock/ping') return reply(res, 'OK');
    if (p.startsWith('/iclock/')) return reply(res, 'OK');

    // ---- page d'état (http://localhost:8090)
    if (p === '/' || p === '/status') {
      const html = statusPage();
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end(html);
    }
    reply(res, 'Not found', 404);
  } catch (e) {
    log(`Erreur ${req.method} ${req.url} :`, e.message);
    // la pointeuse réessaiera plus tard — les pointages restent dans l'appareil
    reply(res, 'ERROR', 500);
  }
});

server.listen(config.port, '0.0.0.0', () => {
  log(`Passerelle pointeuse démarrée sur le port ${config.port} — page d'état : http://localhost:${config.port}`);
});
server.on('error', (e) => {
  log('Impossible de démarrer :', e.message);
  process.exit(1);
});
