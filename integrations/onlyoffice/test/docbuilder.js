'use strict';
// Menjalankan kode editor plugin (EDITOR_OPS di scripts/adapter.js) di dalam
// OnlyOffice sungguhan lewat ONLYOFFICE DocumentBuilder, menyimpan .docx,
// membukanya lagi, dan memeriksa bahwa tag sitasi, daftar pustaka, dan custom
// XML part bertahan.
//
//   node docbuilder.js gen   <dir>   menulis <dir>/test.docbuilder
//   node docbuilder.js check <dir>   memeriksa <dir>/out/result.txt
//
// Dipakai oleh scripts/test-onlyoffice-docbuilder.sh (di dalam Docker).
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');

const INT = path.join(__dirname, '..', '..');
global.self = global;
require(path.join(INT, 'onlyoffice', 'scripts', 'adapter.js'));
const h = require(path.join(INT, 'core', 'test', 'helpers.js'));
const RP = h.RP;

// Asc.scope milik editor tidak boleh ditimpa di DocumentBuilder; ganti namanya.
const OPS = global.ReadPaperOnlyOfficeAdapter.EDITOR_OPS.toString().replace(/Asc\.scope/g, '__RP_SCOPE');

function fixtures() {
  // Item dengan abstrak panjang: tag menjadi beberapa KB.
  const big = Object.assign({}, h.ITEMS.MCCLEAN, { abstract: 'Lorem ipsum dolor sit amet — ü ñ 中文. '.repeat(150) });
  const c1 = RP.makeCitation([{ itemData: big, locator: '12', label: 'page' }], { id: 'c-111111' });
  const c2 = RP.makeCitation([{ itemData: h.ITEMS.KARISMA }], { id: 'c-222222' });
  const p = h.processor('apa');
  const r = p.render([c1, c2]);
  const settings = RP.normalizeSettings({ style: 'apa', uncited: [{ itemData: h.ITEMS.ADAMS }] });
  const bib = {
    paragraphs: r.bibliography.entries.map((e) => ({ runs: e.runs })),
    hangingIndent: true, secondFieldAlign: false, maxOffset: 0, lineSpacing: 2, entrySpacing: 0,
  };
  const cache = { style: 'apa', styleXml: h.styleXml('apa'), locales: { 'en-US': h.localeXml('en-US'), 'id-ID': h.localeXml('id-ID') } };
  const storeXml = RP.buildStoreXml({ settings, cache, citations: {} });
  return { c1, c2, r, settings, bib, storeXml };
}

function call(ops) {
  return `(function(){ var __RP_SCOPE = {ops: ${JSON.stringify(ops)}}; return (${OPS})(); })()`;
}

function gen(dir) {
  const f = fixtures();
  const out = '/work/out';
  const script = `
builder.CreateFile("docx");
var d = Api.GetDocument();
d.GetElement(0).AddText("Kalimat dengan sitasi ");
var R = [];
R.push(${call([{ op: 'insertCitation', tag: RP.encodeCitationTag(f.c1), runs: [{ text: '[…]' }] }])});
var h1 = R[0][0];
R.push(${call([{ op: 'insertCitation', tag: RP.encodeCitationTag(f.c2), runs: f.r.citations[f.c2.id].runs }])});
R.push((function(){ var __RP_SCOPE = {ops: [{op:'writeCitations', list:[{handle: h1, runs: ${JSON.stringify(f.r.citations[f.c1.id].runs)}}]}]}; return (${OPS})(); })());
R.push(${call([{ op: 'writeBibliography', handle: null, tag: RP.encodeBibliographyTag(f.settings), bib: f.bib }])});
R.push(${call([{ op: 'writeStore', xml: f.storeXml }])});
R.push(${call([{ op: 'read' }])});
GlobalVariable["s1"] = JSON.stringify(R);
builder.SaveFile("docx", "${out}/a.docx");
builder.CloseFile();

builder.OpenFile("${out}/a.docx");
var R2 = [];
R2.push(${call([{ op: 'read' }])});
GlobalVariable["s2"] = JSON.stringify(R2);
var bibId = null;
var c = R2[0][0] && R2[0][0].controls ? R2[0][0].controls : [];
for (var i = 0; i < c.length; i++) if (c[i].tag.indexOf("READPAPER_BIBLIOGRAPHY") === 0) bibId = c[i].handle;
R2.push((function(){ var __RP_SCOPE = {ops: [{op:'writeBibliography', handle: bibId, tag: ${JSON.stringify(RP.BIBLIOGRAPHY_TAG)}, bib: ${JSON.stringify(f.bib)}}, {op:'read'}]}; return (${OPS})(); })());
var ids = c.map(function(x){ return x.handle; });
R2.push((function(){ var __RP_SCOPE = {ops: [{op:'unwrap', handles: ids}, {op:'writeStore', xml: null}, {op:'read'}]}; return (${OPS})(); })());
GlobalVariable["s2"] = JSON.stringify(R2);
builder.SaveFile("txt", "${out}/b.txt");
builder.CloseFile();

builder.CreateFile("docx");
Api.GetDocument().GetElement(0).AddText(GlobalVariable["s1"] + "=====" + GlobalVariable["s2"]);
builder.SaveFile("txt", "${out}/result.txt");
builder.CloseFile();
`;
  fs.writeFileSync(path.join(dir, 'test.docbuilder'), script);
}

function check(dir) {
  const f = fixtures();
  const raw = fs.readFileSync(path.join(dir, 'out', 'result.txt'), 'utf8').replace(/^﻿/, '');
  const [a, b] = raw.split('=====').map((s) => JSON.parse(s));
  const flat = a.concat(b).map((x) => x[0]);
  flat.forEach((x) => assert.ok(!(x && x.__error), 'galat editor: ' + (x && x.__error)));

  const before = a[a.length - 1][0];
  const after = b[0][0];
  assert.equal(before.storeSupported, true, 'GetCustomXmlParts tersedia');
  assert.equal(before.controls.length, 3);
  assert.deepEqual(after.controls.map((c) => c.tag), before.controls.map((c) => c.tag), 'tag bertahan setelah simpan-buka');
  assert.equal(after.storeXml, before.storeXml, 'custom XML part bertahan');
  const store = RP.parseStoreXml(after.storeXml);
  assert.deepEqual(store.settings, f.settings);
  assert.equal(store.cache.styleXml, h.styleXml('apa'));
  const tags = after.controls.map((c) => c.tag);
  assert.deepEqual(RP.parseCitationTag(tags[0]).citation, RP.normalizeCitation(f.c1));
  assert.deepEqual(RP.parseCitationTag(tags[1]).citation, RP.normalizeCitation(f.c2));
  assert.deepEqual(RP.parseBibliographyTag(tags[2]), f.settings);
  assert.ok(tags[0].length > 5000, 'tag panjang (' + tags[0].length + ' karakter)');

  const rebuilt = b[1];
  assert.equal(rebuilt[1].controls[2].tag, RP.BIBLIOGRAPHY_TAG, 'daftar pustaka ditulis ulang di tempat');
  const unwrapped = b[2];
  assert.deepEqual(unwrapped[2].controls, []);
  assert.equal(unwrapped[2].storeXml, null);

  const text = fs.readFileSync(path.join(dir, 'out', 'b.txt'), 'utf8');
  assert.match(text, /\(McClean dkk\., 2018, hlm\. 12\)/);
  assert.match(text, /\(Karisma, 2020\)/);
  assert.match(text, /Karisma, H\. \(2020\)\. Membaca makalah dengan tenang\. Penerbit Contoh\./);
  console.log('OK: ' + tags[0].length + ' karakter tag sitasi, ' + after.storeXml.length +
    ' karakter custom XML; semuanya bertahan setelah disimpan dan dibuka ulang.');
}

const [cmd, dir] = process.argv.slice(2);
if (cmd === 'gen') gen(dir);
else if (cmd === 'check') check(dir);
else { console.error('pakai: node docbuilder.js gen|check <dir>'); process.exit(2); }
