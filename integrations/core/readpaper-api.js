/*
 * Pemanggil server sitasi ReadPaper desktop (http://127.0.0.1:23121).
 * Kontraknya ada di docs/api-sitasi.md.
 *
 * Dimuat sebagai <script> biasa (global `ReadPaperApi`) atau di-require()
 * dari Node untuk pengujian (fetch dan storage bisa disuntikkan).
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.ReadPaperApi = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var DEFAULT_BASE_URL = 'http://127.0.0.1:23121';
  var TOKEN_KEY = 'readpaper.token';
  var CACHE_PREFIX = 'readpaper.cache.';

  var MESSAGES = {
    offline: 'ReadPaper tidak berjalan atau server sitasinya mati. Buka ReadPaper ' +
      'desktop, lalu coba lagi.',
    notoken: 'Token belum diisi. Salin token dari Pengaturan ReadPaper → Sitasi ' +
      'di Word dan OnlyOffice.',
    unauthorized: 'Token salah. Salin ulang token dari Pengaturan ReadPaper; ' +
      'token berubah bila dibuat ulang di sana.',
    timeout: 'ReadPaper tidak menjawab tepat waktu. Coba lagi sebentar lagi.',
  };

  function ApiError(code, message, status) {
    var e = new Error(message || MESSAGES[code] || 'Galat tak dikenal');
    e.name = 'ReadPaperApiError';
    e.code = code;
    e.status = status || 0;
    return e;
  }

  /** Penyimpanan yang tidak pernah melempar (localStorage bisa diblokir). */
  function safeStorage(storage) {
    var mem = {};
    return {
      get: function (k) {
        try { if (storage) { var v = storage.getItem(k); return v === null ? null : v; } } catch (e) { /* abaikan */ }
        return Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null;
      },
      set: function (k, v) {
        mem[k] = v;
        try { if (storage) storage.setItem(k, v); } catch (e) { /* penuh atau diblokir */ }
      },
      remove: function (k) {
        delete mem[k];
        try { if (storage) storage.removeItem(k); } catch (e) { /* abaikan */ }
      },
    };
  }

  /**
   * @param {object} [opts]
   * @param {string} [opts.baseUrl]
   * @param {Storage} [opts.storage]  bawaan: window.localStorage
   * @param {function} [opts.fetch]   bawaan: fetch global
   * @param {number} [opts.timeoutMs] bawaan 8000
   */
  function Client(opts) {
    opts = opts || {};
    var ls = null;
    if (opts.storage !== undefined) ls = opts.storage;
    else { try { ls = typeof localStorage !== 'undefined' ? localStorage : null; } catch (e) { ls = null; } }
    this.store = safeStorage(ls);
    this.baseUrl = (opts.baseUrl || this.store.get('readpaper.baseUrl') || DEFAULT_BASE_URL).replace(/\/+$/, '');
    this.fetchImpl = opts.fetch || (typeof fetch !== 'undefined' ? fetch.bind(typeof self !== 'undefined' ? self : this) : null);
    this.timeoutMs = opts.timeoutMs || 8000;
  }

  Client.prototype.getToken = function () { return (this.store.get(TOKEN_KEY) || '').trim(); };
  Client.prototype.setToken = function (t) {
    t = String(t || '').trim();
    if (t) this.store.set(TOKEN_KEY, t); else this.store.remove(TOKEN_KEY);
  };
  Client.prototype.hasToken = function () { return !!this.getToken(); };

  Client.prototype._request = function (path, options) {
    options = options || {};
    var self = this;
    if (!this.fetchImpl) return Promise.reject(ApiError('offline'));
    var headers = {};
    if (!options.noAuth) {
      var token = this.getToken();
      if (!token) return Promise.reject(ApiError('notoken'));
      headers.Authorization = 'Bearer ' + token;
    }
    var init = { method: options.method || 'GET', headers: headers, cache: 'no-store' };
    if (options.body !== undefined) {
      headers['Content-Type'] = 'application/json';
      init.body = JSON.stringify(options.body);
    }
    var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    if (controller) init.signal = controller.signal;
    if (options.signal && controller) {
      if (options.signal.aborted) controller.abort();
      else options.signal.addEventListener('abort', function () { controller.abort(); });
    }
    var timedOut = false;
    var timer = setTimeout(function () { timedOut = true; if (controller) controller.abort(); },
      options.timeoutMs || this.timeoutMs);

    return Promise.resolve()
      .then(function () { return self.fetchImpl(self.baseUrl + path, init); })
      .then(function (res) {
        clearTimeout(timer);
        if (res.ok) return options.xml ? res.text() : res.json();
        return res.text().then(function (body) {
          var msg = null;
          try { msg = JSON.parse(body).error; } catch (e) { /* bukan JSON */ }
          if (res.status === 401) throw ApiError('unauthorized', null, 401);
          if (res.status === 404) throw ApiError('notfound', msg || 'Tidak ditemukan di ReadPaper.', 404);
          throw ApiError('http', msg || ('Server ReadPaper menjawab galat ' + res.status + '.'), res.status);
        });
      }, function (err) {
        clearTimeout(timer);
        if (err && err.name === 'AbortError') {
          if (timedOut) throw ApiError('timeout');
          throw ApiError('aborted', 'Dibatalkan.');
        }
        // fetch menolak tanpa status: server mati, port tertutup, atau
        // peramban memblokir akses ke alamat lokal.
        throw ApiError('offline');
      });
  };

  /** `GET /api/ping` — tanpa token. */
  Client.prototype.ping = function () {
    return this._request('/api/ping', { noAuth: true, timeoutMs: 3000 });
  };

  /**
   * Memeriksa server sekaligus token: ping, lalu satu panggilan bertoken.
   * @returns {Promise<{ping: object}>}
   */
  Client.prototype.check = function () {
    var self = this;
    return this.ping().then(function (p) {
      return self._request('/api/search?limit=1').then(function () { return { ping: p }; });
    });
  };

  Client.prototype.search = function (q, limit, signal) {
    var qs = [];
    if (q) qs.push('q=' + encodeURIComponent(q));
    if (limit) qs.push('limit=' + encodeURIComponent(limit));
    return this._request('/api/search' + (qs.length ? '?' + qs.join('&') : ''), { signal: signal })
      .then(function (r) { return (r && r.items) || []; });
  };

  /** CSL-JSON untuk sejumlah kunci: `{items, missing}`. */
  Client.prototype.items = function (keys) {
    return this._request('/api/items', { method: 'POST', body: { keys: keys || [] } })
      .then(function (r) { return { items: (r && r.items) || [], missing: (r && r.missing) || [] }; });
  };

  Client.prototype.annotations = function (key) {
    return this._request('/api/items/' + encodeURIComponent(key) + '/annotations')
      .then(function (r) { return (r && r.annotations) || []; });
  };

  Client.prototype.styles = function () {
    var self = this;
    return this._request('/api/styles').then(function (r) {
      var styles = (r && r.styles) || [];
      self.store.set(CACHE_PREFIX + 'styles', JSON.stringify(styles));
      return styles;
    });
  };

  /** Daftar gaya dari cache lokal (dipakai saat server mati). */
  Client.prototype.cachedStyles = function () {
    try { return JSON.parse(this.store.get(CACHE_PREFIX + 'styles') || '[]'); } catch (e) { return []; }
  };

  Client.prototype.styleXml = function (id) {
    return this._request('/api/styles/' + encodeURIComponent(id), { xml: true });
  };

  Client.prototype.localeXml = function (tag) {
    return this._request('/api/locales/' + encodeURIComponent(tag), { xml: true });
  };

  function getXml(client, kind, id, fetcher, docCacheXml) {
    var key = CACHE_PREFIX + kind + '.' + id;
    return fetcher().then(function (xml) {
      client.store.set(key, xml);
      return { xml: xml, source: 'server' };
    }, function (err) {
      if (err && (err.code === 'notfound')) throw err;
      var local = client.store.get(key);
      if (local) return { xml: local, source: 'local', error: err };
      if (docCacheXml) return { xml: docCacheXml, source: 'document', error: err };
      throw err;
    });
  }

  /**
   * Mengambil semua yang dibutuhkan untuk membangun mesin citeproc: XML gaya
   * dan locale. Urutannya: server → cache lokal add-in → salinan di dokumen.
   *
   * @param {Client} client
   * @param {string} styleId
   * @param {string} locale
   * @param {object} [docCache]  `{style, styleXml, locales: {tag: xml}}` dari dokumen
   * @returns {Promise<{styleId, styleXml, locales, sources, offline}>}
   */
  function loadStyleResources(client, styleId, locale, docCache) {
    docCache = docCache || {};
    var docStyle = docCache.style === styleId ? docCache.styleXml : null;
    var docLocales = docCache.locales || {};
    var sources = {};
    return getXml(client, 'style', styleId, function () { return client.styleXml(styleId); }, docStyle)
      .then(function (s) {
        sources.style = s.source;
        var m = /<style\b[^>]*\bdefault-locale="([^"]+)"/.exec(s.xml);
        var wanted = [locale || 'en-US', 'en-US'];
        if (m) wanted.push(m[1]);
        wanted = wanted.filter(function (t, i) { return wanted.indexOf(t) === i; });
        return Promise.all(wanted.map(function (tag) {
          return getXml(client, 'locale', tag, function () { return client.localeXml(tag); }, docLocales[tag])
            .then(function (l) { sources['locale:' + tag] = l.source; return [tag, l.xml]; },
              function () { return [tag, null]; });
        })).then(function (pairs) {
          var locales = {};
          pairs.forEach(function (p) { if (p[1]) locales[p[0]] = p[1]; });
          if (!locales['en-US']) {
            throw ApiError('offline', 'Locale en-US tidak tersedia: ReadPaper tidak berjalan dan dokumen ' +
              'ini belum menyimpan salinannya.');
          }
          var offline = Object.keys(sources).some(function (k) { return sources[k] !== 'server'; });
          return { styleId: styleId, styleXml: s.xml, locales: locales, sources: sources, offline: offline };
        });
      });
  }

  /** Fungsi retrieveLocale untuk CitationProcessor dari hasil loadStyleResources. */
  function localeRetriever(resources) {
    return function (tag) {
      var l = resources.locales;
      if (l[tag]) return l[tag];
      var lang = String(tag).split('-')[0];
      for (var k in l) if (k.split('-')[0] === lang) return l[k];
      return null;
    };
  }

  return {
    DEFAULT_BASE_URL: DEFAULT_BASE_URL,
    MESSAGES: MESSAGES,
    Client: Client,
    ApiError: ApiError,
    loadStyleResources: loadStyleResources,
    localeRetriever: localeRetriever,
  };
});
