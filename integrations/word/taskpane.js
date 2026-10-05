/*
 * Titik masuk task pane Word ReadPaper.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (window) {
  'use strict';
  /* global Office */
  if (window.READPAPER_UNSUPPORTED) return;

  function boot(message) {
    var el = document.getElementById('boot');
    if (el) el.textContent = message;
  }

  Office.onReady(function (info) {
    if (info.host !== Office.HostType.Word) {
      boot('Add-in ini hanya untuk Microsoft Word.');
      return;
    }
    if (!Office.context.requirements.isSetSupported('WordApi', '1.3')) {
      boot('Versi Word ini terlalu lama (butuh WordApi 1.3: Word 2016 atau lebih baru, atau Word web).');
      return;
    }
    var controller = new window.ReadPaperController({
      adapter: new window.ReadPaperWordAdapter(),
      api: new window.ReadPaperApi.Client(),
    });
    var ui = window.ReadPaperUI.mount(document.getElementById('app'), { controller: controller, editor: 'Word' });
    applyTheme(ui);
    if (Office.context.document && Office.context.document.addHandlerAsync && Office.EventType.OfficeThemeChanged) {
      try {
        Office.context.document.addHandlerAsync(Office.EventType.OfficeThemeChanged, function () { applyTheme(ui); });
      } catch (e) { /* tidak didukung di semua versi */ }
    }
  });

  function applyTheme(ui) {
    var t = Office.context.officeTheme;
    if (!t || !t.bodyBackgroundColor) return;
    var hex = String(t.bodyBackgroundColor).replace('#', '');
    if (hex.length !== 6) return;
    var r = parseInt(hex.slice(0, 2), 16);
    var g = parseInt(hex.slice(2, 4), 16);
    var b = parseInt(hex.slice(4, 6), 16);
    ui.setTheme((0.299 * r + 0.587 * g + 0.114 * b) < 128);
  }
})(window);
