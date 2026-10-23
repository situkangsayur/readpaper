/*
 * Add-on Google Docs ReadPaper — bagian yang berjalan di server Google
 * (Apps Script, runtime V8).
 *
 * Yang di sini hanya menulis dan membaca dokumen. Panel sampingnya
 * (Sidebar.html) berjalan di peramban penulis: di sanalah citeproc-js dan
 * controller.js yang SAMA dengan Word/OnlyOffice bekerja, dan dari sanalah
 * ReadPaper di 127.0.0.1 dihubungi. Satu perintah = dua panggilan ke sini:
 * rpSnapshot() memotret dokumen, rpApply() menulis perubahannya.
 *
 * Bentuk data di dokumen (Google Docs tidak punya content control):
 *  - sitasi: named range bernama READPAPER_CITATION_v1#c-xxxxxx di atas
 *    teks sitasinya;
 *  - daftar pustaka: named range READPAPER_BIBLIOGRAPHY_v1 di atas
 *    paragraf-paragrafnya;
 *  - data sitasi, pengaturan, salinan gaya: properti dokumen add-on ini,
 *    dipecah per 8000 karakter (batas satu nilai 9 KB).
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
/* global DocumentApp, HtmlService, PropertiesService */

var RP_CITATION = 'READPAPER_CITATION_v1';
var RP_BIBLIOGRAPHY = 'READPAPER_BIBLIOGRAPHY_v1';
var RP_STORE_KEY = 'readpaper.store';
var RP_CHUNK = 8000;

function onOpen() {
  DocumentApp.getUi().createAddonMenu()
    .addItem('Buka panel sitasi', 'showSidebar')
    .addToUi();
}

function onInstall(e) {
  onOpen(e);
}

function showSidebar() {
  var html = HtmlService.createTemplateFromFile('Sidebar').evaluate().setTitle('ReadPaper');
  DocumentApp.getUi().showSidebar(html);
}

/** Menyisipkan berkas HTML lain dari proyek (inti sitasi) ke panel. */
function include(name) {
  return HtmlService.createHtmlOutputFromFile(name).getContent();
}

// ---------------------------------------------------------------- posisi

/** Jalur indeks anak dari body ke elemen, untuk mengurutkan menurut dokumen. */
function rpPath_(el) {
  var path = [];
  var cur = el;
  while (cur && cur.getParent && cur.getParent()) {
    var parent = cur.getParent();
    path.unshift(parent.getChildIndex(cur));
    cur = parent;
    if (cur.getType && cur.getType() === DocumentApp.ElementType.BODY_SECTION) break;
  }
  return path;
}

function rpCompare_(a, b) {
  var n = Math.min(a.length, b.length);
  for (var i = 0; i < n; i++) if (a[i] !== b[i]) return a[i] - b[i];
  return a.length - b.length;
}

function rpKey_(el, offset) {
  return rpPath_(el).concat([offset]);
}

/** Awal dan akhir sebuah named range sebagai kunci urutan. */
function rpSpan_(nr) {
  var els = nr.getRange().getRangeElements();
  if (!els.length) return null;
  var first = els[0];
  var last = els[els.length - 1];
  var start = rpKey_(first.getElement(), first.isPartial() ? first.getStartOffset() : 0);
  var endEl = last.getElement();
  var endOff = last.isPartial() ? last.getEndOffsetInclusive() + 1
    : (endEl.getText ? endEl.getText().length : 0);
  return { start: start, end: rpKey_(endEl, endOff) };
}

function rpCursorKey_(doc) {
  var cursor = doc.getCursor();
  if (cursor) {
    var text = cursor.getSurroundingText();
    if (text) return rpKey_(text, cursor.getSurroundingTextOffset());
    return rpKey_(cursor.getElement(), cursor.getOffset());
  }
  var sel = doc.getSelection();
  if (sel) {
    var els = sel.getRangeElements();
    var last = els[els.length - 1];
    var el = last.getElement();
    return rpKey_(el, last.isPartial() ? last.getEndOffsetInclusive() + 1 : (el.getText ? el.getText().length : 0));
  }
  return null;
}

function rpCitations_(doc) {
  var out = [];
  doc.getNamedRanges().forEach(function (nr) {
    var name = nr.getName();
    if (name.indexOf(RP_CITATION) !== 0) return;
    var span = rpSpan_(nr);
    if (!span) return; // teksnya sudah dihapus: sitasi yang dihapus, bukan sitasi
    out.push({ nr: nr, span: span });
  });
  out.sort(function (a, b) { return rpCompare_(a.span.start, b.span.start); });
  return out;
}

// --------------------------------------------------------------- store

function rpReadStore_() {
  var props = PropertiesService.getDocumentProperties();
  var n = Number(props.getProperty(RP_STORE_KEY + '.n') || 0);
  if (!n) return null;
  var parts = [];
  for (var i = 0; i < n; i++) parts.push(props.getProperty(RP_STORE_KEY + '.' + i) || '');
  return parts.join('');
}

function rpWriteStore_(xml) {
  var props = PropertiesService.getDocumentProperties();
  var old = Number(props.getProperty(RP_STORE_KEY + '.n') || 0);
  var values = {};
  var n = 0;
  if (xml) {
    for (var i = 0; i < xml.length; i += RP_CHUNK) values[RP_STORE_KEY + '.' + n++] = xml.slice(i, i + RP_CHUNK);
  }
  values[RP_STORE_KEY + '.n'] = String(n);
  props.setProperties(values);
  for (var j = n; j < old; j++) props.deleteProperty(RP_STORE_KEY + '.' + j);
}

// ------------------------------------------------------------- potret

/**
 * Potret dokumen untuk ReadPaperHost.MemoryAdapter di panel: sitasi sesuai
 * urutan dokumen, lalu daftar pustaka; posisi kursor di antara sitasi; dan
 * sitasi tempat kursor berada.
 */
function rpSnapshot() {
  var doc = DocumentApp.getActiveDocument();
  var cits = rpCitations_(doc);
  var cur = rpCursorKey_(doc);
  var cursor = cits.length;
  var cursorIn = null;
  if (cur) {
    cursor = 0;
    cits.forEach(function (c) {
      if (rpCompare_(c.span.start, cur) < 0) cursor++;
      if (rpCompare_(c.span.start, cur) <= 0 && rpCompare_(cur, c.span.end) <= 0) cursorIn = c.nr.getId();
    });
    // Kursor tepat di ujung kanan sitasi: sisipan baru jatuh sesudahnya.
  }
  var controls = cits.map(function (c) { return { handle: c.nr.getId(), tag: c.nr.getName() }; });
  doc.getNamedRanges(RP_BIBLIOGRAPHY).forEach(function (nr) {
    controls.push({ handle: nr.getId(), tag: RP_BIBLIOGRAPHY });
  });
  return {
    tagMode: 'ref',
    controls: controls,
    storeXml: rpReadStore_(),
    cursor: cursor,
    cursorIn: cursorIn,
    storeSupported: true,
  };
}

// --------------------------------------------------------------- tulis

function rpFormat_(textEl, start, runs) {
  var used = { italic: false, bold: false, underline: false, sup: false };
  runs.forEach(function (r) {
    if (r.italic) used.italic = true;
    if (r.bold) used.bold = true;
    if (r.underline) used.underline = true;
    if (r.superscript || r.subscript) used.sup = true;
  });
  var at = start;
  runs.forEach(function (r) {
    var len = (r.text || '').length;
    if (!len) return;
    var a = at;
    var b = at + len - 1;
    if (used.italic) textEl.setItalic(a, b, !!r.italic);
    if (used.bold) textEl.setBold(a, b, !!r.bold);
    if (used.underline) textEl.setUnderline(a, b, !!r.underline);
    if (used.sup) {
      var A = DocumentApp.TextAlignment;
      textEl.setTextAlignment(a, b, r.superscript ? A.SUPERSCRIPT : r.subscript ? A.SUBSCRIPT : A.NORMAL);
    }
    at += len;
  });
}

function rpRunsText_(runs) {
  var s = (runs || []).map(function (r) { return r.text || ''; }).join('');
  return s || '[?]';
}

function rpNamed_(doc, name, textEl, start, len) {
  var range = doc.newRange().addElement(textEl, start, start + len - 1).build();
  return doc.addNamedRange(name, range);
}

/** Teks dan posisi tempat menyisipkan sitasi baru: kursor, di luar sitasi lain. */
function rpInsertPoint_(doc, cits) {
  var cursor = doc.getCursor();
  var key = rpCursorKey_(doc);
  for (var i = 0; key && i < cits.length; i++) {
    var c = cits[i];
    if (rpCompare_(c.span.start, key) <= 0 && rpCompare_(key, c.span.end) <= 0) {
      var els = c.nr.getRange().getRangeElements();
      var last = els[els.length - 1];
      return { text: last.getElement().asText(), offset: last.getEndOffsetInclusive() + 1 };
    }
  }
  if (!cursor) throw new Error('Letakkan kursor di dokumen dulu (bukan seleksi).');
  var text = cursor.getSurroundingText();
  if (text) return { text: text, offset: cursor.getSurroundingTextOffset() };
  var el = cursor.getElement();
  if (el.getType() === DocumentApp.ElementType.PARAGRAPH || el.getType() === DocumentApp.ElementType.LIST_ITEM) {
    return { text: el.appendText(''), offset: 0 };
  }
  throw new Error('Sitasi tidak bisa disisipkan di posisi ini.');
}

function rpWriteCitation_(doc, nr, tag, runs) {
  var els = nr.getRange().getRangeElements();
  var first = els[0];
  var text = first.getElement().asText();
  var start = first.isPartial() ? first.getStartOffset() : 0;
  var last = els[els.length - 1];
  var end = last.isPartial() ? last.getEndOffsetInclusive() : last.getElement().asText().getText().length - 1;
  var name = tag || nr.getName();
  var s = rpRunsText_(runs);
  // Teks baru disisipkan dulu, baru yang lama dihapus: elemen teksnya tidak
  // pernah kosong, jadi tidak hilang dari paragrafnya.
  text.insertText(start, s);
  text.deleteText(start + s.length, end + s.length);
  nr.remove();
  rpFormat_(text, start, runs && runs.length ? runs : [{ text: s }]);
  return rpNamed_(doc, name, text, start, s.length);
}

function rpBibParagraphs_(nr) {
  var seen = [];
  nr.getRange().getRangeElements().forEach(function (re) {
    var el = re.getElement();
    while (el && el.getType() !== DocumentApp.ElementType.PARAGRAPH &&
      el.getType() !== DocumentApp.ElementType.LIST_ITEM) el = el.getParent();
    if (el && seen.indexOf(el) < 0) seen.push(el);
  });
  return seen;
}

function rpFillBibliography_(doc, body, index, bib) {
  var paragraphs = bib.paragraphs && bib.paragraphs.length ? bib.paragraphs : [{ runs: [{ text: '' }] }];
  var indent = bib.hangingIndent ? 36 : bib.secondFieldAlign ? Math.max(18, Math.min(72, ((bib.maxOffset || 0) + 1) * 6)) : 0;
  var made = [];
  paragraphs.forEach(function (p, i) {
    var para = body.insertParagraph(index + i, rpRunsText_(p.runs) === '[?]' ? '' : rpRunsText_(p.runs));
    para.setIndentStart(indent);
    para.setIndentFirstLine(0);
    para.setLineSpacing(bib.lineSpacing || 1);
    if (bib.entrySpacing > 1) para.setSpacingAfter(12 * (bib.entrySpacing - 1));
    if (para.getText()) rpFormat_(para.editAsText(), 0, p.runs || []);
    made.push(para);
  });
  var builder = doc.newRange();
  made.forEach(function (p) { builder.addElement(p); });
  doc.addNamedRange(RP_BIBLIOGRAPHY, builder.build());
}

function rpTopIndex_(body, el) {
  var cur = el;
  while (cur.getParent() && cur.getParent().getType() !== DocumentApp.ElementType.BODY_SECTION) cur = cur.getParent();
  return body.getChildIndex(cur);
}

/**
 * Menerapkan perubahan dari ReadPaperHost.compact(): sitasi baru di posisi
 * kursor, sitasi yang ditulis ulang, daftar pustaka, store, dan penanda yang
 * dilepas.
 */
function rpApply(changes) {
  var doc = DocumentApp.getActiveDocument();
  var body = doc.getBody();
  var byId = {};
  doc.getNamedRanges().forEach(function (nr) { byId[nr.getId()] = nr; });
  var map = {};

  (changes.unwrap || []).forEach(function (h) { if (byId[h]) byId[h].remove(); });

  if (changes.insert) {
    var at = rpInsertPoint_(doc, rpCitations_(doc));
    var s = rpRunsText_(changes.insert.runs);
    at.text.insertText(at.offset, s);
    rpFormat_(at.text, at.offset, changes.insert.runs || []);
    var nr = rpNamed_(doc, changes.insert.tag, at.text, at.offset, s.length);
    map[changes.insert.handle] = nr.getId();
    try { doc.setCursor(doc.newPosition(at.text, at.offset + s.length)); } catch (e) { /* kursor tidak wajib */ }
  }

  (changes.citations || []).forEach(function (u) {
    var target = byId[map[u.handle] || u.handle];
    if (target) rpWriteCitation_(doc, target, u.tag, u.runs);
  });

  (changes.bibliographies || []).forEach(function (b) {
    if (b.created) {
      var cursor = doc.getCursor();
      var index = cursor ? rpTopIndex_(body, cursor.getElement()) + 1 : body.getNumChildren();
      rpFillBibliography_(doc, body, index, b.bib);
      return;
    }
    var old = byId[b.handle];
    if (!old) return;
    var paras = rpBibParagraphs_(old);
    if (!paras.length) return;
    var first = body.getChildIndex(paras[0]);
    old.remove();
    rpFillBibliography_(doc, body, first, b.bib);
    // Body Google Docs tidak boleh kehilangan paragraf terakhirnya.
    var count = body.getNumChildren();
    paras.forEach(function (p) {
      if (body.getChildIndex(p) === count - 1) body.appendParagraph('');
      p.removeFromParent();
      count = body.getNumChildren();
    });
  });

  if (changes.store !== undefined) rpWriteStore_(changes.store);
  return true;
}
