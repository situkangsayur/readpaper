'use strict';
// Uji ujung ke ujung inti add-in terhadap server sitasi ReadPaper SUNGGUHAN:
// fetch asli, token asli, gaya dan locale CSL yang dikirim server, citeproc-js
// yang sama dengan panel Word. Hanya dokumennya yang tiruan — Word sendiri
// tidak ada di runner CI.
//
//   READPAPER_URL=http://127.0.0.1:23121 READPAPER_TOKEN=... \
//   READPAPER_KEYS=KEY1,KEY2 node --test e2e/server.e2e.js
const test = require('node:test');
const assert = require('node:assert/strict');
const Api = require('../core/readpaper-api.js');
const Controller = require('../core/controller.js');
const RP = require('../core/citations.js');

const BASE = process.env.READPAPER_URL || 'http://127.0.0.1:23121';
const TOKEN = process.env.READPAPER_TOKEN || '';
const KEYS = (process.env.READPAPER_KEYS || '').split(',').filter(Boolean);

function memStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k) };
}

/** Dokumen tiruan dengan perilaku content control Word ('ref': tag pendek). */
function fakeWord() {
  let next = 1;
  const doc = { controls: [], cursor: 0, store: null };
  const adapter = {
    tagMode: 'ref',
    async readControls() {
      return { controls: doc.controls.map((c) => ({ handle: c.handle, tag: c.tag })), storeXml: doc.store };
    },
    async currentControl() { return null; },
    async insertCitation(tag, runs) {
      const c = { handle: 'h' + next++, tag, text: RP.runsToText(runs) };
      doc.controls.splice(doc.cursor, 0, c);
      doc.cursor++;
      return c.handle;
    },
    async writeCitations(list) {
      list.forEach((u) => {
        const c = doc.controls.find((x) => x.handle === u.handle);
        if (u.tag) c.tag = u.tag;
        c.text = RP.runsToText(u.runs);
      });
    },
    async writeBibliography(handle, tag, bib) {
      let c = handle && doc.controls.find((x) => x.handle === handle);
      if (!c) {
        c = { handle: 'h' + next++ };
        doc.controls.splice(doc.cursor, 0, c);
        doc.cursor++;
      }
      c.tag = tag;
      c.paragraphs = bib.paragraphs.map((p) => RP.runsToText(p.runs));
      return c.handle;
    },
    async writeStore(xml) { doc.store = xml; return true; },
    async unwrap(handles) { doc.controls = doc.controls.filter((c) => handles.indexOf(c.handle) < 0); },
  };
  return { doc, adapter };
}

function client(token) {
  const api = new Api.Client({ baseUrl: BASE, fetch: (u, i) => fetch(u, i), storage: memStorage() });
  if (token) api.setToken(token);
  return api;
}

test('server hidup dan menyebut library yang terbuka', async () => {
  const p = await client('').ping();
  assert.ok(p, 'ping harus menjawab');
});

test('token salah ditolak dengan pesan yang benar', async () => {
  await assert.rejects(client('token-salah').search('', 1), (e) => e.code === 'unauthorized');
});

test('pencarian menemukan item library', async () => {
  const r = await client(TOKEN).search('', 10);
  const found = (r.items || r).map((i) => i.key || i.id);
  for (const k of KEYS) assert.ok(found.includes(k), `item ${k} harus ada di hasil pencarian`);
});

for (const [style, pattern] of [
  ['apa', /\(.+, \d{4}\)/],
  ['ieee', /^\[1\]$/],
]) {
  test(`sitasi dan daftar pustaka ${style} seperti di Word`, async () => {
    const api = client(TOKEN);
    const word = fakeWord();
    const ctl = new Controller({ adapter: word.adapter, api });
    await ctl.setStyle(style, 'id-ID');
    const { items } = await api.items(KEYS);
    assert.equal(items.length, KEYS.length, 'server harus mengirim CSL-JSON tiap item');

    const doc = await ctl.loadDocument();
    const cit = ctl.newCitation(doc, [{ itemData: items[0] }], false);
    const r = await ctl.insertCitation(cit);
    assert.match(r.text, pattern);

    word.doc.cursor = word.doc.controls.length;
    const b = await ctl.bibliography();
    assert.equal(b.inserted, true);
    const sum = await ctl.refreshAll();
    assert.equal(sum.citations, 1);
    assert.equal(sum.bibliographies, 1);
    const bib = word.doc.controls.find((c) => c.paragraphs).paragraphs;
    assert.equal(bib.length, 1);
    const title = String(items[0].title || '');
    assert.ok(bib[0].includes(title.slice(0, 20)), `daftar pustaka memuat judul: ${bib[0]}`);
    console.log(`  ${style}: ${r.text}  |  ${bib[0]}`);
  });
}

test('anotasi item terbaca oleh panel', async () => {
  const notes = await client(TOKEN).annotations(KEYS[0]);
  assert.ok(Array.isArray(notes.annotations || notes), 'anotasi berupa daftar');
});
