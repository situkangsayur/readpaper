/*
 * Titik masuk plugin OnlyOffice ReadPaper.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (window) {
  'use strict';
  var ui = null;

  window.Asc.plugin.init = function () {
    var plugin = this;
    var controller = new window.ReadPaperController({
      adapter: new window.ReadPaperOnlyOfficeAdapter(plugin),
      api: new window.ReadPaperApi.Client(),
    });
    ui = window.ReadPaperUI.mount(document.getElementById('app'), { controller: controller, editor: 'OnlyOffice' });
    if (plugin.theme) applyTheme(plugin.theme);
  };

  function applyTheme(theme) {
    if (!ui || !theme) return;
    var t = String(theme.type || theme.name || '').toLowerCase();
    ui.setTheme(t.indexOf('dark') >= 0 || t.indexOf('contrast') >= 0);
  }

  window.Asc.plugin.onThemeChanged = function (theme) {
    if (window.Asc.plugin.onThemeChangedBase) window.Asc.plugin.onThemeChangedBase(theme);
    applyTheme(theme);
  };

  window.Asc.plugin.button = function () {
    this.executeCommand('close', '');
  };

  // Panel plugin tidak memakai terjemahan OnlyOffice; antarmukanya berbahasa Indonesia.
  window.Asc.plugin.onTranslate = function () {};
})(window);
