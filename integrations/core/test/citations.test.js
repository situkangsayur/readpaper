'use strict';
// Uji inti sitasi dengan gaya dan locale CSL asli dari assets/csl/.
const test = require('node:test');
const assert = require('node:assert/strict');
const { RP, processor, ITEMS, cite } = require('./helpers.js');

function texts(result) {
  return result.order.map((id) => result.citations[id].text);
}
function bibKeys(result) {
  return result.bibliography.entries.map((e) => e.key);
}

test('gaya bernomor: nomor mengikuti urutan kemunculan (vancouver-nlm)', () => {
  const p = processor('vancouver-nlm');
  const r = p.render([cite('KARISMA'), cite('MCCLEAN'), cite('KARISMA'), cite('ZHANG')]);
  assert.deepEqual(texts(r), ['(1)', '(2)', '(1)', '(3)']);
  assert.deepEqual(bibKeys(r), ['KARISMA', 'MCCLEAN', 'ZHANG']);
  assert.match(r.bibliography.entries[0].text, /^1\.\tKarisma H\./);
  assert.equal(r.bibliography.secondFieldAlign, 'flush');
});

test('gaya bernomor: memindahkan sitasi menomori ulang (ieee)', () => {
  const p = processor('ieee');
  const a = cite('KARISMA');
  const b = cite('MCCLEAN');
  assert.deepEqual(texts(p.render([a, b])), ['[1]', '[2]']);
  // Urutan dokumen berubah: B sekarang lebih dulu. Mesin yang sama dipakai ulang.
  const r = p.render([b, a]);
  assert.deepEqual(texts(r), ['[1]', '[2]']);
  assert.deepEqual(bibKeys(r), ['MCCLEAN', 'KARISMA']);
  assert.match(r.bibliography.entries[0].text, /^\[1\]\tJ\. R\. McClean/);
});

test('author-date (apa): daftar pustaka urut abjad, bukan urut sitasi', () => {
  const p = processor('apa');
  const r = p.render([cite('ZHANG'), cite('KARISMA')]);
  assert.deepEqual(texts(r), ['(Zhang & Abbott, 2015)', '(Karisma, 2020)']);
  assert.deepEqual(bibKeys(r), ['KARISMA', 'ZHANG']);
  assert.equal(r.bibliography.hangingIndent, true);
  // Judul buku dimiringkan: run berformat terbawa dari HTML citeproc.
  const italic = r.bibliography.entries[0].runs.filter((x) => x.italic).map((x) => x.text).join('');
  assert.equal(italic, 'Membaca makalah dengan tenang');
});

test('klaster berisi beberapa item', () => {
  const r1 = processor('apa').render([cite(['ZHANG', 'MCCLEAN'])]);
  assert.deepEqual(texts(r1), ['(McClean dkk., 2018; Zhang & Abbott, 2015)']);
  const r2 = processor('vancouver-nlm').render([cite('KARISMA'), cite(['ZHANG', 'MCCLEAN'])]);
  assert.deepEqual(texts(r2), ['(1)', '(2,3)']);
});

test('lokator halaman memakai istilah locale ("hlm." di id-ID)', () => {
  const c = cite('MCCLEAN', { item: { MCCLEAN: { locator: '12-14', label: 'page' } } });
  assert.deepEqual(texts(processor('apa', 'id-ID').render([c])), ['(McClean dkk., 2018, hlm. 12–14)']);
  assert.deepEqual(texts(processor('apa', 'en-US').render([c])), ['(McClean et al., 2018, pp. 12–14)']);
  assert.deepEqual(texts(processor('ieee', 'id-ID').render([c])), ['[1, hlm. 12–14]']);
});

test('prefiks dan sufiks', () => {
  const c = cite('KARISMA', { item: { KARISMA: { prefix: 'lihat', suffix: ', khususnya bab 2' } } });
  assert.deepEqual(texts(processor('apa').render([c])), ['(lihat Karisma, 2020, khususnya bab 2)']);
});

test('aturan 1: sitasi yang dihapus hilang dari daftar pustaka', () => {
  const p = processor('vancouver-nlm');
  const a = cite('KARISMA');
  const b = cite('MCCLEAN');
  const c = cite('ZHANG');
  assert.deepEqual(bibKeys(p.render([a, b, c])), ['KARISMA', 'MCCLEAN', 'ZHANG']);
  const r = p.render([a, c]);
  assert.deepEqual(bibKeys(r), ['KARISMA', 'ZHANG']);
  assert.deepEqual(texts(r), ['(1)', '(2)']);
});

test('noBib: item yang hanya disitasi dengan noBib tidak masuk daftar pustaka', () => {
  const p = processor('apa');
  const r = p.render([cite('KARISMA'), cite('ZHANG', { noBib: true })]);
  assert.deepEqual(texts(r), ['(Karisma, 2020)', '(Zhang & Abbott, 2015)']);
  assert.deepEqual(bibKeys(r), ['KARISMA']);
  // Disitasi juga tanpa noBib di tempat lain: tetap masuk.
  const r2 = p.render([cite('KARISMA'), cite('ZHANG', { noBib: true }), cite('ZHANG')]);
  assert.deepEqual(bibKeys(r2), ['KARISMA', 'ZHANG']);
});

test('uncited: masuk daftar pustaka tanpa sitasi', () => {
  const uncited = [{ key: 'ADAMS', itemData: ITEMS.ADAMS }];
  const r = processor('apa').render([cite('KARISMA')], uncited);
  assert.deepEqual(bibKeys(r), ['ADAMS', 'KARISMA']);
  // Di gaya bernomor, item tanpa sitasi bernomor sesudah yang disitasi.
  const r2 = processor('ieee').render([cite('KARISMA')], uncited);
  assert.deepEqual(bibKeys(r2), ['KARISMA', 'ADAMS']);
  assert.match(r2.bibliography.entries[1].text, /^\[2\]\t/);
  // Uncited yang juga disitasi tidak muncul dua kali.
  const r3 = processor('apa').render([cite('ADAMS')], uncited);
  assert.deepEqual(bibKeys(r3), ['ADAMS']);
});

test('suppressAuthor: pengarang disembunyikan', () => {
  const c = cite('ZHANG', { item: { ZHANG: { suppressAuthor: true, locator: '15' } } });
  assert.deepEqual(texts(processor('apa').render([c])), ['(2015, hlm. 15)']);
  assert.deepEqual(texts(processor('chicago-author-date').render([c])), ['(2015, 15)']);
});

test('locale id-ID: "dkk." kecuali gaya yang mengunci bahasanya sendiri', () => {
  const r = processor('apa', 'id-ID').render([cite('MCCLEAN')]);
  assert.deepEqual(texts(r), ['(McClean dkk., 2018)']);
  const harvard = processor('harvard-cite-them-right', 'id-ID').render([cite('MCCLEAN')]);
  assert.match(harvard.bibliography.entries[0].text, /^McClean, J\.R\. dkk\. \(2018\)/);
  // Locale en-US: "et al."
  assert.deepEqual(texts(processor('apa', 'en-US').render([cite('MCCLEAN')])), ['(McClean et al., 2018)']);
  // AMA punya default-locale="en-US": seperti Zotero, bahasanya tidak ikut
  // diganti, jadi lokatornya "p" dan bukan "hlm.".
  const ama = processor('american-medical-association', 'id-ID')
    .render([cite('MCCLEAN', { item: { MCCLEAN: { locator: '5' } } })]);
  assert.deepEqual(texts(ama), ['1(p5)']);
  assert.equal(ama.citations[ama.order[0]].runs[0].superscript, true);
  assert.doesNotMatch(ama.bibliography.text, /dkk\./);
  // vancouver-nlm (induknya nlm-citation-sequence) tanpa default-locale:
  // ikut locale dokumen.
  const many = Object.assign({}, ITEMS.MCCLEAN, {
    author: ITEMS.MCCLEAN.author.concat([{ family: 'Satu', given: 'A' }, { family: 'Dua', given: 'B' }]),
  });
  const nlm = processor('vancouver-nlm', 'id-ID')
    .render([RP.makeCitation([{ itemData: many }])]);
  assert.match(nlm.bibliography.entries[0].text, /Neven H, Satu A, dkk\./);
});

test('preview: teks sitasi baru dihitung dari yang sudah ada', () => {
  const p = processor('ieee');
  const a = cite('KARISMA');
  const b = cite('MCCLEAN');
  const fresh = cite('ZHANG');
  assert.equal(p.preview([a, fresh, b], fresh.id).text, '[2]');
  assert.equal(p.preview([a, b, cite('KARISMA', { id: 'c-aaaaaa' })], 'c-aaaaaa').text, '[1]');
});

test('data item terbaru dipakai ulang oleh mesin yang sama', () => {
  const p = processor('apa');
  const c = cite('KARISMA');
  assert.deepEqual(texts(p.render([c])), ['(Karisma, 2020)']);
  RP.refreshItemData([c], null, { KARISMA: Object.assign({}, ITEMS.KARISMA, { issued: { 'date-parts': [[2021]] } }) });
  assert.deepEqual(texts(p.render([c])), ['(Karisma, 2021)']);
});

test('bentuk data: id c-xxxxxx, normalisasi, dan serialisasi', () => {
  const c = cite(['KARISMA', 'KARISMA', 'ZHANG']);
  assert.match(c.id, /^c-[0-9a-f]{6}$/);
  const n = RP.normalizeCitation(JSON.parse(JSON.stringify(c)));
  assert.deepEqual(n.items.map((i) => i.key), ['KARISMA', 'ZHANG']);
  assert.equal(n.v, 1);
  assert.equal(n.noBib, false);
  const it = n.items[0];
  assert.deepEqual(Object.keys(it).sort(),
    ['itemData', 'key', 'label', 'locator', 'prefix', 'suffix', 'suppressAuthor']);
  assert.equal(it.itemData.id, 'KARISMA');
  assert.deepEqual(RP.parseCitation(RP.serializeCitation(n)), n);
  assert.throws(() => RP.normalizeCitation({ v: 1, id: 'c-1', items: [] }));
  assert.throws(() => RP.normalizeCitation({ v: 99, id: 'c-1', items: [{ itemData: ITEMS.ZHANG }] }));
  const s = RP.normalizeSettings({ style: 'ieee', uncited: [{ itemData: ITEMS.ADAMS }, { itemData: ITEMS.ADAMS }] });
  assert.deepEqual(s, { v: 1, style: 'ieee', locale: 'id-ID', uncited: [{ key: 'ADAMS', itemData: ITEMS.ADAMS }] });
  assert.deepEqual(RP.removeUncited(RP.addUncited(RP.defaultSettings(), ITEMS.ZHANG), 'ZHANG').uncited, []);
});

test('tag content control: bentuk inline dan rujukan', () => {
  const c = cite('MCCLEAN', { item: { MCCLEAN: { prefix: 'lihat — ü', annotationKey: 'AB12CD34' } } });
  const inline = RP.encodeCitationTag(c);
  assert.ok(inline.startsWith('READPAPER_CITATION_v1:'));
  const parsed = RP.parseCitationTag(inline);
  assert.equal(parsed.kind, 'inline');
  assert.deepEqual(parsed.citation, RP.normalizeCitation(c));
  assert.equal(parsed.citation.items[0].annotationKey, 'AB12CD34');
  assert.deepEqual(RP.parseCitationTag(RP.encodeCitationTag(c, 'ref')), { kind: 'ref', id: c.id });
  assert.equal(RP.parseCitationTag('ZOTERO_ITEM'), null);
  assert.equal(RP.parseCitationTag('READPAPER_CITATION_v1:%%%').kind, 'broken');
  const settings = RP.normalizeSettings({ style: 'ieee' });
  assert.deepEqual(RP.parseBibliographyTag(RP.encodeBibliographyTag(settings)), settings);
  assert.equal(RP.parseBibliographyTag(RP.BIBLIOGRAPHY_TAG), null);
  assert.ok(RP.isBibliographyTag(RP.BIBLIOGRAPHY_TAG));
});

test('custom XML part: bolak-balik', () => {
  const a = cite('KARISMA');
  const b = cite('ZHANG', { noBib: true });
  const settings = RP.normalizeSettings({ style: 'vancouver-nlm', uncited: [{ itemData: ITEMS.ADAMS }] });
  const cache = { style: 'vancouver-nlm', styleXml: '<style/>', locales: { 'en-US': '<locale/>' } };
  const xml = RP.buildStoreXml({ settings, cache, citations: { [a.id]: a, [b.id]: b } });
  assert.match(xml, /xmlns="urn:readpaper:citations:1"/);
  const back = RP.parseStoreXml(xml);
  assert.deepEqual(back.settings, settings);
  assert.deepEqual(back.cache, cache);
  assert.deepEqual(back.citations[a.id], RP.normalizeCitation(a));
  assert.equal(back.citations[b.id].noBib, true);
  // Editor bisa mengembalikan XML dengan prefiks namespace.
  const prefixed = xml.replace(/<(\/?)(readpaper|settings|cache|citation)/g, '<$1rp:$2');
  assert.deepEqual(RP.parseStoreXml(prefixed).settings, settings);
});

test('salin-tempel: id ganda diberi id baru', () => {
  const a = cite('KARISMA');
  const copy = JSON.parse(JSON.stringify(a));
  const list = [a, cite('ZHANG'), copy];
  const changes = RP.dedupeCitationIds(list);
  assert.equal(changes.length, 1);
  assert.equal(changes[0].index, 2);
  assert.notEqual(list[2].id, a.id);
  assert.match(list[2].id, /^c-[0-9a-f]{6}$/);
});

test('htmlToRuns: tag citeproc dan entitas', () => {
  const runs = RP.htmlToRuns('A &#38; B <i>miring <span style="font-style:normal;">tegak</span></i>' +
    '<sup>1</sup> <span style="font-variant:small-caps;">kapital</span>');
  assert.deepEqual(runs.map((r) => [r.text, r.italic, r.superscript, r.smallCaps]), [
    ['A & B ', false, false, false], ['miring ', true, false, false], ['tegak', false, false, false],
    ['1', false, true, false], [' ', false, false, false], ['kapital', false, false, true],
  ]);
  assert.equal(RP.runsToText(RP.htmlToRuns(
    '<div class="csl-entry">\n    <div class="csl-left-margin">1.</div><div class="csl-right-inline">X.</div>\n  </div>')),
  '1.\tX.');
});

test('gaya tanpa daftar pustaka atau tanpa sitasi tetap aman', () => {
  const r = processor('apa').render([]);
  assert.deepEqual(r.order, []);
  assert.deepEqual(r.bibliography.entries, []);
  assert.equal(r.bibliography.text, '');
});

test('inspectStyle membaca format gaya', () => {
  const { styleXml } = require('./helpers.js');
  assert.equal(RP.inspectStyle(styleXml('ieee')).numeric, true);
  assert.equal(RP.inspectStyle(styleXml('apa')).numeric, false);
  assert.equal(RP.inspectStyle(styleXml('american-medical-association')).defaultLocale, 'en-US');
});
