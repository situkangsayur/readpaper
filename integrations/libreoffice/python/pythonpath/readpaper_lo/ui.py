# Menu, dialog, dan pesan ReadPaper di LibreOffice Writer.
#
# Dialognya dibangun dengan UNO AWT langsung — tanpa berkas .xdl dan tanpa
# Basic — supaya muncul seketika (aturan 2: dialog sitasi siap diketik dalam
# sepersekian detik). Pencarian berjalan sambil mengetik ke server lokal
# ReadPaper, yang menjawab dalam hitungan milidetik.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import os

import uno
import unohelper
from com.sun.star.awt import XActionListener, XItemListener, XTextListener, XMouseListener

from . import api as rp_api
from . import commands

LABELS = [
    ('page', 'Halaman'), ('chapter', 'Bab'), ('section', 'Bagian'), ('paragraph', 'Paragraf'),
    ('figure', 'Gambar'), ('table', 'Tabel'), ('line', 'Baris'), ('volume', 'Volume'),
    ('issue', 'Nomor terbitan'), ('appendix', 'Lampiran'), ('equation', 'Persamaan'),
    ('note', 'Catatan'), ('column', 'Kolom'), ('verse', 'Ayat'), ('algorithm', 'Algoritma'),
]
LOCALES = [('id-ID', 'Bahasa Indonesia'), ('en-US', 'English (US)')]


# ----------------------------------------------------------------- dasar


def _smgr(ctx):
    return ctx.ServiceManager


def _create(ctx, name):
    return _smgr(ctx).createInstanceWithContext(name, ctx)


def _user_dir(ctx):
    subst = _create(ctx, 'com.sun.star.util.PathSubstitution')
    return uno.fileUrlToSystemPath(subst.substituteVariables('$(user)', True))


def client(ctx):
    """Pemanggil ReadPaper. Token: yang disimpan lewat ReadPaper → Token…
    (di profil LibreOffice), atau otomatis dari ReadPaper di komputer ini."""
    return rp_api.Client(token_file=os.path.join(_user_dir(ctx), 'readpaper', 'token'))


def _window(ctx):
    desktop = _create(ctx, 'com.sun.star.frame.Desktop')
    frame = desktop.CurrentFrame
    return frame.ContainerWindow if frame else None


def message(ctx, text, title='ReadPaper', kind='infobox'):
    toolkit = _create(ctx, 'com.sun.star.awt.Toolkit')
    parent = _window(ctx)
    from com.sun.star.awt.MessageBoxType import INFOBOX, ERRORBOX, QUERYBOX
    from com.sun.star.awt.MessageBoxButtons import BUTTONS_OK, BUTTONS_OK_CANCEL
    box_type = {'infobox': INFOBOX, 'errorbox': ERRORBOX, 'querybox': QUERYBOX}[kind]
    buttons = BUTTONS_OK_CANCEL if kind == 'querybox' else BUTTONS_OK
    box = toolkit.createMessageBox(parent, box_type, buttons, title, text)
    try:
        return box.execute()
    finally:
        box.dispose()


def error(ctx, e):
    message(ctx, str(e), 'ReadPaper', 'errorbox')


class _Listener(unohelper.Base, XActionListener, XItemListener, XTextListener, XMouseListener):
    def __init__(self, on_action=None, on_item=None, on_text=None, on_double=None):
        self.on_action, self.on_item, self.on_text, self.on_double = on_action, on_item, on_text, on_double

    def actionPerformed(self, ev):
        if self.on_action:
            self.on_action(ev)

    def itemStateChanged(self, ev):
        if self.on_item:
            self.on_item(ev)

    def textChanged(self, ev):
        if self.on_text:
            self.on_text(ev)

    def mousePressed(self, ev):
        if self.on_double and ev.ClickCount == 2:
            self.on_double(ev)

    def mouseReleased(self, ev):
        pass

    def mouseEntered(self, ev):
        pass

    def mouseExited(self, ev):
        pass

    def disposing(self, ev):
        pass


class Dialog:
    """Dialog UNO kecil; ukuran dalam satuan AppFont seperti dialog Basic."""

    def __init__(self, ctx, title, width, height):
        self.ctx = ctx
        self.model = _create(ctx, 'com.sun.star.awt.UnoControlDialogModel')
        self.model.Title = title
        self.model.Width = width
        self.model.Height = height
        self.dialog = _create(ctx, 'com.sun.star.awt.UnoControlDialog')
        self.dialog.setModel(self.model)
        self._listeners = []

    def add(self, kind, name, x, y, w, h, **props):
        m = self.model.createInstance('com.sun.star.awt.UnoControl%sModel' % kind)
        m.PositionX, m.PositionY, m.Width, m.Height = x, y, w, h
        for k, v in props.items():
            setattr(m, k, v)
        self.model.insertByName(name, m)
        return self.dialog.getControl(name)

    def label(self, name, x, y, w, text, h=10):
        return self.add('FixedText', name, x, y, w, h, Label=text)

    def button(self, name, x, y, w, text, on=None, kind=0, default=False, h=14):
        c = self.add('Button', name, x, y, w, h, Label=text, PushButtonType=kind, DefaultButton=default)
        if on:
            lst = _Listener(on_action=lambda ev: on())
            self._listeners.append(lst)
            c.addActionListener(lst)
        return c

    def edit(self, name, x, y, w, text='', on_change=None, h=13):
        c = self.add('Edit', name, x, y, w, h, Text=text)
        if on_change:
            lst = _Listener(on_text=lambda ev: on_change(c.Text))
            self._listeners.append(lst)
            c.addTextListener(lst)
        return c

    def listbox(self, name, x, y, w, h, items=(), on_select=None, on_double=None, dropdown=False):
        c = self.add('ListBox', name, x, y, w, h, Dropdown=dropdown)
        c.Model.StringItemList = tuple(items)
        if on_select:
            lst = _Listener(on_item=lambda ev: on_select(c.SelectedItemPos))
            self._listeners.append(lst)
            c.addItemListener(lst)
        if on_double:
            lst = _Listener(on_double=lambda ev: on_double(c.SelectedItemPos))
            self._listeners.append(lst)
            c.addMouseListener(lst)
        return c

    def checkbox(self, name, x, y, w, text, state=False, on_change=None, h=10):
        c = self.add('CheckBox', name, x, y, w, h, Label=text, State=1 if state else 0)
        if on_change:
            lst = _Listener(on_item=lambda ev: on_change(c.State == 1))
            self._listeners.append(lst)
            c.addItemListener(lst)
        return c

    def execute(self, focus=None):
        toolkit = _create(self.ctx, 'com.sun.star.awt.Toolkit')
        self.dialog.createPeer(toolkit, _window(self.ctx))
        if focus is not None:
            # Langsung bisa diketik, tanpa harus mengklik kotaknya dulu.
            focus.setFocus()
        try:
            return self.dialog.execute()
        finally:
            self.dialog.dispose()

    def end(self, result):
        self.dialog.endDialog(result)


def _pick(listbox, index):
    """Memilih baris lewat modelnya: dipanggil sebelum dialog tampil, saat
    kontrolnya belum punya jendela dan selectItemPos diabaikan."""
    listbox.Model.SelectedItems = (int(index),) if index >= 0 else ()


def _short(s, n):
    s = ' '.join(str(s or '').split())
    return s if len(s) <= n else s[:n - 1] + '…'


def _describe(it):
    who = it.get('creators') or ''
    year = it.get('year') or ''
    head = ', '.join(x for x in (who, year) if x)
    return '%s — %s' % (_short(it.get('title') or it.get('key'), 70), head) if head else _short(it.get('title'), 90)


# ------------------------------------------------------------ dialog sitasi


class CitationDialog:
    """Sisipkan atau sunting satu sitasi: cari, pilih beberapa item, lokator,
    prefiks/sufiks, sembunyikan pengarang, atau pilih anotasi ReadPaper."""

    def __init__(self, ctx, api, current=None):
        self.ctx = ctx
        self.api = api
        self.results = []
        self.items = [dict(i) for i in (current or {}).get('items', [])]
        self.no_bib = bool((current or {}).get('noBib'))
        self.editing = current is not None
        self.sel = 0 if self.items else -1
        self._loading = False

    def run(self):
        d = Dialog(self.ctx, 'Sunting sitasi ReadPaper' if self.editing else 'Sisipkan sitasi ReadPaper', 300, 262)
        self.d = d
        d.label('lq', 6, 6, 288, 'Cari di library ReadPaper — judul, pengarang, tahun, atau abstrak:')
        self.q = d.edit('q', 6, 17, 288, on_change=self._search)
        self.res = d.listbox('res', 6, 33, 288, 64, on_double=lambda i: self._add())
        d.button('add', 6, 100, 90, 'Tambahkan ke sitasi ↓', on=self._add)
        self.status = d.label('status', 100, 103, 194, '')
        d.label('lc', 6, 120, 288, 'Dalam sitasi ini (beberapa item boleh):')
        self.chosen = d.listbox('chosen', 6, 131, 214, 38, on_select=self._select)
        d.button('up', 224, 131, 34, 'Naik', on=lambda: self._move(-1))
        d.button('down', 260, 131, 34, 'Turun', on=lambda: self._move(1))
        d.button('remove', 224, 155, 70, 'Keluarkan', on=self._remove)
        d.label('ll', 6, 175, 60, 'Lokator:')
        self.label_box = d.listbox('label', 6, 185, 70, 13, [n for _, n in LABELS], dropdown=True,
                                   on_select=lambda i: self._set('label', LABELS[i][0] if i >= 0 else 'page'))
        self.locator = d.edit('locator', 80, 185, 50, on_change=lambda t: self._set('locator', t))
        d.button('annot', 134, 185, 80, 'Pilih anotasi…', on=self._annotations)
        self.suppress = d.checkbox('suppress', 218, 187, 80, 'Sembunyikan pengarang',
                                   on_change=lambda v: self._set('suppressAuthor', v))
        d.label('lp', 6, 203, 60, 'Prefiks:')
        self.prefix = d.edit('prefix', 6, 213, 140, on_change=lambda t: self._set('prefix', t))
        d.label('ls', 154, 203, 60, 'Sufiks:')
        self.suffix = d.edit('suffix', 154, 213, 140, on_change=lambda t: self._set('suffix', t))
        self.nobib = d.checkbox('nobib', 6, 231, 288, 'Jangan masukkan item sitasi ini ke daftar pustaka',
                                state=self.no_bib)
        d.button('ok', 182, 244, 56, 'Simpan' if self.editing else 'Sisipkan', kind=1, default=True)
        d.button('cancel', 242, 244, 52, 'Batal', kind=2)
        self._refresh_chosen()
        self._search('')
        if d.execute(focus=self.q) != 1 or not self.items:
            return None
        return {
            'items': [{k: it.get(k) for k in ('key', 'locator', 'label', 'prefix', 'suffix',
                                              'suppressAuthor', 'annotationKey')} for it in self.items],
            'noBib': self.nobib.State == 1,
        }

    def _search(self, q):
        try:
            self.results = self.api.search(q, 25)
            self.status.Text = '' if self.results else 'Tidak ada yang cocok.'
        except rp_api.ApiError as e:
            self.results = []
            self.status.Text = _short(str(e), 80)
        self.res.Model.StringItemList = tuple(_describe(r) for r in self.results)
        if self.results:
            _pick(self.res, 0)

    def _add(self):
        i = self.res.SelectedItemPos
        if i < 0 or i >= len(self.results):
            return
        r = self.results[i]
        if any(it['key'] == r['key'] for it in self.items):
            return
        self.items.append({'key': r['key'], 'title': r.get('title'), 'creators': r.get('creators'),
                           'year': r.get('year'), 'locator': '', 'label': 'page', 'prefix': '',
                           'suffix': '', 'suppressAuthor': False, 'annotationKey': ''})
        self.sel = len(self.items) - 1
        self._refresh_chosen()

    def _remove(self):
        if 0 <= self.sel < len(self.items):
            del self.items[self.sel]
            self.sel = min(self.sel, len(self.items) - 1)
            self._refresh_chosen()

    def _move(self, delta):
        j = self.sel + delta
        if 0 <= self.sel < len(self.items) and 0 <= j < len(self.items):
            self.items[self.sel], self.items[j] = self.items[j], self.items[self.sel]
            self.sel = j
            self._refresh_chosen()

    def _refresh_chosen(self):
        def line(it):
            loc = (' · %s %s' % (dict(LABELS).get(it.get('label') or 'page', ''), it['locator'])) if it.get('locator') else ''
            return _describe(it) + loc
        self.chosen.Model.StringItemList = tuple(line(it) for it in self.items)
        if 0 <= self.sel < len(self.items):
            _pick(self.chosen, self.sel)
        self._select(self.sel)

    def _select(self, i):
        self.sel = i
        it = self.items[i] if 0 <= i < len(self.items) else None
        self._loading = True
        try:
            for c in (self.locator, self.prefix, self.suffix, self.label_box, self.suppress):
                c.Model.Enabled = it is not None
            if it is None:
                return
            self.locator.Text = it.get('locator') or ''
            self.prefix.Text = it.get('prefix') or ''
            self.suffix.Text = it.get('suffix') or ''
            keys = [k for k, _ in LABELS]
            lab = it.get('label') or 'page'
            _pick(self.label_box, keys.index(lab) if lab in keys else 0)
            self.suppress.State = 1 if it.get('suppressAuthor') else 0
        finally:
            self._loading = False

    def _set(self, key, value):
        if self._loading or not (0 <= self.sel < len(self.items)):
            return
        it = self.items[self.sel]
        it[key] = value
        if key == 'locator' and it.get('annotationKey'):
            # Lokator diketik ulang: tidak lagi menunjuk anotasi tertentu.
            it['annotationKey'] = ''

    def _annotations(self):
        if not (0 <= self.sel < len(self.items)):
            return
        it = self.items[self.sel]
        try:
            anns = self.api.annotations(it['key'])
        except rp_api.ApiError as e:
            error(self.ctx, e)
            return
        if not anns:
            message(self.ctx, 'Item ini belum punya anotasi di ReadPaper.')
            return
        d = Dialog(self.ctx, 'Pilih anotasi sebagai penanda', 260, 170)
        rows = ['hlm. %s — %s' % (a.get('pageLabel') or '?', _short(a.get('text') or a.get('comment') or a.get('type'), 70))
                for a in anns]
        box = d.listbox('anns', 6, 6, 248, 136, rows, on_double=lambda i: d.end(1))
        _pick(box, 0)
        d.button('ok', 142, 150, 56, 'Pakai', kind=1, default=True)
        d.button('cancel', 202, 150, 52, 'Batal', kind=2)
        if d.execute() != 1:
            return
        i = box.SelectedItemPos
        if i < 0:
            return
        a = anns[i]
        it['label'] = 'page'
        it['locator'] = a.get('pageLabel') or ''
        it['annotationKey'] = a.get('key') or ''
        self._refresh_chosen()


# ------------------------------------------------------------- perintah


def _writer(ctx):
    doc = _create(ctx, 'com.sun.star.frame.Desktop').CurrentComponent
    if not commands.is_writer(doc):
        message(ctx, 'Sitasi ReadPaper hanya tersedia di dokumen Writer.')
        return None
    return doc


def cite(ctx):
    doc = _writer(ctx)
    if doc is None:
        return
    api = client(ctx)
    try:
        st = commands.state(api, doc)
        args = CitationDialog(ctx, api, st.get('current')).run()
        if args is None:
            return
        commands.run(api, doc, 'update' if st.get('current') else 'insert', args)
    except rp_api.ApiError as e:
        error(ctx, e)


def bibliography(ctx):
    doc = _writer(ctx)
    if doc is None:
        return
    try:
        commands.run(client(ctx), doc, 'bibliography')
    except rp_api.ApiError as e:
        error(ctx, e)


def refresh(ctx):
    doc = _writer(ctx)
    if doc is None:
        return
    try:
        s = commands.run(client(ctx), doc, 'refresh')
    except rp_api.ApiError as e:
        error(ctx, e)
        return
    lines = ['%d sitasi dan %d daftar pustaka diperbarui.' % (s.get('citations', 0), s.get('bibliographies', 0))]
    if s.get('broken'):
        lines.append('%d sitasi tidak terbaca dan dibiarkan apa adanya.' % s['broken'])
    if s.get('missing'):
        lines.append('Tidak ada lagi di library ReadPaper (memakai data di dokumen): ' + ', '.join(s['missing']))
    message(ctx, '\n'.join(lines))


def style(ctx):
    doc = _writer(ctx)
    if doc is None:
        return
    api = client(ctx)
    try:
        styles = api.styles()
        st = commands.state(api, doc)
    except rp_api.ApiError as e:
        error(ctx, e)
        return
    d = Dialog(ctx, 'Gaya sitasi', 260, 190)
    d.label('l1', 6, 6, 248, 'Gaya (dari ReadPaper):')
    box = d.listbox('styles', 6, 17, 248, 120, [s['title'] for s in styles])
    ids = [s['id'] for s in styles]
    _pick(box, ids.index(st['style']) if st.get('style') in ids else 0)
    d.label('l2', 6, 142, 100, 'Bahasa istilah ("dkk.", "hlm."):')
    loc = d.listbox('locale', 6, 153, 120, 13, [n for _, n in LOCALES], dropdown=True)
    codes = [c for c, _ in LOCALES]
    _pick(loc, codes.index(st['locale']) if st.get('locale') in codes else 0)
    d.button('ok', 142, 172, 56, 'Terapkan', kind=1, default=True)
    d.button('cancel', 202, 172, 52, 'Batal', kind=2)
    if d.execute() != 1 or box.SelectedItemPos < 0:
        return
    try:
        commands.run(api, doc, 'setStyle', {'style': ids[box.SelectedItemPos],
                                            'locale': codes[max(0, loc.SelectedItemPos)]})
    except rp_api.ApiError as e:
        error(ctx, e)


def uncited(ctx):
    doc = _writer(ctx)
    if doc is None:
        return
    api = client(ctx)
    state = {'results': [], 'uncited': []}
    d = Dialog(ctx, 'Masuk daftar pustaka tanpa disitasi', 300, 230)

    def reload_list():
        try:
            state['uncited'] = commands.state(api, doc).get('uncited', [])
        except rp_api.ApiError as e:
            error(ctx, e)
        current.Model.StringItemList = tuple(_describe(u) for u in state['uncited']) or ('(belum ada)',)

    def search(q):
        try:
            state['results'] = api.search(q, 25)
        except rp_api.ApiError as e:
            state['results'] = []
            status.Text = _short(str(e), 80)
        res.Model.StringItemList = tuple(_describe(r) for r in state['results'])

    def add():
        i = res.SelectedItemPos
        if 0 <= i < len(state['results']):
            try:
                commands.run(api, doc, 'addUncited', {'key': state['results'][i]['key']})
            except rp_api.ApiError as e:
                error(ctx, e)
            reload_list()

    def remove():
        i = current.SelectedItemPos
        if 0 <= i < len(state['uncited']):
            try:
                commands.run(api, doc, 'removeUncited', {'key': state['uncited'][i]['key']})
            except rp_api.ApiError as e:
                error(ctx, e)
            reload_list()

    d.label('l1', 6, 6, 288, 'Sudah masuk daftar pustaka tanpa disitasi:')
    current = d.listbox('current', 6, 17, 288, 56)
    d.button('remove', 6, 76, 90, 'Keluarkan', on=remove)
    d.label('l2', 6, 98, 288, 'Tambah dari library ReadPaper:')
    d.edit('q', 6, 109, 288, on_change=search)
    res = d.listbox('res', 6, 125, 288, 70, on_double=lambda i: add())
    d.button('add', 6, 198, 90, 'Tambahkan', on=add)
    status = d.label('status', 100, 201, 194, '')
    d.button('close', 242, 212, 52, 'Tutup', kind=1, default=True)
    reload_list()
    search('')
    d.execute()


def plain(ctx):
    doc = _writer(ctx)
    if doc is None:
        return
    ok = message(ctx, 'Semua sitasi dan daftar pustaka ReadPaper di dokumen ini dijadikan teks biasa. '
                      'Teksnya tetap, tetapi tidak bisa diperbarui lagi. Lanjutkan?', 'ReadPaper', 'querybox')
    if ok != 1:
        return
    try:
        r = commands.run(client(ctx), doc, 'convertToText')
        message(ctx, '%d penanda ReadPaper dilepas.' % r.get('removed', 0))
    except rp_api.ApiError as e:
        error(ctx, e)


def token(ctx):
    c = client(ctx)
    d = Dialog(ctx, 'Token ReadPaper', 260, 92)
    d.label('l1', 6, 6, 248, 'Salin token dari Pengaturan ReadPaper → Sitasi di Word & OnlyOffice.', h=20)
    d.label('l2', 6, 26, 248, 'Kosongkan untuk memakai token ReadPaper di komputer ini secara otomatis.', h=20)
    e = d.edit('token', 6, 48, 248, c._saved_token() or '')
    d.button('ok', 142, 72, 56, 'Simpan', kind=1, default=True)
    d.button('cancel', 202, 72, 52, 'Batal', kind=2)
    if d.execute() != 1:
        return
    c.save_token(e.Text)
    try:
        c.search('', 1)
        message(ctx, 'Tersambung ke ReadPaper.')
    except rp_api.ApiError as err:
        error(ctx, err)


COMMANDS = {
    'cite': cite, 'bibliography': bibliography, 'refresh': refresh, 'style': style,
    'uncited': uncited, 'plain': plain, 'token': token,
}


def dispatch(ctx, name):
    fn = COMMANDS.get(name)
    if fn is None:
        message(ctx, 'Perintah ReadPaper tidak dikenal: %s' % name)
        return
    try:
        fn(ctx)
    except Exception as e:  # jangan sampai galat Python diam-diam hilang
        error(ctx, 'Galat di ekstensi ReadPaper: %s' % e)
