# Uji ekstensi LibreOffice di Writer sungguhan (soffice tanpa layar) melawan
# ReadPaper tiruan yang menjalankan host.js asli.
#
#   python3 integrations/libreoffice/test/test_writer.py
#
# Butuh soffice dan node di PATH, dan modul `uno` (python3-uno di
# Debian/Ubuntu, bawaan paket libreoffice di Arch).
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'python', 'pythonpath'))

import uno  # noqa: E402
from com.sun.star.beans import PropertyValue  # noqa: E402

from readpaper_lo import api as rp_api  # noqa: E402
from readpaper_lo import commands  # noqa: E402
from readpaper_lo.document import WriterDocument, BIBLIOGRAPHY_TAG  # noqa: E402

TOKEN = 'token-uji-libreoffice-yang-panjang-sekali-0123'


def pv(name, value):
    p = PropertyValue()
    p.Name = name
    p.Value = value
    return p


def free_port():
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    port = s.getsockname()[1]
    s.close()
    return port


class Office:
    def __init__(self):
        self.dir = tempfile.mkdtemp(prefix='rp-lo-')
        self.port = free_port()
        self.proc = subprocess.Popen(
            ['soffice', '--headless', '--invisible', '--norestore', '--nologo',
             '-env:UserInstallation=file://' + os.path.join(self.dir, 'profile'),
             '--accept=socket,host=127.0.0.1,port=%d;urp;' % self.port],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        local = uno.getComponentContext()
        resolver = local.ServiceManager.createInstanceWithContext('com.sun.star.bridge.UnoUrlResolver', local)
        for _ in range(120):
            try:
                self.ctx = resolver.resolve(
                    'uno:socket,host=127.0.0.1,port=%d;urp;StarOffice.ComponentContext' % self.port)
                break
            except Exception:
                time.sleep(0.25)
        else:
            raise RuntimeError('soffice tidak bisa dihubungi')
        self.desktop = self.ctx.ServiceManager.createInstanceWithContext('com.sun.star.frame.Desktop', self.ctx)

    def new(self):
        return self.desktop.loadComponentFromURL('private:factory/swriter', '_blank', 0, (pv('Hidden', True),))

    def open(self, path):
        return self.desktop.loadComponentFromURL('file://' + path, '_blank', 0, (pv('Hidden', True),))

    def close(self):
        try:
            self.desktop.terminate()
        except Exception:
            pass
        try:
            self.proc.wait(timeout=30)
        except Exception:
            self.proc.kill()
        shutil.rmtree(self.dir, ignore_errors=True)


def type_text(doc, s):
    t = doc.Text
    c = t.createTextCursor()
    c.gotoEnd(False)
    t.insertString(c, s, False)
    return c


def end_cursor(doc):
    c = doc.Text.createTextCursor()
    c.gotoEnd(False)
    return c


def citation_texts(doc):
    return [c.cc.String for c in WriterDocument(doc).scan().citations]


def bib_paragraphs(doc):
    wd = WriterDocument(doc).scan()
    assert len(wd.bibliographies) == 1, 'harus ada tepat satu daftar pustaka, ada %d' % len(wd.bibliographies)
    b = wd.bibliographies[0]
    return [p for p in b.bookmark.Anchor.String.split('\n') if p != ''] if b.bookmark else None


class WriterTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server_port = free_port()
        cls.server = subprocess.Popen(
            ['node', os.path.join(HERE, 'mock-readpaper.js'), str(cls.server_port), TOKEN],
            stdout=subprocess.PIPE)
        line = cls.server.stdout.readline().decode()
        assert line.startswith('ready'), line
        cls.office = Office()
        cls.api = rp_api.Client(base_url='http://127.0.0.1:%d' % cls.server_port, token=TOKEN)

    @classmethod
    def tearDownClass(cls):
        cls.office.close()
        cls.server.kill()

    def setUp(self):
        self.doc = self.office.new()

    def tearDown(self):
        self.doc.close(True)

    def run_cmd(self, command, args=None, vc=None):
        return commands.run(self.api, self.doc, command, args, vc=vc if vc is not None else end_cursor(self.doc))

    def test_sisip_daftar_pustaka_perbarui(self):
        self.run_cmd('setStyle', {'style': 'ieee', 'locale': 'id-ID'})
        type_text(self.doc, 'Buku tenang ')
        r = self.run_cmd('insert', {'items': [{'key': 'KARISMA'}]})
        self.assertEqual(r['text'], '[1]')
        type_text(self.doc, ' dan plateau ')
        r = self.run_cmd('insert', {'items': [{'key': 'MCCLEAN', 'locator': '12'}]})
        self.assertEqual(r['text'], '[2, hlm. 12]')
        # Kursor di awal: sitasi baru di depan dihitung dari yang ada, sitasi
        # lain belum ditulis ulang (aturan 2).
        start = self.doc.Text.createTextCursor()
        start.gotoStart(False)
        r = self.run_cmd('insert', {'items': [{'key': 'ZHANG'}]}, vc=start)
        self.assertEqual(r['text'], '[1]')
        self.assertEqual(citation_texts(self.doc), ['[1]', '[1]', '[2, hlm. 12]'])

        type_text(self.doc, '\n')
        r = self.run_cmd('bibliography')
        self.assertTrue(r['inserted'])
        r = self.run_cmd('refresh')
        self.assertEqual(r['citations'], 3)
        self.assertEqual(citation_texts(self.doc), ['[1]', '[2]', '[3, hlm. 12]'])
        bib = bib_paragraphs(self.doc)
        self.assertEqual(len(bib), 3)
        self.assertTrue(bib[0].startswith('[1]\tW. Zhang'), bib[0])
        self.assertTrue(self.doc.Text.String.startswith('[1]'))

        st = commands.state(self.api, self.doc, vc=end_cursor(self.doc))
        self.assertEqual(st['style'], 'ieee')
        self.assertEqual(st['bibliographies'], 1)

    def test_bug_zotero_referensi_ikut_hilang(self):
        self.run_cmd('setStyle', {'style': 'apa', 'locale': 'id-ID'})
        type_text(self.doc, 'A ')
        self.run_cmd('insert', {'items': [{'key': 'KARISMA'}, {'key': 'ZHANG'}]})
        type_text(self.doc, ' B ')
        self.run_cmd('insert', {'items': [{'key': 'MCCLEAN'}]})
        type_text(self.doc, '\n')
        self.run_cmd('bibliography')
        self.assertEqual(len(bib_paragraphs(self.doc)), 3)

        # Klaster dikurangi: kursor di dalam sitasi pertama, Zhang dibuang.
        wd = WriterDocument(self.doc).scan()
        inside = wd.citations[0].cc.Anchor.Text.createTextCursorByRange(wd.citations[0].cc.Anchor.Start)
        inside.goRight(2, False)
        st = commands.state(self.api, self.doc, vc=inside)
        self.assertEqual([i['key'] for i in st['current']['items']], ['KARISMA', 'ZHANG'])
        self.run_cmd('update', {'items': [{'key': 'KARISMA'}]}, vc=inside)
        self.run_cmd('refresh')
        bib = bib_paragraphs(self.doc)
        self.assertEqual(len(bib), 2)
        self.assertNotIn('Zhang', '\n'.join(bib))

        # Sitasi McClean dihapus penulis: teksnya diseleksi lalu dihapus.
        # LibreOffice membiarkan content control kosong bertag tertinggal —
        # yang tetap tidak boleh menahan referensinya.
        wd = WriterDocument(self.doc).scan()
        mc = [c for c in wd.citations if 'McClean' in c.cc.String][0]
        inner = mc.cc.createTextCursor()
        inner.gotoStart(False)
        inner.gotoEnd(True)
        inner.setString('')
        self.run_cmd('refresh')
        self.assertEqual(WriterDocument(self.doc).scan().emptied, [], 'wadah kosong dibuang')
        bib = bib_paragraphs(self.doc)
        self.assertEqual(len(bib), 1)
        self.assertTrue(bib[0].startswith('Karisma'), bib[0])
        st = commands.state(self.api, self.doc, vc=end_cursor(self.doc))
        self.assertEqual(st['uncited'], [])
        self.assertEqual(st['citations'], 1)

    def test_simpan_odt_dan_docx_lalu_buka_lagi(self):
        self.run_cmd('setStyle', {'style': 'vancouver-nlm', 'locale': 'id-ID'})
        type_text(self.doc, 'Satu ')
        self.run_cmd('insert', {'items': [{'key': 'MCCLEAN'}]})
        type_text(self.doc, ' dua ')
        self.run_cmd('insert', {'items': [{'key': 'KARISMA'}]})
        type_text(self.doc, '\n')
        self.run_cmd('bibliography')
        out = tempfile.mkdtemp(prefix='rp-lo-out-')
        try:
            for name, filt in (('a.odt', None), ('a.docx', 'MS Word 2007 XML')):
                path = os.path.join(out, name)
                args = (pv('FilterName', filt),) if filt else ()
                self.doc.storeToURL('file://' + path, args)
                d = self.office.open(path)
                try:
                    self.assertEqual(citation_texts(d), ['(1)', '(2)'], name)
                    wd = WriterDocument(d).scan()
                    self.assertEqual(len(wd.bibliographies), 1, name)
                    # Gaya ikut tersimpan: dibuka di komputer lain, tanpa
                    # memilih gaya lagi.
                    st = commands.state(self.api, d, vc=end_cursor(d))
                    self.assertEqual(st['style'], 'vancouver-nlm', name)
                    commands.run(self.api, d, 'refresh', vc=end_cursor(d))
                    self.assertEqual(citation_texts(d), ['(1)', '(2)'], name)
                    self.assertEqual(len(WriterDocument(d).scan().bibliographies), 1, name)
                finally:
                    d.close(True)
            # Di .docx, sitasinya content control bertag ReadPaper dan daftar
            # pustakanya bookmark — tanpa pemisah section.
            with zipfile.ZipFile(os.path.join(out, 'a.docx')) as z:
                xml = z.read('word/document.xml').decode('utf-8')
            self.assertIn('w:val="READPAPER_CITATION_v1:', xml)
            self.assertIn('w:name="' + BIBLIOGRAPHY_TAG + '"', xml)
            self.assertEqual(xml.count('<w:sectPr'), 1)
        finally:
            shutil.rmtree(out, ignore_errors=True)

    def test_format_run_dan_teks_biasa(self):
        self.run_cmd('setStyle', {'style': 'apa', 'locale': 'id-ID'})
        type_text(self.doc, 'Lihat ')
        self.run_cmd('insert', {'items': [{'key': 'ZHANG'}]})
        type_text(self.doc, '\n')
        self.run_cmd('bibliography')
        # APA memiringkan nama jurnal di daftar pustaka.
        wd = WriterDocument(self.doc).scan()
        anchor = wd.bibliographies[0].bookmark.Anchor
        italic = []
        for para in anchor.Text.createEnumeration():
            for por in para.createEnumeration():
                if por.String and por.CharPosture == uno.Enum('com.sun.star.awt.FontSlant', 'ITALIC'):
                    italic.append(por.String)
        self.assertTrue(any('Journal of Examples' in s for s in italic), italic)

        before = self.doc.Text.String
        r = self.run_cmd('convertToText')
        self.assertEqual(r['removed'], 2)
        wd = WriterDocument(self.doc).scan()
        self.assertEqual(wd.citations, [])
        self.assertEqual(wd.bibliographies, [])
        self.assertIsNone(wd.read_store())
        self.assertEqual(self.doc.Text.String, before)

    def test_tanpa_disitasi(self):
        type_text(self.doc, 'X ')
        self.run_cmd('insert', {'items': [{'key': 'MCCLEAN'}]})
        type_text(self.doc, '\n')
        self.run_cmd('bibliography')
        self.run_cmd('addUncited', {'key': 'ADAMS'})
        self.assertEqual(len(bib_paragraphs(self.doc)), 2)
        st = commands.state(self.api, self.doc, vc=end_cursor(self.doc))
        self.assertEqual([u['key'] for u in st['uncited']], ['ADAMS'])
        self.run_cmd('removeUncited', {'key': 'ADAMS'})
        self.assertEqual(len(bib_paragraphs(self.doc)), 1)

    def test_gagal_tidak_meninggalkan_penanda(self):
        type_text(self.doc, 'Teks ')
        with self.assertRaises(rp_api.ApiError):
            self.run_cmd('insert', {'items': [{'key': 'TIDAKADA'}]})
        self.assertEqual(self.doc.Text.String, 'Teks ')
        self.assertIsNone(WriterDocument(self.doc).scan().pending)

    def test_daftar_pustaka_dari_word(self):
        # Sitasi dan daftar pustaka buatan OnlyOffice/Word: content control
        # inline untuk sitasi, content control BLOK untuk daftar pustaka.
        r = self.api.run('setStyle', {'tagMode': 'inline', 'controls': [], 'cursor': 0}, {'style': 'ieee'})
        r = self.api.run('insert', {'tagMode': 'inline', 'controls': [], 'cursor': 0,
                                    'storeXml': r['changes'].get('store')}, {'items': [{'key': 'KARISMA'}]})
        tag = r['changes']['insert']['tag']
        out = tempfile.mkdtemp(prefix='rp-lo-word-')
        try:
            path = os.path.join(out, 'word.docx')
            write_word_docx(path, tag)
            d = self.office.open(path)
            try:
                wd = WriterDocument(d).scan()
                self.assertEqual(len(wd.citations), 1)
                self.assertEqual(len(wd.bibliographies), 1)
                self.assertEqual(len(wd.bibliographies[0].paragraphs), 3)
                commands.run(self.api, d, 'refresh', vc=end_cursor(d))
                text = d.Text.String
                # Entri lama yang tidak lagi disitasi tidak boleh tertinggal.
                self.assertNotIn('Entri lama dua', text)
                self.assertNotIn('Entri lama tiga', text)
                self.assertIn('Karisma', text)
                self.assertTrue(text.rstrip().endswith('Paragraf sesudahnya.'), text)
                wd = WriterDocument(d).scan()
                self.assertEqual(len(wd.bibliographies), 1)
                self.assertIsNotNone(wd.bibliographies[0].bookmark)
            finally:
                d.close(True)
        finally:
            shutil.rmtree(out, ignore_errors=True)


def write_word_docx(path, citation_tag):
    W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    doc = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="%s"><w:body>'
        '<w:p><w:r><w:t xml:space="preserve">Kalimat </w:t></w:r>'
        '<w:sdt><w:sdtPr><w:tag w:val="%s"/></w:sdtPr><w:sdtContent><w:r><w:t>[1]</w:t></w:r></w:sdtContent></w:sdt></w:p>'
        '<w:sdt><w:sdtPr><w:tag w:val="READPAPER_BIBLIOGRAPHY_v1"/></w:sdtPr><w:sdtContent>'
        '<w:p><w:r><w:t>[1] Entri lama satu.</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>[2] Entri lama dua.</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>[3] Entri lama tiga.</w:t></w:r></w:p>'
        '</w:sdtContent></w:sdt>'
        '<w:p><w:r><w:t>Paragraf sesudahnya.</w:t></w:r></w:p>'
        '</w:body></w:document>') % (W, citation_tag)
    with zipfile.ZipFile(path, 'w') as z:
        z.writestr('[Content_Types].xml',
                   '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                   '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                   '<Default Extension="xml" ContentType="application/xml"/>'
                   '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
        z.writestr('_rels/.rels',
                   '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        z.writestr('word/document.xml', doc)


if __name__ == '__main__':
    unittest.main(verbosity=2)
