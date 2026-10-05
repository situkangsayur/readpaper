'use strict';
// Uji asap panel (core/ui.js) di jsdom: berkas dimuat sebagai <script> biasa,
// persis seperti di task pane Word dan plugin OnlyOffice, dengan server
// ReadPaper dan editor tiruan. Dilewati bila jsdom belum dipasang (npm ci).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const h = require('./helpers.js');

let JSDOM = null;
try { ({ JSDOM } = require('jsdom')); } catch (e) { /* lewati */ }

const CORE = path.join(__dirname, '..');
const RP = h.RP;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function until(fn, what, ms = 8000) {
  const end = Date.now() + ms;
  for (;;) {
    const v = fn();
    if (v) return v;
    if (Date.now() > end) throw new Error('Menunggu terlalu lama: ' + what);
    await sleep(20);
  }
}

function fakeFetch() {
  const ok = (body, xml) => ({ ok: true, status: 200, json: async () => body, text: async () => (xml ? body : JSON.stringify(body)) });
  return async (url, init) => {
    const u = new URL(url);
    if (u.pathname === '/api/ping') return ok({ app: 'ReadPaper', version: '0.25.0', api: 1, library: 'Library Uji' });
    if (init.headers.Authorization !== 'Bearer rahasia') return { ok: false, status: 401, json: async () => ({}), text: async () => '{"error":"x"}' };
    if (u.pathname === '/api/search') {
      const q = (u.searchParams.get('q') || '').toLowerCase();
      return ok({ items: Object.values(h.ITEMS).filter((i) => i.title.toLowerCase().includes(q)).map((i) => ({
        key: i.id, title: i.title, creators: i.author[0].family, year: String(i.issued['date-parts'][0][0]),
        type: 'journalArticle', collections: [], annotationCount: i.id === 'MCCLEAN' ? 1 : 0 })) });
    }
    if (u.pathname === '/api/items') {
      const keys = JSON.parse(init.body).keys;
      return ok({ items: keys.map((k) => h.ITEMS[k]).filter(Boolean), missing: [] });
    }
    if (u.pathname === '/api/items/MCCLEAN/annotations') {
      return ok({ annotations: [{ key: 'AB12CD34', type: 'highlight', color: '#ffd400', text: 'barren plateaus', comment: '', pageLabel: '7' }] });
    }
    if (u.pathname === '/api/styles') return ok({ styles: [{ id: 'apa', title: 'APA', format: 'author-date' }, { id: 'ieee', title: 'IEEE', format: 'numeric' }] });
    if (u.pathname.startsWith('/api/styles/')) return ok(h.styleXml(u.pathname.split('/').pop()), true);
    if (u.pathname.startsWith('/api/locales/')) return ok(h.localeXml(u.pathname.split('/').pop()) || h.localeXml('en-US'), true);
    return { ok: false, status: 404, json: async () => ({}), text: async () => '{}' };
  };
}

function fakeAdapter(doc) {
  let next = 1;
  return {
    tagMode: 'ref',
    async readControls() { return { controls: doc.controls.map((c) => ({ handle: c.handle, tag: c.tag })), storeXml: doc.store }; },
    async currentControl() { const c = doc.controls[doc.cursorIn]; return c ? { handle: c.handle, tag: c.tag } : null; },
    async insertCitation(tag, runs) { const c = { handle: next++, tag, text: RP.runsToText(runs) }; doc.controls.splice(doc.cursor++, 0, c); return c.handle; },
    async writeCitations(list) { list.forEach((u) => { const c = doc.controls.find((x) => x.handle === u.handle); if (u.tag) c.tag = u.tag; c.text = RP.runsToText(u.runs); }); },
    async writeBibliography(handle, tag, bib) {
      let c = doc.controls.find((x) => x.handle === handle);
      if (!c) { c = { handle: next++ }; doc.controls.splice(doc.cursor++, 0, c); }
      c.tag = tag; c.text = bib.paragraphs.map((p) => RP.runsToText(p.runs)).join('\n');
      return c.handle;
    },
    async writeStore(xml) { doc.store = xml; return true; },
    async unwrap(hs) { doc.controls = doc.controls.filter((c) => !hs.includes(c.handle)); },
  };
}

test('panel: token, sisip, anotasi, sunting, daftar pustaka, gaya, uncited, teks biasa', { skip: !JSDOM && 'jsdom belum dipasang', timeout: 60000 }, async () => {
  const dom = new JSDOM('<!DOCTYPE html><div id="app"></div>', { runScripts: 'dangerously', url: 'https://example.org/word/taskpane.html' });
  const w = dom.window;
  w.TextEncoder = TextEncoder; w.TextDecoder = TextDecoder;
  const errors = [];
  w.addEventListener('error', (e) => errors.push(e.message));
  for (const f of ['vendor/citeproc.js', 'citations.js', 'readpaper-api.js', 'controller.js', 'ui.js']) {
    const s = w.document.createElement('script');
    s.textContent = fs.readFileSync(path.join(CORE, f), 'utf8');
    w.document.head.appendChild(s);
  }
  assert.ok(w.ReadPaperCitations && w.ReadPaperCitations.citeprocVersion, 'citeproc dimuat sebagai global');

  const doc = { controls: [], cursor: 0, store: null };
  const api = new w.ReadPaperApi.Client({ fetch: fakeFetch() });
  const ctl = new w.ReadPaperController({ adapter: fakeAdapter(doc), api });
  w.ReadPaperUI.mount(w.document.getElementById('app'), { controller: ctl, editor: 'Word' });
  const $ = (s) => w.document.querySelector(s);
  const $$ = (s) => [...w.document.querySelectorAll(s)];
  const btn = (t) => $$('button').find((b) => b.textContent.trim() === t);
  const status = () => $('.rp-status').textContent;

  // Tanpa token: layar token muncul lebih dulu.
  await until(() => $('input[type=password]'), 'layar token');
  $('input[type=password]').value = 'rahasia';
  btn('Simpan dan periksa').click();
  await until(() => /Terhubung/.test(status()), 'terhubung');
  assert.match($('.rp-header').textContent, /Library Uji/);

  // Sisipkan: cari sambil mengetik, Enter memilih, anotasi mengisi halaman, Ctrl+Enter menyisipkan.
  btn('Sisipkan sitasi').click();
  const input = await until(() => $('.rp-search input'), 'kotak cari');
  input.value = 'barren';
  input.dispatchEvent(new w.Event('input'));
  await until(() => $$('.rp-result').length === 1, 'hasil cari');
  input.dispatchEvent(new w.KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
  (await until(() => btn('Pilih anotasi'), 'tombol anotasi')).click();
  (await until(() => $('.rp-ann'), 'daftar anotasi')).click();
  await until(() => /hlm\. 7/.test($('.rp-preview').textContent), 'pratinjau');
  input.dispatchEvent(new w.KeyboardEvent('keydown', { key: 'Enter', ctrlKey: true, bubbles: true }));
  await until(() => doc.controls.length === 1 && /Sitasi disisipkan/.test(status()), 'sisip');
  assert.equal(doc.controls[0].text, '(McClean dkk., 2018, hlm. 7)');
  let loaded = await ctl.loadDocument();
  assert.equal(loaded.citations[0].citation.items[0].annotationKey, 'AB12CD34');
  assert.equal(loaded.citations[0].citation.items[0].locator, '7');

  // Daftar pustaka.
  doc.cursor = doc.controls.length;
  await until(() => btn('Sisipkan daftar pustaka'), 'tombol daftar pustaka');
  btn('Sisipkan daftar pustaka').click();
  await until(() => doc.controls.length === 2, 'daftar pustaka');
  assert.match(doc.controls[1].text, /^McClean, J\. R\./);

  // Sunting sitasi di kursor.
  doc.cursorIn = 0;
  btn('Sunting sitasi').click();
  const prefix = await until(() => $$('.rp-field input').find((x) => x.placeholder === 'mis. lihat'), 'isian prefiks');
  prefix.value = 'lihat';
  prefix.dispatchEvent(new w.Event('input'));
  btn('Simpan perubahan').click();
  await until(() => /Sitasi diperbarui/.test(status()), 'sunting');
  assert.equal(doc.controls[0].text, '(lihat McClean dkk., 2018, hlm. 7)');

  // Gaya: IEEE, perbarui semua.
  btn('Gaya sitasi…').click();
  (await until(() => $$('input[name=rp-style]').find((r) => r.value === 'ieee'), 'daftar gaya')).click();
  btn('Terapkan dan perbarui semua').click();
  await until(() => /Gaya diganti/.test(status()), 'ganti gaya', 20000);
  assert.equal(doc.controls[0].text, 'lihat [1, hlm. 7]');

  // Tanpa disitasi.
  btn('Tanpa disitasi…').click();
  const in3 = await until(() => $('.rp-search input'), 'kotak cari uncited');
  in3.value = 'uncited';
  in3.dispatchEvent(new w.Event('input'));
  (await until(() => $$('.rp-result')[0], 'hasil uncited')).dispatchEvent(new w.MouseEvent('mousedown', { bubbles: true }));
  await until(() => /Adams/.test($('.rp-uncited').textContent), 'uncited masuk');
  assert.match(doc.controls[1].text, /\[2\]\tA\. Adams/);
  btn('Keluarkan').click();
  await until(() => /Dikeluarkan/.test(status()), 'uncited keluar');
  assert.doesNotMatch(doc.controls[1].text, /Adams/);

  // Jadikan teks biasa.
  $('.rp-back').click();
  (await until(() => btn('Jadikan teks biasa…'), 'menu utama')).click();
  btn('Ya, jadikan teks biasa').click();
  await until(() => /teks biasa/.test(status()), 'teks biasa');
  assert.equal(doc.controls.length, 0);
  assert.equal(doc.store, null);

  assert.deepEqual(errors, []);
  w.close();
});
