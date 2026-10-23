# Perintah sitasi di LibreOffice: potret dokumen → ReadPaper → tulis balik.
#
# Setiap perintah memindai dokumennya dari awal (aturan 1: daftar pustaka
# diturunkan dari dokumen, tidak pernah ditimbun) dan dibungkus satu langkah
# Urungkan, jadi Ctrl+Z membatalkan satu sitasi atau satu "Perbarui semua"
# sekaligus, bukan potongan-potongannya.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

from .document import WriterDocument

UNDO_TITLES = {
    'insert': 'ReadPaper: sisipkan sitasi',
    'update': 'ReadPaper: sunting sitasi',
    'refresh': 'ReadPaper: perbarui semua',
    'bibliography': 'ReadPaper: daftar pustaka',
    'setStyle': 'ReadPaper: gaya sitasi',
    'addUncited': 'ReadPaper: tanpa disitasi',
    'removeUncited': 'ReadPaper: tanpa disitasi',
    'convertToText': 'ReadPaper: jadikan teks biasa',
}


def view_cursor(doc):
    try:
        return doc.CurrentController.ViewCursor
    except Exception:
        return None


def is_writer(doc):
    try:
        return doc is not None and doc.supportsService('com.sun.star.text.TextDocument')
    except Exception:
        return False


def state(api, doc, vc=None):
    """Keadaan sitasi dokumen (gaya, jumlah, tanpa disitasi, sitasi di
    kursor). Tidak mengubah apa pun."""
    wd = WriterDocument(doc).scan()
    return api.run('state', wd.snapshot(vc if vc is not None else view_cursor(doc)))['result']


def run(api, doc, command, args=None, vc=None):
    """Menjalankan satu perintah yang mengubah dokumen; mengembalikan
    `result` dari ReadPaper."""
    if vc is None:
        vc = view_cursor(doc)
    wd = WriterDocument(doc).scan()
    undo = doc.UndoManager
    undo.enterUndoContext(UNDO_TITLES.get(command, 'ReadPaper'))
    pending = False
    try:
        if command == 'insert':
            wd.insert_pending(vc)
            pending = True
        snapshot = wd.snapshot(vc)
        r = api.run(command, snapshot, args or {})
        wd.apply(r.get('changes') or {}, vc)
        pending = False
        return r.get('result')
    finally:
        if pending:
            try:
                wd.remove_pending()
            except Exception:
                pass
        undo.leaveUndoContext()
