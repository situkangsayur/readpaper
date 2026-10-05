'use strict';
// Uji pemanggil API dengan fetch palsu (tanpa server sungguhan).
const test = require('node:test');
const assert = require('node:assert/strict');
const Api = require('../readpaper-api.js');
const { styleXml, localeXml } = require('./helpers.js');

function memStorage() {
  const m = new Map();
  return {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: (k) => m.delete(k),
  };
}

function response(status, body, xml) {
  const text = xml ? body : JSON.stringify(body);
  return {
    ok: status >= 200 && status < 300, status,
    json: async () => JSON.parse(text), text: async () => text,
  };
}

/** Server palsu yang menjawab sesuai kontrak. */
function fakeServer(opts = {}) {
  const calls = [];
  const f = async (url, init) => {
    calls.push({ url, init });
    if (opts.down) throw new TypeError('Failed to fetch');
    const u = new URL(url);
    if (u.pathname === '/api/ping') return response(200, { app: 'ReadPaper', version: '0.25.0', api: 1, library: 'My Library' });
    if (init.headers.Authorization !== 'Bearer rahasia') return response(401, { error: 'Token tidak sah' });
    if (u.pathname === '/api/search') return response(200, { items: [{ key: 'K1', title: u.searchParams.get('q') }] });
    if (u.pathname === '/api/items') {
      const keys = JSON.parse(init.body).keys;
      return response(200, { items: keys.filter((k) => k !== 'NOPE').map((k) => ({ id: k, type: 'book' })), missing: keys.filter((k) => k === 'NOPE') });
    }
    if (u.pathname === '/api/items/K1/annotations') return response(200, { annotations: [{ key: 'A1', pageLabel: '12' }] });
    if (u.pathname === '/api/styles') return response(200, { styles: [{ id: 'apa', title: 'APA' }] });
    if (u.pathname.startsWith('/api/styles/')) return response(200, styleXml(u.pathname.split('/').pop()), true);
    if (u.pathname.startsWith('/api/locales/')) return response(200, localeXml(u.pathname.split('/').pop()) || localeXml('en-US'), true);
    return response(404, { error: 'Tidak ada' });
  };
  f.calls = calls;
  return f;
}

test('ping tidak membawa token', async () => {
  const fetch = fakeServer();
  const c = new Api.Client({ fetch, storage: memStorage() });
  const p = await c.ping();
  assert.equal(p.app, 'ReadPaper');
  assert.equal(fetch.calls[0].url, 'http://127.0.0.1:23121/api/ping');
  assert.equal(fetch.calls[0].init.headers.Authorization, undefined);
});

test('tanpa token: galat "notoken" tanpa memanggil server', async () => {
  const fetch = fakeServer();
  const c = new Api.Client({ fetch, storage: memStorage() });
  await assert.rejects(c.search('x'), (e) => e.code === 'notoken' && /Token belum diisi/.test(e.message));
  assert.equal(fetch.calls.length, 0);
});

test('token salah: 401 menjadi pesan "Token salah"', async () => {
  const c = new Api.Client({ fetch: fakeServer(), storage: memStorage() });
  c.setToken('keliru');
  await assert.rejects(c.search('x'), (e) => e.code === 'unauthorized' && /^Token salah/.test(e.message));
});

test('server mati: pesan berbahasa Indonesia', async () => {
  const c = new Api.Client({ fetch: fakeServer({ down: true }), storage: memStorage() });
  c.setToken('rahasia');
  await assert.rejects(c.ping(), (e) => e.code === 'offline' &&
    e.message.startsWith('ReadPaper tidak berjalan atau server sitasinya mati'));
});

test('token disimpan di storage dan dipakai sebagai Bearer', async () => {
  const storage = memStorage();
  const fetch = fakeServer();
  new Api.Client({ fetch, storage }).setToken('  rahasia ');
  const c = new Api.Client({ fetch, storage });
  assert.equal(c.getToken(), 'rahasia');
  const items = await c.search('barren plateaus', 10);
  assert.equal(items[0].title, 'barren plateaus');
  assert.match(fetch.calls[0].url, /\/api\/search\?q=barren%20plateaus&limit=10$/);
  const it = await c.items(['K1', 'NOPE']);
  assert.deepEqual(it.missing, ['NOPE']);
  assert.equal(it.items[0].id, 'K1');
  assert.equal((await c.annotations('K1'))[0].pageLabel, '12');
  assert.equal((await c.styles())[0].id, 'apa');
  assert.deepEqual(c.cachedStyles(), [{ id: 'apa', title: 'APA' }]);
  await c.check();
});

test('galat server meneruskan pesan {"error"}', async () => {
  const fetch = async () => response(500, { error: 'Library belum dibuka' });
  const c = new Api.Client({ fetch, storage: memStorage() });
  c.setToken('rahasia');
  await assert.rejects(c.search(''), (e) => e.code === 'http' && e.message === 'Library belum dibuka');
});

test('loadStyleResources: server, lalu cache lokal, lalu salinan dokumen', async () => {
  const storage = memStorage();
  const c = new Api.Client({ fetch: fakeServer(), storage });
  c.setToken('rahasia');
  const r = await Api.loadStyleResources(c, 'american-medical-association', 'id-ID');
  assert.equal(r.offline, false);
  assert.deepEqual(Object.keys(r.locales).sort(), ['en-US', 'id-ID']);

  // Server mati: cache lokal add-in yang dipakai.
  const down = new Api.Client({ fetch: fakeServer({ down: true }), storage });
  const r2 = await Api.loadStyleResources(down, 'american-medical-association', 'id-ID');
  assert.equal(r2.offline, true);
  assert.equal(r2.sources.style, 'local');
  assert.equal(r2.styleXml, r.styleXml);

  // Komputer lain tanpa cache: salinan di dokumen.
  const other = new Api.Client({ fetch: fakeServer({ down: true }), storage: memStorage() });
  other.setToken('rahasia');
  const docCache = { style: 'apa', styleXml: styleXml('apa'), locales: { 'en-US': localeXml('en-US') } };
  const r3 = await Api.loadStyleResources(other, 'apa', 'id-ID', docCache);
  assert.equal(r3.sources.style, 'document');
  assert.ok(r3.locales['en-US']);
  assert.equal(r3.locales['id-ID'], undefined);
  const get = Api.localeRetriever(r3);
  assert.ok(get('en-GB')); // jatuh ke en-US lewat bahasa yang sama

  // Tidak ada apa-apa: galat yang jelas.
  await assert.rejects(Api.loadStyleResources(other, 'ieee', 'id-ID'), (e) => e.code === 'offline');
});
