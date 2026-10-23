'use strict';
// Uji add-on Google Docs: Code.js (server Apps Script) dijalankan di atas
// DocumentApp tiruan, panelnya — controller.js lewat gdocs-bridge.js — di
// Node. Setiap panggilan ke "server" lewat JSON, seperti google.script.run.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const Api = require('../../core/readpaper-api.js');
const Bridge = require('../gdocs-bridge.js');
const { RP, styleXml, localeXml, ITEMS } = require('../../core/test/helpers.js');
const { makeDoc, makeGlobals } = require('./fake-docs.js');

function memStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k) };
}

function fakeFetch() {
  return async (url, init) => {
    const u = new URL(url);
    const ok = (body, xml) => ({ ok: true, status: 200, json: async () => body, text: async () => (xml ? body : JSON.stringify(body)) });
    if (u.pathname === '/api/items') {
      const keys = JSON.parse(init.body).keys;
      return ok({ items: keys.filter((k) => ITEMS[k]).map((k) => ITEMS[k]), missing: keys.filter((k) => !ITEMS[k]) });
    }
    if (u.pathname.startsWith('/api/styles/')) return ok(styleXml(u.pathname.split('/').pop()), true);
    if (u.pathname.startsWith('/api/locales/')) return ok(localeXml(u.pathname.split('/').pop()) || localeXml('en-US'), true);
    return { ok: false, status: 404, json: async () => ({}), text: async () => '{}' };
  };
}

function setup() {
  const { doc, helpers } = makeDoc();
  const globals = makeGlobals(doc);
  const sandbox = Object.assign({}, globals);
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'Code.js'), 'utf8'), sandbox, { filename: 'Code.js' });
  const calls = [];
  const call = (name, arg) => {
    calls.push(name);
    // Seperti google.script.run: argumen dan hasil diserialisasi.
    const a = arg === undefined ? undefined : JSON.parse(JSON.stringify(arg));
    try {
      const r = sandbox[name](a);
      return Promise.resolve(r === undefined ? null : JSON.parse(JSON.stringify(r)));
    } catch (e) {
      return Promise.reject(e);
    }
  };
  const api = new Api.Client({ fetch: fakeFetch(), storage: memStorage() });
  api.setToken('rahasia');
  const ctl = Bridge.create({ api, call });
  return { doc, helpers, ctl, calls, props: globals._props };
}

async function insert(ctl, keys, extra) {
  const doc = await ctl.loadDocument();
  const cit = ctl.newCitation(doc, keys.map((k) => Object.assign({ itemData: ITEMS[k] }, (extra || {})[k])), false);
  return ctl.insertCitation(cit);
}

function citationTexts(h) {
  const pos = (p) => h.body.children.indexOf(p.el.para) * 1e6 + p.start;
  return h.ranges.filter((r) => r.name.startsWith('READPAPER_CITATION_v1') && r.parts.length)
    .sort((a, b) => pos(a.parts[0]) - pos(b.parts[0]))
    .map((r) => r.parts[0].el.s.slice(r.parts[0].start, r.parts[0].end + 1));
}

function bibTexts(h) {
  const r = h.ranges.filter((x) => x.name === 'READPAPER_BIBLIOGRAPHY_v1');
  assert.equal(r.length, 1, 'harus ada tepat satu daftar pustaka');
  return r[0].parts.map((p) => p.para.text.s);
}

test('Google Docs: sisip di kursor, nomor sementara, daftar pustaka, perbarui — dua panggilan per perintah', async () => {
  const s = setup();
  await s.ctl.setStyle('ieee', 'id-ID');
  s.helpers.type('Buku tenang ');
  s.calls.length = 0;
  let r = await insert(s.ctl, ['KARISMA']);
  assert.equal(r.text, '[1]');
  // loadDocument + insertCitation: masing-masing satu potret; hanya
  // insertCitation yang menulis.
  assert.deepEqual(s.calls, ['rpSnapshot', 'rpSnapshot', 'rpApply']);
  s.helpers.type(' dan plateau ');
  r = await insert(s.ctl, ['MCCLEAN'], { MCCLEAN: { locator: '12', label: 'page' } });
  assert.equal(r.text, '[2, hlm. 12]');
  assert.equal(s.helpers.text(), 'Buku tenang [1] dan plateau [2, hlm. 12]');

  // Kursor di awal kalimat: sitasi baru di depan, yang lain belum disentuh.
  s.helpers.cursorAt(s.helpers.body.children[0].text, 0);
  r = await insert(s.ctl, ['ZHANG']);
  assert.equal(r.text, '[1]');
  assert.deepEqual(citationTexts(s.helpers), ['[1]', '[1]', '[2, hlm. 12]']);

  s.helpers.newParagraph();
  const b = await s.ctl.bibliography();
  assert.equal(b.inserted, true);
  await s.ctl.refreshAll();
  assert.equal(s.helpers.text().split('\n')[0], '[1]Buku tenang [2] dan plateau [3, hlm. 12]');
  const bib = bibTexts(s.helpers);
  assert.equal(bib.length, 3);
  assert.match(bib[0], /^\[1\]\tW\. Zhang/);
  // Paragraf daftar pustaka diberi indentasi gantung untuk gaya bernomor.
  const para = s.helpers.ranges.find((x) => x.name === 'READPAPER_BIBLIOGRAPHY_v1').parts[0].para;
  assert.ok(para.props.indentStart > 0);
});

test('Google Docs — aturan 1 (bug Zotero): klaster dikurangi dan sitasi dihapus, referensinya ikut hilang', async () => {
  const s = setup();
  await s.ctl.setStyle('apa', 'id-ID');
  s.helpers.type('A ');
  await insert(s.ctl, ['KARISMA', 'ZHANG']);
  s.helpers.type(' B ');
  await insert(s.ctl, ['MCCLEAN']);
  s.helpers.newParagraph();
  await s.ctl.bibliography();
  assert.equal(bibTexts(s.helpers).length, 3);

  // Kursor di dalam sitasi pertama → sunting, keluarkan Zhang.
  const first = s.helpers.ranges.find((r) => r.name.startsWith('READPAPER_CITATION_v1') && /Karisma/.test(r.parts[0].el.s.slice(r.parts[0].start, r.parts[0].end + 1)));
  s.helpers.cursorAt(first.parts[0].el, first.parts[0].start + 2);
  const cur = await s.ctl.currentCitation();
  assert.ok(cur, 'sitasi di kursor harus ditemukan');
  assert.deepEqual(cur.entry.citation.items.map((i) => i.key), ['KARISMA', 'ZHANG']);
  await s.ctl.updateCitation(cur.entry, RP.makeCitation([{ itemData: ITEMS.KARISMA }], { id: cur.entry.citation.id }));
  await s.ctl.refreshAll();
  assert.doesNotMatch(bibTexts(s.helpers).join('\n'), /Zhang/);
  assert.equal(bibTexts(s.helpers).length, 2);

  // Teks sitasi McClean dihapus penulis: named range-nya ikut kosong.
  const mc = s.helpers.ranges.find((r) => r.name.startsWith('READPAPER_CITATION_v1') && /McClean/.test(r.parts[0].el.s.slice(r.parts[0].start, r.parts[0].end + 1)));
  mc.parts[0].el.deleteText(mc.parts[0].start, mc.parts[0].end);
  await s.ctl.refreshAll();
  const bib = bibTexts(s.helpers);
  assert.equal(bib.length, 1);
  assert.match(bib[0], /^Karisma/);
  const doc = await s.ctl.loadDocument();
  assert.equal(doc.citations.length, 1);
  assert.deepEqual(doc.settings.uncited, []);
});

test('Google Docs: tanpa disitasi, jadikan teks biasa, store dipecah per 8000 karakter', async () => {
  const s = setup();
  await s.ctl.setStyle('chicago-author-date', 'id-ID');
  s.helpers.type('X ');
  await insert(s.ctl, ['MCCLEAN']);
  s.helpers.newParagraph();
  await s.ctl.bibliography();
  await s.ctl.addUncited(ITEMS.ADAMS);
  assert.equal(bibTexts(s.helpers).length, 2);
  assert.ok(Number(s.props.get('readpaper.store.n')) > 1, 'salinan gaya Chicago lebih dari satu potong');
  for (const [k, v] of s.props) if (k !== 'readpaper.store.n') assert.ok(v.length <= 8000, k);
  await s.ctl.removeUncited('ADAMS');
  assert.equal(bibTexts(s.helpers).length, 1);

  const before = s.helpers.text();
  const r = await s.ctl.convertToText();
  assert.equal(r.removed, 2);
  assert.equal(s.helpers.ranges.length, 0);
  assert.equal(s.helpers.text(), before);
  assert.equal(s.props.get('readpaper.store.n'), '0');
});

test('Google Docs: perintah yang gagal tidak menulis setengah perubahan', async () => {
  const s = setup();
  s.helpers.type('Teks ');
  const doc = await s.ctl.loadDocument();
  const bad = s.ctl.newCitation(doc, [{ itemData: ITEMS.KARISMA }], false);
  s.ctl.api.styleXml = () => Promise.reject(Object.assign(new Error('Gaya tidak ada'), { code: 'notfound' }));
  s.calls.length = 0;
  await assert.rejects(s.ctl.insertCitation(bad));
  assert.deepEqual(s.calls, ['rpSnapshot']);
  assert.equal(s.helpers.text(), 'Teks ');
});
