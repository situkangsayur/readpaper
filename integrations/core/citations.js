/*
 * Inti sitasi ReadPaper — dipakai apa adanya oleh plugin OnlyOffice dan
 * add-in Word. Kontraknya ada di docs/api-sitasi.md.
 *
 * Isinya:
 *  - bentuk data sitasi dan pengaturan dokumen (buat, periksa, serialisasi);
 *  - penyandian ke tag content control dan ke custom XML part;
 *  - menjalankan citeproc-js atas seluruh sitasi sesuai urutan dokumen,
 *    lalu menghasilkan teks sitasi dan daftar pustaka (HTML, teks, dan
 *    "run" berformat yang bisa ditulis oleh lapisan editor).
 *
 * Tanpa bundler: berkas ini dimuat sebagai <script> biasa (global
 * `ReadPaperCitations`, butuh global `CSL` dari vendor/citeproc.js) atau
 * di-require() dari Node untuk pengujian.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./vendor/citeproc.js'));
  } else {
    /* global CSL */
    root.ReadPaperCitations = factory(root.CSL || (typeof CSL !== 'undefined' ? CSL : undefined));
  }
})(typeof self !== 'undefined' ? self : this, function (CSL) {
  'use strict';

  var DATA_VERSION = 1;
  var CITATION_TAG = 'READPAPER_CITATION_v1';
  var BIBLIOGRAPHY_TAG = 'READPAPER_BIBLIOGRAPHY_v1';
  var STORE_NAMESPACE = 'urn:readpaper:citations:1';
  var DEFAULT_STYLE = 'apa';
  var DEFAULT_LOCALE = 'id-ID';

  /** Label lokator CSL, dengan nama tampilan berbahasa Indonesia. */
  var LOCATOR_LABELS = [
    ['page', 'Halaman'], ['chapter', 'Bab'], ['section', 'Bagian'],
    ['paragraph', 'Paragraf'], ['figure', 'Gambar'], ['table', 'Tabel'],
    ['line', 'Baris'], ['volume', 'Volume'], ['issue', 'Nomor terbitan'],
    ['part', 'Bagian (part)'], ['appendix', 'Lampiran'], ['equation', 'Persamaan'],
    ['note', 'Catatan'], ['column', 'Kolom'], ['folio', 'Folio'],
    ['verse', 'Ayat'], ['book', 'Buku'], ['algorithm', 'Algoritma'],
  ];

  // ---------------------------------------------------------------------
  // Utilitas

  function randomHex(n) {
    var out = '';
    var c = (typeof crypto !== 'undefined' && crypto.getRandomValues) ? crypto : null;
    if (c) {
      var bytes = new Uint8Array(Math.ceil(n / 2));
      c.getRandomValues(bytes);
      for (var i = 0; i < bytes.length; i++) out += ('0' + bytes[i].toString(16)).slice(-2);
      return out.slice(0, n);
    }
    while (out.length < n) out += Math.floor(Math.random() * 16).toString(16);
    return out;
  }

  /** Id sitasi baru, misalnya `c-7f3a9b`. */
  function newCitationId(existing) {
    var taken = {};
    (existing || []).forEach(function (id) { taken[id] = true; });
    for (;;) {
      var id = 'c-' + randomHex(6);
      if (!taken[id]) return id;
    }
  }

  function utf8ToBase64(text) {
    var bytes = new TextEncoder().encode(text);
    var bin = '';
    for (var i = 0; i < bytes.length; i += 0x8000) {
      bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    }
    return btoa(bin);
  }

  function base64ToUtf8(b64) {
    var bin = atob(b64.replace(/\s+/g, ''));
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return new TextDecoder().decode(bytes);
  }

  function str(v) { return v === undefined || v === null ? '' : String(v); }

  function clone(o) { return o === undefined ? undefined : JSON.parse(JSON.stringify(o)); }

  // ---------------------------------------------------------------------
  // Bentuk data (kontrak "Data di dalam dokumen")

  /**
   * Satu item di dalam sitasi. `itemData` wajib (CSL-JSON lengkap); `id`-nya
   * disamakan dengan `key`, karena citeproc mengenali item lewat `id`.
   */
  function makeCitationItem(itemData, opts) {
    opts = opts || {};
    if (!itemData || typeof itemData !== 'object') throw new Error('itemData wajib ada');
    var key = str(opts.key || itemData.id);
    if (!key) throw new Error('Item tanpa kunci');
    var data = clone(itemData);
    data.id = key;
    var item = {
      key: key,
      itemData: data,
      locator: str(opts.locator),
      label: str(opts.label || 'page'),
      prefix: str(opts.prefix),
      suffix: str(opts.suffix),
      suppressAuthor: !!opts.suppressAuthor,
    };
    if (opts.annotationKey) item.annotationKey = str(opts.annotationKey);
    return item;
  }

  function makeCitation(items, opts) {
    opts = opts || {};
    return {
      v: DATA_VERSION,
      id: opts.id || newCitationId(opts.existingIds),
      items: (items || []).map(function (it) { return makeCitationItem(it.itemData, it); }),
      noBib: !!opts.noBib,
    };
  }

  /** Memeriksa dan melengkapi sitasi hasil parse. Melempar galat bila rusak. */
  function normalizeCitation(obj) {
    if (!obj || typeof obj !== 'object') throw new Error('Sitasi bukan objek');
    if (obj.v !== undefined && obj.v > DATA_VERSION) {
      throw new Error('Sitasi dibuat oleh versi ReadPaper yang lebih baru (v' + obj.v + ')');
    }
    if (!Array.isArray(obj.items) || obj.items.length === 0) throw new Error('Sitasi tanpa item');
    var seen = {};
    var items = [];
    obj.items.forEach(function (it) {
      var n = makeCitationItem(it.itemData, it);
      if (seen[n.key]) return; // satu item cukup sekali per klaster
      seen[n.key] = true;
      items.push(n);
    });
    return {
      v: DATA_VERSION,
      id: str(obj.id) || newCitationId(),
      items: items,
      noBib: !!obj.noBib,
    };
  }

  function defaultSettings() {
    return { v: DATA_VERSION, style: DEFAULT_STYLE, locale: DEFAULT_LOCALE, uncited: [] };
  }

  function normalizeSettings(obj) {
    var d = defaultSettings();
    if (!obj || typeof obj !== 'object') return d;
    var uncited = [];
    var seen = {};
    (Array.isArray(obj.uncited) ? obj.uncited : []).forEach(function (u) {
      if (!u || !u.itemData) return;
      var key = str(u.key || u.itemData.id);
      if (!key || seen[key]) return;
      seen[key] = true;
      var data = clone(u.itemData);
      data.id = key;
      uncited.push({ key: key, itemData: data });
    });
    return {
      v: DATA_VERSION,
      style: str(obj.style) || d.style,
      locale: str(obj.locale) || d.locale,
      uncited: uncited,
    };
  }

  function serializeCitation(cit) { return JSON.stringify(normalizeCitation(cit)); }
  function parseCitation(json) { return normalizeCitation(JSON.parse(json)); }
  function serializeSettings(s) { return JSON.stringify(normalizeSettings(s)); }
  function parseSettings(json) { return normalizeSettings(JSON.parse(json)); }

  // ---------------------------------------------------------------------
  // Tag content control
  //
  // Dua bentuk tag sitasi, dan pembaca di kedua editor menerima keduanya:
  //   READPAPER_CITATION_v1:<base64 JSON>   data ada di tag itu sendiri
  //   READPAPER_CITATION_v1#c-7f3a9b        data ada di custom XML part
  // Tag daftar pustaka: READPAPER_BIBLIOGRAPHY_v1, opsional diikuti
  // `:<base64 JSON pengaturan>` sebagai cadangan pengaturan dokumen.

  function encodeCitationTag(cit, mode) {
    var c = normalizeCitation(cit);
    if (mode === 'ref') return CITATION_TAG + '#' + c.id;
    return CITATION_TAG + ':' + utf8ToBase64(JSON.stringify(c));
  }

  /**
   * @returns {null | {kind: 'inline', citation, id} | {kind: 'ref', id} |
   *           {kind: 'broken', id: null, error}}
   */
  function parseCitationTag(tag) {
    tag = str(tag);
    if (tag.indexOf(CITATION_TAG) !== 0) return null;
    var rest = tag.slice(CITATION_TAG.length);
    if (rest.charAt(0) === '#') {
      var id = rest.slice(1).trim();
      return id ? { kind: 'ref', id: id } : { kind: 'broken', id: null, error: 'Tag tanpa id' };
    }
    if (rest.charAt(0) === ':') {
      try {
        var c = parseCitation(base64ToUtf8(rest.slice(1)));
        return { kind: 'inline', id: c.id, citation: c };
      } catch (e) {
        return { kind: 'broken', id: null, error: String(e && e.message || e) };
      }
    }
    return { kind: 'broken', id: null, error: 'Tag tidak dikenal' };
  }

  function isCitationTag(tag) { return str(tag).indexOf(CITATION_TAG) === 0; }
  function isBibliographyTag(tag) { return str(tag).indexOf(BIBLIOGRAPHY_TAG) === 0; }

  function encodeBibliographyTag(settings) {
    if (!settings) return BIBLIOGRAPHY_TAG;
    return BIBLIOGRAPHY_TAG + ':' + utf8ToBase64(serializeSettings(settings));
  }

  /** Pengaturan yang dicadangkan di tag daftar pustaka, atau null. */
  function parseBibliographyTag(tag) {
    tag = str(tag);
    if (!isBibliographyTag(tag)) return null;
    var rest = tag.slice(BIBLIOGRAPHY_TAG.length);
    if (rest.charAt(0) !== ':') return null;
    try { return parseSettings(base64ToUtf8(rest.slice(1))); } catch (e) { return null; }
  }

  // ---------------------------------------------------------------------
  // Custom XML part
  //
  // <readpaper xmlns="urn:readpaper:citations:1" v="1">
  //   <settings>base64 JSON pengaturan</settings>
  //   <cache>base64 JSON {style, styleXml, locales: {tag: xml}}</cache>
  //   <citation id="c-7f3a9b">base64 JSON sitasi</citation>
  // </readpaper>
  // Isinya base64 supaya tidak ada urusan escape XML maupun spasi yang
  // dinormalkan editor.

  function xmlAttr(s) {
    return str(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
  }

  function buildStoreXml(store) {
    store = store || {};
    var out = ['<?xml version="1.0" encoding="UTF-8"?>',
      '<readpaper xmlns="' + STORE_NAMESPACE + '" v="' + DATA_VERSION + '">'];
    out.push('<settings>' + utf8ToBase64(serializeSettings(store.settings)) + '</settings>');
    if (store.cache) out.push('<cache>' + utf8ToBase64(JSON.stringify(store.cache)) + '</cache>');
    var cits = store.citations || {};
    Object.keys(cits).sort().forEach(function (id) {
      out.push('<citation id="' + xmlAttr(id) + '">' +
        utf8ToBase64(JSON.stringify(normalizeCitation(cits[id]))) + '</citation>');
    });
    out.push('</readpaper>');
    return out.join('');
  }

  /** Kebalikan buildStoreXml. Bagian yang rusak dilewati, tidak melempar. */
  function parseStoreXml(xml) {
    var res = { settings: null, cache: null, citations: {} };
    xml = str(xml);
    var m = /<(?:\w+:)?settings[^>]*>([^<]*)<\/(?:\w+:)?settings>/.exec(xml);
    if (m) { try { res.settings = parseSettings(base64ToUtf8(m[1])); } catch (e) { /* lewati */ } }
    m = /<(?:\w+:)?cache[^>]*>([^<]*)<\/(?:\w+:)?cache>/.exec(xml);
    if (m) { try { res.cache = JSON.parse(base64ToUtf8(m[1])); } catch (e) { /* lewati */ } }
    var re = /<(?:\w+:)?citation\s+id="([^"]*)"[^>]*>([^<]*)<\/(?:\w+:)?citation>/g;
    while ((m = re.exec(xml))) {
      try {
        var c = parseCitation(base64ToUtf8(m[2]));
        res.citations[m[1]] = c;
      } catch (e) { /* lewati */ }
    }
    return res;
  }

  // ---------------------------------------------------------------------
  // HTML citeproc → run berformat

  var ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };

  function decodeEntities(s) {
    return s.replace(/&(#x[0-9a-fA-F]+|#\d+|\w+);/g, function (all, e) {
      if (e.charAt(0) === '#') {
        var code = e.charAt(1).toLowerCase() === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        return isFinite(code) ? String.fromCodePoint(code) : all;
      }
      return Object.prototype.hasOwnProperty.call(ENTITIES, e) ? ENTITIES[e] : all;
    });
  }

  function styleFlags(tag, attrs) {
    var f = {};
    switch (tag) {
      case 'i': case 'em': f.italic = true; break;
      case 'b': case 'strong': f.bold = true; break;
      case 'sup': f.superscript = true; f.subscript = false; break;
      case 'sub': f.subscript = true; f.superscript = false; break;
      case 'u': f.underline = true; break;
      default: break;
    }
    var st = /style\s*=\s*"([^"]*)"/i.exec(attrs || '');
    if (st) {
      var css = st[1].replace(/\s+/g, '').toLowerCase();
      if (css.indexOf('font-style:italic') >= 0) f.italic = true;
      if (css.indexOf('font-style:normal') >= 0) f.italic = false;
      if (css.indexOf('font-weight:bold') >= 0) f.bold = true;
      if (css.indexOf('font-weight:normal') >= 0) f.bold = false;
      if (css.indexOf('font-variant:small-caps') >= 0) f.smallCaps = true;
      if (css.indexOf('font-variant:normal') >= 0) f.smallCaps = false;
      if (css.indexOf('text-decoration:underline') >= 0) f.underline = true;
      if (css.indexOf('text-decoration:none') >= 0) f.underline = false;
      if (css.indexOf('vertical-align:sup') >= 0) f.superscript = true;
      if (css.indexOf('vertical-align:sub') >= 0) f.subscript = true;
    }
    return f;
  }

  /**
   * Mengubah HTML keluaran citeproc-js menjadi daftar run:
   * `[{text, italic, bold, underline, smallCaps, superscript, subscript}]`.
   * Hanya tag yang memang dihasilkan citeproc yang dikenali; tag lain
   * dibuang dan teksnya dipertahankan. `csl-left-margin` diakhiri tab.
   */
  function htmlToRuns(html) {
    var runs = [];
    var stack = [{}];
    var re = /<(\/?)([a-zA-Z0-9]+)([^>]*)>|([^<]+)/g;
    var m;
    function cur() { return stack[stack.length - 1]; }
    function push(text) {
      if (!text) return;
      var s = cur();
      var run = {
        text: text, italic: !!s.italic, bold: !!s.bold, underline: !!s.underline,
        smallCaps: !!s.smallCaps, superscript: !!s.superscript, subscript: !!s.subscript,
      };
      var last = runs[runs.length - 1];
      if (last && last.italic === run.italic && last.bold === run.bold &&
          last.underline === run.underline && last.smallCaps === run.smallCaps &&
          last.superscript === run.superscript && last.subscript === run.subscript) {
        last.text += run.text;
      } else {
        runs.push(run);
      }
    }
    while ((m = re.exec(str(html)))) {
      if (m[4] !== undefined) {
        var raw = m[4];
        if (/^\s*$/.test(raw) && raw.indexOf('\n') >= 0) continue; // indentasi HTML citeproc
        push(decodeEntities(raw.replace(/\s*\n\s*/g, ' ')));
        continue;
      }
      var closing = m[1] === '/';
      var tag = m[2].toLowerCase();
      var attrs = m[3] || '';
      if (tag === 'br') { push('\n'); continue; }
      if (closing) {
        var top = stack.length > 1 ? stack.pop() : cur();
        if (top.__tab) push('\t');
        continue;
      }
      if (/\/\s*$/.test(attrs)) continue; // tag kosong
      var next = {};
      var base = cur();
      for (var k in base) if (k !== '__tab') next[k] = base[k];
      var f = styleFlags(tag, attrs);
      for (var j in f) next[j] = f[j];
      if (tag === 'div' && /csl-left-margin/.test(attrs)) next.__tab = true;
      stack.push(next);
    }
    // Rapikan spasi di ujung.
    if (runs.length) {
      runs[0].text = runs[0].text.replace(/^[ \t\n]+/, '');
      var l = runs[runs.length - 1];
      l.text = l.text.replace(/[ \n]+$/, '');
    }
    return runs.filter(function (r) { return r.text.length > 0; });
  }

  function runsToText(runs) {
    return runs.map(function (r) { return r.text; }).join('');
  }

  // ---------------------------------------------------------------------
  // Mesin citeproc

  /** Membaca beberapa atribut gaya tanpa membangun mesin. */
  function inspectStyle(styleXml) {
    var xml = str(styleXml);
    var cls = /<style\b[^>]*\bclass="([^"]+)"/.exec(xml);
    var loc = /<style\b[^>]*\bdefault-locale="([^"]+)"/.exec(xml);
    var fmt = /<category\b[^>]*\bcitation-format="([^"]+)"/.exec(xml);
    var parent = /<link\b[^>]*rel="independent-parent"[^>]*>/.exec(xml);
    var title = /<title>([^<]*)<\/title>/.exec(xml);
    return {
      class: cls ? cls[1] : 'in-text',
      defaultLocale: loc ? loc[1] : null,
      format: fmt ? fmt[1] : null,
      dependent: !!parent,
      title: title ? decodeEntities(title[1]) : null,
      numeric: /citation-number/.test(xml) || (fmt ? fmt[1] === 'numeric' : false),
    };
  }

  /**
   * Mengumpulkan data item dari sitasi (urutan dokumen) dan item tanpa sitasi.
   * Bila satu kunci muncul dengan salinan berbeda, yang pertama menang.
   */
  function collectItemData(citations, uncited) {
    var map = {};
    (citations || []).forEach(function (c) {
      c.items.forEach(function (it) { if (!map[it.key]) map[it.key] = it.itemData; });
    });
    (uncited || []).forEach(function (u) { if (!map[u.key]) map[u.key] = u.itemData; });
    return map;
  }

  /** Kunci yang masuk daftar pustaka: dari sitasi tanpa noBib, plus uncited. */
  function bibliographyKeys(citations, uncited) {
    var keys = {};
    (citations || []).forEach(function (c) {
      if (c.noBib) return;
      c.items.forEach(function (it) { keys[it.key] = true; });
    });
    (uncited || []).forEach(function (u) { keys[u.key] = true; });
    return keys;
  }

  function toCiteprocCitation(c) {
    return {
      citationID: c.id,
      citationItems: c.items.map(function (it) {
        var ci = { id: it.key };
        if (it.locator) { ci.locator = it.locator; ci.label = it.label || 'page'; }
        if (it.prefix) ci.prefix = it.prefix;
        if (it.suffix) ci.suffix = it.suffix;
        if (it.suppressAuthor) ci['suppress-author'] = true;
        return ci;
      }),
      properties: { noteIndex: 0 },
    };
  }

  /**
   * Memproses sitasi dengan citeproc-js.
   *
   * @param {object} opts
   * @param {string} opts.styleXml   XML gaya independen.
   * @param {string} [opts.locale]   misalnya 'id-ID'.
   * @param {function(string): (string|null)} opts.retrieveLocale
   *        XML locale untuk sebuah tag; citeproc juga meminta 'en-US'.
   */
  function CitationProcessor(opts) {
    if (!CSL) throw new Error('citeproc-js (CSL) belum dimuat');
    if (!opts || !opts.styleXml) throw new Error('XML gaya wajib ada');
    this.styleXml = opts.styleXml;
    this.locale = opts.locale || DEFAULT_LOCALE;
    this.retrieveLocaleFn = opts.retrieveLocale;
    this.style = inspectStyle(opts.styleXml);
    this._items = {};
    this._localeCache = {};
    this._engine = null;
  }

  CitationProcessor.prototype._sys = function () {
    var self = this;
    return {
      retrieveLocale: function (lang) {
        if (Object.prototype.hasOwnProperty.call(self._localeCache, lang)) return self._localeCache[lang];
        var xml = self.retrieveLocaleFn ? self.retrieveLocaleFn(lang) : null;
        self._localeCache[lang] = xml || null;
        return xml || null;
      },
      retrieveItem: function (id) {
        var it = self._items[id];
        if (!it) throw new Error('Data item ' + id + ' tidak ada di dokumen');
        return it;
      },
    };
  };

  CitationProcessor.prototype._newEngine = function () {
    // forceLang=false: gaya yang punya default-locale (mis. AMA) tetap
    // memakai bahasanya sendiri, sama seperti Zotero.
    var engine = new CSL.Engine(this._sys(), this.styleXml, this.locale, false);
    engine.setOutputFormat('html');
    return engine;
  };

  /**
   * Mesin citeproc, dibangun sekali lalu dipakai ulang: membangunnya
   * (mengurai XML gaya) bisa makan satu-dua detik untuk gaya besar seperti
   * Chicago, sedangkan rebuildProcessorState atas mesin yang sudah ada hanya
   * puluhan milidetik. Panggil lebih awal (mis. saat panel dibuka) supaya
   * menyisipkan sitasi tidak menunggu.
   */
  CitationProcessor.prototype.engine = function () {
    if (!this._engine) this._engine = this._newEngine();
    return this._engine;
  };

  /**
   * Membangun ulang seluruh sitasi dan daftar pustaka.
   *
   * @param {Array} citations  sitasi (bentuk kontrak) sesuai urutan dokumen.
   * @param {Array} [uncited]  `settings.uncited`.
   * @returns {{citations: Object<string, {html, text, runs}>,
   *            order: string[], bibliography: object}}
   */
  CitationProcessor.prototype.render = function (citations, uncited) {
    citations = (citations || []).map(normalizeCitation);
    uncited = normalizeSettings({ uncited: uncited || [] }).uncited;
    // Item lama tetap tersedia: registri citeproc masih bisa memintanya
    // (mis. item uncited yang baru dihapus) sebelum dibersihkan.
    var fresh = collectItemData(citations, uncited);
    var merged = {};
    var k;
    for (k in this._items) merged[k] = this._items[k];
    for (k in fresh) merged[k] = fresh[k];
    this._items = merged;

    var engine = this.engine();

    var cited = {};
    citations.forEach(function (c) { c.items.forEach(function (it) { cited[it.key] = true; }); });
    var uncitedIds = uncited.map(function (u) { return u.key; }).filter(function (k) { return !cited[k]; });

    var result = { citations: {}, order: [], bibliography: null };
    var rebuilt = engine.rebuildProcessorState(citations.map(toCiteprocCitation), 'html', uncitedIds);
    rebuilt.forEach(function (row) {
      var html = row[2];
      var runs = htmlToRuns(html);
      result.citations[row[0]] = { html: html, runs: runs, text: runsToText(runs) };
      result.order.push(row[0]);
    });
    result.bibliography = this._bibliography(engine, bibliographyKeys(citations, uncited));
    return result;
  };

  /**
   * Teks satu sitasi, dihitung dari sitasi yang sudah ada tanpa menulis
   * ulang apa pun di dokumen. `citations` sudah berisi sitasi baru itu di
   * posisinya.
   */
  CitationProcessor.prototype.preview = function (citations, id, uncited) {
    var r = this.render(citations, uncited);
    return r.citations[id] || null;
  };

  CitationProcessor.prototype._bibliography = function (engine, keep) {
    if (!engine.bibliography || !engine.bibliography.tokens || !engine.bibliography.tokens.length) {
      return { supported: false, entries: [], html: '', text: '' };
    }
    var out = engine.makeBibliography();
    if (!out) return { supported: true, entries: [], html: '', text: '' };
    var meta = out[0];
    var entries = [];
    out[1].forEach(function (html, i) {
      var ids = (meta.entry_ids && meta.entry_ids[i]) || [];
      var key = String(ids[0]);
      if (!keep[key]) return; // hanya disitasi dengan noBib
      var runs = htmlToRuns(html);
      entries.push({ key: key, html: html, runs: runs, text: runsToText(runs) });
    });
    return {
      supported: true,
      entries: entries,
      html: meta.bibstart + entries.map(function (e) { return e.html; }).join('') + meta.bibend,
      text: entries.map(function (e) { return e.text; }).join('\n'),
      hangingIndent: !!meta.hangingindent,
      secondFieldAlign: meta['second-field-align'] || false,
      maxOffset: meta.maxoffset || 0,
      lineSpacing: meta.linespacing || 1,
      entrySpacing: meta.entryspacing || 0,
    };
  };

  // ---------------------------------------------------------------------
  // Bantuan untuk lapisan editor

  /**
   * Memberi id baru kepada sitasi yang id-nya sudah dipakai sitasi lebih
   * awal (terjadi setelah salin-tempel di dokumen yang sama).
   * @returns {Array<{index, oldId, newId}>} perubahan yang dibuat.
   */
  function dedupeCitationIds(citations) {
    var seen = {};
    var changes = [];
    var all = citations.map(function (c) { return c.id; });
    citations.forEach(function (c, i) {
      if (seen[c.id]) {
        var nid = newCitationId(all);
        all.push(nid);
        changes.push({ index: i, oldId: c.id, newId: nid });
        c.id = nid;
      }
      seen[c.id] = true;
    });
    return changes;
  }

  /**
   * Mengganti `itemData` di semua sitasi dan uncited dengan data terbaru dari
   * server (`fresh`: {key: CSL-JSON}). Mengembalikan jumlah item yang berubah.
   */
  function refreshItemData(citations, settings, fresh) {
    var changed = 0;
    function apply(holder) {
      var d = fresh[holder.key];
      if (!d) return;
      var nd = clone(d);
      nd.id = holder.key;
      if (JSON.stringify(nd) !== JSON.stringify(holder.itemData)) changed++;
      holder.itemData = nd;
    }
    citations.forEach(function (c) { c.items.forEach(apply); });
    if (settings && settings.uncited) settings.uncited.forEach(apply);
    return changed;
  }

  function allItemKeys(citations, settings) {
    var keys = {};
    citations.forEach(function (c) { c.items.forEach(function (it) { keys[it.key] = true; }); });
    if (settings && settings.uncited) settings.uncited.forEach(function (u) { keys[u.key] = true; });
    return Object.keys(keys);
  }

  function addUncited(settings, itemData) {
    var s = normalizeSettings(settings);
    var key = str(itemData && itemData.id);
    if (!key) throw new Error('Item tanpa kunci');
    if (s.uncited.some(function (u) { return u.key === key; })) return s;
    var d = clone(itemData);
    d.id = key;
    s.uncited.push({ key: key, itemData: d });
    return s;
  }

  function removeUncited(settings, key) {
    var s = normalizeSettings(settings);
    s.uncited = s.uncited.filter(function (u) { return u.key !== key; });
    return s;
  }

  /** Ringkasan pendek item untuk tampilan: "McClean dkk. (2018) — judul". */
  function describeItem(itemData) {
    var d = itemData || {};
    var names = (d.author || d.editor || []).map(function (n) { return n.family || n.literal || ''; }).filter(Boolean);
    var who = names.length > 2 ? names[0] + ' dkk.' : names.join(' & ');
    var year = d.issued && d.issued['date-parts'] && d.issued['date-parts'][0] && d.issued['date-parts'][0][0];
    return (who || 'Tanpa pengarang') + (year ? ' (' + year + ')' : '') + (d.title ? ' — ' + d.title : '');
  }

  return {
    DATA_VERSION: DATA_VERSION,
    CITATION_TAG: CITATION_TAG,
    BIBLIOGRAPHY_TAG: BIBLIOGRAPHY_TAG,
    STORE_NAMESPACE: STORE_NAMESPACE,
    DEFAULT_STYLE: DEFAULT_STYLE,
    DEFAULT_LOCALE: DEFAULT_LOCALE,
    LOCATOR_LABELS: LOCATOR_LABELS,
    citeprocVersion: CSL && CSL.PROCESSOR_VERSION,
    newCitationId: newCitationId,
    utf8ToBase64: utf8ToBase64,
    base64ToUtf8: base64ToUtf8,
    makeCitationItem: makeCitationItem,
    makeCitation: makeCitation,
    normalizeCitation: normalizeCitation,
    parseCitation: parseCitation,
    serializeCitation: serializeCitation,
    defaultSettings: defaultSettings,
    normalizeSettings: normalizeSettings,
    parseSettings: parseSettings,
    serializeSettings: serializeSettings,
    encodeCitationTag: encodeCitationTag,
    parseCitationTag: parseCitationTag,
    isCitationTag: isCitationTag,
    isBibliographyTag: isBibliographyTag,
    encodeBibliographyTag: encodeBibliographyTag,
    parseBibliographyTag: parseBibliographyTag,
    buildStoreXml: buildStoreXml,
    parseStoreXml: parseStoreXml,
    htmlToRuns: htmlToRuns,
    runsToText: runsToText,
    decodeEntities: decodeEntities,
    inspectStyle: inspectStyle,
    collectItemData: collectItemData,
    bibliographyKeys: bibliographyKeys,
    CitationProcessor: CitationProcessor,
    dedupeCitationIds: dedupeCitationIds,
    refreshItemData: refreshItemData,
    allItemKeys: allItemKeys,
    addUncited: addUncited,
    removeUncited: removeUncited,
    describeItem: describeItem,
  };
});
