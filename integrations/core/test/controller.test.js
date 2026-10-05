'use strict';
// Uji alur perintah dengan editor tiruan di memori, untuk kedua mode
// penyimpanan: 'inline' (OnlyOffice) dan 'ref' (Word).
const test = require('node:test');
const assert = require('node:assert/strict');
const Controller = require('../controller.js');
const Api = require('../readpaper-api.js');
const { RP, styleXml, localeXml, ITEMS } = require('./helpers.js');

function memStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k) };
}

function fakeFetch(state) {
  return async (url, init) => {
    if (state.down) throw new TypeError('Failed to fetch');
    const u = new URL(url);
    const ok = (body, xml) => ({ ok: true, status: 200, json: async () => body, text: async () => (xml ? body : JSON.stringify(body)) });
    if (u.pathname === '/api/items') {
      const keys = JSON.parse(init.body).keys;
      return ok({ items: keys.filter((k) => state.items[k]).map((k) => state.items[k]), missing: keys.filter((k) => !state.items[k]) });
    }
    if (u.pathname.startsWith('/api/styles/')) return ok(styleXml(u.pathname.split('/').pop()), true);
    if (u.pathname.startsWith('/api/locales/')) return ok(localeXml(u.pathname.split('/').pop()) || localeXml('en-US'), true);
    return { ok: false, status: 404, json: async () => ({}), text: async () => '{}' };
  };
}

/** Dokumen tiruan: deretan content control + posisi kursor. */
function fakeEditor(tagMode) {
  let next = 1;
  const doc = { controls: [], cursor: 0, store: null, storeSupported: true };
  const adapter = {
    tagMode,
    async readControls() {
      return { controls: doc.controls.map((c) => ({ handle: c.handle, tag: c.tag })), storeXml: doc.store };
    },
    async currentControl() {
      const c = doc.controls[doc.cursorIn];
      return c ? { handle: c.handle, tag: c.tag } : null;
    },
    async insertCitation(tag, runs) {
      const c = { handle: 'h' + next++, tag, text: RP.runsToText(runs), kind: 'citation' };
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
        c = { handle: 'h' + next++, kind: 'bibliography' };
        doc.controls.splice(doc.cursor, 0, c);
        doc.cursor++;
      }
      c.tag = tag;
      c.paragraphs = bib.paragraphs.map((p) => RP.runsToText(p.runs));
      return c.handle;
    },
    async writeStore(xml) {
      if (!doc.storeSupported) return false;
      doc.store = xml;
      return true;
    },
    async unwrap(handles) {
      doc.controls = doc.controls.filter((c) => handles.indexOf(c.handle) < 0);
    },
  };
  return { doc, adapter };
}

function setup(tagMode, opts = {}) {
  const state = { down: false, items: Object.assign({}, ITEMS) };
  const api = new Api.Client({ fetch: fakeFetch(state), storage: memStorage() });
  api.setToken('rahasia');
  const ed = fakeEditor(tagMode);
  if (opts.noStore) ed.doc.storeSupported = false;
  const ctl = new Controller({ adapter: ed.adapter, api });
  return { state, api, ed, ctl };
}

async function insert(ctl, keys, extra) {
  const doc = await ctl.loadDocument();
  const cit = ctl.newCitation(doc, keys.map((k) => Object.assign({ itemData: ITEMS[k] }, (extra || {})[k])), false);
  return ctl.insertCitation(cit);
}

for (const mode of ['inline', 'ref']) {
  test(`[${mode}] sisip, nomor sementara, perbarui semua, daftar pustaka`, async () => {
    const { ctl, ed } = setup(mode);
    await ctl.setStyle('ieee', 'id-ID');
    let r = await insert(ctl, ['KARISMA']);
    assert.equal(r.text, '[1]');
    r = await insert(ctl, ['MCCLEAN'], { MCCLEAN: { locator: '12', label: 'page' } });
    assert.equal(r.text, '[2, hlm. 12]');
    // Kursor dipindah ke awal: sitasi baru di depan dihitung dari yang ada.
    ed.doc.cursor = 0;
    r = await insert(ctl, ['ZHANG']);
    assert.equal(r.text, '[1]');
    // Sitasi lain belum disentuh (aturan 2).
    assert.deepEqual(ed.doc.controls.map((c) => c.text), ['[1]', '[1]', '[2, hlm. 12]']);
    if (mode === 'ref') {
      assert.ok(ed.doc.controls.every((c) => c.tag.length < 64), 'tag Word harus pendek');
    }

    ed.doc.cursor = ed.doc.controls.length;
    const b = await ctl.bibliography();
    assert.equal(b.inserted, true);
    const sum = await ctl.refreshAll();
    assert.equal(sum.citations, 3);
    assert.equal(sum.bibliographies, 1);
    assert.deepEqual(ed.doc.controls.slice(0, 3).map((c) => c.text), ['[1]', '[2]', '[3, hlm. 12]']);
    const bib = ed.doc.controls[3].paragraphs;
    assert.equal(bib.length, 3);
    assert.match(bib[0], /^\[1\]\tW\. Zhang/);

    // Aturan 1: hapus sitasi, perbarui, item hilang dari daftar pustaka.
    ed.doc.controls.splice(0, 1);
    await ctl.refreshAll();
    assert.deepEqual(ed.doc.controls.slice(0, 2).map((c) => c.text), ['[1]', '[2, hlm. 12]']);
    assert.equal(ed.doc.controls[2].paragraphs.length, 2);
    assert.doesNotMatch(ed.doc.controls[2].paragraphs.join('\n'), /Zhang/);
  });

  test(`[${mode}] sunting sitasi di posisi kursor`, async () => {
    const { ctl, ed } = setup(mode);
    await insert(ctl, ['KARISMA']);
    ed.doc.cursorIn = 0;
    const cur = await ctl.currentCitation();
    assert.ok(cur);
    const items = cur.entry.citation.items.map((it) => Object.assign({}, it, { locator: '7', prefix: 'lihat' }));
    const updated = RP.makeCitation(items, { id: cur.entry.citation.id });
    const r = await ctl.updateCitation(cur.entry, updated);
    assert.equal(r.text, '(lihat Karisma, 2020, hlm. 7)');
    const again = await ctl.loadDocument();
    assert.equal(again.citations[0].citation.items[0].locator, '7');
  });

  test(`[${mode}] gaya, uncited, tanpa ReadPaper, dan jadikan teks biasa`, async () => {
    const { ctl, ed, state, api } = setup(mode);
    await insert(ctl, ['MCCLEAN']);
    ed.doc.cursor = ed.doc.controls.length;
    await ctl.bibliography();
    await ctl.addUncited(ITEMS.ADAMS);
    let doc = await ctl.loadDocument();
    assert.deepEqual(doc.settings.uncited.map((u) => u.key), ['ADAMS']);
    assert.match(ed.doc.controls[1].paragraphs[0], /^Adams/);

    // Data item berubah di ReadPaper: "perbarui semua" mengambilnya.
    state.items.MCCLEAN = Object.assign({}, ITEMS.MCCLEAN, { issued: { 'date-parts': [[2019]] } });
    let sum = await ctl.refreshAll();
    assert.equal(sum.refreshedItems, 1);
    assert.equal(ed.doc.controls[0].text, '(McClean dkk., 2019)');

    // ReadPaper mati, add-in di komputer lain (cache lokal kosong):
    // dokumen tetap bisa diperbarui dari salinan gaya, locale, dan data di dalamnya.
    state.down = true;
    const other = new Controller({ adapter: ed.adapter, api: new Api.Client({ fetch: fakeFetch(state), storage: memStorage() }) });
    sum = await other.refreshAll();
    assert.equal(sum.offline, true);
    assert.equal(ed.doc.controls[0].text, '(McClean dkk., 2019)');
    state.down = false;

    await ctl.setStyle('vancouver-nlm', 'id-ID');
    assert.equal(ed.doc.controls[0].text, '(1)');
    assert.equal(ed.doc.controls[1].paragraphs.length, 2);
    doc = await ctl.loadDocument();
    assert.equal(doc.settings.style, 'vancouver-nlm');
    assert.equal(api.store.get('readpaper.lastStyle'), 'vancouver-nlm');

    await ctl.removeUncited('ADAMS');
    assert.equal(ed.doc.controls[1].paragraphs.length, 1);

    const conv = await ctl.convertToText();
    assert.equal(conv.removed, 2);
    assert.equal(ed.doc.controls.length, 0);
    assert.equal(ed.doc.store, null);
  });
}

test('[inline] pengaturan tetap terbaca dari tag daftar pustaka bila custom XML tidak didukung', async () => {
  const { ctl, ed } = setup('inline', { noStore: true });
  await ctl.setStyle('ieee', 'id-ID');
  await insert(ctl, ['KARISMA']);
  ed.doc.cursor = ed.doc.controls.length;
  await ctl.bibliography();
  ctl.api.store.remove('readpaper.lastStyle');
  const doc = await ctl.loadDocument();
  assert.equal(doc.hasSettings, true);
  assert.equal(doc.settings.style, 'ieee');
});

test('[ref] dokumen buatan OnlyOffice (tag inline) terbaca di Word, dan sebaliknya', async () => {
  const oo = setup('inline');
  await insert(oo.ctl, ['KARISMA']);
  const word = setup('ref');
  word.ed.doc.controls = oo.ed.doc.controls.map((c) => Object.assign({}, c));
  word.ed.doc.store = oo.ed.doc.store;
  let doc = await word.ctl.loadDocument();
  assert.equal(doc.citations.length, 1);
  await word.ctl.refreshAll();
  assert.match(word.ed.doc.controls[0].tag, /^READPAPER_CITATION_v1#c-/);
  // Kembali ke OnlyOffice: tag rujukan dibaca dari custom XML part.
  oo.ed.doc.controls = word.ed.doc.controls.map((c) => Object.assign({}, c));
  oo.ed.doc.store = word.ed.doc.store;
  doc = await oo.ctl.loadDocument();
  assert.equal(doc.citations.length, 1);
  assert.equal(doc.broken.length, 0);
});

test('[ref] salin-tempel di dokumen yang sama menghasilkan id baru saat diperbarui', async () => {
  const { ctl, ed } = setup('ref');
  await insert(ctl, ['KARISMA']);
  ed.doc.controls.push(Object.assign({}, ed.doc.controls[0], { handle: 'tempel' }));
  const sum = await ctl.refreshAll();
  assert.equal(sum.renamed, 1);
  assert.notEqual(ed.doc.controls[0].tag, ed.doc.controls[1].tag);
  const doc = await ctl.loadDocument();
  assert.equal(doc.citations.length, 2);
});

test('[ref] sitasi tanpa data (ditempel dari dokumen lain) dilaporkan, tidak dihapus', async () => {
  const { ctl, ed } = setup('ref');
  ed.doc.controls.push({ handle: 'x', tag: 'READPAPER_CITATION_v1#c-abcdef', text: '(Lama, 2000)' });
  const sum = await ctl.refreshAll();
  assert.equal(sum.broken, 1);
  assert.equal(ed.doc.controls[0].text, '(Lama, 2000)');
});
