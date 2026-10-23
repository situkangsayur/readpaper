# Uji paket .oxt yang sungguhan: dipasang dengan unopkg ke profil kosong,
# lalu perintahnya dipanggil lewat layanan UNO-nya — jalur yang sama dengan
# menu ReadPaper di Writer. Token ditemukan sendiri dari credentials.json
# ReadPaper (XDG_DATA_HOME tiruan), tanpa diketik.
#
#   scripts/package-libreoffice-extension.sh
#   python3 integrations/libreoffice/test/test_installed.py build/integrations/readpaper-libreoffice-1.0.0.oxt
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'python', 'pythonpath'))
sys.path.insert(0, HERE)

import uno  # noqa: E402
import test_writer as tw  # noqa: E402
from readpaper_lo.document import WriterDocument  # noqa: E402

OXT = None


class InstalledTest(unittest.TestCase):
    def test_menu_memanggil_readpaper_dengan_token_otomatis(self):
        work = tempfile.mkdtemp(prefix='rp-oxt-')
        server = office = None
        try:
            data = os.path.join(work, 'data', 'readpaper')
            os.makedirs(data)
            with open(os.path.join(data, 'credentials.json'), 'w') as f:
                json.dump({'readpaper:citation-server-token': tw.TOKEN, 'akun-lain': 'jangan-dibaca'}, f)
            port = tw.free_port()
            server = subprocess.Popen(['node', os.path.join(HERE, 'mock-readpaper.js'), str(port), tw.TOKEN],
                                      stdout=subprocess.PIPE)
            assert server.stdout.readline().startswith(b'ready')

            profile = 'file://' + os.path.join(work, 'profile')
            env = dict(os.environ, XDG_DATA_HOME=os.path.join(work, 'data'),
                       READPAPER_URL='http://127.0.0.1:%d' % port)
            r = subprocess.run(['unopkg', 'add', '-f', OXT,
                                '-env:UserInstallation=' + profile], env=env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            r = subprocess.run(['unopkg', 'list', '-env:UserInstallation=' + profile], env=env,
                               capture_output=True, text=True)
            self.assertIn('com.situkangsayur.readpaper.libreoffice', r.stdout)

            uport = tw.free_port()
            office = subprocess.Popen(
                ['soffice', '--headless', '--norestore', '--nologo', '-env:UserInstallation=' + profile,
                 '--accept=socket,host=127.0.0.1,port=%d;urp;' % uport],
                env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            local = uno.getComponentContext()
            resolver = local.ServiceManager.createInstanceWithContext('com.sun.star.bridge.UnoUrlResolver', local)
            for _ in range(120):
                try:
                    ctx = resolver.resolve('uno:socket,host=127.0.0.1,port=%d;urp;StarOffice.ComponentContext' % uport)
                    break
                except Exception:
                    time.sleep(0.25)
            desktop = ctx.ServiceManager.createInstanceWithContext('com.sun.star.frame.Desktop', ctx)
            doc = desktop.loadComponentFromURL('private:factory/swriter', '_blank', 0, ())

            job = ctx.ServiceManager.createInstanceWithContext('com.situkangsayur.readpaper.LibreOffice', ctx)
            self.assertIsNotNone(job, 'layanan ReadPaper tidak terdaftar')

            # Satu sitasi lewat inti (tanpa dialog), lalu menu "Daftar pustaka"
            # dan "Perbarui semua" lewat layanan yang terpasang.
            from readpaper_lo import api as rp_api, commands
            client = rp_api.Client(base_url='http://127.0.0.1:%d' % port, token=tw.TOKEN)
            tw.type_text(doc, 'Kalimat ')
            commands.run(client, doc, 'insert', {'items': [{'key': 'MCCLEAN'}]}, vc=tw.end_cursor(doc))
            vc = doc.CurrentController.ViewCursor
            vc.gotoEnd(False)
            job.trigger('bibliography')
            wd = WriterDocument(doc).scan()
            self.assertEqual(len(wd.bibliographies), 1, 'menu daftar pustaka tidak menulis apa pun')
            self.assertIn('McClean', wd.bibliographies[0].bookmark.Anchor.String)
            doc.close(True)
        finally:
            if office is not None:
                try:
                    desktop.terminate()
                except Exception:
                    pass
                try:
                    office.wait(timeout=30)
                except Exception:
                    office.kill()
            if server is not None:
                server.kill()
            shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    OXT = os.path.abspath(sys.argv.pop(1))
    unittest.main(verbosity=2)
