/*
 * Panel ReadPaper — antarmuka yang sama untuk plugin OnlyOffice dan task
 * pane Word. Bergantung pada ReadPaperCitations, ReadPaperApi, dan
 * ReadPaperController; lapisan editor hanya memanggil ReadPaperUI.mount().
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
(function (root) {
  'use strict';
  var RP = root.ReadPaperCitations;

  function h(tag, attrs, children) {
    var el = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        var v = attrs[k];
        if (v === undefined || v === null || v === false) return;
        if (k === 'class') el.className = v;
        else if (k === 'text') el.textContent = v;
        else if (k.indexOf('on') === 0) el.addEventListener(k.slice(2), v);
        else if (k === 'checked' || k === 'value' || k === 'disabled' || k === 'selected') el[k] = v;
        else el.setAttribute(k, v === true ? '' : v);
      });
    }
    (Array.isArray(children) ? children : children === undefined ? [] : [children]).forEach(function (c) {
      if (c === null || c === undefined || c === false) return;
      el.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    });
    return el;
  }

  function runsToNodes(runs) {
    return (runs || []).map(function (r) {
      var el = document.createElement(r.superscript ? 'sup' : r.subscript ? 'sub' : 'span');
      el.textContent = r.text;
      if (r.italic) el.style.fontStyle = 'italic';
      if (r.bold) el.style.fontWeight = 'bold';
      if (r.underline) el.style.textDecoration = 'underline';
      if (r.smallCaps) el.style.fontVariant = 'small-caps';
      return el;
    });
  }

  function debounce(fn, ms) {
    var t = null;
    return function () {
      var args = arguments;
      var self = this;
      clearTimeout(t);
      t = setTimeout(function () { fn.apply(self, args); }, ms);
    };
  }

  function errMessage(e) {
    return (e && e.message) ? e.message : String(e || 'Galat tak dikenal');
  }

  /**
   * @param {HTMLElement} container
   * @param {object} opts
   * @param {ReadPaperController} opts.controller
   * @param {string} opts.editor   'Word' | 'OnlyOffice'
   */
  function mount(container, opts) {
    var ctl = opts.controller;
    var api = ctl.api;
    var state = { view: 'main', conn: null, doc: null, busy: false };

    container.innerHTML = '';
    container.classList.add('rp');
    var header = h('header', { class: 'rp-header' });
    var main = h('main', { class: 'rp-main' });
    var status = h('div', { class: 'rp-status', role: 'status', 'aria-live': 'polite' });
    container.appendChild(header);
    container.appendChild(main);
    container.appendChild(status);

    // -------------------------------------------------------------------
    // Status dan sibuk

    function setStatus(msg, kind, action) {
      status.innerHTML = '';
      status.className = 'rp-status' + (kind ? ' rp-' + kind : '');
      if (!msg) return;
      status.appendChild(h('span', { text: msg }));
      if (action) status.appendChild(h('button', { class: 'rp-link', onclick: action.fn, text: action.label }));
    }

    function fail(e) {
      var code = e && e.code;
      if (code === 'notoken' || code === 'unauthorized') {
        setStatus(errMessage(e), 'error', { label: 'Atur token', fn: function () { show('token'); } });
      } else {
        setStatus(errMessage(e), 'error');
      }
    }

    function busy(promise, label) {
      state.busy = true;
      container.classList.add('rp-busy');
      if (label) setStatus(label, 'info');
      return promise.then(function (v) {
        state.busy = false;
        container.classList.remove('rp-busy');
        return v;
      }, function (e) {
        state.busy = false;
        container.classList.remove('rp-busy');
        fail(e);
        throw e;
      });
    }

    // -------------------------------------------------------------------
    // Header: nama dan status koneksi

    function renderHeader() {
      header.innerHTML = '';
      var pill;
      if (!state.conn) pill = h('span', { class: 'rp-pill', text: 'Memeriksa…' });
      else if (state.conn.ok) {
        pill = h('span', { class: 'rp-pill rp-ok', title: 'ReadPaper ' + (state.conn.ping.version || ''),
          text: state.conn.ping.library ? state.conn.ping.library : 'Terhubung' });
      } else {
        pill = h('button', { class: 'rp-pill rp-bad', title: state.conn.error, text: 'Tidak terhubung',
          onclick: function () { checkConnection(true); } });
      }
      header.appendChild(h('div', { class: 'rp-brand' }, [
        state.view !== 'main' ? h('button', { class: 'rp-back', title: 'Kembali', 'aria-label': 'Kembali',
          onclick: function () { show('main'); }, text: '‹' }) : null,
        h('span', { text: 'ReadPaper' }),
      ]));
      header.appendChild(pill);
    }

    function checkConnection(verbose) {
      state.conn = null;
      renderHeader();
      return api.ping().then(function (p) {
        if (!api.hasToken()) {
          state.conn = { ok: false, ping: p, error: 'Token belum diisi' };
          renderHeader();
          return state.conn;
        }
        return api.check().then(function () {
          state.conn = { ok: true, ping: p };
          renderHeader();
          if (verbose) setStatus('Terhubung ke ReadPaper' + (p.library ? ' — ' + p.library : '') + '.', 'ok');
          return state.conn;
        });
      }).catch(function (e) {
        state.conn = { ok: false, error: errMessage(e), code: e && e.code };
        renderHeader();
        if (verbose) fail(e);
        return state.conn;
      });
    }

    // -------------------------------------------------------------------
    // Navigasi

    function show(view, arg, keepStatus) {
      state.view = view;
      renderHeader();
      main.innerHTML = '';
      if (!keepStatus) setStatus('');
      if (view === 'main') renderMain();
      else if (view === 'cite') renderCite(arg);
      else if (view === 'styles') renderStyles();
      else if (view === 'uncited') renderUncited();
      else if (view === 'token') renderToken();
      else if (view === 'convert') renderConvert();
    }

    // -------------------------------------------------------------------
    // Tampilan utama

    function renderMain() {
      var info = h('p', { class: 'rp-docinfo', text: 'Membaca dokumen…' });
      var bibBtn = h('button', { class: 'rp-btn', text: 'Daftar pustaka', onclick: onBibliography });
      main.appendChild(info);
      main.appendChild(h('div', { class: 'rp-actions' }, [
        h('button', { class: 'rp-btn rp-primary', text: 'Sisipkan sitasi', onclick: function () { show('cite'); } }),
        h('button', { class: 'rp-btn', text: 'Sunting sitasi', onclick: onEdit,
          title: 'Letakkan kursor di dalam sebuah sitasi terlebih dahulu' }),
        bibBtn,
        h('button', { class: 'rp-btn', text: 'Perbarui semua', onclick: onRefresh,
          title: 'Render ulang semua sitasi dan daftar pustaka sesuai urutan dokumen' }),
      ]));
      main.appendChild(h('div', { class: 'rp-actions rp-secondary' }, [
        h('button', { class: 'rp-btn', text: 'Gaya sitasi…', onclick: function () { show('styles'); } }),
        h('button', { class: 'rp-btn', text: 'Tanpa disitasi…', onclick: function () { show('uncited'); },
          title: 'Item yang masuk daftar pustaka tanpa disitasi' }),
        h('button', { class: 'rp-btn', text: 'Jadikan teks biasa…', onclick: function () { show('convert'); } }),
        h('button', { class: 'rp-btn', text: 'Token…', onclick: function () { show('token'); } }),
      ]));
      ctl.loadDocument().then(function (doc) {
        state.doc = doc;
        var styles = api.cachedStyles();
        var st = styles.filter(function (s) { return s.id === doc.settings.style; })[0];
        var parts = ['Gaya: ' + (st ? st.title : doc.settings.style), 'Bahasa: ' + doc.settings.locale,
          doc.citations.length + ' sitasi'];
        if (doc.settings.uncited.length) parts.push(doc.settings.uncited.length + ' tanpa disitasi');
        info.textContent = parts.join(' · ');
        if (doc.broken.length) {
          info.appendChild(h('span', { class: 'rp-warn', text: ' · ' + doc.broken.length +
            ' sitasi tanpa data (mungkin ditempel dari dokumen lain)' }));
        }
        bibBtn.textContent = doc.bibliographies.length ? 'Bangun ulang daftar pustaka' : 'Sisipkan daftar pustaka';
      }, function (e) { info.textContent = 'Dokumen tidak terbaca: ' + errMessage(e); });
    }

    function onEdit() {
      busy(ctl.currentCitation(), 'Membaca sitasi…').then(function (cur) {
        if (!cur) {
          setStatus('Kursor tidak berada di dalam sitasi ReadPaper. Klik sebuah sitasi lalu coba lagi.', 'error');
          return;
        }
        show('cite', cur);
      }, function () {});
    }

    function onBibliography() {
      busy(ctl.bibliography(), 'Membangun daftar pustaka…').then(function (r) {
        setStatus((r.inserted ? 'Daftar pustaka disisipkan' : 'Daftar pustaka dibangun ulang') +
          ' — ' + r.entries + ' entri.', 'ok');
        renderMainInfoLater();
      }, function () {});
    }

    function onRefresh() {
      busy(ctl.refreshAll(), 'Memperbarui semua sitasi…').then(function (s) {
        var msg = s.citations + ' sitasi dan ' + s.bibliographies + ' daftar pustaka diperbarui.';
        if (s.offline) msg += ' ReadPaper tidak terhubung, jadi data item diambil dari salinan di dokumen.';
        else if (s.refreshedItems) msg += ' ' + s.refreshedItems + ' item memakai data terbaru dari ReadPaper.';
        if (s.missing && s.missing.length) msg += ' ' + s.missing.length + ' item tidak ada lagi di library; salinannya di dokumen dipakai.';
        if (s.broken) msg += ' ' + s.broken + ' sitasi tanpa data dilewati.';
        if (s.storeSupported === false) msg += ' Editor ini tidak mendukung penyimpanan pengaturan dokumen; pengaturan disimpan di daftar pustaka.';
        setStatus(msg, s.offline || s.broken ? 'warn' : 'ok');
        renderMainInfoLater();
      }, function () {});
    }

    function renderMainInfoLater() {
      if (state.view === 'main') show('main', null, true);
    }

    // -------------------------------------------------------------------
    // Pencarian (dipakai dialog sitasi dan "tanpa disitasi")

    function searchBox(onPick, placeholder) {
      var input = h('input', { type: 'search', class: 'rp-input', placeholder: placeholder ||
        'Cari judul, pengarang, tahun, abstrak…', autocomplete: 'off', spellcheck: 'false' });
      var list = h('ul', { class: 'rp-results', role: 'listbox' });
      var results = [];
      var active = 0;
      var ctrl = null;
      var seq = 0;

      function render() {
        list.innerHTML = '';
        results.forEach(function (it, i) {
          var meta = [it.creators, it.year].filter(Boolean).join(' · ');
          var li = h('li', { class: 'rp-result' + (i === active ? ' rp-active' : ''), role: 'option',
            onmousedown: function (ev) { ev.preventDefault(); onPick(it); } }, [
            h('div', { class: 'rp-title', text: it.title || '(tanpa judul)' }),
            h('div', { class: 'rp-meta' }, [meta,
              it.annotationCount ? h('span', { class: 'rp-badge', title: 'Anotasi', text: it.annotationCount + ' anotasi' }) : null]),
          ]);
          list.appendChild(li);
        });
      }

      var run = debounce(function () {
        var q = input.value.trim();
        if (ctrl) ctrl.abort();
        ctrl = typeof AbortController !== 'undefined' ? new AbortController() : null;
        var my = ++seq;
        api.search(q, 25, ctrl && ctrl.signal).then(function (items) {
          if (my !== seq) return;
          results = items;
          active = 0;
          render();
          if (!items.length) list.appendChild(h('li', { class: 'rp-empty', text: q ? 'Tidak ada yang cocok.' : 'Library kosong.' }));
        }, function (e) {
          if (my !== seq || (e && e.code === 'aborted')) return;
          results = [];
          render();
          fail(e);
        });
      }, 120);

      input.addEventListener('input', run);
      input.addEventListener('keydown', function (ev) {
        if (ev.key === 'ArrowDown') { active = Math.min(active + 1, results.length - 1); render(); ev.preventDefault(); }
        else if (ev.key === 'ArrowUp') { active = Math.max(active - 1, 0); render(); ev.preventDefault(); }
        else if (ev.key === 'Enter' && !ev.ctrlKey && !ev.metaKey && results[active]) { onPick(results[active]); ev.preventDefault(); }
      });
      run();
      return { input: input, list: list, el: h('div', { class: 'rp-search' }, [input, list]) };
    }

    // -------------------------------------------------------------------
    // Dialog sitasi (sisipkan / sunting)

    function renderCite(editing) {
      var cluster = [];
      var noBib = false;
      var doc = null;
      var replaceId = null;
      if (editing) {
        doc = editing.doc;
        replaceId = editing.entry.citation.id;
        noBib = !!editing.entry.citation.noBib;
        editing.entry.citation.items.forEach(function (it) {
          cluster.push({ key: it.key, itemData: it.itemData, locator: it.locator, label: it.label || 'page',
            prefix: it.prefix, suffix: it.suffix, suppressAuthor: it.suppressAuthor,
            annotationKey: it.annotationKey, title: it.itemData.title, annotationCount: it.annotationKey ? 1 : null });
        });
      }

      var clusterEl = h('div', { class: 'rp-cluster' });
      var preview = h('div', { class: 'rp-preview' });
      var submit = h('button', { class: 'rp-btn rp-primary', text: editing ? 'Simpan perubahan' : 'Sisipkan',
        onclick: onSubmit });
      var noBibBox = h('input', { type: 'checkbox', checked: noBib, onchange: function () { noBib = noBibBox.checked; schedulePreview(); } });

      var search = searchBox(function (it) {
        if (cluster.some(function (c) { return c.key === it.key; })) {
          setStatus('Item itu sudah ada di sitasi ini.', 'info');
          return;
        }
        var entry = { key: it.key, title: it.title, creators: it.creators, year: it.year,
          annotationCount: it.annotationCount, label: 'page', loading: true };
        cluster.push(entry);
        renderCluster();
        ctl.fetchItem(it.key).then(function (data) {
          entry.itemData = data;
          entry.loading = false;
          renderCluster();
          schedulePreview();
        }, function (e) {
          cluster.splice(cluster.indexOf(entry), 1);
          renderCluster();
          fail(e);
        });
        search.input.select();
      });

      var view = h('div', { class: 'rp-cite' });
      main.appendChild(view);
      view.appendChild(h('h2', { class: 'rp-h', text: editing ? 'Sunting sitasi' : 'Sisipkan sitasi' }));
      view.appendChild(search.el);
      view.appendChild(clusterEl);
      view.appendChild(h('label', { class: 'rp-check' }, [noBibBox, ' Jangan masukkan ke daftar pustaka']));
      view.appendChild(preview);
      view.appendChild(h('div', { class: 'rp-row' }, [
        submit, h('button', { class: 'rp-btn', text: 'Batal', onclick: function () { show('main'); } }),
      ]));
      view.appendChild(h('p', { class: 'rp-hint', text: 'Enter menambah hasil yang disorot; Ctrl+Enter ' +
        (editing ? 'menyimpan.' : 'menyisipkan.') + ' Nomor sitasi lain dan daftar pustaka dirapikan lewat “Perbarui semua”.' }));
      setTimeout(function () { search.input.focus(); }, 0);
      view.addEventListener('keydown', function (ev) {
        if (ev.key === 'Enter' && (ev.ctrlKey || ev.metaKey)) { ev.preventDefault(); onSubmit(); }
        if (ev.key === 'Escape') show('main');
      });

      // Dokumen dan mesin disiapkan di latar sambil pengguna mengetik.
      var ready = (doc ? Promise.resolve(doc) : ctl.warm()).then(function (d) { doc = d; return d; });
      ready.catch(fail);

      function field(entry, name, labelText, attrs) {
        var input = h('input', Object.assign({ class: 'rp-input rp-small', value: entry[name] || '',
          oninput: function () { entry[name] = input.value; schedulePreview(); } }, attrs || {}));
        return h('label', { class: 'rp-field' }, [h('span', { text: labelText }), input]);
      }

      function renderCluster() {
        clusterEl.innerHTML = '';
        if (!cluster.length) {
          clusterEl.appendChild(h('p', { class: 'rp-hint', text: 'Pilih satu atau beberapa item dari hasil pencarian.' }));
          submit.disabled = true;
          return;
        }
        submit.disabled = cluster.some(function (c) { return c.loading; });
        cluster.forEach(function (entry, i) {
          var labelSel = h('select', { class: 'rp-input rp-small', onchange: function () { entry.label = labelSel.value; schedulePreview(); } },
            RP.LOCATOR_LABELS.map(function (l) { return h('option', { value: l[0], selected: l[0] === (entry.label || 'page'), text: l[1] }); }));
          var annBox = h('div', { class: 'rp-annotations' });
          var annBtn = h('button', { class: 'rp-link', text: entry.annotationKey ? 'Anotasi terpilih — ganti' : 'Pilih anotasi',
            onclick: function () { entry.annOpen = !entry.annOpen; loadAnnotations(entry, annBox); } });
          var sup = h('input', { type: 'checkbox', checked: !!entry.suppressAuthor,
            onchange: function () { entry.suppressAuthor = sup.checked; schedulePreview(); } });
          clusterEl.appendChild(h('div', { class: 'rp-item' }, [
            h('div', { class: 'rp-item-head' }, [
              h('div', { class: 'rp-title', text: (entry.loading ? '⏳ ' : '') + (entry.title || (entry.itemData && entry.itemData.title) || entry.key) }),
              h('button', { class: 'rp-x', title: 'Buang dari sitasi', 'aria-label': 'Buang', text: '×',
                onclick: function () { cluster.splice(i, 1); renderCluster(); schedulePreview(); } }),
            ]),
            h('div', { class: 'rp-grid' }, [
              h('label', { class: 'rp-field' }, [h('span', { text: 'Lokator' }), labelSel]),
              field(entry, 'locator', 'Nilai', { placeholder: 'mis. 12–14' }),
              field(entry, 'prefix', 'Prefiks', { placeholder: 'mis. lihat' }),
              field(entry, 'suffix', 'Sufiks'),
            ]),
            h('div', { class: 'rp-row' }, [
              h('label', { class: 'rp-check' }, [sup, ' Sembunyikan pengarang']),
              annBtn,
            ]),
            annBox,
          ]));
          if (entry.annOpen) loadAnnotations(entry, annBox);
        });
      }

      function closeAnnotations(entry, box) {
        entry.annOpen = false;
        box.innerHTML = '';
      }

      function loadAnnotations(entry, box) {
        box.innerHTML = '';
        if (!entry.annOpen) return;
        box.appendChild(h('p', { class: 'rp-hint', text: 'Memuat anotasi…' }));
        api.annotations(entry.key).then(function (anns) {
          if (!entry.annOpen) return;
          box.innerHTML = '';
          if (!anns.length) { box.appendChild(h('p', { class: 'rp-hint', text: 'Item ini belum punya anotasi.' })); return; }
          if (entry.annotationKey) {
            box.appendChild(h('button', { class: 'rp-link', text: 'Lepas anotasi', onclick: function () {
              entry.annotationKey = null; closeAnnotations(entry, box); renderCluster(); schedulePreview();
            } }));
          }
          anns.forEach(function (a) {
            var text = (a.text || a.comment || '(tanpa teks)').replace(/\s+/g, ' ');
            box.appendChild(h('button', { class: 'rp-ann' + (a.key === entry.annotationKey ? ' rp-active' : ''),
              onclick: function () {
                entry.annotationKey = a.key;
                if (a.pageLabel) { entry.locator = String(a.pageLabel); entry.label = 'page'; }
                closeAnnotations(entry, box);
                renderCluster();
                schedulePreview();
              } }, [
              h('span', { class: 'rp-swatch', style: 'background:' + (/^#[0-9a-fA-F]{3,8}$/.test(a.color || '') ? a.color : '#ccc') }),
              h('span', { class: 'rp-ann-page', text: a.pageLabel ? 'hlm. ' + a.pageLabel : '—' }),
              h('span', { class: 'rp-ann-text', text: text.length > 140 ? text.slice(0, 140) + '…' : text }),
            ]));
          });
        }, function (e) { closeAnnotations(entry, box); fail(e); });
      }

      function buildCitation() {
        var items = cluster.filter(function (c) { return c.itemData; }).map(function (c) {
          return { itemData: c.itemData, key: c.key, locator: c.locator, label: c.label, prefix: c.prefix,
            suffix: c.suffix, suppressAuthor: c.suppressAuthor, annotationKey: c.annotationKey };
        });
        if (!items.length) return null;
        if (editing) return RP.makeCitation(items, { id: replaceId, noBib: noBib });
        return ctl.newCitation(doc, items, noBib);
      }

      var schedulePreview = debounce(function () {
        ready.then(function () {
          var cit = buildCitation();
          preview.innerHTML = '';
          if (!cit) return;
          return ctl.preview(doc, cit, replaceId).then(function (out) {
            preview.innerHTML = '';
            preview.appendChild(h('span', { class: 'rp-preview-label', text: 'Pratinjau: ' }));
            (out ? runsToNodes(out.runs) : [document.createTextNode('—')]).forEach(function (n) { preview.appendChild(n); });
          });
        }).catch(fail);
      }, 200);

      function onSubmit() {
        if (state.busy || submit.disabled) return;
        var cit;
        ready.then(function () {
          cit = buildCitation();
          if (!cit) throw new Error('Pilih minimal satu item.');
          return busy(editing ? ctl.updateCitation(editing.entry, cit) : ctl.insertCitation(cit),
            editing ? 'Menyimpan…' : 'Menyisipkan…');
        }).then(function (r) {
          show('main');
          setStatus((editing ? 'Sitasi diperbarui: ' : 'Sitasi disisipkan: ') + r.text, 'ok');
        }).catch(fail);
      }

      renderCluster();
      if (editing) schedulePreview();
    }

    // -------------------------------------------------------------------
    // Gaya

    function renderStyles() {
      var list = h('div', { class: 'rp-styles', text: 'Memuat daftar gaya…' });
      var locale = h('select', { class: 'rp-input' }, [
        h('option', { value: 'id-ID', text: 'Bahasa Indonesia (id-ID)' }),
        h('option', { value: 'en-US', text: 'English (en-US)' }),
      ]);
      var chosen = null;
      main.appendChild(h('h2', { class: 'rp-h', text: 'Gaya sitasi' }));
      main.appendChild(list);
      main.appendChild(h('label', { class: 'rp-field' }, [h('span', { text: 'Bahasa sitasi' }), locale]));
      main.appendChild(h('p', { class: 'rp-hint', text: 'Gaya yang menetapkan bahasanya sendiri (mis. AMA) tetap memakai bahasa itu, sama seperti Zotero.' }));
      var apply = h('button', { class: 'rp-btn rp-primary', text: 'Terapkan dan perbarui semua', onclick: function () {
        if (!chosen) return;
        busy(ctl.setStyle(chosen, locale.value), 'Menerapkan gaya…').then(function (s) {
          show('main');
          setStatus('Gaya diganti; ' + s.citations + ' sitasi diperbarui.', 'ok');
        }, function () {});
      } });
      main.appendChild(h('div', { class: 'rp-row' }, [apply,
        h('button', { class: 'rp-btn', text: 'Batal', onclick: function () { show('main'); } })]));

      Promise.all([ctl.loadDocument(), api.styles().catch(function (e) {
        var cached = api.cachedStyles();
        if (!cached.length) throw e;
        setStatus('ReadPaper tidak terhubung; daftar gaya diambil dari cache.', 'warn');
        return cached;
      })]).then(function (r) {
        var doc = r[0];
        var styles = r[1];
        chosen = doc.settings.style;
        locale.value = doc.settings.locale;
        list.innerHTML = '';
        styles.forEach(function (s) {
          var radio = h('input', { type: 'radio', name: 'rp-style', value: s.id, checked: s.id === chosen,
            onchange: function () { chosen = s.id; } });
          var kind = s.format === 'numeric' ? 'bernomor' : s.format === 'author-date' ? 'pengarang-tahun' :
            s.format === 'author' ? 'pengarang' : s.format === 'note' ? 'catatan' : (s.format || '');
          list.appendChild(h('label', { class: 'rp-style' }, [radio, h('span', {}, [
            h('span', { class: 'rp-title', text: s.title || s.id }),
            h('span', { class: 'rp-meta', text: ' ' + kind + (s.parent ? ' · memakai aturan ' + s.parent : '') }),
          ])]));
        });
      }, function (e) { list.textContent = ''; fail(e); });
    }

    // -------------------------------------------------------------------
    // Tanpa disitasi

    function renderUncited() {
      var listEl = h('ul', { class: 'rp-uncited' });
      main.appendChild(h('h2', { class: 'rp-h', text: 'Masuk daftar pustaka tanpa disitasi' }));
      main.appendChild(listEl);
      main.appendChild(h('p', { class: 'rp-hint', text: 'Tambahkan item yang harus muncul di daftar pustaka walau tidak disitasi di teks. Catatannya disimpan di dokumen.' }));
      var search = searchBox(function (it) {
        busy(ctl.fetchItem(it.key).then(function (data) { return ctl.addUncited(data); }), 'Menambahkan…').then(function () {
          setStatus('Ditambahkan: ' + (it.title || it.key), 'ok');
          refresh();
        }, function () {});
      }, 'Cari item untuk ditambahkan…');
      main.appendChild(search.el);

      function refresh() {
        ctl.loadDocument().then(function (doc) {
          listEl.innerHTML = '';
          if (!doc.settings.uncited.length) listEl.appendChild(h('li', { class: 'rp-empty', text: 'Belum ada.' }));
          doc.settings.uncited.forEach(function (u) {
            listEl.appendChild(h('li', { class: 'rp-row rp-between' }, [
              h('span', { text: RP.describeItem(u.itemData) }),
              h('button', { class: 'rp-link', text: 'Keluarkan', onclick: function () {
                busy(ctl.removeUncited(u.key), 'Mengeluarkan…').then(function () {
                  setStatus('Dikeluarkan dari daftar pustaka.', 'ok');
                  refresh();
                }, function () {});
              } }),
            ]));
          });
        }, fail);
      }
      refresh();
    }

    // -------------------------------------------------------------------
    // Token

    function renderToken() {
      var input = h('input', { type: 'password', class: 'rp-input', value: api.getToken(), autocomplete: 'off',
        placeholder: 'Tempel token di sini', spellcheck: 'false' });
      var showBox = h('input', { type: 'checkbox', onchange: function () { input.type = showBox.checked ? 'text' : 'password'; } });
      main.appendChild(h('h2', { class: 'rp-h', text: 'Sambungkan ke ReadPaper' }));
      main.appendChild(h('ol', { class: 'rp-steps' }, [
        h('li', { text: 'Buka ReadPaper desktop (Linux, Windows, atau macOS).' }),
        h('li', { text: 'Buka Pengaturan ReadPaper di desktop, kartu "Sitasi di Word & OnlyOffice", lalu salin tokennya.' }),
        h('li', { text: 'Tempel di bawah, lalu Simpan.' }),
      ]));
      main.appendChild(input);
      main.appendChild(h('label', { class: 'rp-check' }, [showBox, ' Tampilkan token']));
      main.appendChild(h('div', { class: 'rp-row' }, [
        h('button', { class: 'rp-btn rp-primary', text: 'Simpan dan periksa', onclick: function () {
          api.setToken(input.value);
          busy(checkConnection(false), 'Memeriksa…').then(function (c) {
            if (c.ok) { show('main'); setStatus('Terhubung ke ReadPaper' + (c.ping.library ? ' — ' + c.ping.library : '') + '.', 'ok'); }
            else setStatus(c.error, 'error');
          }, function () {});
        } }),
        h('button', { class: 'rp-btn', text: 'Kembali', onclick: function () { show('main'); } }),
      ]));
      main.appendChild(h('p', { class: 'rp-hint', text: 'Token disimpan di add-in ini saja, di komputer ini. ' +
        'ReadPaper hanya menerima koneksi dari komputer yang sama (127.0.0.1:23121).' }));
      setTimeout(function () { input.focus(); }, 0);
    }

    // -------------------------------------------------------------------
    // Jadikan teks biasa

    function renderConvert() {
      main.appendChild(h('h2', { class: 'rp-h', text: 'Jadikan teks biasa' }));
      main.appendChild(h('p', { text: 'Semua sitasi dan daftar pustaka ReadPaper di dokumen ini menjadi teks biasa. ' +
        'Teksnya tetap, tetapi sitasi tidak bisa lagi disunting atau diperbarui, dan data sitasi yang tersimpan di dokumen dihapus.' }));
      main.appendChild(h('p', { class: 'rp-hint', text: 'Biasanya dilakukan pada salinan akhir sebelum dikirim. Simpan salinan dokumen yang masih bersitasi bila nanti perlu disunting.' }));
      main.appendChild(h('div', { class: 'rp-row' }, [
        h('button', { class: 'rp-btn rp-danger', text: 'Ya, jadikan teks biasa', onclick: function () {
          busy(ctl.convertToText(), 'Mengubah…').then(function (r) {
            show('main');
            setStatus(r.removed + ' content control diubah menjadi teks biasa.', 'ok');
          }, function () {});
        } }),
        h('button', { class: 'rp-btn', text: 'Batal', onclick: function () { show('main'); } }),
      ]));
    }

    // -------------------------------------------------------------------

    show('main');
    checkConnection(false).then(function (c) {
      if (!c.ok && (c.code === 'notoken' || !api.hasToken())) show('token');
      else if (!c.ok) setStatus(c.error, 'error');
    });
    // Panaskan mesin citeproc di latar.
    ctl.warm().catch(function () { /* galat ditampilkan saat perintah dipakai */ });

    return {
      show: show,
      setStatus: setStatus,
      setTheme: function (dark) { container.classList.toggle('rp-dark', !!dark); },
    };
  }

  root.ReadPaperUI = { mount: mount, runsToNodes: runsToNodes };
})(typeof self !== 'undefined' ? self : this);
