'use strict';
// ReadPaper tiruan untuk menguji ekstensi LibreOffice tanpa aplikasi Flutter:
// alamat dan bentuk jawabannya sama dengan CitationServer, dan POST /api/run
// dijalankan host.js yang SAMA dengan yang dimuat ReadPaper ke JavaScriptCore.
//
//   node mock-readpaper.js <port> <token>
//
// Item dan gaya diambil dari data uji inti (core/test/helpers.js) dan
// assets/csl/.
const http = require('http');
const path = require('path');
const fs = require('fs');
const Host = require('../../core/host.js');
const { styleXml, localeXml, ITEMS } = require('../../core/test/helpers.js');

const port = Number(process.argv[2] || 23999);
const token = process.argv[3] || 'token-uji-libreoffice-yang-panjang-sekali-0123';
const CSL = path.join(__dirname, '..', '..', '..', 'assets', 'csl');

const ANNOTATIONS = {
  MCCLEAN: [{ key: 'AB12CD34', type: 'highlight', color: '#ffd400', text: 'Barren plateau', comment: 'inti', pageLabel: '12' }],
};

function summary(it) {
  const names = (it.author || []).map((a) => a.family || a.literal);
  return {
    key: it.id, title: it.title,
    creators: names.length > 3 ? names.slice(0, 3).join(', ') + ' dkk.' : names.join(', '),
    year: String(((it.issued || {})['date-parts'] || [[]])[0][0] || ''),
    type: 'journalArticle', collections: [], annotationCount: (ANNOTATIONS[it.id] || []).length,
  };
}

function api(method, pathname, query, body) {
  if (pathname === '/api/items' && method === 'POST') {
    const keys = body.keys || [];
    return [200, { items: keys.filter((k) => ITEMS[k]).map((k) => ITEMS[k]), missing: keys.filter((k) => !ITEMS[k]) }];
  }
  let m;
  if ((m = /^\/api\/styles\/([^/]+)$/.exec(pathname))) return [200, styleXml(decodeURIComponent(m[1])), true];
  if ((m = /^\/api\/locales\/([^/]+)$/.exec(pathname))) {
    return [200, localeXml(decodeURIComponent(m[1])) || localeXml('en-US'), true];
  }
  if (pathname === '/api/styles') {
    const list = JSON.parse(fs.readFileSync(path.join(CSL, 'styles.json'), 'utf8')).styles;
    return [200, { styles: list.map((s) => ({ id: s.id, title: s.title, kind: s.kind, format: s.format, parent: s.parent || null })) }];
  }
  if (pathname === '/api/search') {
    const q = (query.get('q') || '').toLowerCase();
    const found = Object.values(ITEMS).filter((it) => !q || JSON.stringify(it).toLowerCase().includes(q));
    return [200, { items: found.map(summary) }];
  }
  if ((m = /^\/api\/items\/([^/]+)\/annotations$/.exec(pathname))) {
    return [200, { annotations: ANNOTATIONS[decodeURIComponent(m[1])] || [] }];
  }
  return [404, { error: 'Alamat tidak dikenal.' }];
}

const host = new Host.Host({
  fetch: async (url, init) => {
    const u = new URL(url);
    const [status, body, xml] = api(init.method || 'GET', u.pathname, u.searchParams, init.body ? JSON.parse(init.body) : {});
    const text = xml ? body : JSON.stringify(body);
    return { ok: status === 200, status, text: async () => text, json: async () => JSON.parse(text) };
  },
});

http.createServer((req, res) => {
  let raw = '';
  req.on('data', (c) => { raw += c; });
  req.on('end', async () => {
    const u = new URL(req.url, 'http://127.0.0.1');
    const send = (status, body, xml) => {
      res.writeHead(status, { 'Content-Type': xml ? 'application/xml' : 'application/json; charset=utf-8' });
      res.end(xml ? body : JSON.stringify(body));
    };
    if (u.pathname === '/api/ping') return send(200, { app: 'ReadPaper', version: 'uji', api: 1, library: 'Uji', run: true });
    if (req.headers.authorization !== 'Bearer ' + token) return send(401, { error: 'Token salah.' });
    const body = raw ? JSON.parse(raw) : {};
    if (u.pathname === '/api/run' && req.method === 'POST') return send(200, await host.run(body));
    const [status, out, xml] = api(req.method, u.pathname, u.searchParams, body);
    return send(status, out, xml);
  });
}).listen(port, '127.0.0.1', () => process.stdout.write('ready ' + port + '\n'));
