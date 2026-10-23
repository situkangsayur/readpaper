/*
 * Jembatan panel Google Docs: controller.js yang sama dengan Word dan
 * OnlyOffice, di atas ReadPaperHost.MemoryAdapter.
 *
 * Setiap panggilan ke server Apps Script makan ratusan milidetik, jadi
 * adapter "langsung" (satu panggilan per content control) akan membuat
 * menyisipkan satu sitasi menunggu beberapa detik — melanggar aturan 2.
 * Di sini setiap perintah panel menjadi satu transaksi: rpSnapshot() sekali
 * di awal, controller bekerja di memori, rpApply() sekali di akhir dengan
 * perubahan yang sudah diringkas.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) {
    module.exports = factory(require('../core/controller.js'), require('../core/host.js'));
  } else {
    root.ReadPaperGDocs = factory(root.ReadPaperController, root.ReadPaperHost);
  }
})(typeof self !== 'undefined' ? self : this, function (Controller, Host) {
  'use strict';

  /** Metode controller yang dipanggil panel; masing-masing satu transaksi. */
  var METHODS = ['loadDocument', 'currentCitation', 'warm', 'preview', 'insertCitation', 'updateCitation',
    'refreshAll', 'bibliography', 'setStyle', 'addUncited', 'removeUncited', 'convertToText'];

  /** google.script.run sebagai Promise. */
  function scriptRunner(run) {
    return function (name, arg) {
      var withArg = arguments.length > 1;
      return new Promise(function (resolve, reject) {
        var r = run.withSuccessHandler(resolve).withFailureHandler(function (e) {
          reject(new Error((e && e.message) || String(e)));
        });
        if (withArg) r[name](arg); else r[name]();
      });
    };
  }

  function hasChanges(c) {
    return !!(c.insert || c.citations.length || c.bibliographies.length || c.unwrap.length || c.store !== undefined);
  }

  /**
   * @param {object} opts {api: ReadPaperApi.Client, call: function(name, arg) -> Promise}
   * @returns {Controller} controller yang setiap perintahnya transaksi dokumen
   */
  function create(opts) {
    var call = opts.call;
    var ctl = new Controller({ adapter: new Host.MemoryAdapter({ tagMode: 'ref' }), api: opts.api });
    var depth = 0;

    function begin() {
      if (depth++ > 0) return Promise.resolve();
      return call('rpSnapshot').then(function (snap) {
        ctl.adapter = new Host.MemoryAdapter(snap);
      }, function (e) { depth--; throw e; });
    }

    function end(ok) {
      if (--depth > 0) return Promise.resolve();
      var changes = Host.compact(ctl.adapter.ops);
      ctl.adapter.ops = [];
      // Perintah yang gagal di tengah jalan tidak meninggalkan setengah
      // perubahan di dokumen.
      if (!ok || !hasChanges(changes)) return Promise.resolve();
      return call('rpApply', changes);
    }

    METHODS.forEach(function (name) {
      var orig = Controller.prototype[name];
      ctl[name] = function () {
        var args = arguments;
        return begin().then(function () { return orig.apply(ctl, args); }).then(function (r) {
          return end(true).then(function () { return r; });
        }, function (e) {
          return end(false).then(function () { throw e; });
        });
      };
    });
    return ctl;
  }

  return { create: create, scriptRunner: scriptRunner, METHODS: METHODS };
});
