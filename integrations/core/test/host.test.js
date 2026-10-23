'use strict';
// Uji host.js: perintah dijalankan atas potret dokumen, hasilnya diterapkan
// ke dokumen tiruan seperti yang dilakukan ekstensi LibreOffice.
const test = require('node:test');
const assert = require('node:assert/strict');
const Host = require('../host.js');
const { RP, styleXml, localeXml, ITEMS } = require('./helpers.js');

function memStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k) };
}

function fakeFetch(items) {
  return async (url, init) => {
    const u = new URL(url);
    const ok = (body, xml) => ({ ok: true, status: 200, json: async () => body, text: async () => (xml ? body : JSON.stringify(body)) });
    if (u.pathname === '/api/items') {
      const keys = JSON.parse(init.body).keys;
      return ok({ items: keys.filter((k) => items[k]).map((k) => items[k]), missing: keys.filter((k) => !items[k]) });
    }
    if (u.pathname.startsWith('/api/styles/')) return ok(styleXml(u.pathname.split('/').pop()), true);
    if (u.pathname.startsWith('/api/locales/')) return ok(localeXml(u.pathname.split('/').pop()) || localeXml('en-US'), true);
    return { ok: false, status: 404, json: async () => ({}), text: async () => '{}' };
  };
}

/**
 * Dokumen LibreOffice tiruan: deretan sitasi dan daftar pustaka, kursor, dan
 * store. `run` memotretnya, menjalankan perintah, dan menerapkan hasilnya
 * persis seperti readpaper_lo.py.
 */
function fakeWriter() {
  let next = 1;
  const doc = { controls: [], cursor: 0, cursorIn: null, store: null };
  const host = new Host.Host({ fetch: fakeFetch(Object.assign({}, ITEMS)), storage: memStorage() });
  async function run(command, args) {
    const snapshot = {
      tagMode: 'inline',
      controls: doc.controls.map((c) => ({ handle: c.handle, tag: c.tag })),
      storeXml: doc.store,
      cursor: doc.cursor,
      cursorIn: doc.cursorIn,
    };
    const r = await host.run({ command, args, doc: JSON.parse(JSON.stringify(snapshot)) });
    if (!r.ok) throw new Error(r.error);
    const ch = r.changes;
    const real = {};
    ch.unwrap.forEach((h) => { doc.controls = doc.controls.filter((c) => c.handle !== h); });
    if (ch.insert) {
      const c = { handle: 'lo' + next++, tag: ch.insert.tag, text: RP.runsToText(ch.insert.runs), kind: 'citation' };
      real[ch.insert.handle] = c.handle;
      doc.controls.splice(doc.cursor, 0, c);
      doc.cursor++;
    }
    ch.citations.forEach((u) => {
      const c = doc.controls.find((x) => x.handle === (real[u.handle] || u.handle));
      if (u.tag) c.tag = u.tag;
      c.text = RP.runsToText(u.runs);
    });
    ch.bibliographies.forEach((b) => {
      let c = doc.controls.find((x) => x.handle === b.handle);
      if (b.created) {
        c = { handle: 'lo' + next++, kind: 'bibliography' };
        doc.controls.splice(doc.cursor, 0, c);
        doc.cursor++;
      }
      c.tag = b.tag;
      c.paragraphs = b.bib.paragraphs.map((p) => RP.runsToText(p.runs));
    });
    if (ch.store !== undefined) doc.store = ch.store;
    return r;
  }
  const texts = () => doc.controls.filter((c) => c.kind === 'citation').map((c) => c.text);
  const bib = () => (doc.controls.find((c) => c.kind === 'bibliography') || {}).paragraphs;
  return { doc, run, texts, bib };
}

test('host: sisip, daftar pustaka, perbarui — satu kali jalan per perintah', async () => {
  const w = fakeWriter();
  await w.run('setStyle', { style: 'ieee', locale: 'id-ID' });
  let r = await w.run('insert', { items: [{ key: 'KARISMA' }] });
  assert.equal(r.result.text, '[1]');
  assert.equal(r.changes.insert.runs.map((x) => x.text).join(''), '[1]', 'sitasi baru ditulis sekali, langsung bernomor');
  r = await w.run('insert', { items: [{ key: 'MCCLEAN', locator: '12' }] });
  assert.equal(r.result.text, '[2, hlm. 12]');
  w.doc.cursor = 0;
  await w.run('insert', { items: [{ key: 'ZHANG' }] });
  // Aturan 2: sitasi lain tidak ditulis ulang saat menyisipkan.
  assert.deepEqual(w.texts(), ['[1]', '[1]', '[2, hlm. 12]']);

  w.doc.cursor = w.doc.controls.length;
  r = await w.run('bibliography');
  assert.equal(r.result.inserted, true);
  r = await w.run('refresh');
  assert.equal(r.result.citations, 3);
  assert.deepEqual(w.texts(), ['[1]', '[2]', '[3, hlm. 12]']);
  assert.equal(w.bib().length, 3);

  const state = (await w.run('state')).result;
  assert.equal(state.style, 'ieee');
  assert.equal(state.citations, 3);
  assert.equal(state.bibliographies, 1);
});

test('aturan 1 (bug Zotero): sitasi dihapus atau dikurangi → referensinya ikut hilang', async () => {
  const w = fakeWriter();
  await w.run('setStyle', { style: 'apa', locale: 'id-ID' });
  await w.run('insert', { items: [{ key: 'KARISMA' }, { key: 'ZHANG' }] });
  await w.run('insert', { items: [{ key: 'MCCLEAN' }] });
  w.doc.cursor = w.doc.controls.length;
  await w.run('bibliography');
  assert.equal(w.bib().length, 3);

  // Dikurangi: klaster (Karisma; Zhang) disunting jadi hanya Karisma.
  w.doc.cursorIn = w.doc.controls[0].handle;
  const cur = (await w.run('state')).result.current;
  assert.deepEqual(cur.items.map((i) => i.key), ['KARISMA', 'ZHANG']);
  await w.run('update', { items: [{ key: 'KARISMA' }] });
  w.doc.cursorIn = null;
  await w.run('refresh');
  assert.equal(w.bib().length, 2);
  assert.doesNotMatch(w.bib().join('\n'), /Zhang/);

  // Dihapus: sitasi McClean dihapus penulis dari teks.
  w.doc.controls = w.doc.controls.filter((c) => !(c.kind === 'citation' && /McClean/.test(c.text)));
  await w.run('refresh');
  assert.equal(w.bib().length, 1);
  assert.doesNotMatch(w.bib().join('\n'), /McClean/);

  // Dan daftar "tanpa disitasi" yang dibuka sesudahnya tidak menyimpan sisa:
  // item yang sitasinya dihapus tidak pindah ke sana.
  const s = (await w.run('state')).result;
  assert.deepEqual(s.uncited, []);
  assert.equal(s.citations, 1);

  // Bibliografi tetap dibangun dari dokumen walau store masih memuat salinan
  // lama: store di sini hanya pengaturan dan cache gaya.
  await w.run('bibliography');
  assert.equal(w.bib().length, 1);
});

test('host: tanpa disitasi, jadikan teks biasa, dan galat yang jelas', async () => {
  const w = fakeWriter();
  await w.run('insert', { items: [{ key: 'MCCLEAN' }] });
  w.doc.cursor = w.doc.controls.length;
  await w.run('bibliography');
  await w.run('addUncited', { key: 'ADAMS' });
  let s = (await w.run('state')).result;
  assert.deepEqual(s.uncited.map((u) => u.key), ['ADAMS']);
  assert.equal(w.bib().length, 2);
  await w.run('removeUncited', { key: 'ADAMS' });
  assert.equal(w.bib().length, 1);

  await assert.rejects(w.run('insert', { items: [{ key: 'TIDAKADA' }] }), /TIDAKADA/);
  await assert.rejects(w.run('update', { items: [{ key: 'MCCLEAN' }] }), /Kursor/);
  await assert.rejects(w.run('entahlah'), /tidak dikenal/);

  const r = await w.run('convertToText');
  assert.equal(r.result.removed, 2);
  assert.equal(r.changes.store, null);
  assert.equal(w.doc.controls.length, 0);
});

test('host: start/take untuk mesin yang hanya bertukar string', async () => {
  const host = new Host.Host({ fetch: fakeFetch(ITEMS), storage: memStorage() });
  const id = host.start(JSON.stringify({ command: 'state', doc: { controls: [] } }));
  assert.equal(typeof id, 'string');
  await new Promise((r) => setImmediate(r));
  const out = JSON.parse(host.take(id));
  assert.equal(out.ok, true);
  assert.equal(out.result.citations, 0);
  assert.equal(host.take(id), null);
});
