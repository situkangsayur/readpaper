# Lapisan dokumen LibreOffice Writer untuk sitasi ReadPaper.
#
# Bentuk data di dokumen sengaja sama dengan OnlyOffice, supaya .docx dan .odt
# bisa berpindah editor:
#   - sitasi: content control inline (LibreOffice 7.6+) bertag
#     READPAPER_CITATION_v1:<base64 JSON>, berisi seluruh data sitasinya;
#   - daftar pustaka: bookmark READPAPER_BIBLIOGRAPHY_v1 yang membentang di
#     paragraf-paragrafnya. LibreOffice tidak punya content control blok, dan
#     section berubah jadi pemisah section (ganti halaman) saat disimpan
#     sebagai .docx. Daftar pustaka buatan Word/OnlyOffice — content control
#     blok yang oleh LibreOffice dibuka sebagai content control inline di
#     paragraf pertamanya — tetap dikenali dan diubah ke bentuk bookmark saat
#     ditulis ulang;
#   - pengaturan dokumen dan salinan gaya/locale: properti dokumen
#     ReadPaperCitations (ikut tersimpan di .odt dan di docProps/custom.xml).
#
# Tidak ada keputusan sitasi di sini — nomor, teks, isi daftar pustaka semua
# datang dari ReadPaper (integrations/core/host.js). Berkas ini hanya
# memotret dokumen dan menulis kembali perubahan yang diminta.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import uno
from com.sun.star.text.ControlCharacter import PARAGRAPH_BREAK

CITATION_PREFIX = 'READPAPER_CITATION_v1'
BIBLIOGRAPHY_TAG = 'READPAPER_BIBLIOGRAPHY_v1'
PENDING_TAG = 'READPAPER_PENDING'
STORE_PROPERTY = 'ReadPaperCitations'
PLACEHOLDER = '[…]'

_ITALIC = uno.Enum('com.sun.star.awt.FontSlant', 'ITALIC')
_UPRIGHT = uno.Enum('com.sun.star.awt.FontSlant', 'NONE')


def _units(s):
    """Panjang dalam satuan UTF-16 — satuan yang dipakai goLeft/goRight."""
    return len(s.encode('utf-16-le')) // 2


def is_citation_tag(tag):
    return bool(tag) and (tag.startswith(CITATION_PREFIX + ':') or tag.startswith(CITATION_PREFIX + '#'))


def is_bibliography_tag(tag):
    return bool(tag) and tag.startswith(BIBLIOGRAPHY_TAG)


class Citation:
    def __init__(self, handle, cc):
        self.handle = handle
        self.cc = cc

    @property
    def tag(self):
        return self.cc.Tag


class Bibliography:
    """Satu daftar pustaka: bookmark ReadPaper, atau daftar pustaka Word yang
    dibuka LibreOffice (content control di paragraf pertama + paragraf-
    paragraf sesudahnya sampai penanda akhir SDT)."""

    def __init__(self, handle, tag, bookmark=None, cc=None, paragraphs=None):
        self.handle = handle
        self.tag = tag
        self.bookmark = bookmark
        self.cc = cc
        self.paragraphs = paragraphs or []


class WriterDocument:
    def __init__(self, doc):
        self.doc = doc
        self.citations = []
        self.bibliographies = []
        self.pending = None
        self._handles = {}

    # ------------------------------------------------------------------ baca

    def scan(self):
        """Memindai seluruh dokumen. Dipanggil di awal SETIAP perintah —
        daftar pustaka diturunkan dari dokumen, tidak pernah diingat."""
        self.citations = []
        self.bibliographies = []
        self.emptied = []
        self.pending = None
        self.pending_index = 0
        self._handles = {}
        self._walk(self.doc.Text)
        bookmarks = self.doc.Bookmarks
        for name in bookmarks.ElementNames:
            if name.startswith(BIBLIOGRAPHY_TAG):
                b = Bibliography('bm:' + name, BIBLIOGRAPHY_TAG, bookmark=bookmarks.getByName(name))
                self.bibliographies.append(b)
                self._handles[b.handle] = b
        return self

    def _walk(self, text):
        enum = text.createEnumeration()
        word_bib = None
        while enum.hasMoreElements():
            el = enum.nextElement()
            if el.supportsService('com.sun.star.text.TextTable'):
                word_bib = None
                for name in el.CellNames:
                    self._walk(el.getCellByName(name))
                continue
            if not el.supportsService('com.sun.star.text.Paragraph'):
                continue
            if word_bib is not None:
                if self._sdt_end_before(el):
                    word_bib = None
                else:
                    word_bib.paragraphs.append(el)
            portions = el.createEnumeration()
            while portions.hasMoreElements():
                por = portions.nextElement()
                if por.TextPortionType != 'ContentControl':
                    continue
                cc = por.ContentControl
                tag = cc.Tag or ''
                if tag == PENDING_TAG:
                    self.pending = Citation('pending', cc)
                    # Pemindaian berjalan sesuai urutan dokumen.
                    self.pending_index = len(self.citations)
                elif is_citation_tag(tag):
                    if not (cc.String or '').strip():
                        # Teksnya sudah dihapus penulis tetapi wadahnya
                        # tertinggal (LibreOffice membiarkan content control
                        # kosong). Itu sitasi yang dihapus, bukan sitasi:
                        # menghitungnya berarti referensinya bertahan di
                        # daftar pustaka — persis bug Zotero yang dihindari.
                        self.emptied.append(cc)
                        continue
                    c = Citation('cc%d' % len(self.citations), cc)
                    self.citations.append(c)
                    self._handles[c.handle] = c
                elif is_bibliography_tag(tag) and word_bib is None:
                    word_bib = Bibliography('wb%d' % len(self.bibliographies), tag, cc=cc, paragraphs=[el])
                    self.bibliographies.append(word_bib)
                    self._handles[word_bib.handle] = word_bib

    @staticmethod
    def _sdt_end_before(paragraph):
        try:
            for p in paragraph.ParaInteropGrabBag:
                if p.Name == 'ParaSdtEndBefore' and p.Value:
                    return True
        except Exception:
            pass
        return False

    def read_store(self):
        props = self.doc.DocumentProperties.UserDefinedProperties
        try:
            v = props.getPropertyValue(STORE_PROPERTY)
        except Exception:
            return None
        return v if isinstance(v, str) and v else None

    def cursor_in(self, view_cursor):
        """Sitasi ReadPaper tempat kursor berada, atau None."""
        for c in self.citations:
            a = c.cc.Anchor
            try:
                t = a.Text
                if t.compareRegionStarts(a, view_cursor) >= 0 and t.compareRegionEnds(view_cursor, a) >= 0:
                    return c
            except Exception:
                continue
        return None

    def snapshot(self, view_cursor=None):
        """Potret untuk POST /api/run. Sitasi sesuai urutan dokumen; daftar
        pustaka di belakang (urutannya tidak memengaruhi penomoran)."""
        controls = [{'handle': c.handle, 'tag': c.tag} for c in self.citations]
        cursor = len(self.citations)
        if self.pending is not None:
            # Sisipan sudah ditaruh di dokumen sebagai penanda; letaknya di
            # antara sitasi lain adalah posisi kursornya.
            cursor = self.pending_index
        controls += [{'handle': b.handle, 'tag': b.tag} for b in self.bibliographies]
        cur = self.cursor_in(view_cursor) if view_cursor is not None else None
        return {
            'tagMode': 'inline',
            'controls': controls,
            'storeXml': self.read_store(),
            'cursor': cursor,
            'cursorIn': cur.handle if cur else None,
        }

    # ----------------------------------------------------------------- tulis

    def insert_pending(self, view_cursor):
        """Menaruh penanda sitasi di posisi kursor — di luar sitasi lain,
        tidak pernah bersarang di dalamnya."""
        self.scan()
        inside = self.cursor_in(view_cursor)
        if inside is not None:
            text = inside.cc.Anchor.Text
            cur = text.createTextCursorByRange(inside.cc.Anchor.End)
            cur.goRight(1, False)
        else:
            text = view_cursor.Text
            cur = text.createTextCursorByRange(view_cursor.End)
        text.insertString(cur, PLACEHOLDER, False)
        cur.goLeft(_units(PLACEHOLDER), True)
        cc = self.doc.createInstance('com.sun.star.text.ContentControl')
        cc.Tag = PENDING_TAG
        cc.Alias = 'ReadPaper'
        text.insertTextContent(cur, cc, True)
        self.scan()
        return cc

    @staticmethod
    def delete_cc(cc):
        """Menghapus content control beserta teksnya. removeTextContent
        meninggalkan wadah kosong di LibreOffice, jadi yang dihapus adalah
        rentangnya, termasuk karakter penanda di kedua ujungnya."""
        a = cc.Anchor
        text = a.Text
        cur = text.createTextCursorByRange(a.Start)
        cur.gotoRange(a.End, True)
        cur.goRight(1, True)
        cur.setString('')

    def release_controls(self):
        """Melepas semua rujukan content control.

        Memegang objek ContentControl sementara pemisah paragraf disisipkan di
        paragrafnya merusak dokumen di LibreOffice 24.2 (sisipan berikutnya
        menjatuhkan soffice). Jadi sebelum daftar pustaka ditulis, semua
        rujukan itu dilepas; yang tersisa hanya rentang teks."""
        import gc
        self.citations = []
        self.pending = None
        self.emptied = []
        for b in self.bibliographies:
            b.cc = None
        self._handles = {h: v for h, v in self._handles.items() if isinstance(v, Bibliography)}
        gc.collect()

    def remove_emptied(self):
        for cc in self.emptied:
            try:
                self.delete_cc(cc)
            except Exception:
                pass
        self.emptied = []

    def remove_pending(self):
        """Membuang penanda (beserta teksnya) bila perintah gagal."""
        self.scan()
        if self.pending is not None:
            self.delete_cc(self.pending.cc)
            self.pending = None

    @staticmethod
    def _write_runs(text, cursor, runs):
        """Menulis run berformat di posisi kursor (yang diciutkan ke ujung
        setiap run). Sifat yang dipakai salah satu run diset eksplisit di
        semua run, persis seperti di Word: teks sesudah run miring tidak
        boleh ikut miring, tetapi format paragraf penulis tidak ditimpa."""
        used = {k: any(r.get(k) for r in runs) for k in
                ('italic', 'bold', 'underline', 'superscript', 'subscript', 'smallCaps')}
        for r in runs:
            s = r.get('text') or ''
            if not s:
                continue
            text.insertString(cursor, s, False)
            cursor.goLeft(_units(s), True)
            if used['italic']:
                cursor.CharPosture = _ITALIC if r.get('italic') else _UPRIGHT
            if used['bold']:
                cursor.CharWeight = 150.0 if r.get('bold') else 100.0
            if used['underline']:
                cursor.CharUnderline = 1 if r.get('underline') else 0
            if used['superscript'] or used['subscript']:
                if r.get('superscript'):
                    cursor.CharEscapement, cursor.CharEscapementHeight = 33, 58
                elif r.get('subscript'):
                    cursor.CharEscapement, cursor.CharEscapementHeight = -33, 58
                else:
                    cursor.CharEscapement, cursor.CharEscapementHeight = 0, 100
            if used['smallCaps']:
                cursor.CharCaseMap = 4 if r.get('smallCaps') else 0
            cursor.collapseToEnd()

    def _fill_cc(self, cc, runs):
        cur = cc.createTextCursor()
        cur.gotoStart(False)
        cur.gotoEnd(True)
        cc.insertString(cur, '', True)
        if not any(r.get('text') for r in runs):
            runs = [{'text': '[?]'}]
        self._write_runs(cc, cur, runs)

    def apply(self, changes, view_cursor=None):
        """Menerapkan `changes` dari host.js. Penanda sisipan (bila ada)
        menjadi sitasi baru."""
        created = None
        for h in changes.get('unwrap') or []:
            self._unwrap(self._handles.get(h))
        ins = changes.get('insert')
        if ins and self.pending is not None:
            cc = self.pending.cc
            cc.Tag = ins['tag']
            self._fill_cc(cc, ins.get('runs') or [])
            created = cc
            cc = None
            self.pending = None
        for u in changes.get('citations') or []:
            c = self._handles.get(u['handle'])
            if not isinstance(c, Citation):
                continue
            if u.get('tag'):
                c.cc.Tag = u['tag']
            self._fill_cc(c.cc, u.get('runs') or [])
            c = None
        # Sitasi yang teksnya sudah dihapus tidak ikut dipotret; wadah
        # kosongnya dibuang supaya tidak muncul lagi di .docx.
        self.remove_emptied()
        after = None
        if created is not None and view_cursor is not None:
            try:
                after = created.Anchor.Text.createTextCursorByRange(created.Anchor.End)
                after.goRight(1, False)
            except Exception:
                after = None
        bibs = changes.get('bibliographies') or []
        if bibs:
            where = self._bibliography_position(view_cursor) if any(b.get('created') for b in bibs) else None
            created = None
            self.release_controls()
            for b in bibs:
                if b.get('created'):
                    self._insert_bibliography(where, b['bib'])
                else:
                    target = self._handles.get(b['handle'])
                    if isinstance(target, Bibliography):
                        self._rewrite_bibliography(target, b['bib'])
        if 'store' in changes:
            self.write_store(changes['store'])
        if after is not None:
            # Kursor ke sesudah sitasi baru, supaya mengetik meneruskan kalimat.
            try:
                view_cursor.gotoRange(after, False)
            except Exception:
                pass

    def write_store(self, xml):
        props = self.doc.DocumentProperties.UserDefinedProperties
        exists = props.PropertySetInfo.hasPropertyByName(STORE_PROPERTY)
        if xml is None:
            if exists:
                props.removeProperty(STORE_PROPERTY)
            return
        if exists:
            props.setPropertyValue(STORE_PROPERTY, xml)
        else:
            # 128 = REMOVABLE: pengguna boleh membuangnya lewat Properti.
            props.addProperty(STORE_PROPERTY, 128, xml)

    # ------------------------------------------------------- daftar pustaka

    def _bib_paragraph_props(self, bib):
        indent = 0
        if bib.get('hangingIndent'):
            indent = 1270  # 1,27 cm, seperti Word dan Zotero
        elif bib.get('secondFieldAlign'):
            indent = max(635, min(2540, (int(bib.get('maxOffset') or 0) + 1) * 212))
        spacing = float(bib.get('entrySpacing') or 0)
        line = float(bib.get('lineSpacing') or 1)
        return indent, spacing, line

    def _write_bib_paragraphs(self, text, cursor, bib):
        """Menulis paragraf daftar pustaka mulai dari kursor (di awal
        paragraf kosong). Mengembalikan rentang yang ditulis."""
        indent, spacing, line = self._bib_paragraph_props(bib)
        paragraphs = bib.get('paragraphs') or [{'runs': [{'text': ''}]}]
        for i, p in enumerate(paragraphs):
            if i:
                text.insertControlCharacter(cursor, PARAGRAPH_BREAK, False)
            self._write_runs(text, cursor, p.get('runs') or [])
            # Kursor yang dibuat di awal sisipan ikut bergeser bersama teks
            # yang disisipkan, jadi paragrafnya dicari dari ujungnya.
            para = text.createTextCursorByRange(cursor.End)
            para.gotoStartOfParagraph(True)
            para.ParaLeftMargin = indent
            para.ParaFirstLineIndent = -indent
            if spacing > 1:
                para.ParaBottomMargin = int(423 * (spacing - 1))  # 12 pt per baris tambahan
            ls = para.ParaLineSpacing
            ls.Mode = 0  # PROP
            ls.Height = int(round(100 * line))
            para.ParaLineSpacing = ls
        rng = text.createTextCursorByRange(cursor.End)
        for _ in range(len(paragraphs) - 1):
            rng.gotoPreviousParagraph(True)
        rng.gotoStartOfParagraph(True)
        return rng

    def _bookmark(self, text, rng):
        name = BIBLIOGRAPHY_TAG
        n = 2
        while self.doc.Bookmarks.hasByName(name):
            name = '%s_%d' % (BIBLIOGRAPHY_TAG, n)
            n += 1
        bm = self.doc.createInstance('com.sun.star.text.Bookmark')
        bm.Name = name
        text.insertTextContent(rng, bm, True)
        return bm

    def _bibliography_position(self, view_cursor):
        """(text, cursor) tempat daftar pustaka baru: posisi kursor, di
        luar sitasi."""
        if view_cursor is None:
            text = self.doc.Text
            cur = text.createTextCursor()
            cur.gotoEnd(False)
        else:
            inside = self.cursor_in(view_cursor)
            if inside is not None:
                text = inside.cc.Anchor.Text
                cur = text.createTextCursorByRange(inside.cc.Anchor.End)
                cur.goRight(1, False)
            else:
                text = view_cursor.Text
                cur = text.createTextCursorByRange(view_cursor.End)
        return text, cur

    def _insert_bibliography(self, where, bib):
        text, cur = where
        # Daftar pustaka selalu di paragrafnya sendiri.
        # Posisinya dibaca sebelum menyisipkan apa pun: menanyai kursor
        # sesudah menyisipkan pemisah paragraf di sebelah content control
        # menjatuhkan LibreOffice 24.2.
        at_start = cur.isStartOfParagraph()
        at_end = cur.isEndOfParagraph()
        if not at_end:
            text.insertControlCharacter(cur, PARAGRAPH_BREAK, False)
            cur.goLeft(1, False)
        if not at_start:
            text.insertControlCharacter(cur, PARAGRAPH_BREAK, False)
        rng = self._write_bib_paragraphs(text, cur, bib)
        self._bookmark(text, rng)

    def _rewrite_bibliography(self, target, bib):
        if target.bookmark is not None:
            anchor = target.bookmark.Anchor
            text = anchor.Text
            cur = text.createTextCursorByRange(anchor)
            text.removeTextContent(target.bookmark)
        else:
            # Daftar pustaka Word: buang content control-nya, ganti seluruh
            # paragrafnya dengan bentuk bookmark.
            first = target.paragraphs[0]
            last = target.paragraphs[-1]
            text = first.Text
            cur = text.createTextCursorByRange(first.Start)
            cur.gotoRange(last.End, True)
        cur.setString('')
        cur.collapseToStart()
        rng = self._write_bib_paragraphs(text, cur, bib)
        self._bookmark(text, rng)

    # ------------------------------------------------------------ teks biasa

    def _unwrap(self, target):
        """Membuang penanda ReadPaper; teksnya, berikut formatnya, tinggal."""
        if target is None:
            return
        if isinstance(target, Bibliography):
            if target.bookmark is not None:
                target.bookmark.Anchor.Text.removeTextContent(target.bookmark)
            elif target.cc is not None:
                self._unwrap_cc(target.cc)
            return
        self._unwrap_cc(target.cc)

    def _unwrap_cc(self, cc):
        # removeTextContent membuang teks content control juga, jadi teksnya
        # dibaca dulu per potongan beserta formatnya, lalu ditulis lagi di
        # tempat yang sama.
        runs = []
        portions = cc.createEnumeration()
        while portions.hasMoreElements():
            por = portions.nextElement()
            s = por.String
            if not s:
                continue
            runs.append({
                'text': s,
                'italic': por.CharPosture == _ITALIC,
                'bold': por.CharWeight > 100,
                'underline': por.CharUnderline != 0,
                'superscript': por.CharEscapement > 0,
                'subscript': por.CharEscapement < 0,
                'smallCaps': por.CharCaseMap == 4,
            })
        anchor = cc.Anchor
        text = anchor.Text
        # Kursor teks tetap sah sesudah rentang di depannya dihapus.
        cur = text.createTextCursorByRange(anchor.Start)
        self.delete_cc(cc)
        self._write_runs(text, cur, runs)
