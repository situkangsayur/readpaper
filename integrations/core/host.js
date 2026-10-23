/*
 * Menjalankan perintah sitasi atas "potret" dokumen, untuk editor yang tidak
 * punya mesin JavaScript sendiri — LibreOffice.
 *
 * Word, OnlyOffice, dan Google Docs menjalankan controller.js di panelnya.
 * LibreOffice tidak bisa: ekstensinya Python. Jadi ekstensi itu memotret
 * dokumennya (daftar content control ReadPaper sesuai urutan, isi store, dan
 * posisi kursor), mengirimnya ke ReadPaper, dan ReadPaper menjalankan
 * controller.js yang SAMA di atas adapter memori di berkas ini. Yang kembali
 * adalah daftar perubahan yang harus ditulis ekstensi ke dokumennya.
 *
 * Akibatnya aturan 1 (daftar pustaka diturunkan dari dokumen) berlaku persis
 * sama: potretnya dibuat dari dokumen setiap kali, dan tidak ada yang
 * diingat di antara dua perintah selain gaya terakhir dan cache mesin.
 *
 * Butuh ReadPaperCitations, ReadPaperApi, dan ReadPaperController.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('./citations.js'), require('./readpaper-api.js'), require('./controller.js'));
  } else {
    root.ReadPaperHost = factory(root.ReadPaperCitations, root.ReadPaperApi, root.ReadPaperController);
  }
})(typeof self !== 'undefined' ? self : this, function (RP, Api, Controller) {
  'use strict';

  /**
   * Adapter di atas potret dokumen. Setiap tulisan dicatat sebagai operasi;
   * potretnya ikut diperbarui supaya controller yang membaca ulang dokumen di
   * tengah perintah (insertCitation melakukannya) melihat hasil tulisannya.
   *
   * snapshot = {tagMode, controls: [{handle, tag}], storeXml, cursor, cursorIn,
   *             storeSupported}
   *   cursor:   banyaknya content control ReadPaper sebelum kursor.
   *   cursorIn: handle content control tempat kursor berada, atau null.
   */
  function MemoryAdapter(snapshot) {
    snapshot = snapshot || {};
    this.tagMode = snapshot.tagMode === 'ref' ? 'ref' : 'inline';
    this.controls = (snapshot.controls || []).map(function (c) {
      return { handle: String(c.handle), tag: String(c.tag || '') };
    });
    this.store = snapshot.storeXml || null;
    this.storeSupported = snapshot.storeSupported !== false;
    var n = Number(snapshot.cursor);
    this.cursor = isFinite(n) ? Math.max(0, Math.min(this.controls.length, n)) : this.controls.length;
    this.cursorIn = snapshot.cursorIn == null ? null : String(snapshot.cursorIn);
    this.ops = [];
    this._next = 1;
  }

  MemoryAdapter.prototype._find = function (handle) {
    for (var i = 0; i < this.controls.length; i++) if (this.controls[i].handle === String(handle)) return this.controls[i];
    return null;
  };

  MemoryAdapter.prototype._newHandle = function () { return 'new:' + this._next++; };

  MemoryAdapter.prototype.readControls = function () {
    return Promise.resolve({
      controls: this.controls.map(function (c) { return { handle: c.handle, tag: c.tag }; }),
      storeXml: this.store,
    });
  };

  MemoryAdapter.prototype.currentControl = function () {
    var c = this.cursorIn == null ? null : this._find(this.cursorIn);
    return Promise.resolve(c ? { handle: c.handle, tag: c.tag } : null);
  };

  MemoryAdapter.prototype.insertCitation = function (tag, runs) {
    var handle = this._newHandle();
    this.controls.splice(this.cursor, 0, { handle: handle, tag: tag });
    this.cursor++;
    this.ops.push({ op: 'insertCitation', handle: handle, tag: tag, runs: runs });
    return Promise.resolve(handle);
  };

  MemoryAdapter.prototype.writeCitations = function (list) {
    var self = this;
    (list || []).forEach(function (u) {
      var c = self._find(u.handle);
      if (c && u.tag) c.tag = u.tag;
      self.ops.push({ op: 'writeCitation', handle: String(u.handle), tag: u.tag || null, runs: u.runs });
    });
    return Promise.resolve();
  };

  MemoryAdapter.prototype.writeBibliography = function (handle, tag, bib) {
    var c = handle == null ? null : this._find(handle);
    var created = !c;
    if (!c) {
      c = { handle: this._newHandle(), tag: tag };
      this.controls.splice(this.cursor, 0, c);
      this.cursor++;
    }
    c.tag = tag;
    this.ops.push({ op: 'writeBibliography', handle: c.handle, created: created, tag: tag, bib: bib });
    return Promise.resolve(c.handle);
  };

  MemoryAdapter.prototype.writeStore = function (xml) {
    if (!this.storeSupported) return Promise.resolve(false);
    this.store = xml;
    this.ops.push({ op: 'writeStore', xml: xml });
    return Promise.resolve(true);
  };

  MemoryAdapter.prototype.unwrap = function (handles) {
    var drop = {};
    (handles || []).forEach(function (h) { drop[String(h)] = true; });
    this.controls = this.controls.filter(function (c) { return !drop[c.handle]; });
    this.ops.push({ op: 'unwrap', handles: Object.keys(drop) });
    return Promise.resolve();
  };

  /**
   * Operasi yang sama diringkas untuk penulisnya: satu entri per content
   * control dengan isi terakhirnya, dan store terakhir saja. Sitasi yang baru
   * disisipkan lalu langsung diberi nomor cukup ditulis sekali.
   *
   * @returns {{insert: object|null, citations: Array, bibliographies: Array,
   *   store: string|null|undefined, unwrap: Array}}
   *   store undefined = tidak berubah; null = hapus.
   */
  function compact(ops) {
    var out = { insert: null, citations: [], bibliographies: [], store: undefined, unwrap: [] };
    var cit = {};
    var bib = {};
    ops.forEach(function (o) {
      if (o.op === 'insertCitation') {
        out.insert = { handle: o.handle, tag: o.tag, runs: o.runs };
      } else if (o.op === 'writeCitation') {
        if (out.insert && out.insert.handle === o.handle) {
          if (o.tag) out.insert.tag = o.tag;
          out.insert.runs = o.runs;
          return;
        }
        var prev = cit[o.handle];
        if (prev) {
          if (o.tag) prev.tag = o.tag;
          prev.runs = o.runs;
        } else {
          cit[o.handle] = { handle: o.handle, tag: o.tag, runs: o.runs };
          out.citations.push(cit[o.handle]);
        }
      } else if (o.op === 'writeBibliography') {
        var b = bib[o.handle];
        if (b) {
          b.tag = o.tag;
          b.bib = o.bib;
        } else {
          bib[o.handle] = { handle: o.handle, created: o.created, tag: o.tag, bib: o.bib };
          out.bibliographies.push(bib[o.handle]);
        }
      } else if (o.op === 'writeStore') {
        out.store = o.xml;
      } else if (o.op === 'unwrap') {
        out.unwrap = out.unwrap.concat(o.handles);
      }
    });
    return out;
  }

  function itemSummary(it) {
    var d = it.itemData || {};
    var names = (d.author || d.editor || []).map(function (a) { return a.family || a.literal || ''; })
      .filter(Boolean);
    var year = d.issued && d.issued['date-parts'] && d.issued['date-parts'][0] ? String(d.issued['date-parts'][0][0]) : '';
    return {
      key: it.key,
      title: d.title || '',
      creators: names.length > 3 ? names.slice(0, 3).join(', ') + ' dkk.' : names.join(', '),
      year: year,
      locator: it.locator || '',
      label: it.label || 'page',
      prefix: it.prefix || '',
      suffix: it.suffix || '',
      suppressAuthor: !!it.suppressAuthor,
      annotationKey: it.annotationKey || '',
    };
  }

  function docState(doc) {
    return {
      style: doc.settings.style,
      locale: doc.settings.locale,
      hasSettings: doc.hasSettings,
      citations: doc.citations.length,
      broken: doc.broken.map(function (b) { return { handle: String(b.handle), reason: b.reason }; }),
      bibliographies: doc.bibliographies.length,
      uncited: doc.settings.uncited.map(function (u) {
        return itemSummary({ key: u.key, itemData: u.itemData });
      }),
    };
  }

  /** Item dialog → item sitasi, dengan CSL-JSON terbaru dari ReadPaper. */
  function withItemData(ctl, items) {
    var keys = items.map(function (it) { return String(it.key); });
    return ctl.api.items(keys).then(function (r) {
      var data = {};
      r.items.forEach(function (d) { data[d.id] = d; });
      var missing = keys.filter(function (k) { return !data[k]; });
      if (missing.length) throw new Error('Item tidak ada di library yang terbuka: ' + missing.join(', '));
      return items.map(function (it) {
        return {
          itemData: data[String(it.key)],
          locator: it.locator || '',
          label: it.label || 'page',
          prefix: it.prefix || '',
          suffix: it.suffix || '',
          suppressAuthor: !!it.suppressAuthor,
          annotationKey: it.annotationKey || '',
        };
      });
    });
  }

  var COMMANDS = {
    state: function (ctl) {
      return ctl.loadDocument().then(function (doc) {
        return ctl.currentCitation().then(function (cur) {
          var s = docState(doc);
          s.current = cur ? {
            handle: String(cur.entry.handle),
            noBib: !!cur.entry.citation.noBib,
            items: cur.entry.citation.items.map(itemSummary),
          } : null;
          return s;
        });
      });
    },
    insert: function (ctl, args) {
      var items = (args && args.items) || [];
      if (!items.length) return Promise.reject(new Error('Belum ada item yang dipilih.'));
      return withItemData(ctl, items).then(function (list) {
        return ctl.loadDocument().then(function (doc) {
          return ctl.insertCitation(ctl.newCitation(doc, list, !!args.noBib));
        });
      }).then(function (r) { return { text: r.text }; });
    },
    update: function (ctl, args) {
      var items = (args && args.items) || [];
      return ctl.currentCitation().then(function (cur) {
        if (!cur) throw new Error('Kursor tidak berada di dalam sitasi ReadPaper.');
        if (!items.length) throw new Error('Sitasi harus berisi paling sedikit satu item.');
        return withItemData(ctl, items).then(function (list) {
          var c = RP.makeCitation(list, { id: cur.entry.citation.id, noBib: !!args.noBib });
          return ctl.updateCitation(cur.entry, c);
        });
      });
    },
    refresh: function (ctl) { return ctl.refreshAll(); },
    bibliography: function (ctl) { return ctl.bibliography(); },
    setStyle: function (ctl, args) {
      if (!args || !args.style) return Promise.reject(new Error('Gaya belum dipilih.'));
      return ctl.setStyle(String(args.style), args.locale ? String(args.locale) : undefined);
    },
    addUncited: function (ctl, args) {
      return ctl.fetchItem(String(args && args.key)).then(function (d) { return ctl.addUncited(d); })
        .then(function (r) { return { uncited: r.settings.uncited.length }; });
    },
    removeUncited: function (ctl, args) {
      return ctl.removeUncited(String(args && args.key))
        .then(function (r) { return { uncited: r.settings.uncited.length }; });
    },
    convertToText: function (ctl) { return ctl.convertToText(); },
  };

  /**
   * Satu host per proses: controller-nya dipakai ulang antar perintah supaya
   * mesin citeproc tidak dibangun ulang setiap kali (aturan 2). Dokumennya
   * tidak: setiap perintah membawa potretnya sendiri.
   *
   * @param {object} opts  {fetch, storage} untuk ReadPaperApi.Client
   */
  function Host(opts) {
    opts = opts || {};
    var api = new Api.Client({ fetch: opts.fetch, storage: opts.storage || null, baseUrl: opts.baseUrl });
    // Host berjalan di dalam ReadPaper; tokennya hanya supaya Client mau
    // bertanya, tidak pernah melewati jaringan.
    if (!api.hasToken()) api.setToken('host');
    this.ctl = new Controller({ adapter: new MemoryAdapter({}), api: api });
  }

  /**
   * @param {{command: string, args?: object, doc: object}} req
   * @returns {Promise<{ok: true, result, changes, ops} | {ok: false, error}>}
   */
  Host.prototype.run = function (req) {
    var self = this;
    req = req || {};
    var fn = COMMANDS[req.command];
    if (!fn) return Promise.resolve({ ok: false, error: 'Perintah tidak dikenal: ' + req.command });
    var adapter = new MemoryAdapter(req.doc);
    // Adapter berganti tiap perintah, mesinnya tidak. Mode tag yang berbeda
    // (dokumen Word dibuka di LibreOffice) tidak memengaruhi mesin.
    this.ctl.adapter = adapter;
    return Promise.resolve().then(function () { return fn(self.ctl, req.args || {}); }).then(function (result) {
      return { ok: true, result: result === undefined ? null : result, changes: compact(adapter.ops), ops: adapter.ops.length };
    }, function (err) {
      return { ok: false, error: (err && err.message) || String(err) };
    });
  };

  // Untuk mesin yang hanya bisa bertukar string (QuickJS di ReadPaper):
  // start() memulai, lalu tuan rumah menjalankan antrean job, lalu take().
  var pending = {};
  var seq = 0;
  Host.prototype.start = function (reqJson) {
    var id = String(++seq);
    pending[id] = null;
    this.run(JSON.parse(reqJson)).then(function (r) { pending[id] = JSON.stringify(r); },
      function (e) { pending[id] = JSON.stringify({ ok: false, error: String(e && e.message || e) }); });
    return id;
  };
  Host.prototype.take = function (id) {
    var r = pending[id];
    if (r === null || r === undefined) return null;
    delete pending[id];
    return r;
  };

  return { Host: Host, MemoryAdapter: MemoryAdapter, compact: compact, COMMANDS: Object.keys(COMMANDS) };
});
