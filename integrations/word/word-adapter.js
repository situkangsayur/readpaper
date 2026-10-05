/*
 * Lapisan Microsoft Word (Office.js) untuk ReadPaperController.
 *
 * Penyimpanan:
 *  - Sitasi: content control inline, tag pendek `READPAPER_CITATION_v1#c-xxxxxx`
 *    (28 karakter). Data sitasinya (JSON kontrak) ada di custom XML part.
 *    Tag panjang tidak dipakai di Word: dokumentasi Office.js tidak
 *    menyebut batas panjang tag, dialog Properti Content Control Word sendiri
 *    membatasinya, dan hal itu tidak bisa diuji di sini — jadi dipilih yang
 *    pasti aman.
 *  - Daftar pustaka: content control blok, tag `READPAPER_BIBLIOGRAPHY_v1`.
 *  - Pengaturan dokumen, salinan gaya/locale, dan data semua sitasi: satu
 *    custom XML part bernamespace urn:readpaper:citations:1 (API umum
 *    Office.context.document.customXmlParts, ada sejak Word 2013 dan di Word
 *    web). Custom XML part tersimpan di dalam .docx, tidak bergantung pada
 *    identitas add-in (berbeda dari Office.context.document.settings).
 *  - Sitasi bertag inline buatan OnlyOffice (`READPAPER_CITATION_v1:<base64>`)
 *    tetap terbaca; saat diperbarui di Word ia diubah ke bentuk pendek.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root) {
  'use strict';
  /* global Word, Office */

  var NS = 'urn:readpaper:citations:1';
  var PREFIX = 'READPAPER_';

  function officeAsync(fn) {
    return new Promise(function (resolve, reject) {
      fn(function (r) {
        if (r.status === Office.AsyncResultStatus.Succeeded) resolve(r.value);
        else reject(new Error('Word: ' + ((r.error && r.error.message) || 'operasi gagal')));
      });
    });
  }

  function xmlParts() {
    var d = Office.context && Office.context.document;
    return d && d.customXmlParts ? d.customXmlParts : null;
  }

  function readStore() {
    var parts = xmlParts();
    if (!parts) return Promise.resolve(null);
    return officeAsync(function (cb) { parts.getByNamespaceAsync(NS, cb); }).then(function (found) {
      if (!found || !found.length) return null;
      return officeAsync(function (cb) { found[0].getXmlAsync(cb); });
    });
  }

  /** Format run: sifat yang dipakai salah satu run diset eksplisit di semua run,
   *  supaya teks yang disisipkan sesudah run miring tidak ikut miring. */
  function applyRuns(insertAt, runs) {
    var used = { italic: false, bold: false, underline: false, superscript: false, subscript: false };
    runs.forEach(function (r) { Object.keys(used).forEach(function (k) { if (r[k]) used[k] = true; }); });
    runs.forEach(function (r) {
      if (!r.text) return;
      var range = insertAt(r.text);
      var f = range.font;
      if (used.italic) f.italic = !!r.italic;
      if (used.bold) f.bold = !!r.bold;
      if (used.underline) f.underline = r.underline ? 'Single' : 'None';
      if (used.superscript || used.subscript) {
        f.superscript = !!r.superscript;
        f.subscript = !!r.subscript;
      }
    });
  }

  function fillInline(cc, runs) {
    cc.clear();
    applyRuns(function (text) { return cc.insertText(text, 'End'); }, runs);
  }

  function fillBlock(cc, bib) {
    cc.clear();
    var first = cc.paragraphs.getFirst();
    var indentPt = 0;
    if (bib.hangingIndent) indentPt = 36;
    else if (bib.secondFieldAlign) indentPt = Math.max(18, Math.min(72, (bib.maxOffset + 1) * 6));
    bib.paragraphs.forEach(function (p, i) {
      var para = i === 0 ? first : cc.insertParagraph('', 'End');
      applyRuns(function (text) { return para.insertText(text, 'End'); }, p.runs);
      if (indentPt) {
        para.leftIndent = indentPt;
        para.firstLineIndent = -indentPt;
      } else {
        para.leftIndent = 0;
        para.firstLineIndent = 0;
      }
      if (bib.entrySpacing > 1) para.spaceAfter = 12 * (bib.entrySpacing - 1);
    });
  }

  function WordAdapter() {
    this.tagMode = 'ref';
  }

  WordAdapter.prototype.readControls = function () {
    return Word.run(function (context) {
      var ccs = context.document.body.contentControls;
      ccs.load('items/id,items/tag');
      return context.sync().then(function () {
        return ccs.items.filter(function (c) { return c.tag && c.tag.indexOf(PREFIX) === 0; })
          .map(function (c) { return { handle: c.id, tag: c.tag }; });
      });
    }).then(function (controls) {
      return readStore().then(function (xml) { return { controls: controls, storeXml: xml }; });
    });
  };

  WordAdapter.prototype.currentControl = function () {
    return Word.run(function (context) {
      var cc = context.document.getSelection().parentContentControlOrNullObject;
      cc.load('id,tag');
      return context.sync().then(function () {
        if (cc.isNullObject || !cc.tag || cc.tag.indexOf(PREFIX) !== 0) return null;
        return { handle: cc.id, tag: cc.tag };
      });
    });
  };

  WordAdapter.prototype.insertCitation = function (tag, runs) {
    return Word.run(function (context) {
      var sel = context.document.getSelection();
      var parent = sel.parentContentControlOrNullObject;
      parent.load('id,tag');
      return context.sync().then(function () {
        // Kursor di dalam sitasi lain: sisipkan sesudahnya, jangan bersarang.
        var at = (!parent.isNullObject && parent.tag && parent.tag.indexOf(PREFIX) === 0)
          ? parent.getRange('After') : sel.getRange('End');
        var text = runs.map(function (r) { return r.text; }).join('') || '[…]';
        var inserted = at.insertText(text, 'Before');
        var cc = inserted.insertContentControl();
        cc.tag = tag;
        cc.title = 'Sitasi ReadPaper';
        cc.appearance = 'BoundingBox';
        cc.load('id');
        return context.sync().then(function () {
          cc.getRange('After').select('Start');
          return context.sync().catch(function () {}).then(function () { return cc.id; });
        });
      });
    });
  };

  WordAdapter.prototype.writeCitations = function (list) {
    if (!list.length) return Promise.resolve();
    return Word.run(function (context) {
      var found = list.map(function (u) {
        var cc = context.document.contentControls.getByIdOrNullObject(u.handle);
        cc.load('id');
        return cc;
      });
      return context.sync().then(function () {
        list.forEach(function (u, i) {
          var cc = found[i];
          if (cc.isNullObject) return;
          if (u.tag) cc.tag = u.tag;
          fillInline(cc, u.runs);
        });
        return context.sync();
      });
    });
  };

  WordAdapter.prototype.writeBibliography = function (handle, tag, bib) {
    return Word.run(function (context) {
      var existing = handle !== null && handle !== undefined
        ? context.document.contentControls.getByIdOrNullObject(handle) : null;
      if (existing) existing.load('id');
      return context.sync().then(function () {
        var cc;
        if (existing && !existing.isNullObject) {
          cc = existing;
        } else {
          var sel = context.document.getSelection();
          var para = sel.paragraphs.getLast().insertParagraph('', 'After');
          cc = para.insertContentControl();
          cc.title = 'Daftar pustaka ReadPaper';
          cc.appearance = 'BoundingBox';
        }
        cc.tag = tag;
        fillBlock(cc, bib);
        cc.load('id');
        return context.sync().then(function () { return cc.id; });
      });
    });
  };

  WordAdapter.prototype.writeStore = function (xml) {
    var parts = xmlParts();
    if (!parts) return Promise.resolve(false);
    return officeAsync(function (cb) { parts.getByNamespaceAsync(NS, cb); }).then(function (found) {
      return (found || []).reduce(function (p, part) {
        return p.then(function () { return officeAsync(function (cb) { part.deleteAsync(cb); }); });
      }, Promise.resolve());
    }).then(function () {
      if (!xml) return true;
      return officeAsync(function (cb) { parts.addAsync(xml, cb); }).then(function () { return true; });
    });
  };

  WordAdapter.prototype.unwrap = function (handles) {
    if (!handles.length) return Promise.resolve();
    return Word.run(function (context) {
      var found = handles.map(function (h) {
        var cc = context.document.contentControls.getByIdOrNullObject(h);
        cc.load('id');
        return cc;
      });
      return context.sync().then(function () {
        found.forEach(function (cc) { if (!cc.isNullObject) cc.delete(true); });
        return context.sync();
      });
    });
  };

  root.ReadPaperWordAdapter = WordAdapter;
})(typeof self !== 'undefined' ? self : this);
