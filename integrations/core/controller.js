/*
 * Perintah sitasi ReadPaper yang sama di Word dan OnlyOffice.
 *
 * Lapisan editor hanya perlu menyediakan "adapter" kecil (lihat
 * ADAPTER di bawah); semua keputusan — membaca sitasi dari dokumen, memberi
 * nomor, membangun daftar pustaka, menyimpan pengaturan — ada di sini.
 *
 * Butuh global ReadPaperCitations dan ReadPaperApi (atau di-require dari Node).
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./citations.js'), require('./readpaper-api.js'));
  } else {
    root.ReadPaperController = factory(root.ReadPaperCitations, root.ReadPaperApi);
  }
})(typeof self !== 'undefined' ? self : this, function (RP, Api) {
  'use strict';

  /*
   * ADAPTER — semua metode async (mengembalikan Promise):
   *
   *   tagMode: 'inline' | 'ref'
   *     'inline': data sitasi di tag content control (OnlyOffice).
   *     'ref':    tag hanya membawa id; data di custom XML part (Word).
   *   readControls() -> {controls: [{handle, tag}], storeXml: string|null}
   *     Semua content control ReadPaper, sesuai urutan dokumen.
   *   currentControl() -> {handle, tag} | null
   *     Content control ReadPaper tempat kursor berada.
   *   insertCitation(tag, runs) -> handle        (di posisi kursor)
   *   writeCitations([{handle, tag?, runs}])     (tag hanya bila berubah)
   *   writeBibliography(handle|null, tag, bib) -> handle
   *     handle null = sisipkan di posisi kursor.
   *     bib = {paragraphs: [{runs}], hangingIndent, secondFieldAlign,
   *            lineSpacing, entrySpacing}
   *   writeStore(xml|null) -> boolean (false bila editor tidak mendukung)
   *   unwrap(handles)                            (buang content control, teks tinggal)
   */

  var LAST_STYLE_KEY = 'readpaper.lastStyle';
  var LAST_LOCALE_KEY = 'readpaper.lastLocale';
  var PLACEHOLDER = [{ text: '[…]', italic: false, bold: false, underline: false,
    smallCaps: false, superscript: false, subscript: false }];

  function plainRuns(text) {
    return [{ text: text, italic: false, bold: false, underline: false, smallCaps: false,
      superscript: false, subscript: false }];
  }

  function Controller(opts) {
    this.adapter = opts.adapter;
    this.api = opts.api || new Api.Client();
    this._proc = null;
    this._procKey = null;
    this._resources = null;
  }

  // ---------------------------------------------------------------------
  // Membaca dokumen

  /**
   * @returns {Promise<{citations: Array<{handle, citation, form}>, broken: Array,
   *   bibliographies: Array, settings, hasSettings, store}>}
   */
  Controller.prototype.loadDocument = function () {
    var self = this;
    return this.adapter.readControls().then(function (r) {
      var store = r.storeXml ? RP.parseStoreXml(r.storeXml) : { settings: null, cache: null, citations: {} };
      var settings = store.settings;
      var citations = [];
      var broken = [];
      var bibliographies = [];
      (r.controls || []).forEach(function (c) {
        if (RP.isBibliographyTag(c.tag)) {
          bibliographies.push(c);
          if (!settings) settings = RP.parseBibliographyTag(c.tag);
          return;
        }
        var p = RP.parseCitationTag(c.tag);
        if (!p) return;
        if (p.kind === 'inline') {
          citations.push({ handle: c.handle, citation: p.citation, form: 'inline' });
        } else if (p.kind === 'ref' && store.citations[p.id]) {
          var cit = JSON.parse(JSON.stringify(store.citations[p.id]));
          cit.id = p.id;
          citations.push({ handle: c.handle, citation: cit, form: 'ref' });
        } else {
          broken.push({ handle: c.handle, tag: c.tag,
            reason: p.kind === 'ref' ? 'Data sitasi ' + p.id + ' tidak ada di dokumen ini' : p.error });
        }
      });
      return {
        citations: citations,
        broken: broken,
        bibliographies: bibliographies,
        hasSettings: !!settings,
        settings: settings || self.defaultSettings(),
        store: store,
      };
    });
  };

  Controller.prototype.defaultSettings = function () {
    var s = RP.defaultSettings();
    var st = this.api.store;
    s.style = st.get(LAST_STYLE_KEY) || s.style;
    s.locale = st.get(LAST_LOCALE_KEY) || s.locale;
    return s;
  };

  /** Sitasi tempat kursor berada, atau null. */
  Controller.prototype.currentCitation = function () {
    var self = this;
    return this.adapter.currentControl().then(function (cur) {
      if (!cur || !RP.isCitationTag(cur.tag)) return null;
      return self.loadDocument().then(function (doc) {
        for (var i = 0; i < doc.citations.length; i++) {
          if (String(doc.citations[i].handle) === String(cur.handle)) return { doc: doc, entry: doc.citations[i] };
        }
        return null;
      });
    });
  };

  // ---------------------------------------------------------------------
  // Mesin citeproc

  /**
   * Prosesor untuk gaya dan locale dokumen. Dibuat sekali lalu dipakai
   * ulang selama gaya tidak berubah.
   */
  Controller.prototype.processor = function (settings, docCache) {
    var self = this;
    var key = settings.style + '|' + settings.locale;
    if (this._proc && this._procKey === key) return Promise.resolve(this._proc);
    return Api.loadStyleResources(this.api, settings.style, settings.locale, docCache).then(function (res) {
      var proc = new RP.CitationProcessor({
        styleXml: res.styleXml,
        locale: settings.locale,
        retrieveLocale: Api.localeRetriever(res),
      });
      proc.engine(); // bangun sekarang, bukan saat menyisipkan
      self._proc = proc;
      self._procKey = key;
      self._resources = res;
      return proc;
    });
  };

  /** Memanaskan mesin di latar supaya dialog sitasi tidak menunggu. */
  Controller.prototype.warm = function () {
    var self = this;
    return this.loadDocument().then(function (doc) {
      return self.processor(doc.settings, doc.store.cache).then(function () { return doc; });
    });
  };

  Controller.prototype._cache = function (doc) {
    var r = this._resources;
    if (r && r.styleId === doc.settings.style && !r.offline) {
      return { style: r.styleId, styleXml: r.styleXml, locales: r.locales };
    }
    return doc.store.cache || null;
  };

  Controller.prototype._writeStore = function (doc, extraCitations) {
    var citations = {};
    if (this.adapter.tagMode === 'ref') {
      var old = doc.store.citations || {};
      Object.keys(old).forEach(function (id) { citations[id] = old[id]; });
      doc.citations.forEach(function (c) { citations[c.citation.id] = c.citation; });
      (extraCitations || []).forEach(function (c) { citations[c.id] = c; });
    }
    var xml = RP.buildStoreXml({ settings: doc.settings, cache: this._cache(doc), citations: citations });
    return this.adapter.writeStore(xml);
  };

  Controller.prototype._tag = function (citation) {
    return RP.encodeCitationTag(citation, this.adapter.tagMode === 'ref' ? 'ref' : 'inline');
  };

  Controller.prototype._bibTag = function (settings) {
    // Cadangan pengaturan di tag daftar pustaka hanya untuk OnlyOffice (tag
    // panjang aman di sana); Word memakai custom XML part saja.
    return this.adapter.tagMode === 'inline' ? RP.encodeBibliographyTag(settings) : RP.BIBLIOGRAPHY_TAG;
  };

  // ---------------------------------------------------------------------
  // Perintah

  /** Daftar sitasi baru: items = [{itemData, locator, label, prefix, suffix, suppressAuthor, annotationKey}] */
  Controller.prototype.newCitation = function (doc, items, noBib) {
    var ids = doc.citations.map(function (c) { return c.citation.id; });
    Object.keys(doc.store.citations || {}).forEach(function (id) { ids.push(id); });
    return RP.makeCitation(items, { noBib: noBib, existingIds: ids });
  };

  /**
   * Teks pratinjau untuk sitasi yang sedang disusun (posisi: di akhir, atau
   * menggantikan sitasi `replaceId`).
   */
  Controller.prototype.preview = function (doc, citation, replaceId) {
    return this.processor(doc.settings, doc.store.cache).then(function (proc) {
      var list = doc.citations.map(function (c) { return c.citation; })
        .filter(function (c) { return c.id !== replaceId; });
      if (replaceId) {
        var idx = doc.citations.map(function (c) { return c.citation.id; }).indexOf(replaceId);
        list.splice(idx < 0 ? list.length : idx, 0, citation);
      } else {
        list.push(citation);
      }
      return proc.preview(list, citation.id, doc.settings.uncited);
    });
  };

  /**
   * Menyisipkan satu sitasi di posisi kursor. Hanya sitasi itu yang ditulis;
   * nomor sitasi lain dan daftar pustaka menunggu "Perbarui semua".
   */
  Controller.prototype.insertCitation = function (citation) {
    var self = this;
    var adapter = this.adapter;
    var doc0;
    return this.loadDocument().then(function (doc) {
      doc0 = doc;
      return self.processor(doc.settings, doc.store.cache);
    }).then(function () {
      return adapter.insertCitation(self._tag(citation), PLACEHOLDER);
    }).then(function (handle) {
      var needStore = adapter.tagMode === 'ref' || !doc0.hasSettings;
      return (needStore ? self._writeStore(doc0, [citation]) : Promise.resolve()).then(function () {
        return self.loadDocument();
      }).then(function (doc) {
        var list = doc.citations.map(function (c) { return c.citation; });
        var found = list.some(function (c) { return c.id === citation.id; });
        if (!found) list.push(citation);
        var r = self._proc.render(list, doc.settings.uncited);
        var out = r.citations[citation.id];
        return adapter.writeCitations([{ handle: handle, runs: out ? out.runs : plainRuns('[?]') }])
          .then(function () { return { handle: handle, text: out ? out.text : '' }; });
      });
    });
  };

  /** Menyimpan perubahan pada sitasi yang sudah ada (`entry` dari currentCitation). */
  Controller.prototype.updateCitation = function (entry, citation) {
    var self = this;
    citation.id = entry.citation.id;
    return this.loadDocument().then(function (doc) {
      return self.processor(doc.settings, doc.store.cache).then(function (proc) {
        var list = doc.citations.map(function (c) {
          return c.handle === entry.handle ? citation : c.citation;
        });
        var r = proc.render(list, doc.settings.uncited);
        var out = r.citations[citation.id];
        doc.citations.forEach(function (c) { if (c.handle === entry.handle) c.citation = citation; });
        var write = self.adapter.writeCitations([{ handle: entry.handle, tag: self._tag(citation),
          runs: out ? out.runs : plainRuns('[?]') }]);
        return write.then(function () {
          return self.adapter.tagMode === 'ref' ? self._writeStore(doc) : null;
        }).then(function () { return { text: out ? out.text : '' }; });
      });
    });
  };

  /**
   * Perbarui semua: ambil data item terbaru bila ReadPaper berjalan, render
   * ulang semua sitasi sesuai urutan dokumen, bangun ulang setiap daftar
   * pustaka, simpan pengaturan.
   */
  Controller.prototype.refreshAll = function (opts) {
    opts = opts || {};
    var self = this;
    var summary = { citations: 0, broken: 0, bibliographies: 0, refreshedItems: 0, offline: false, missing: [] };
    var doc;
    return this.loadDocument().then(function (d) {
      doc = d;
      if (opts.settings) doc.settings = RP.normalizeSettings(opts.settings);
      var renamed = RP.dedupeCitationIds(doc.citations.map(function (c) { return c.citation; }));
      summary.renamed = renamed.length;
      var keys = RP.allItemKeys(doc.citations.map(function (c) { return c.citation; }), doc.settings);
      if (!keys.length || opts.skipFetch) return null;
      return self.api.items(keys).then(function (r) {
        var fresh = {};
        r.items.forEach(function (it) { fresh[it.id] = it; });
        summary.missing = r.missing || [];
        summary.refreshedItems = RP.refreshItemData(doc.citations.map(function (c) { return c.citation; }),
          doc.settings, fresh);
      }, function (err) {
        // Tanpa ReadPaper: tetap perbarui dari data yang tersimpan di dokumen.
        summary.offline = true;
        summary.offlineReason = err && err.message;
      });
    }).then(function () {
      if (opts.settings) { self._proc = null; self._procKey = null; }
      return self.processor(doc.settings, doc.store.cache);
    }).then(function (proc) {
      var list = doc.citations.map(function (c) { return c.citation; });
      var r = proc.render(list, doc.settings.uncited);
      var updates = doc.citations.map(function (c) {
        var out = r.citations[c.citation.id];
        return { handle: c.handle, tag: self._tag(c.citation), runs: out ? out.runs : plainRuns('[?]') };
      });
      summary.citations = updates.length;
      summary.broken = doc.broken.length;
      return self.adapter.writeCitations(updates).then(function () {
        var bib = self._bibContent(r.bibliography);
        var tag = self._bibTag(doc.settings);
        return doc.bibliographies.reduce(function (p, b) {
          return p.then(function () {
            summary.bibliographies++;
            return self.adapter.writeBibliography(b.handle, tag, bib);
          });
        }, Promise.resolve());
      });
    }).then(function () {
      return self._writeStore(doc);
    }).then(function (stored) {
      summary.storeSupported = stored !== false;
      return summary;
    });
  };

  Controller.prototype._bibContent = function (b) {
    var paragraphs;
    if (!b.supported) paragraphs = [{ runs: plainRuns('(Gaya ini tidak membuat daftar pustaka.)') }];
    else if (!b.entries.length) paragraphs = [{ runs: plainRuns('(Daftar pustaka kosong — belum ada sitasi.)') }];
    else paragraphs = b.entries.map(function (e) { return { runs: e.runs, key: e.key }; });
    return {
      paragraphs: paragraphs,
      hangingIndent: !!b.hangingIndent,
      secondFieldAlign: b.secondFieldAlign || false,
      maxOffset: b.maxOffset || 0,
      lineSpacing: b.lineSpacing || 1,
      entrySpacing: b.entrySpacing || 0,
    };
  };

  /**
   * Daftar pustaka: sisipkan di kursor bila belum ada; bila sudah ada,
   * bangun ulang yang ada.
   */
  Controller.prototype.bibliography = function () {
    var self = this;
    return this.loadDocument().then(function (doc) {
      return self.processor(doc.settings, doc.store.cache).then(function (proc) {
        var r = proc.render(doc.citations.map(function (c) { return c.citation; }), doc.settings.uncited);
        var bib = self._bibContent(r.bibliography);
        var tag = self._bibTag(doc.settings);
        var write;
        if (doc.bibliographies.length) {
          write = doc.bibliographies.reduce(function (p, b) {
            return p.then(function () { return self.adapter.writeBibliography(b.handle, tag, bib); });
          }, Promise.resolve());
        } else {
          write = self.adapter.writeBibliography(null, tag, bib);
        }
        return write.then(function () { return self._writeStore(doc); }).then(function () {
          return { inserted: !doc.bibliographies.length, entries: r.bibliography.entries.length };
        });
      });
    });
  };

  /** Ganti gaya (dan locale), lalu perbarui semua. */
  Controller.prototype.setStyle = function (styleId, locale) {
    var self = this;
    this.api.store.set(LAST_STYLE_KEY, styleId);
    if (locale) this.api.store.set(LAST_LOCALE_KEY, locale);
    return this.loadDocument().then(function (doc) {
      var s = RP.normalizeSettings(doc.settings);
      s.style = styleId;
      if (locale) s.locale = locale;
      return self.refreshAll({ settings: s });
    });
  };

  Controller.prototype._saveSettingsAndBibliography = function (settings) {
    var self = this;
    return this.loadDocument().then(function (doc) {
      doc.settings = settings;
      return self.processor(doc.settings, doc.store.cache).then(function (proc) {
        var r = proc.render(doc.citations.map(function (c) { return c.citation; }), doc.settings.uncited);
        var bib = self._bibContent(r.bibliography);
        var tag = self._bibTag(doc.settings);
        return doc.bibliographies.reduce(function (p, b) {
          return p.then(function () { return self.adapter.writeBibliography(b.handle, tag, bib); });
        }, Promise.resolve());
      }).then(function () { return self._writeStore(doc); })
        .then(function (ok) { return { settings: settings, storeSupported: ok !== false }; });
    });
  };

  /** Tambah item ke daftar pustaka tanpa disitasi. */
  Controller.prototype.addUncited = function (itemData) {
    var self = this;
    return this.loadDocument().then(function (doc) {
      return self._saveSettingsAndBibliography(RP.addUncited(doc.settings, itemData));
    });
  };

  Controller.prototype.removeUncited = function (key) {
    var self = this;
    return this.loadDocument().then(function (doc) {
      return self._saveSettingsAndBibliography(RP.removeUncited(doc.settings, key));
    });
  };

  /** Jadikan teks biasa: buang semua content control ReadPaper dan datanya. */
  Controller.prototype.convertToText = function () {
    var self = this;
    return this.adapter.readControls().then(function (r) {
      var handles = (r.controls || []).map(function (c) { return c.handle; });
      return self.adapter.unwrap(handles).then(function () {
        return self.adapter.writeStore(null);
      }).then(function () { return { removed: handles.length }; });
    });
  };

  /** Ambil CSL-JSON satu item dari ReadPaper. */
  Controller.prototype.fetchItem = function (key) {
    return this.api.items([key]).then(function (r) {
      if (!r.items.length) throw new Error('Item ' + key + ' tidak ditemukan di library yang terbuka.');
      return r.items[0];
    });
  };

  Controller.PLACEHOLDER = PLACEHOLDER;
  return Controller;
});
