# Komponen UNO ekstensi ReadPaper untuk LibreOffice Writer.
#
# Menu dan bilah alat (Addons.xcu) memanggil
# service:com.situkangsayur.readpaper.LibreOffice?<perintah>; semua isinya
# ada di pythonpath/readpaper_lo/.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

import unohelper
from com.sun.star.task import XJobExecutor

IMPLEMENTATION = 'com.situkangsayur.readpaper.LibreOffice'


class ReadPaperCommands(unohelper.Base, XJobExecutor):
    def __init__(self, ctx):
        self.ctx = ctx

    def trigger(self, arg):
        # Diimpor di sini, bukan di atas: LibreOffice memuat komponen ini saat
        # menu dibangun, dan dialog baru dibutuhkan saat perintah dipilih.
        from readpaper_lo import ui
        ui.dispatch(self.ctx, arg)


g_ImplementationHelper = unohelper.ImplementationHelper()
g_ImplementationHelper.addImplementation(ReadPaperCommands, IMPLEMENTATION, ('com.sun.star.task.Job',))
