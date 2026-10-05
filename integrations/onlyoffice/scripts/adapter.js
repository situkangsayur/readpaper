/*
 * Lapisan OnlyOffice untuk ReadPaperController.
 *
 * Penyimpanan:
 *  - Sitasi: content control inline, tag `READPAPER_CITATION_v1:<base64 JSON>`.
 *    Datanya ikut di tag, jadi sitasi yang disalin ke dokumen lain tetap
 *    membawa datanya. Pola yang sama dipakai plugin Mendeley resmi OnlyOffice
 *    (`MENDELEY_CITATION_v3_<base64>`), dan tag tersimpan sebagai w:tag di DOCX.
 *  - Daftar pustaka: content control blok, tag
 *    `READPAPER_BIBLIOGRAPHY_v1:<base64 pengaturan>` (cadangan pengaturan).
 *  - Pengaturan dokumen (+ salinan gaya dan locale): custom XML part
 *    bernamespace urn:readpaper:citations:1, lewat ApiDocument.GetCustomXmlParts
 *    (OnlyOffice 9.0+, juga syarat GetInternalId pada content control; karena
 *    itu config.json meminta minVersion 9.0.0). Diuji dengan DocumentBuilder
 *    9.0.4 dan 9.4.0: tag ~10 KB dan custom XML ~200 KB bertahan setelah
 *    .docx disimpan dan dibuka ulang (scripts/test-onlyoffice-docbuilder.sh).
 *    8.3.3 gagal.
 *
 * Semua kode yang berjalan di dalam editor ada di satu fungsi `EDITOR_OPS`
 * karena callCommand mengirim fungsi sebagai teks: fungsi itu tidak bisa
 * memakai variabel dari luar, hanya Asc.scope.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root) {
  'use strict';

  /* global Api, Asc */
  // Dijalankan di dalam editor. Membaca Asc.scope.ops, mengembalikan hasil per operasi.
  var EDITOR_OPS = function () {
    var NS = 'urn:readpaper:citations:1';
    var doc = Api.GetDocument();
    var results = [];

    function all() {
      var list = doc.GetAllContentControls() || [];
      var out = [];
      for (var i = 0; i < list.length; i++) {
        var cc = list[i];
        var tag = cc.GetTag ? cc.GetTag() : '';
        if (tag && tag.indexOf('READPAPER_') === 0) out.push(cc);
      }
      return out;
    }
    function byId(id) {
      var list = all();
      for (var i = 0; i < list.length; i++) if (list[i].GetInternalId() === id) return list[i];
      return null;
    }
    function byNewTag(tag, before) {
      var list = all();
      for (var i = 0; i < list.length; i++) {
        var id = list[i].GetInternalId();
        if (list[i].GetTag() === tag && before.indexOf(id) < 0) return list[i];
      }
      return null;
    }
    function ids() { return all().map(function (c) { return c.GetInternalId(); }); }
    function makeRun(r) {
      var run = Api.CreateRun();
      var parts = String(r.text).split('\t');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) run.AddTabStop();
        if (parts[i]) run.AddText(parts[i]);
      }
      // Hanya yang aktif yang diset; sisanya mengikuti teks di sekitarnya.
      if (r.italic) run.SetItalic(true);
      if (r.bold) run.SetBold(true);
      if (r.underline) run.SetUnderline(true);
      if (r.smallCaps && run.SetSmallCaps) run.SetSmallCaps(true);
      if (r.superscript) run.SetVertAlign('superscript');
      else if (r.subscript) run.SetVertAlign('subscript');
      return run;
    }
    function fillInline(cc, runs) {
      cc.RemoveAllElements();
      for (var i = 0; i < runs.length; i++) cc.AddElement(makeRun(runs[i]), i);
    }
    function fillBlock(cc, bib) {
      var content = cc.GetContent();
      content.RemoveAllElements();
      var indent = 0;
      if (bib.hangingIndent) indent = 720;
      else if (bib.secondFieldAlign) indent = Math.max(360, Math.min(1440, (bib.maxOffset + 1) * 120));
      for (var i = 0; i < bib.paragraphs.length; i++) {
        var p = Api.CreateParagraph();
        var runs = bib.paragraphs[i].runs;
        for (var j = 0; j < runs.length; j++) p.AddElement(makeRun(runs[j]));
        if (indent) { p.SetIndLeft(indent); p.SetIndFirstLine(-indent); }
        if (bib.lineSpacing && bib.lineSpacing !== 1) p.SetSpacingLine(Math.round(240 * bib.lineSpacing), 'auto');
        if (bib.entrySpacing > 1) p.SetSpacingAfter(Math.round(240 * (bib.entrySpacing - 1)));
        content.Push(p);
      }
      // RemoveAllElements meninggalkan satu paragraf kosong di depan.
      while (content.GetElementsCount() > bib.paragraphs.length) content.RemoveElement(0);
    }
    function customXml() {
      if (!doc.GetCustomXmlParts) return null;
      try { return doc.GetCustomXmlParts(); } catch (e) { return null; }
    }

    var ops = Asc.scope.ops || [];
    for (var k = 0; k < ops.length; k++) {
      var op = ops[k];
      try {
        if (op.op === 'read') {
          var parts = customXml();
          var xml = null;
          if (parts) {
            var found = parts.GetByNamespace(NS) || [];
            if (found.length) xml = found[0].GetXml();
          }
          results.push({ controls: all().map(function (c) { return { handle: c.GetInternalId(), tag: c.GetTag() }; }),
            storeXml: xml, storeSupported: !!parts });
        } else if (op.op === 'insertCitation') {
          // Kursor di dalam sitasi lain: keluar dulu, jangan bersarang.
          var inside = doc.GetCurrentContentControl ? doc.GetCurrentContentControl() : null;
          if (inside && inside.GetTag && String(inside.GetTag()).indexOf('READPAPER_CITATION') === 0 && inside.MoveCursorOutside) {
            inside.MoveCursorOutside(true);
          }
          var before = ids();
          var sdt = Api.CreateInlineLvlSdt();
          sdt.SetTag(op.tag);
          if (sdt.SetAlias) sdt.SetAlias('ReadPaper');
          fillInline(sdt, op.runs);
          var para = Api.CreateParagraph();
          para.AddInlineLvlSdt(sdt);
          doc.InsertContent([para], true);
          var placed = byNewTag(op.tag, before);
          if (placed && placed.MoveCursorOutside) { try { placed.MoveCursorOutside(true); } catch (e) { /* versi lama */ } }
          results.push(placed ? placed.GetInternalId() : null);
        } else if (op.op === 'writeCitations') {
          for (var i = 0; i < op.list.length; i++) {
            var u = op.list[i];
            var cc = byId(u.handle);
            if (!cc) continue;
            if (u.tag && cc.GetTag() !== u.tag) cc.SetTag(u.tag);
            fillInline(cc, u.runs);
          }
          results.push(true);
        } else if (op.op === 'writeBibliography') {
          var target = op.handle ? byId(op.handle) : null;
          if (!target) {
            var before2 = ids();
            var block = Api.CreateBlockLvlSdt();
            block.SetTag(op.tag);
            if (block.SetAlias) block.SetAlias('Daftar pustaka ReadPaper');
            fillBlock(block, op.bib);
            doc.InsertContent([block]);
            target = byNewTag(op.tag, before2);
            results.push(target ? target.GetInternalId() : null);
          } else {
            if (target.GetTag() !== op.tag) target.SetTag(op.tag);
            fillBlock(target, op.bib);
            results.push(op.handle);
          }
        } else if (op.op === 'writeStore') {
          var xparts = customXml();
          if (!xparts) { results.push(false); continue; }
          var old = xparts.GetByNamespace(NS) || [];
          for (var d = 0; d < old.length; d++) old[d].Delete();
          if (op.xml) xparts.Add(op.xml);
          results.push(true);
        } else if (op.op === 'unwrap') {
          for (var h = 0; h < op.handles.length; h++) {
            var c2 = byId(op.handles[h]);
            if (c2) c2.Delete(true);
          }
          results.push(true);
        } else {
          results.push({ __error: 'Operasi tidak dikenal: ' + op.op });
        }
      } catch (e) {
        results.push({ __error: String((e && e.message) || e) });
      }
    }
    return results;
  };

  function OnlyOfficeAdapter(plugin) {
    this.plugin = plugin;
    this.tagMode = 'inline';
    this._queue = Promise.resolve();
  }

  /** callCommand berurutan: Asc.scope dipakai bersama, jadi jangan tumpang tindih. */
  OnlyOfficeAdapter.prototype._run = function (ops, recalc) {
    var plugin = this.plugin;
    var p = this._queue.then(function () {
      return new Promise(function (resolve, reject) {
        root.Asc.scope.ops = ops;
        plugin.callCommand(EDITOR_OPS, false, !!recalc, function (res) {
          if (!Array.isArray(res)) { reject(new Error('OnlyOffice tidak menjawab perintah plugin.')); return; }
          for (var i = 0; i < res.length; i++) {
            if (res[i] && res[i].__error) { reject(new Error('OnlyOffice: ' + res[i].__error)); return; }
          }
          resolve(res);
        });
      });
    });
    this._queue = p.catch(function () {});
    return p;
  };

  OnlyOfficeAdapter.prototype.readControls = function () {
    return this._run([{ op: 'read' }], false).then(function (r) { return r[0]; });
  };

  OnlyOfficeAdapter.prototype.currentControl = function () {
    var plugin = this.plugin;
    return new Promise(function (resolve) {
      plugin.executeMethod('GetCurrentContentControlPr', [], function (pr) {
        if (!pr || !pr.Tag || String(pr.Tag).indexOf('READPAPER_') !== 0) { resolve(null); return; }
        resolve({ handle: pr.InternalId, tag: pr.Tag });
      });
    });
  };

  OnlyOfficeAdapter.prototype.insertCitation = function (tag, runs) {
    return this._run([{ op: 'insertCitation', tag: tag, runs: runs }], true).then(function (r) {
      if (!r[0]) throw new Error('Sitasi tidak bisa disisipkan di posisi ini.');
      return r[0];
    });
  };

  OnlyOfficeAdapter.prototype.writeCitations = function (list) {
    if (!list.length) return Promise.resolve();
    return this._run([{ op: 'writeCitations', list: list }], true);
  };

  OnlyOfficeAdapter.prototype.writeBibliography = function (handle, tag, bib) {
    return this._run([{ op: 'writeBibliography', handle: handle, tag: tag, bib: bib }], true)
      .then(function (r) { return r[0]; });
  };

  OnlyOfficeAdapter.prototype.writeStore = function (xml) {
    return this._run([{ op: 'writeStore', xml: xml }], false).then(function (r) { return r[0]; });
  };

  OnlyOfficeAdapter.prototype.unwrap = function (handles) {
    return this._run([{ op: 'unwrap', handles: handles }], true);
  };

  root.ReadPaperOnlyOfficeAdapter = OnlyOfficeAdapter;
  root.ReadPaperOnlyOfficeAdapter.EDITOR_OPS = EDITOR_OPS;
})(typeof self !== 'undefined' ? self : this);
