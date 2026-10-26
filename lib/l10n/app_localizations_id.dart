// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'ReadPaper';

  @override
  String get languageMenu => 'Bahasa';

  @override
  String get languageSystem => 'Ikuti sistem';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeMenu => 'Tema';

  @override
  String get themeSystem => 'Ikut sistem';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String get filesCancel => 'Batal';

  @override
  String get filesSave => 'Simpan';

  @override
  String get filesCreate => 'Buat';

  @override
  String get filesDelete => 'Hapus';

  @override
  String get filesRename => 'Ganti nama';

  @override
  String get filesOpen => 'Buka';

  @override
  String get filesShare => 'Bagikan';

  @override
  String get filesPickWorkFolder => 'Pilih folder kerja';

  @override
  String get filesWorkFolderNotReady =>
      'Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.';

  @override
  String get filesPickFilesToCopy => 'Pilih berkas untuk disalin ke sini';

  @override
  String filesCopiedHere(int count) {
    return '$count berkas disalin ke sini';
  }

  @override
  String get filesNameTaken => 'Sudah ada berkas atau folder bernama itu';

  @override
  String filesRenameFailed(String error) {
    return 'Gagal mengganti nama: $error';
  }

  @override
  String get filesCannotDeleteRoot =>
      'Folder kerja itu sendiri tidak bisa dihapus dari sini.';

  @override
  String get filesDeleteFolderTitle => 'Hapus folder ini?';

  @override
  String get filesFolderEmpty => 'Foldernya kosong.';

  @override
  String get filesFolderUncountable => 'Isinya tidak bisa dihitung.';

  @override
  String filesFolderDeletesCount(int count) {
    return '$count berkas di dalamnya ikut terhapus.';
  }

  @override
  String get filesLibraryCopiesUntouched =>
      'Salinan yang sudah masuk library tidak tersentuh.';

  @override
  String filesDeleteCount(int count) {
    return 'Hapus $count berkas';
  }

  @override
  String filesDeleteFailed(String error) {
    return 'Gagal menghapus: $error';
  }

  @override
  String get filesDeleteFileTitle => 'Hapus berkas ini?';

  @override
  String filesDeleteFileBody(String name) {
    return '$name\n\nDihapus dari folder ini. Salinan yang sudah masuk library tidak tersentuh.';
  }

  @override
  String get filesNewBoardTitle => 'Papan tulis baru';

  @override
  String get filesNewBoardBody =>
      'Berlembar-lembar, bisa dicoreti, lalu disimpan sebagai PDF di folder ini.';

  @override
  String get filesPortrait => 'Tegak';

  @override
  String get filesLandscape => 'Mendatar';

  @override
  String filesSavedHere(String name) {
    return '$name tersimpan di folder ini';
  }

  @override
  String get filesNewFolderTitle => 'Folder baru';

  @override
  String get filesNameLabel => 'Nama';

  @override
  String get filesNewMarkdownTitle => 'Berkas Markdown baru';

  @override
  String get filesFileNameLabel => 'Nama berkas';

  @override
  String get filesNewNotebookTitle => 'Buku catatan baru';

  @override
  String get filesHeader => 'Berkas';

  @override
  String get filesUpOneLevel => 'Naik satu tingkat';

  @override
  String get filesCreateHere => 'Buat baru di folder ini';

  @override
  String get filesWhiteboard => 'Papan tulis';

  @override
  String get filesNotebook => 'Buku catatan';

  @override
  String get filesMarkdownFile => 'Berkas Markdown';

  @override
  String get filesFolder => 'Folder';

  @override
  String get filesCopyInTooltip =>
      'Salin berkas atau folder ke sini — dari mana pun di perangkat';

  @override
  String get filesPickFolderToCopy => 'Pilih folder untuk disalin ke sini';

  @override
  String get filesCopyFiles => 'Salin berkas…';

  @override
  String get filesCopyFolder => 'Salin folder (beserta isinya)…';

  @override
  String get filesOpenOtherFolder => 'Buka folder lain';

  @override
  String get filesEmptyFolderHint =>
      'Folder ini kosong.\n\nBuat papan tulis, atau salin PDF ke sini dengan tombol unduh di atas — lalu seret ke sebuah koleksi untuk memasukkannya ke library.';

  @override
  String get filesFolderActions => 'Tindakan folder';

  @override
  String get filesDeleteFolder => 'Hapus folder';

  @override
  String get filesFileActions => 'Tindakan berkas';

  @override
  String get filesDeleteFile => 'Hapus berkas';

  @override
  String filesCannotOpenExt(String ext) {
    return 'Berkas $ext belum bisa dibuka di dalam ReadPaper. Yang bisa: PDF, EPUB, gambar, CSV, dan Excel.';
  }

  @override
  String get filesCannotOpenThis =>
      'Berkas ini belum bisa dibuka di dalam ReadPaper. Yang bisa: PDF, EPUB, gambar, CSV, dan Excel.';

  @override
  String filesNoAppForExt(String ext) {
    return 'Tidak ada aplikasi di sistem ini yang membuka berkas $ext.';
  }

  @override
  String get filesNoAppForThis =>
      'Tidak ada aplikasi di sistem ini yang membuka berkas ini.';

  @override
  String get filesOpenWithOtherApp => 'Buka dengan aplikasi lain';

  @override
  String filesTableUnreadable(String error) {
    return 'Tabel ini tidak bisa dibaca: $error';
  }

  @override
  String get filesNoSheets => 'Tidak ada lembar di berkas ini.';

  @override
  String get filesSheetEmpty => 'Lembar ini kosong.';

  @override
  String filesOnlyFirstRows(int count) {
    return 'Hanya $count baris pertama yang ditampilkan. Buka dengan aplikasi lain untuk melihat semuanya.';
  }

  @override
  String get settingsRepositories => 'Repositori';

  @override
  String get settingsAddRepository => 'Tambah repositori';

  @override
  String get settingsNoRepositories => 'Belum ada repositori.';

  @override
  String settingsDeleteProfileTitle(String name) {
    return 'Hapus \"$name\"?';
  }

  @override
  String get settingsDeleteProfileBody => 'Profil akan dihapus dari ReadPaper.';

  @override
  String get settingsDeleteCloneToo => 'Hapus juga folder clone lokal';

  @override
  String settingsUrlTransportMismatch(String mode) {
    return 'URL tidak cocok dengan mode $mode.';
  }

  @override
  String get settingsMakeActive => 'Jadikan aktif';

  @override
  String get settingsLicense =>
      'Perangkat lunak bebas, lisensi AGPL-3.0-or-later.\nKode sumber: github.com/situkangsayur/readpaper';

  @override
  String get settingsEditRepository => 'Ubah repositori';

  @override
  String get settingsRepoUrl => 'URL repositori';

  @override
  String get settingsUrlRequired => 'URL tidak boleh kosong';

  @override
  String get settingsApiTokenNote =>
      'Perangkat ini menyinkronkan lewat GitHub API, jadi aksesnya memakai token HTTPS.';

  @override
  String get settingsDisplayName => 'Nama tampilan';

  @override
  String get settingsNameRequired => 'Nama tidak boleh kosong';

  @override
  String get settingsSshKeyOptional => 'Kunci privat SSH (opsional)';

  @override
  String get settingsSshKeyHelper =>
      'Kosongkan untuk memakai ssh-agent atau kunci bawaan.';

  @override
  String get settingsGithubUsername => 'Username GitHub';

  @override
  String get settingsAccessToken => 'Personal access token';

  @override
  String get settingsTokenHelper =>
      'Disimpan terpisah di credentials.json (izin 600).';

  @override
  String get settingsLocalCloneFolder => 'Folder clone lokal';

  @override
  String get settingsPrivateStorage =>
      'Data disimpan di penyimpanan privat aplikasi.';

  @override
  String get settingsCommitIdentity => 'Identitas commit';

  @override
  String get settingsNameLabel => 'Nama';

  @override
  String get settingsAuthorHint => 'kosong = pakai konfigurasi git';

  @override
  String get settingsLazyPdfTitle => 'Unduh PDF hanya saat dibuka';

  @override
  String get settingsLazyPdfSubtitle =>
      'Ambil metadata library dulu (puluhan MB); berkas PDF menyusul satu per satu. Matikan kalau ingin semua PDF diunduh sekaligus sesudah ambil dan pull, supaya bisa dibaca offline.';

  @override
  String get settingsAutoPushTitle => 'Push otomatis setelah menyimpan anotasi';

  @override
  String get settingsAutoPushSubtitle =>
      'Setiap highlight/komentar langsung dikirim ke GitHub.';

  @override
  String get settingsPickSshKey => 'Pilih kunci privat SSH';

  @override
  String get settingsPickCloneFolder => 'Pilih folder clone';

  @override
  String citationRunningAt(String address) {
    return 'Berjalan di $address';
  }

  @override
  String get citationOff =>
      'Mati. Add-in Word, OnlyOffice, LibreOffice, dan Google Docs tidak bisa tersambung.';

  @override
  String get citationStarting => 'Menyalakan…';

  @override
  String get citationTitle =>
      'Sitasi di Word, OnlyOffice, LibreOffice & Google Docs';

  @override
  String get citationSubtitle =>
      'Server lokal yang dipakai add-in untuk mencari dan menyitasi.';

  @override
  String get citationRetry => 'Coba lagi';

  @override
  String get citationAddress => 'Alamat';

  @override
  String get citationCopyAddress => 'Salin alamat';

  @override
  String get citationAddressCopied => 'Alamat disalin.';

  @override
  String get citationNoToken => 'Belum ada';

  @override
  String get citationHideToken => 'Sembunyikan token';

  @override
  String get citationShowToken => 'Tampilkan token';

  @override
  String get citationCopyToken => 'Salin token';

  @override
  String get citationTokenCopied => 'Token disalin.';

  @override
  String get citationNewToken => 'Buat token baru';

  @override
  String get citationPasteHint =>
      'Tempel alamat dan token ini di add-in Word, OnlyOffice, atau Google Docs. Ekstensi LibreOffice menemukan tokennya sendiri. Panduannya: integrations/README.md di repositori ReadPaper.';

  @override
  String get citationNewTokenTitle => 'Buat token baru?';

  @override
  String get citationNewTokenBody =>
      'Token lama langsung tidak berlaku. Add-in Word, OnlyOffice, dan Google Docs yang sudah tersambung harus diberi token baru.';

  @override
  String get citationCreateNew => 'Buat baru';

  @override
  String citationTokenSaveFailed(String error) {
    return 'Token baru tidak bisa disimpan: $error';
  }

  @override
  String citationSettingsUnreadable(String error) {
    return 'Pengaturan server sitasi tidak terbaca: $error';
  }

  @override
  String citationPortInUse(int port, String reason) {
    return 'Port $port sudah dipakai program lain (mungkin ReadPaper lain yang sedang terbuka). $reason';
  }

  @override
  String get citationEmptyCollection => 'Koleksi ini belum berisi paper.';

  @override
  String citationBibWritten(int count, String file) {
    return '$count entri ditulis ke $file di folder kerja';
  }

  @override
  String citationBibCopied(String key) {
    return 'BibTeX disalin — kuncinya $key';
  }

  @override
  String get commonColorYellow => 'Kuning';

  @override
  String get commonColorRed => 'Merah';

  @override
  String get commonColorGreen => 'Hijau';

  @override
  String get commonColorBlue => 'Biru';

  @override
  String get commonColorPurple => 'Ungu';

  @override
  String get commonColorMagenta => 'Magenta';

  @override
  String get commonColorOrange => 'Oranye';

  @override
  String get commonColorGray => 'Abu-abu';

  @override
  String get commonColorTeal => 'Tosca';

  @override
  String get commonColorPink => 'Merah muda';

  @override
  String get commonColorBrown => 'Cokelat';

  @override
  String get commonColorInk => 'Tinta';

  @override
  String get commonColorWhite => 'Putih';

  @override
  String get commonColorBlack => 'Hitam';

  @override
  String get commonColorGrayShort => 'Abu';

  @override
  String get commonColorOrangeInk => 'Jingga';

  @override
  String get commonColorLightGreen => 'Hijau muda';

  @override
  String get commonColorSkyBlue => 'Biru langit';

  @override
  String get commonColorNavyBlue => 'Biru malam';

  @override
  String get commonFilePickUnreadable =>
      'Berkas itu tidak bisa dibaca dari tempatnya. Salin dulu ke folder kerja.';

  @override
  String commonFilePickerFailed(String error) {
    return 'Pemilih berkas gagal dibuka: $error';
  }

  @override
  String commonFolderPickerFailed(String error) {
    return 'Pemilih folder gagal dibuka: $error';
  }

  @override
  String commonLinuxPickerHelp(String error) {
    return 'Dialog pilih berkas tidak bisa dibuka ($error). Pasang xdg-desktop-portal beserta backend-nya (mis. xdg-desktop-portal-gtk), atau zenity.';
  }

  @override
  String commonShareUnsupported(String error, String path) {
    return 'Berbagi berkas belum didukung di sini ($error). Berkasnya ada di $path';
  }

  @override
  String get commonJustNow => 'baru saja';

  @override
  String commonMinutesAgo(int count) {
    return '$count menit lalu';
  }

  @override
  String commonHoursAgo(int count) {
    return '$count jam lalu';
  }

  @override
  String commonDaysAgo(int count) {
    return '$count hari lalu';
  }

  @override
  String commonWeeksAgo(int count) {
    return '$count pekan lalu';
  }

  @override
  String commonMonthsAgo(int count) {
    return '$count bulan lalu';
  }

  @override
  String commonYearsAgo(int count) {
    return '$count tahun lalu';
  }

  @override
  String get commonWorkFolder => 'Folder kerja';

  @override
  String get commonYesterday => 'kemarin';

  @override
  String get commonShapeRectangle => 'Kotak';

  @override
  String get commonShapeEllipse => 'Bulat';

  @override
  String get commonShapeDiamond => 'Belah ketupat';

  @override
  String get commonShapeTriangle => 'Segitiga';

  @override
  String get commonShapeLine => 'Garis';

  @override
  String get commonShapeArrow => 'Panah';

  @override
  String citationLibreOfficeReady(String engine) {
    return 'LibreOffice siap — sitasi dirender dengan $engine.';
  }

  @override
  String get citationLibreOfficeMissing =>
      'LibreOffice belum bisa dipakai: pasang libjavascriptcoregtk-4.1 (Debian/Ubuntu) atau webkit2gtk-4.1 (Arch/CachyOS), lalu buka ulang ReadPaper.';

  @override
  String get settingsTabsAtBottom => 'Bilah tab di bawah';

  @override
  String get settingsTabsAtBottomHint =>
      'Tab library dan dokumen tetap terjangkau saat pojok atas layar tertutup gelembung berbagi layar (Google Meet). Juga bisa dipilih dengan menekan lama sebuah tab.';

  @override
  String get findTooltip => 'Cari di dokumen (Ctrl+F)';

  @override
  String get findHint => 'Cari kata…';

  @override
  String get findSearching => 'Mencari…';

  @override
  String get findNoResults => 'Tidak ditemukan';

  @override
  String findCount(int current, int total) {
    return '$current dari $total';
  }

  @override
  String get findPrevious => 'Sebelumnya (Shift+Enter)';

  @override
  String get findNext => 'Berikutnya (Enter)';

  @override
  String get findClose => 'Tutup pencarian (Esc)';

  @override
  String findInChapter(int chapter) {
    return 'Bab $chapter';
  }

  @override
  String get githubLoginButton => 'Masuk dengan GitHub';

  @override
  String get githubLoginButtonHint =>
      'Tanpa membuat token: masuk lewat browser, lalu pilih atau buat repositori library.';

  @override
  String get githubLoginTitle => 'Masuk dengan GitHub';

  @override
  String get githubLoginCancel => 'Batal';

  @override
  String get githubLoginRetry => 'Coba lagi';

  @override
  String get githubLoginStep1 =>
      'Buka GitHub, masukkan kode ini, lalu tekan Authorize. Kodenya sudah disalin ke papan klip.';

  @override
  String get githubLoginCopyCode => 'Salin kode';

  @override
  String get githubLoginOpen => 'Buka GitHub';

  @override
  String get githubLoginWaiting => 'Menunggu persetujuan di GitHub…';

  @override
  String githubLoginSignedIn(String login) {
    return 'Masuk sebagai $login';
  }

  @override
  String get githubLoginChooseRepo => 'Pilih repositori library:';

  @override
  String get githubLoginSearchRepo => 'Cari repositori…';

  @override
  String get githubLoginNoRepos =>
      'Tidak ada repositori yang bisa ditulisi. Buat yang baru di bawah.';

  @override
  String get githubLoginCreateTitle => 'Belum punya repositorinya?';

  @override
  String get githubLoginCreateHint =>
      'ReadPaper membuatkannya di akun GitHub Anda, lengkap dengan README supaya langsung bisa diambil.';

  @override
  String get githubLoginRepoName => 'Nama repositori baru';

  @override
  String get githubLoginPrivate => 'Privat (hanya Anda yang bisa melihat)';

  @override
  String get githubLoginCreate => 'Buat repositori';

  @override
  String get githubLoginExpired =>
      'Kodenya kedaluwarsa sebelum disetujui. Coba lagi.';

  @override
  String get githubLoginDenied => 'Akses ditolak di GitHub.';

  @override
  String githubLoginFailed(String detail) {
    return 'Gagal masuk ke GitHub: $detail';
  }

  @override
  String githubRepoNameTaken(String name) {
    return 'Repositori \"$name\" sudah ada di akun ini, atau namanya tidak valid. Pilih nama lain, atau pilih repositorinya dari daftar di atas.';
  }

  @override
  String githubLoginDone(String login, String repo) {
    return 'Masuk sebagai $login — repositori $repo dipilih. Periksa lalu Simpan.';
  }

  @override
  String get githubLoginChooseAccount =>
      'Pakai akun yang sudah masuk, atau masuk dengan akun lain:';

  @override
  String githubLoginUseAccount(String login) {
    return 'Pakai akun $login';
  }

  @override
  String get githubLoginForgetAccount => 'Lupakan akun ini di perangkat ini';

  @override
  String get githubLoginOtherAccount => 'Masuk dengan akun lain';

  @override
  String get libraryAddToLibraryTooltip =>
      'Tambahkan berkas atau folder ke library';

  @override
  String get libraryAddFiles => 'Tambahkan berkas…';

  @override
  String get libraryAddFolderAsCollection => 'Tambahkan folder (jadi koleksi)…';

  @override
  String get libraryNewPaperCollection => 'Koleksi paper baru';

  @override
  String get libraryUnfiled => 'Tanpa koleksi';

  @override
  String get libraryNotesRoot => 'Catatan';

  @override
  String get libraryNewNoteCollection => 'Koleksi catatan baru';

  @override
  String libraryItemsAndCollections(int items, int collections) {
    return '$items item · $collections koleksi';
  }

  @override
  String get libraryIncludeSubOn => 'Sertakan item sub-koleksi: aktif';

  @override
  String get libraryIncludeSubOff => 'Sertakan item sub-koleksi: nonaktif';

  @override
  String get libraryCollapseAll => 'Tutup semua';

  @override
  String get libraryExpandAll => 'Buka semua';

  @override
  String get libraryNoNoteCollections =>
      'Belum ada koleksi catatan. Catatan disimpan di folder tersendiri di dalam repositori, terpisah dari paper.';

  @override
  String get libraryNewSubcollectionHere => 'Sub-koleksi baru di sini';

  @override
  String get libraryCollectionMenu => 'Ubah nama, pindahkan, atau hapus';

  @override
  String get libraryNewPaperSubcollection => 'Sub-koleksi paper baru';

  @override
  String get libraryNewCollectionHint =>
      'Ditulis ke collections.json, ikut tersinkron ke GitHub';

  @override
  String get libraryCreateCollectionFailed => 'Gagal membuat koleksi';

  @override
  String get libraryNewNoteSubcollection => 'Sub-koleksi catatan baru';

  @override
  String get libraryAddFilesHere => 'Tambahkan berkas ke sini…';

  @override
  String get libraryAnyTypeOrDrag =>
      'jenis apa pun, beberapa sekaligus; atau seret dari pengelola berkas';

  @override
  String get libraryAnyTypeSeveral => 'jenis apa pun, beberapa sekaligus';

  @override
  String get libraryAddFolderHere => 'Tambahkan folder ke sini…';

  @override
  String get librarySubfoldersBecomeSub => 'subfolder jadi sub-koleksi';

  @override
  String get libraryNewSubcollection => 'Sub-koleksi baru';

  @override
  String get libraryRename => 'Ubah nama';

  @override
  String get libraryMoveTo => 'Pindahkan ke…';

  @override
  String get libraryTransferToRepo =>
      'Pindahkan atau salin ke repositori lain…';

  @override
  String get libraryWithSubsAndPapers => 'beserta sub-koleksi dan paper-nya';

  @override
  String get libraryExportBibtex => 'Ekspor ke BibTeX (.bib)';

  @override
  String get libraryExportBibtexHint => 'untuk naskah LaTeX; sub-koleksi ikut';

  @override
  String get libraryDeleteCollection => 'Hapus koleksi';

  @override
  String get libraryPapersKept => 'Paper di dalamnya tidak ikut terhapus';

  @override
  String get libraryChangeCollectionFailed => 'Gagal mengubah koleksi';

  @override
  String get libraryRenameCollection => 'Ubah nama koleksi';

  @override
  String get libraryRenameCollectionHint =>
      'Paper di dalamnya tetap; jalur sub-koleksinya ikut berubah';

  @override
  String libraryCollectionRenamed(String name) {
    return 'Koleksi diubah namanya jadi \"$name\"';
  }

  @override
  String get libraryRoot => 'akar';

  @override
  String libraryCollectionMoved(String parent) {
    return 'Koleksi dipindah ke $parent';
  }

  @override
  String libraryTransferWhatCollection(String path) {
    return 'Koleksi $path, beserta sub-koleksi dan paper-nya';
  }

  @override
  String libraryCollectionMovedToRepo(String name, String repo) {
    return 'Koleksi \"$name\" dipindahkan ke $repo';
  }

  @override
  String libraryCollectionCopiedToRepo(String name, String repo) {
    return 'Koleksi \"$name\" disalin ke $repo';
  }

  @override
  String libraryConfirmDeleteCollection(String name) {
    return 'Yakin hapus koleksi \"$name\"?';
  }

  @override
  String libraryDeleteKeepsPapers(int count) {
    return '$count paper di dalamnya tidak ikut terhapus — hanya dilepas dari koleksi ini, sama seperti di Zotero.';
  }

  @override
  String libraryDeleteHasChildren(int count) {
    return 'Koleksi ini punya $count sub-koleksi. Ikut dihapus, atau naik satu tingkat?';
  }

  @override
  String get libraryCollectionEmpty => 'Koleksinya kosong.';

  @override
  String get libraryCancel => 'Batal';

  @override
  String get librarySubsMoveUp => 'Sub-koleksi naik';

  @override
  String get libraryYesDeleteAll => 'Ya, hapus semuanya';

  @override
  String get libraryYesDelete => 'Ya, hapus';

  @override
  String libraryCollectionDeleted(String name) {
    return 'Koleksi \"$name\" dihapus; paper-nya tetap ada';
  }

  @override
  String libraryMoveNameTo(String name) {
    return 'Pindahkan \"$name\" ke…';
  }

  @override
  String get libraryLibraryRoot => 'Akar library';

  @override
  String get libraryNoParent => 'tanpa induk';

  @override
  String get libraryWithSubsAndNotes => 'beserta sub-koleksi dan catatannya';

  @override
  String get libraryNotesKept => 'Catatannya tidak ikut terhapus';

  @override
  String libraryTransferWhatNoteCollection(String name) {
    return 'Koleksi catatan \"$name\", beserta sub-koleksi dan catatannya';
  }

  @override
  String libraryNoteCollectionMovedToRepo(String name, String repo) {
    return 'Koleksi catatan \"$name\" dipindahkan ke $repo';
  }

  @override
  String libraryNoteCollectionCopiedToRepo(String name, String repo) {
    return 'Koleksi catatan \"$name\" disalin ke $repo';
  }

  @override
  String libraryConfirmDeleteNoteCollection(String name) {
    return 'Hapus koleksi catatan \"$name\"?';
  }

  @override
  String libraryNoteCollectionHolds(int count) {
    return 'Berisi $count catatan. Catatannya tidak ikut terhapus — pindah ke \"Tanpa koleksi\" bila tidak ada di koleksi lain.';
  }

  @override
  String librarySubsDeletedToo(int count) {
    return '$count sub-koleksi di dalamnya ikut terhapus.';
  }

  @override
  String get libraryName => 'Nama';

  @override
  String get librarySave => 'Simpan';

  @override
  String get libraryNoItems => 'Tidak ada item.';

  @override
  String get librarySearchHelpTitle => 'Mempersempit pencarian';

  @override
  String get librarySearchHelpIntro =>
      'Kata biasa dicari di judul, pengarang, jurnal, tag, koleksi, DOI, dan abstrak. Beberapa kata berarti semuanya harus cocok.';

  @override
  String get librarySearchOpAuthor => 'hanya di nama pengarang';

  @override
  String get librarySearchOpTitle => 'frasa utuh di judul';

  @override
  String get librarySearchOpYear => 'tahun persis';

  @override
  String get librarySearchOpTag => 'hanya di tag';

  @override
  String get librarySearchOpType => 'jenis item Zotero';

  @override
  String get librarySearchOpJournal => 'nama publikasi';

  @override
  String get librarySearchOpAbstract => 'hanya di abstrak';

  @override
  String get librarySearchOpCollection => 'nama koleksi';

  @override
  String get librarySearchOpExclude => 'kecualikan yang mengandungnya';

  @override
  String get librarySearchHelpEnglish =>
      'Nama bidang boleh bahasa Inggris juga: author, title, year, type, journal, abstract, collection.';

  @override
  String get libraryClose => 'Tutup';

  @override
  String get librarySearchHint => 'Cari judul, pengarang, abstrak, DOI…';

  @override
  String get librarySearchHelpTooltip => 'Cara mempersempit pencarian';

  @override
  String get libraryOpenAnyFile =>
      'Buka berkas dari perangkat ini (tanpa memasukkannya ke library)';

  @override
  String get libraryPickFileToOpen => 'Pilih berkas untuk dibuka';

  @override
  String get libraryFindDuplicates => 'Cari item yang masuk lebih dari sekali';

  @override
  String libraryPossibleDuplicates(int count) {
    return '$count kemungkinan duplikat';
  }

  @override
  String get libraryStats => 'Statistik library';

  @override
  String get libraryBrowseByAuthor => 'Telusuri berdasarkan pengarang';

  @override
  String librarySortBy(String label) {
    return 'Urutkan: $label';
  }

  @override
  String libraryItemCount(int count) {
    return '$count item';
  }

  @override
  String get libraryHasFile => 'berkas';

  @override
  String get libraryNoFile => 'tidak ada berkas';

  @override
  String get libraryPickPaper => 'Pilih satu paper untuk melihat detailnya.';

  @override
  String get libraryAbstract => 'Abstrak';

  @override
  String libraryAnnotationsCount(int count) {
    return 'Anotasi ($count)';
  }

  @override
  String libraryNotesCount(int count) {
    return 'Catatan ($count)';
  }

  @override
  String get libraryCopyBibtex => 'Salin BibTeX';

  @override
  String get libraryDeleteDocument => 'Hapus dokumen ini dari library';

  @override
  String get libraryBackToList => 'Kembali ke daftar';

  @override
  String get libraryNoAttachments => 'Tidak ada lampiran.';

  @override
  String libraryAnnotationCount(int count) {
    return '$count anotasi';
  }

  @override
  String get libraryOnGithubNotDownloaded => 'ada di GitHub, belum diunduh';

  @override
  String get libraryFileNotDownloaded => 'berkas belum diunduh';

  @override
  String get libraryLfsPointer => 'pointer Git LFS — jalankan LFS pull';

  @override
  String get libraryCannotOpenFormat =>
      'format belum bisa dibuka di perangkat ini';

  @override
  String get libraryRead => 'Baca';

  @override
  String get libraryOpen => 'Buka';

  @override
  String get libraryDownload => 'Unduh';

  @override
  String get libraryFieldAuthors => 'Pengarang';

  @override
  String get libraryFieldPublication => 'Publikasi';

  @override
  String get libraryFieldDate => 'Tanggal';

  @override
  String get libraryFieldPublisher => 'Penerbit';

  @override
  String get libraryFieldTags => 'Tag';

  @override
  String get libraryFieldCollections => 'Koleksi';

  @override
  String get libraryFieldAdded => 'Ditambahkan';

  @override
  String get libraryDetails => 'Detail';

  @override
  String libraryAnnotationPage(String page, String type) {
    return 'hal. $page · $type';
  }

  @override
  String libraryMovingTo(String target) {
    return 'Memindah ke $target…';
  }

  @override
  String libraryCopyingTo(String target) {
    return 'Menyalin ke $target…';
  }

  @override
  String libraryMovedTo(String where) {
    return 'Dipindahkan ke $where';
  }

  @override
  String libraryCopiedTo(String where) {
    return 'Disalin ke $where';
  }

  @override
  String get libraryConfirmDeleteDocument => 'Hapus dokumen ini?';

  @override
  String libraryConfirmDeleteDocumentBody(String title) {
    return 'Berkas item, lampirannya, dan catatannya dihapus dari library, lalu perubahannya di-commit.\n\n\"$title\"\n\nKoleksi dan dokumen lain tidak tersentuh.';
  }

  @override
  String get libraryDelete => 'Hapus';

  @override
  String get libraryDocumentDeleted => 'Dokumen dihapus';

  @override
  String get libraryDeleteFailed => 'Gagal menghapus';

  @override
  String get libraryRecentlyRead => 'Terakhir dibaca';

  @override
  String get libraryClearHistory => 'Bersihkan';

  @override
  String libraryPageN(int page) {
    return 'halaman $page';
  }

  @override
  String get libraryRemoveFromHistory => 'Hapus dari riwayat';

  @override
  String libraryAuthorsCount(int count) {
    return 'Pengarang ($count)';
  }

  @override
  String get libraryMostWorks => 'Terbanyak';

  @override
  String get libraryFilterNames => 'Saring nama';

  @override
  String get libraryNoLibraryRead => 'Belum ada library yang terbaca.';

  @override
  String get libraryNoMatchingNames => 'Tidak ada nama yang cocok.';

  @override
  String get libraryDuplicatesTitle => 'Kemungkinan duplikat';

  @override
  String libraryDuplicatesNone(int count) {
    return '$count item diperiksa, tidak ada yang mencurigakan.';
  }

  @override
  String libraryDuplicatesSummary(int groups, int copies, int items) {
    return '$groups kelompok · $copies salinan dari $items item';
  }

  @override
  String libraryDuplicatesRisky(int count) {
    return ' · $count perlu hati-hati';
  }

  @override
  String get libraryNothingDuplicated => 'Tidak ada yang tampak ganda.';

  @override
  String get libraryDuplicatesHow =>
      'Dicocokkan lewat DOI, lalu ISBN, lalu judul bersama tahun dan nama pengarang pertama.';

  @override
  String get libraryDuplicatesFooter =>
      'Tidak ada yang dihapus dari sini. Penggabungan dikerjakan di Zotero, tempat riwayat dan lampirannya ikut dipindahkan — daftar ini gunanya menunjukkan mana yang perlu dilihat.';

  @override
  String libraryCopiesCount(int count) {
    return '$count salinan';
  }

  @override
  String get libraryAnnotationsOnSeveral =>
      'Anotasi ada di lebih dari satu salinan — menggabungkan bisa menghilangkan sebagiannya.';

  @override
  String get libraryHasFileFact => 'ada berkas';

  @override
  String get libraryStatsEmpty => 'Belum ada item untuk dihitung.';

  @override
  String get libraryStatsByYear => 'Per tahun terbit';

  @override
  String libraryStatsWithoutYear(int count) {
    return '$count item tanpa tahun tidak ikut dihitung di sini.';
  }

  @override
  String get libraryStatsByType => 'Per jenis';

  @override
  String get libraryStatsTopAuthors => 'Pengarang tersering';

  @override
  String get libraryStatsTopTags => 'Tag tersering';

  @override
  String get libraryStatsItems => 'Item';

  @override
  String get libraryStatsWithFile => 'Berkasnya ada';

  @override
  String get libraryStatsWithAnnotations => 'Ada anotasi';

  @override
  String get libraryStatsYearSpan => 'Rentang tahun';

  @override
  String get libraryStatsUntitled => 'Tanpa judul';

  @override
  String get librarySortTitle => 'Judul';

  @override
  String get librarySortYear => 'Tahun';

  @override
  String get librarySortCreator => 'Pengarang';

  @override
  String get librarySortDateAdded => 'Ditambahkan';

  @override
  String get librarySortAnnotations => 'Anotasi';

  @override
  String libraryPickFolderFor(String name) {
    return 'Pilih folder untuk $name';
  }

  @override
  String libraryPickFilesFor(String name) {
    return 'Pilih berkas untuk $name';
  }

  @override
  String libraryFilesAdded(int count, String name) {
    return '$count berkas masuk ke $name';
  }

  @override
  String libraryFilesAddedPartly(
    int added,
    int total,
    String name,
    String failed,
  ) {
    return '$added dari $total berkas masuk ke $name. Gagal: $failed. ';
  }

  @override
  String libraryMovingInto(String name) {
    return 'Memindahkan ke $name…';
  }

  @override
  String libraryMovedInto(String name) {
    return 'Pindah ke $name';
  }

  @override
  String get libraryMoveFailed => 'Gagal memindahkan';

  @override
  String libraryAddingInto(String name) {
    return 'Memasukkan ke $name…';
  }

  @override
  String get libraryAddFileFailed => 'Gagal memasukkan berkas';

  @override
  String libraryAddedInto(String name) {
    return 'Masuk ke $name';
  }

  @override
  String get libraryPapersStayInLibrary =>
      'Paper tinggal di akar paper: item Zotero punya rujukan dan bibliografi yang dijaga plugin sinkronisasi, dan folder catatan tidak mengenalnya. Yang bisa dipindahkan ke sini adalah catatan.';

  @override
  String get libraryMoveNoteFailed => 'Gagal memindahkan catatan';

  @override
  String get librarySaveNoteFailed => 'Gagal menyimpan catatan';

  @override
  String libraryFolderEmpty(String name) {
    return 'Folder $name tidak berisi berkas.';
  }

  @override
  String libraryImportFolderQuestion(String folder, String name) {
    return 'Impor folder \"$folder\" ke $name?';
  }

  @override
  String libraryFolderSummary(int files, int folders, String size) {
    return '$files berkas dalam $folders folder ($size).';
  }

  @override
  String get libraryFolderToNotes =>
      'Folder ini jadi koleksi catatan, subfoldernya jadi sub-koleksi, dan setiap berkas jadi catatan.';

  @override
  String get libraryFolderToLibrary =>
      'Folder ini jadi koleksi, subfoldernya jadi sub-koleksi, dan setiap berkas jadi item Zotero dengan lampirannya — terlihat juga di Zotero.';

  @override
  String get libraryFolderReuses =>
      'Koleksi yang namanya sudah ada di tempat yang sama dipakai, bukan digandakan.';

  @override
  String get libraryFolderLarge =>
      'Ukurannya besar. Semua berkas ini masuk repositori git dan ikut terkirim ke GitHub.';

  @override
  String get libraryImport => 'Impor';

  @override
  String libraryImporting(String name) {
    return 'Mengimpor $name…';
  }

  @override
  String libraryProgress(int done, int total) {
    return '$done dari $total berkas';
  }

  @override
  String get libraryImportFailed => 'Impor folder gagal';

  @override
  String libraryImportDone(int added, int collections) {
    return '$added berkas masuk, $collections koleksi baru.';
  }

  @override
  String libraryImportFailedSome(int count, String names) {
    return 'Gagal ($count): $names';
  }

  @override
  String libraryAddToTooltip(String name) {
    return 'Tambahkan berkas atau folder ke $name';
  }

  @override
  String get libraryAnyTypeMany => 'jenis apa pun, bisa beberapa sekaligus';

  @override
  String get libraryAddFolder => 'Tambahkan folder…';

  @override
  String libraryAddFolderHint(String name) {
    return 'jadi koleksi di $name, subfolder jadi sub-koleksi';
  }

  @override
  String get libraryTypeJournalArticle => 'Artikel jurnal';

  @override
  String get libraryTypeConferencePaper => 'Makalah konferensi';

  @override
  String get libraryTypeBook => 'Buku';

  @override
  String get libraryTypeBookSection => 'Bab buku';

  @override
  String get libraryTypeThesis => 'Tesis / disertasi';

  @override
  String get libraryTypeReport => 'Laporan';

  @override
  String get libraryTypePreprint => 'Pracetak';

  @override
  String get libraryTypeWebpage => 'Halaman web';

  @override
  String get libraryTypeManuscript => 'Naskah';

  @override
  String get libraryTypeDocument => 'Dokumen';

  @override
  String get libraryTypePresentation => 'Presentasi';

  @override
  String get libraryTypeDataset => 'Data';

  @override
  String get libraryTypeStandard => 'Standar';

  @override
  String get libraryTypePatent => 'Paten';

  @override
  String get libraryTypeMagazineArticle => 'Artikel majalah';

  @override
  String get libraryTypeNewspaperArticle => 'Artikel koran';

  @override
  String get libraryTypeEncyclopediaArticle => 'Artikel ensiklopedia';

  @override
  String get libraryTypeBlogPost => 'Tulisan blog';

  @override
  String get libraryTypeComputerProgram => 'Perangkat lunak';

  @override
  String get libraryTypeAttachment => 'Lampiran';

  @override
  String get libraryTypeNote => 'Catatan';

  @override
  String get libraryReasonDoi => 'DOI-nya sama';

  @override
  String get libraryReasonIsbn => 'ISBN-nya sama';

  @override
  String get libraryReasonTitleYearAuthor =>
      'Judul, tahun, dan pengarangnya sama';

  @override
  String get libraryErrItemNotFound => 'Berkas item tidak ditemukan';

  @override
  String get libraryErrLibraryDirMissing => 'Direktori library tidak ada';

  @override
  String get libraryErrItemInvalid => 'Berkas item tidak valid';

  @override
  String libraryErrAttachmentsMissing(int count, String names) {
    return '$count lampiran belum ada di perangkat ini (belum diunduh, atau masih penunjuk Git LFS): $names';
  }

  @override
  String get libraryErrItemNoKey => 'Berkas item tidak punya kunci Zotero';

  @override
  String libraryErrItemExistsInTarget(String itemKey) {
    return 'Item ini sudah ada di repositori tujuan (kunci $itemKey). Tidak disalin dua kali.';
  }

  @override
  String get libraryErrCollectionGone => 'Koleksi tidak ada lagi';

  @override
  String get libraryErrTargetCollectionMissing => 'Koleksi tujuan tidak ada';

  @override
  String libraryErrTargetHasCollection(String name) {
    return 'Di tempat tujuan sudah ada koleksi bernama \"$name\". Ganti namanya dulu.';
  }

  @override
  String libraryErrItemTitleExists(String title) {
    return 'Item $title sudah ada di repositori tujuan.';
  }

  @override
  String get libraryErrCollectionsNotList =>
      'collections.json tidak berisi daftar koleksi';

  @override
  String get libraryErrRefuseDeleteNotItem =>
      'Menolak menghapus: berkas ini bukan item di dalam items/';

  @override
  String get libraryErrCollectionNameEmpty => 'Nama koleksi tidak boleh kosong';

  @override
  String get libraryErrCollectionNameSlash =>
      'Nama koleksi tidak boleh memuat garis miring';

  @override
  String get libraryErrCollectionsNotListRefuse =>
      'collections.json tidak berisi daftar koleksi — menolak menulisinya';

  @override
  String get libraryErrCollectionsBadEntry =>
      'Ada entri di collections.json yang bukan koleksi — menolak menulisinya';

  @override
  String get libraryErrParentMissing => 'Koleksi induk tidak ada';

  @override
  String libraryErrCollectionExists(String name) {
    return 'Sudah ada koleksi bernama \"$name\" di tempat yang sama';
  }

  @override
  String get libraryErrCollectionKey => 'Gagal membuat kunci koleksi baru';

  @override
  String get libraryErrMoveIntoSelf =>
      'Koleksi tidak bisa dipindah ke dalam dirinya sendiri';

  @override
  String get libraryErrCollectionsMissing => 'collections.json tidak ada';

  @override
  String get libraryErrItemNoZotero => 'Berkas item tidak punya bagian zotero';

  @override
  String get libraryErrFileNotFound => 'Berkas tidak ditemukan';

  @override
  String get libraryOpenTree => 'Koleksi';

  @override
  String get notesUnfiledTitle => 'Catatan tanpa koleksi';

  @override
  String get notesRootTitle => 'Catatan';

  @override
  String get notesAllTitle => 'Semua catatan';

  @override
  String notesCount(int count) {
    return '$count catatan';
  }

  @override
  String get notesNewNotebook => 'Buku catatan baru';

  @override
  String get notesNewMarkdown => 'Catatan Markdown baru';

  @override
  String get notesEmpty =>
      'Belum ada catatan di sini. Seret berkas dari panel berkas, atau pakai tombol tambah di atas. Tarik ke bawah untuk mengambil perubahan dari GitHub.';

  @override
  String get notesActions => 'Tindakan';

  @override
  String get notesClose => 'Tutup';

  @override
  String get notesNotebookDefaultTitle => 'Catatan';

  @override
  String get notesNewNotebookFailed => 'Gagal membuat buku catatan';

  @override
  String get notesNewNoteTitle => 'Catatan baru';

  @override
  String get notesNewNoteFailed => 'Gagal membuat catatan';

  @override
  String get notesRename => 'Ubah judul';

  @override
  String get notesShare => 'Bagikan';

  @override
  String get notesShareAsPdf => 'sebagai PDF';

  @override
  String get notesShareToApps => 'ke aplikasi lain';

  @override
  String get notesMoveToCollection => 'Pindahkan ke koleksi';

  @override
  String get notesTransferToRepo => 'Pindahkan atau salin ke repositori lain…';

  @override
  String get notesDelete => 'Hapus catatan';

  @override
  String get notesDeleteSubtitle => 'Berkasnya ikut terhapus';

  @override
  String notesTransferWhat(String title) {
    return 'Catatan \"$title\"';
  }

  @override
  String notesMoved(String target) {
    return 'Catatan dipindahkan ke $target';
  }

  @override
  String notesCopied(String target) {
    return 'Catatan disalin ke $target';
  }

  @override
  String get notesDeleteConfirmTitle => 'Hapus catatan?';

  @override
  String notesDeleteConfirmBody(String title) {
    return '“$title” beserta berkasnya akan dihapus dari repositori.';
  }

  @override
  String get notesCancel => 'Batal';

  @override
  String get notesDeleteButton => 'Hapus';

  @override
  String get notesNoCollection => 'Tanpa koleksi';

  @override
  String get notesTitleField => 'Judul';

  @override
  String get notesSave => 'Simpan';

  @override
  String get notesNoActiveRepo => 'Belum ada repositori aktif.';

  @override
  String get notesNoteGone => 'Catatannya tidak ada lagi.';

  @override
  String get notesCollectionGone => 'Koleksinya tidak ada lagi.';

  @override
  String get notesNoRepoToSave =>
      'Belum ada repositori aktif untuk menyimpan catatan.';

  @override
  String get notesErrEmptyCollectionName =>
      'Nama koleksi catatan tidak boleh kosong';

  @override
  String get notesErrParentMissing => 'Koleksi induk tidak ada';

  @override
  String get notesErrCollectionMissing => 'Koleksi catatan tidak ada';

  @override
  String get notesErrFileNotFound => 'Berkas catatan tidak ditemukan';

  @override
  String get notesErrNoteMissing => 'Catatan tidak ada';

  @override
  String get notesErrEmptyTitle => 'Judul catatan tidak boleh kosong';

  @override
  String get notesErrTargetCollectionMissing =>
      'Koleksi catatan tujuan tidak ada';

  @override
  String get notesErrFileOutside => 'Berkas catatan ada di luar folder catatan';

  @override
  String get notesErrFileNotOnDevice =>
      'Berkas catatan tidak ada di perangkat ini';

  @override
  String notesErrTargetNameTaken(String name) {
    return 'Di tempat tujuan sudah ada koleksi catatan bernama \"$name\". Ganti namanya dulu.';
  }

  @override
  String notesErrNamedFileNotOnDevice(String title) {
    return 'Berkas catatan \"$title\" tidak ada di perangkat ini';
  }

  @override
  String get notesErrNoNewKey => 'Gagal membuat kunci catatan baru';

  @override
  String get notesTargetRefusal =>
      'Catatan hanya bisa disimpan di akar \"Catatan\". Akar paper berisi item Zotero — item di sana punya properti rujukan dan bibliografi, dan formatnya dijaga oleh plugin sinkronisasi Zotero. Pilih koleksi di bawah akar Catatan, atau buat satu lebih dulu.';

  @override
  String notesImageMissing(String path) {
    return 'Berkas gambarnya tidak ada lagi:\n$path';
  }

  @override
  String get epubThemeLight => 'Terang';

  @override
  String get epubThemeSepia => 'Sepia';

  @override
  String get epubThemeDark => 'Gelap';

  @override
  String epubUnreadable(String error) {
    return 'EPUB ini tidak bisa dibaca: $error';
  }

  @override
  String get epubSmallerText => 'Perkecil huruf';

  @override
  String get epubLargerText => 'Perbesar huruf';

  @override
  String epubPageColor(String name) {
    return 'Warna halaman: $name';
  }

  @override
  String get epubContents => 'Daftar isi';

  @override
  String get epubNoChapters => 'EPUB ini tidak punya bab yang bisa dibaca.';

  @override
  String get epubPrevChapter => 'Bab sebelumnya';

  @override
  String get epubNextChapter => 'Bab berikutnya';

  @override
  String epubChapterN(int number) {
    return 'Bab $number';
  }

  @override
  String get epubErrNoContainer =>
      'Bukan EPUB: META-INF/container.xml tidak ada.';

  @override
  String get epubErrNoOpf => 'Bukan EPUB: berkas OPF tidak ditemukan.';

  @override
  String markdownReadFailed(String error) {
    return 'Gagal membaca berkas: $error';
  }

  @override
  String markdownSaved(String name) {
    return 'Tersimpan: $name';
  }

  @override
  String markdownSaveFailed(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get markdownWritingPdf => 'Menulis PDF…';

  @override
  String markdownPdfSaved(String name) {
    return 'PDF tersimpan: $name';
  }

  @override
  String get markdownPrint => 'Cetak';

  @override
  String markdownPdfFailed(String error) {
    return 'Gagal menulis PDF: $error';
  }

  @override
  String get markdownSaveFirstTitle => 'Simpan dulu?';

  @override
  String get markdownUnsavedBody => 'Ada perubahan yang belum disimpan.';

  @override
  String get markdownKeepEditing => 'Kembali menyunting';

  @override
  String get markdownDiscard => 'Buang perubahan';

  @override
  String get markdownSave => 'Simpan';

  @override
  String get markdownUnsaved => 'Belum disimpan';

  @override
  String get markdownEdit => 'Sunting';

  @override
  String get markdownPreview => 'Pratinjau';

  @override
  String get markdownBoth => 'Keduanya';

  @override
  String get markdownMore => 'Lainnya';

  @override
  String get markdownSaveAsPdf => 'Simpan sebagai PDF';

  @override
  String get markdownShareFile => 'Bagikan berkas Markdown';

  @override
  String get markdownShareAsPdf => 'Bagikan sebagai PDF';

  @override
  String get markdownCopyAll => 'Salin seluruh teks';

  @override
  String get markdownHint =>
      'Tulis di sini. Markdown: # tajuk, **tebal**, - daftar, ```mermaid diagram.';

  @override
  String get markdownHeading => 'Tajuk';

  @override
  String get markdownBold => 'Tebal';

  @override
  String get markdownItalic => 'Miring';

  @override
  String get markdownList => 'Daftar';

  @override
  String get markdownTaskList => 'Daftar tugas';

  @override
  String get markdownQuote => 'Kutipan';

  @override
  String get markdownCode => 'Kode';

  @override
  String get markdownTable => 'Tabel';

  @override
  String get markdownTableTemplate =>
      '| Kolom | Nilai |\n| --- | --- |\n|  |  |\n';

  @override
  String get markdownMermaid => 'Diagram mermaid';

  @override
  String get markdownMermaidEmpty => 'Diagram kosong.';

  @override
  String markdownMermaidUnsupported(String kind) {
    return 'Jenis diagram \"$kind\" belum digambar — yang sudah: graph dan flowchart. Sumbernya tetap ditampilkan apa adanya.';
  }

  @override
  String get markdownMermaidNoNodes =>
      'Tidak ada simpul yang bisa dibaca dari diagram ini.';

  @override
  String get markdownMermaidCannotDraw => 'Diagram ini belum bisa digambar.';

  @override
  String get markdownPdfEmpty => '(dokumen kosong)';

  @override
  String markdownPdfImageMissing(String path) {
    return '[gambar tidak ditemukan: $path]';
  }

  @override
  String get markdownEmptyDoc => 'Dokumen masih kosong.';

  @override
  String get whiteboardPortrait => 'Tegak';

  @override
  String get whiteboardLandscape => 'Mendatar';

  @override
  String get whiteboardBgWhite => 'Putih';

  @override
  String get whiteboardBgBlack => 'Hitam';

  @override
  String get whiteboardBgGreen => 'Hijau papan';

  @override
  String get whiteboardBgCream => 'Krem';

  @override
  String get whiteboardBgNavy => 'Biru malam';

  @override
  String whiteboardTurned(String orientation) {
    return 'Kertas jadi $orientation — coretannya ikut berputar, tidak ada yang hilang.';
  }

  @override
  String whiteboardSaveFailed(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String whiteboardShareFailed(String error) {
    return 'Gagal membagikan: $error';
  }

  @override
  String whiteboardSavedAs(String name) {
    return 'Tersimpan sebagai $name';
  }

  @override
  String get notesCannotSaveAsNote => 'Belum bisa disimpan sebagai catatan';

  @override
  String get notesUnderstood => 'Mengerti';

  @override
  String get whiteboardSaveNoteFailed => 'Gagal menyimpan catatan';

  @override
  String get whiteboardSavedAsNote => 'Tersimpan sebagai catatan';

  @override
  String get whiteboardLeaveTitle => 'Tinggalkan papan ini?';

  @override
  String get whiteboardLeaveBody =>
      'Coretannya belum disimpan, dan tidak bisa dikembalikan.';

  @override
  String get whiteboardKeepDrawing => 'Kembali menggambar';

  @override
  String get whiteboardLeave => 'Tinggalkan';

  @override
  String get whiteboardTitle => 'Papan tulis';

  @override
  String whiteboardSheetStatus(int page, int count, String orientation) {
    return 'Lembar $page dari $count · kertas $orientation';
  }

  @override
  String get whiteboardFreehand => 'Tangan bebas';

  @override
  String whiteboardShape(String shape) {
    return 'Bangun: $shape';
  }

  @override
  String get whiteboardFingerOn =>
      'Jari + stylus boleh menggambar — ketuk untuk hanya stylus';

  @override
  String get whiteboardStylusOnly =>
      'Stylus saja — sentuhan tangan tidak menggambar apa pun';

  @override
  String get whiteboardBackToWriting => 'Kembali menulis';

  @override
  String get whiteboardEraserHint => 'Penghapus — sapukan di atas goresan';

  @override
  String get whiteboardEraser => 'Penghapus';

  @override
  String get whiteboardPortraitTurn =>
      'Kertas tegak — ketuk untuk memutar jadi mendatar';

  @override
  String get whiteboardLandscapeTurn =>
      'Kertas mendatar — ketuk untuk memutar jadi tegak';

  @override
  String get notesUndo => 'Urungkan';

  @override
  String get notesRedo => 'Ulangi';

  @override
  String get whiteboardClearSheet => 'Kosongkan lembar ini';

  @override
  String get notesShareAsPdf2 => 'Bagikan sebagai PDF';

  @override
  String get whiteboardSaveAsNote => 'Simpan sebagai catatan';

  @override
  String get whiteboardSavePdf => 'Simpan PDF';

  @override
  String get whiteboardSheet => 'Lembar';

  @override
  String get whiteboardStrokeWidth => 'Tebal goresan';

  @override
  String get notesPenColor => 'Warna pena';

  @override
  String get markdownMermaidStart => 'Mulai';

  @override
  String get markdownMermaidDone => 'Sudah?';

  @override
  String get markdownMermaidYes => 'ya';

  @override
  String get markdownMermaidFinish => 'Selesai';

  @override
  String get markdownMermaidNo => 'belum';

  @override
  String get notebookHandwritingAlt => 'tulisan tangan';

  @override
  String notebookPageAlt(int number) {
    return 'Halaman $number';
  }

  @override
  String get notebookErrUnknownContent => 'Isi berkas catatan tidak dikenali';

  @override
  String notebookErrNewerFormat(int version) {
    return 'Catatan ini ditulis versi ReadPaper yang lebih baru (format $version). Perbarui aplikasinya dulu supaya isinya tidak rusak.';
  }

  @override
  String get notebookImageMissing => 'gambar hilang';

  @override
  String get notebookDragMove => 'Seret untuk memindahkan';

  @override
  String get notebookDragResize => 'Seret untuk mengubah ukuran';

  @override
  String get notebookDragRotate => 'Seret untuk memutar';

  @override
  String get notebookTapSecond => 'Sekarang ketuk benda yang kedua.';

  @override
  String get notebookNewText => 'Teks baru';

  @override
  String get notebookTextHint => 'Tulis teksnya';

  @override
  String get notebookNewDiagram => 'Diagram baru';

  @override
  String get notebookMermaidSource => 'Sumber Mermaid';

  @override
  String get notebookPickImage => 'Pilih gambar untuk catatan';

  @override
  String get notebookImagePlaced =>
      'Gambar ditaruh — sekarang bisa digeser, diubah ukuran, atau dihapus.';

  @override
  String get notebookEditText => 'Ubah teks';

  @override
  String get notebookEditDiagram => 'Ubah diagram';

  @override
  String get notebookPickPdf => 'Pilih PDF untuk disisipkan sebagai lembar';

  @override
  String notebookPreparingSheets(String name) {
    return 'Menyiapkan lembar dari $name…';
  }

  @override
  String get notebookPdfNoPages =>
      'PDF itu tidak punya halaman yang bisa dibaca.';

  @override
  String notebookSheetsInserted(int count, String name) {
    return '$count lembar disisipkan dari $name.';
  }

  @override
  String notebookInsertPdfFailed(String error) {
    return 'Gagal menyisipkan PDF: $error';
  }

  @override
  String notebookMarkdownSaved(String name) {
    return 'Markdown tersimpan: $name';
  }

  @override
  String notebookMarkdownFailed(String error) {
    return 'Gagal menulis Markdown: $error';
  }

  @override
  String get notebookSaveToCollectionFailed => 'Gagal menyimpan ke koleksi';

  @override
  String get notebookSavedToCollection => 'Masuk ke koleksi catatan';

  @override
  String get notebookUnsavedBody => 'Ada tulisan yang belum disimpan.';

  @override
  String get notebookKeepWriting => 'Kembali menulis';

  @override
  String get notebookDiscard => 'Buang';

  @override
  String notebookStatus(
    int page,
    int count,
    String paper,
    String orientation,
    String tool,
  ) {
    return 'Lembar $page dari $count · $paper $orientation · alat: $tool';
  }

  @override
  String get notebookUnsavedSuffix => ' · belum disimpan';

  @override
  String get notebookZoomOut => 'Perkecil';

  @override
  String get notebookZoomIn => 'Perbesar';

  @override
  String get notebookFit => 'Pas ke layar — kembalikan zum';

  @override
  String get notebookSaveAndShare => 'Simpan dan bagikan';

  @override
  String get notebookSaveAsMarkdown => 'Simpan sebagai Markdown';

  @override
  String get notebookSaveToNoteCollection => 'Simpan ke koleksi catatan';

  @override
  String get notebookGuideLines => 'Garis bantu lembar';

  @override
  String get notebookPlaceText => 'teks';

  @override
  String get notebookPlaceImage => 'gambar';

  @override
  String get notebookPlaceDiagram => 'diagram';

  @override
  String notebookTapToPlace(String what) {
    return 'Ketuk lembar untuk menaruh $what.';
  }

  @override
  String get notebookTapFirstThenSecond =>
      'Ketuk benda pertama, lalu benda kedua.';

  @override
  String notebookPickedCount(int count) {
    return '$count benda dipilih';
  }

  @override
  String get notebookRelease => 'Lepas';

  @override
  String notebookPaperChanged(String paper, int count) {
    return 'Kertas jadi $paper. $count benda sekarang di luar kertas.';
  }

  @override
  String notebookTurned(String orientation) {
    return 'Kertas jadi $orientation — isinya ikut berputar, tidak ada yang keluar tepi.';
  }

  @override
  String notebookIdleTool(String tool) {
    return 'Alat sekarang \"$tool\" — pilih ikon pena untuk menggambar.';
  }

  @override
  String get notebookToolPen => 'Pena';

  @override
  String get notebookToolEraseStroke => 'Hapus goresan';

  @override
  String get notebookToolErasePart => 'Hapus sebagian';

  @override
  String get notebookToolSelect => 'Pilih';

  @override
  String get notebookToolConnectTwo => 'Hubungkan dua benda';

  @override
  String get notebookToolText => 'Teks';

  @override
  String get notebookToolDiagram => 'Diagram';

  @override
  String get notebookToolImage => 'Gambar';

  @override
  String get notebookComponentColor => 'Warna komponen';

  @override
  String get notebookPenWidth => 'Tebal pena';

  @override
  String get notebookEraserSize => 'Ukuran penghapus';

  @override
  String notebookWidthValue(String value) {
    return 'Tebal $value';
  }

  @override
  String notebookEraserValue(String value) {
    return 'Penghapus $value';
  }

  @override
  String get notebookOpacity => 'Kepekatan';

  @override
  String notebookPaperSize(String paper) {
    return 'Ukuran kertas: $paper';
  }

  @override
  String get notebookPortraitTap => 'Kertas tegak — ketuk untuk mendatar';

  @override
  String get notebookLandscapeTap => 'Kertas mendatar — ketuk untuk tegak';

  @override
  String get notebookToolShape => 'Bangun';

  @override
  String get notebookToolConnect => 'Hubungkan';

  @override
  String get notebookFingerOn =>
      'Jari dan stylus sama-sama menggambar. Ketuk untuk hanya stylus — jari lalu dipakai menggeser dan memperbesar saja.';

  @override
  String get notebookStylusOnly =>
      'Stylus menggambar, jari menggeser dan memperbesar. Ketuk untuk mengizinkan jari menggambar lagi.';

  @override
  String get notebookFingerChip => 'Jari + stylus';

  @override
  String get notebookStylusChip => 'Stylus saja';

  @override
  String get notebookPrevSheet => 'Lembar sebelumnya';

  @override
  String get notebookNextSheet => 'Lembar berikutnya';

  @override
  String get notebookNewSheet => 'Lembar kosong baru';

  @override
  String get notebookInsertPdfSheet => 'Sisipkan halaman PDF sebagai lembar';

  @override
  String get notebookDeleteSheet => 'Hapus lembar ini';

  @override
  String get whiteboardErrPngEncode => 'PNG gagal dikodekan';

  @override
  String get whiteboardErrPixels => 'Piksel gagal dibaca';

  @override
  String notesUpTo(String name) {
    return 'Kembali ke $name';
  }

  @override
  String notesSubcollectionSummary(int notes, int subs) {
    String _temp0 = intl.Intl.pluralLogic(
      notes,
      locale: localeName,
      other: '$notes catatan',
      zero: 'kosong',
    );
    String _temp1 = intl.Intl.pluralLogic(
      subs,
      locale: localeName,
      other: ' · $subs sub-koleksi',
      zero: '',
    );
    return '$_temp0$_temp1';
  }

  @override
  String get notesEditDetails => 'Ubah keterangan';

  @override
  String get notesOpen => 'Buka';

  @override
  String get notesPickNote => 'Pilih catatan untuk melihat keterangannya.';

  @override
  String get notesDetails => 'Keterangan';

  @override
  String get notesNoDetails =>
      'Belum ada keterangan. Tambahkan penulis, tanggal, tag, atau sumber supaya catatan ini mudah dikenali dan dicari.';

  @override
  String get notesAddDetails => 'Tambah keterangan';

  @override
  String get notesFieldAuthors => 'Penulis / pengajar';

  @override
  String get notesFieldAuthorsHint => 'Satu nama per baris';

  @override
  String get notesFieldDate => 'Tanggal';

  @override
  String get notesFieldDateHint => 'mis. 14 Okt 2026, atau Minggu 3';

  @override
  String get notesFieldTags => 'Tag';

  @override
  String get notesFieldTagsHint => 'Pisahkan dengan koma';

  @override
  String get notesFieldSource => 'Sumber';

  @override
  String get notesFieldSourceHint => 'Tautan, mata kuliah, atau acara';

  @override
  String get notesFieldDescription => 'Uraian';

  @override
  String get notesFieldCollections => 'Koleksi';

  @override
  String get notesFieldAdded => 'Ditambahkan';

  @override
  String get notesFieldModified => 'Diubah';

  @override
  String get notesFieldFile => 'Berkas';

  @override
  String get notesMoreActions => 'Tindakan lain';

  @override
  String get notesBackToList => 'Kembali ke daftar';

  @override
  String officeUnreadable(String error) {
    return 'Dokumen ini tidak bisa dibaca: $error';
  }

  @override
  String get officeEmpty => 'Dokumennya kosong.';

  @override
  String get officeTextSmaller => 'Perkecil teks';

  @override
  String get officeTextLarger => 'Perbesar teks';

  @override
  String get officeOpenExact =>
      'Tampilan persis — ubah ke PDF lewat LibreOffice, lalu bisa dicari, ditandai, dan disajikan';

  @override
  String officeConvertFailed(String error) {
    return 'LibreOffice gagal mengubahnya ke PDF: $error';
  }

  @override
  String get officeTextOnly =>
      'Format Office lama: hanya teksnya yang terbaca di sini. Untuk tampilan lengkap, buka di aplikasi Office.';

  @override
  String get officeTextOnlyWithExact =>
      'Format Office lama: hanya teksnya yang terbaca di sini. Tombol PDF di atas menampilkannya persis, lewat LibreOffice.';

  @override
  String officeSlideN(int number) {
    return 'Slide $number';
  }

  @override
  String get officeSpeakerNotes => 'Catatan pembicara';

  @override
  String get officePlay => 'Putar presentasi';

  @override
  String get officeOpenAsPdf =>
      'Buka sebagai PDF — mode menyajikan, mode baca, tandai';

  @override
  String get officeSaveAsPdf => 'Simpan sebagai PDF…';

  @override
  String get officeMakingPdf => 'Membuat PDF…';

  @override
  String officeMakingPdfSlides(int done, int total) {
    return 'Membuat PDF… slide $done dari $total';
  }

  @override
  String get officePdfSaved => 'PDF tersimpan.';

  @override
  String get officePdfNotSaved => 'PDF tidak disimpan.';

  @override
  String officePdfFailed(String error) {
    return 'Gagal membuat PDF: $error';
  }

  @override
  String get officeSaveOriginal => 'Simpan berkas asli…';

  @override
  String get officeOriginalSaved => 'Berkas asli tersimpan.';

  @override
  String get officeOriginalNotSaved => 'Berkas asli tidak disimpan.';

  @override
  String officeOriginalFailed(String error) {
    return 'Gagal menyimpan berkas asli: $error';
  }

  @override
  String get officeDownload => 'Unduh…';

  @override
  String officeDownloadOriginal(String ext) {
    return 'Berkas asli ($ext)';
  }

  @override
  String get officeDownloadPdf => 'Sebagai PDF';

  @override
  String get presenterAudienceWaiting => 'Menunggu presenter…';

  @override
  String presenterSlideOf(int page, int total) {
    return 'Slide $page dari $total';
  }

  @override
  String get presenterResetTimer =>
      'Waktu berjalan — ketuk untuk mengulang dari nol';

  @override
  String get presenterNextSlide => 'Slide berikutnya';

  @override
  String get presenterLastSlide => 'Ini slide terakhir';

  @override
  String get presenterNotes => 'Catatan presenter (hanya terlihat di sini)';

  @override
  String get presenterNotesHint => 'Tulis catatan untuk slide ini…';

  @override
  String get presenterBlank => 'Layar hitam';

  @override
  String get presenterFullSlide => 'Slide penuh';

  @override
  String get presenterStopAudience => 'Tutup layar audiens';

  @override
  String get presenterOpenAudience =>
      'Tampilkan di layar lain (monitor kedua / proyektor)';

  @override
  String get presenterShowPanel => 'Tampilkan panel presenter';

  @override
  String get presenterNoExternalDisplay =>
      'Tidak ada layar eksternal. Sambungkan monitor/proyektor (HDMI, USB-C) atau cast layar, lalu coba lagi.';

  @override
  String get presenterAudienceOpened =>
      'Layar audiens terbuka — tekan F11 di jendela itu bila belum layar penuh';

  @override
  String get presenterAudienceClosed => 'Layar audiens ditutup';

  @override
  String presenterNotesSaveFailed(String error) {
    return 'Catatan presenter gagal disimpan: $error';
  }

  @override
  String presenterNotesChanged(String title) {
    return 'Catatan presenter: $title';
  }

  @override
  String get presenterPointer => 'Penunjuk';

  @override
  String get presenterPointerTrail => 'Buntut penunjuk';

  @override
  String get presenterTrailOff => 'Tanpa buntut';

  @override
  String presenterTrailSeconds(String seconds) {
    return '$seconds detik';
  }

  @override
  String get readerStylusOnlyOn =>
      'Stylus saja: tangan yang bertumpu tidak akan menggambar.';

  @override
  String get readerStylusOnlyOff =>
      'Jari dan stylus dua-duanya boleh menggambar.';

  @override
  String get readerCopyNotAllowed => 'Dokumen ini tidak mengizinkan penyalinan';

  @override
  String get readerNothingSelected =>
      'Tidak ada teks terpilih — tekan lama tepat di atas sebuah kata';

  @override
  String get readerEraserOn => 'Penghapus aktif — sapukan di atas coretan';

  @override
  String get readerBackToWriting => 'Kembali menulis';

  @override
  String get readerEraserTooltip =>
      'Penghapus — sapukan di atas coretan yang salah';

  @override
  String get readerEraser => 'Penghapus';

  @override
  String get readerBackToPreviousColor => 'Kembali ke warna sebelumnya';

  @override
  String get readerWhiteInk => 'Tinta putih — menutup coretan';

  @override
  String get readerUndoEraseInk => 'menghapus coretan';

  @override
  String get readerUndoEraseStroke => 'menghapus goresan';

  @override
  String get readerEraserMissed => 'Tidak ada coretan yang tersentuh penghapus';

  @override
  String get readerRedoStroke => 'Ulangi goresan';

  @override
  String get readerNothingToRedo => 'Tidak ada yang bisa diulangi';

  @override
  String get readerTapToPlaceSignature =>
      'Ketuk halaman di tempat tanda tangannya ditaruh';

  @override
  String get readerCannotOverwriteAttachment =>
      'Lampiran library tidak bisa ditimpa — pilih nama lain';

  @override
  String get readerPreparingPdf => 'Menyiapkan PDF…';

  @override
  String get readerSavePdf => 'Simpan PDF';

  @override
  String get readerNotSaved => 'Tidak jadi disimpan';

  @override
  String get readerNoLibraryOpen =>
      'Belum ada library yang terbuka di aplikasi ini.';

  @override
  String get readerUnsavedNotIncluded =>
      'Anotasi yang belum disimpan tidak ikut. Simpan PDF dulu bila perlu.';

  @override
  String get readerAddToCollectionTitle => 'Tambahkan ke koleksi';

  @override
  String get readerNoCollection => 'Tanpa koleksi';

  @override
  String get readerNoCollectionHint =>
      'masuk library, tidak masuk koleksi mana pun';

  @override
  String get readerNewCollectionEllipsis => 'Koleksi baru…';

  @override
  String get readerNewCollectionHint => 'dibuat lalu langsung dipakai';

  @override
  String get readerCreateCollectionFailed => 'Gagal membuat koleksi';

  @override
  String get readerDocumentTitle => 'Judul dokumen';

  @override
  String get readerCancel => 'Batal';

  @override
  String get readerAdd => 'Tambahkan';

  @override
  String get readerAddingToLibrary => 'Menambahkan ke library…';

  @override
  String get readerAddFailed => 'Gagal menambahkan';

  @override
  String get readerNewCollection => 'Koleksi baru';

  @override
  String get readerCollectionName => 'Nama koleksi';

  @override
  String get readerCollectionNameHelper =>
      'Ditulis ke collections.json, ikut tersinkron ke GitHub';

  @override
  String get readerCreate => 'Buat';

  @override
  String get readerReadingPageText => 'Membaca teks halaman…';

  @override
  String get readerPrintWithoutLatest => 'Cetak tanpa anotasi terbaru?';

  @override
  String get readerPrintAsIs => 'Cetak apa adanya';

  @override
  String get readerAddBlankPages => 'Tambah halaman kosong';

  @override
  String get readerPdfSavedAsImages =>
      'PDF ini tidak bisa ditulisi langsung; halamannya disimpan sebagai gambar.';

  @override
  String get readerPreparingFile => 'Menyiapkan berkas…';

  @override
  String get readerNothingSaved => 'Tidak ada yang disimpan';

  @override
  String get readerSaveAnnotatedCopy => 'Simpan salinan beranotasi';

  @override
  String get readerSaveChangesFirst => 'Simpan perubahan dulu?';

  @override
  String get readerUnsavedStrokes =>
      'Ada goresan yang belum disimpan. Kalau keluar sekarang, goresan itu hilang.';

  @override
  String get readerLeaveWithoutSaving => 'Keluar tanpa menyimpan';

  @override
  String get readerSaveEllipsis => 'Simpan…';

  @override
  String get readerSave => 'Simpan';

  @override
  String get readerMarking => 'Menandai';

  @override
  String get readerMark => 'Tandai';

  @override
  String get readerTapToPlaceNote =>
      'Ketuk halaman untuk menaruh catatan (ketuk lagi untuk batal)';

  @override
  String get readerPlaceNote => 'Tempel catatan di halaman';

  @override
  String get readerDoneDrawing => 'Selesai menggambar';

  @override
  String get readerDrawOnPage => 'Tulis atau gambar di halaman';

  @override
  String get readerTapToPlaceText =>
      'Ketuk halaman untuk menaruh teks (ketuk lagi untuk batal)';

  @override
  String get readerFillText => 'Isi teks di halaman — untuk mengisi formulir';

  @override
  String get readerKeepScreenOnActive =>
      'Layar tetap menyala — tekan untuk mematikan';

  @override
  String get readerKeepScreenOn => 'Biarkan layar menyala selama membaca';

  @override
  String get readerKeepScreenOnEnabled =>
      'Layar akan tetap menyala selama membaca';

  @override
  String get readerKeepScreenOnDisabled => 'Layar kembali mati sendiri';

  @override
  String get readerPresent => 'Sajikan — satu halaman penuh layar';

  @override
  String get readerNothingToUndo => 'Belum ada yang bisa diurungkan';

  @override
  String get readerNothingToRedoYet => 'Belum ada yang bisa diulangi';

  @override
  String get readerSignature => 'Tanda tangan';

  @override
  String get readerSaveAndShare => 'Simpan dan bagikan';

  @override
  String get readerAddToCollectionMenu => 'Tambahkan ke koleksi…';

  @override
  String get readerAddToCollectionMenuHint =>
      'masuk library dan ikut tersinkron';

  @override
  String get readerPrintMenu => 'Cetak…';

  @override
  String get readerPrintMenuHint => 'ke pencetak, atau simpan sebagai PDF';

  @override
  String get readerToMarkdown => 'Ubah ke Markdown';

  @override
  String get readerToMarkdownHint => 'teksnya jadi dokumen yang bisa disunting';

  @override
  String get readerToNotebook => 'Jadikan buku catatan';

  @override
  String get readerToNotebookHint =>
      'halamannya jadi alas, bisa disunting lagi';

  @override
  String get readerBlankPagesMenuHint => 'papan tulis di akhir dokumen';

  @override
  String get readerSaveMenuHintNew => 'pilih nama dan tempat; yang asli aman';

  @override
  String get readerSaveAsMenu => 'Simpan sebagai…';

  @override
  String get readerSaveAsMenuHint => 'nama atau tempat lain';

  @override
  String get readerExportPagesMenu => 'Ekspor halaman…';

  @override
  String get readerExportPagesMenuHint => 'PDF, PNG, atau JPG';

  @override
  String get readerShare => 'Bagikan';

  @override
  String get readerShareHint => 'chat, surel, atau aplikasi lain';

  @override
  String get readerStylusOnlyTooltip =>
      'Stylus saja — sentuhan tangan tidak menggambar';

  @override
  String get readerFingerAndStylusTooltip =>
      'Jari + stylus boleh menggambar — ketuk untuk stylus saja';

  @override
  String get readerAddBlankSheet => 'Tambah lembar kosong';

  @override
  String get readerReadMode => 'Mode baca — sembunyikan semua bilah';

  @override
  String get readerSaveAnnotatedCopyFormats =>
      'Simpan salinan beranotasi (PNG, JPG, PDF)';

  @override
  String get readerZoomOut => 'Perkecil';

  @override
  String get readerZoomIn => 'Perbesar';

  @override
  String get readerAnnotationPanel => 'Panel anotasi';

  @override
  String get readerGotIt => 'Mengerti';

  @override
  String get readerDone => 'Selesai';

  @override
  String get readerUndoLastStroke => 'Urungkan goresan terakhir';

  @override
  String get readerDiscardStrokes => 'Buang semua goresan yang belum disimpan';

  @override
  String get readerTapWhereNote =>
      'Ketuk tempat di halaman untuk menaruh catatan.';

  @override
  String get readerPreviousPage => 'Halaman sebelumnya';

  @override
  String get readerNextPage => 'Halaman berikutnya';

  @override
  String get readerFingerAndStylusShort =>
      'Jari + stylus — ketuk untuk stylus saja';

  @override
  String get readerFitPage => 'Pas satu halaman ke layar';

  @override
  String get readerScribble => 'Coret-coret di halaman';

  @override
  String get readerUndo => 'Urungkan';

  @override
  String get readerSaveChooseTooltip => 'Simpan… (pilih nama dan tempat)';

  @override
  String get readerAddScribbleSheet => 'Tambah lembar kosong untuk dicoreti';

  @override
  String get readerExitPresent => 'Keluar dari mode menyajikan';

  @override
  String get readerExitReadMode => 'Keluar dari mode baca';

  @override
  String get readerClipboardFallback => 'Anotasi ReadPaper';

  @override
  String get readerClipboardEmpty =>
      'Papan klip tidak berisi gambar atau anotasi';

  @override
  String get readerPasteImageUnsupported =>
      'Menempel gambar belum bisa di perangkat ini — pakai \"Pilih berkas gambar\"';

  @override
  String get readerClipboardNoImage =>
      'Papan klip tidak berisi gambar. Di peramban: klik kanan gambar → Salin gambar.';

  @override
  String get readerChooseImage => 'Pilih gambar';

  @override
  String get readerPreparingImage => 'Menyiapkan gambar…';

  @override
  String get readerNotAnImage =>
      'Isi papan klip atau berkasnya bukan gambar yang bisa dibaca';

  @override
  String get readerUndoPasteImage => 'menempel gambar';

  @override
  String get readerInsertImage => 'Sisipkan gambar';

  @override
  String get readerPasteImage => 'Tempel gambar dari papan klip';

  @override
  String get readerPasteImageHint =>
      'mis. \"Salin gambar\" di peramban — Ctrl+V';

  @override
  String get readerChooseImageFile => 'Pilih berkas gambar…';

  @override
  String get readerAnnotationCopied =>
      'Anotasi disalin — buka halaman tujuan, lalu Tempel';

  @override
  String get readerUndoCut => 'memotong anotasi';

  @override
  String get readerAnnotationCut =>
      'Anotasi dipotong — buka halaman tujuan, lalu Tempel';

  @override
  String get readerUndoPaste => 'menempel anotasi';

  @override
  String get readerMoveToPage => 'Pindahkan ke halaman';

  @override
  String get readerMove => 'Pindahkan';

  @override
  String get readerCopy => 'Salin';

  @override
  String get readerCut => 'Potong';

  @override
  String get readerToPage => 'Ke halaman…';

  @override
  String get readerPaste => 'Tempel';

  @override
  String get readerDeselect => 'Batal pilih';

  @override
  String get readerClearClipboard => 'Kosongkan papan klip';

  @override
  String get readerDropOnPage =>
      'Lepaskan di atas halaman untuk memindahkannya';

  @override
  String get readerOutsidePage => 'Di luar halaman';

  @override
  String get readerUndoReshape => 'mengubah bentuk anotasi';

  @override
  String get readerUndoMove => 'memindahkan anotasi';

  @override
  String get readerHighlight => 'Stabilo';

  @override
  String get readerHighlightComment => 'Stabilo + komentar';

  @override
  String get readerUnderline => 'Garis bawah';

  @override
  String get readerText => 'Teks';

  @override
  String get readerComment => 'Komentar';

  @override
  String get readerTextHint => 'Yang ditulis di halaman…';

  @override
  String get readerCommentHint => 'Catatan untuk bagian ini…';

  @override
  String get readerUndoEdit => 'mengubah anotasi';

  @override
  String get readerDeleteAnnotationQuestion => 'Hapus anotasi?';

  @override
  String get readerDelete => 'Hapus';

  @override
  String get readerUndoDelete => 'menghapus anotasi';

  @override
  String get readerAnnotationDeleted => 'Anotasi dihapus';

  @override
  String get readerDeleteFailed => 'Gagal menghapus anotasi';

  @override
  String get readerSaveImageFailed => 'Gagal menyimpan gambar';

  @override
  String get readerSaved => 'Tersimpan';

  @override
  String get readerChangesSaved => 'Perubahan tersimpan';

  @override
  String get readerAddedNotSaved => 'Ditambahkan — belum disimpan ke berkas';

  @override
  String get readerAdded => 'Ditambahkan';

  @override
  String get readerSaveAnnotationFailed => 'Gagal menyimpan anotasi';

  @override
  String get readerEditNote => 'Sunting catatan';

  @override
  String get readerCloseNote => 'Tutup catatan';

  @override
  String get readerDragToMove => 'Seret untuk memindahkan';

  @override
  String get readerDragToResize => 'Seret untuk mengubah ukuran';

  @override
  String get readerDragToRotate => 'Seret untuk memutar';

  @override
  String get readerEditCommentColor => 'Ubah komentar / warna';

  @override
  String get readerDpiScreen => 'Layar (72 dpi)';

  @override
  String get readerDpiGood => 'Baik (144 dpi)';

  @override
  String get readerDpiPrint => 'Cetak (288 dpi)';

  @override
  String get readerFormat => 'Format';

  @override
  String get readerDensity => 'Kerapatan';

  @override
  String get readerWholeDocument => 'Seluruh dokumen';

  @override
  String get readerJumpToPage => 'Lompat ke halaman';

  @override
  String get readerPage => 'Halaman';

  @override
  String get readerGo => 'Pergi';

  @override
  String get readerTableOfContents => 'Daftar isi';

  @override
  String get readerNoTableOfContents => 'Berkas ini tidak membawa daftar isi.';

  @override
  String get readerUntitled => '(tanpa judul)';

  @override
  String get readerTintNormal => 'Normal';

  @override
  String get readerTintSepia => 'Sepia';

  @override
  String get readerTintDim => 'Redup';

  @override
  String get readerTintInvert => 'Balik warna';

  @override
  String get readerSaveInFolder => 'Simpan di folder';

  @override
  String get readerFileNameTaken => 'Nama berkas sudah dipakai';

  @override
  String get readerNo => 'Tidak';

  @override
  String get readerYesOverwrite => 'Ya, timpa';

  @override
  String get readerSaveAs => 'Simpan sebagai';

  @override
  String get readerFileName => 'Nama berkas';

  @override
  String get readerSaveIn => 'Simpan di';

  @override
  String get readerChooseOtherFolder => 'Pilih folder lain…';

  @override
  String get readerOtherPlace => 'Tempat lain…';

  @override
  String get readerClearSelection => 'Batalkan pilihan';

  @override
  String get readerSignatureHint =>
      'Tulis di sini, lalu ketuk halaman untuk menaruhnya.';

  @override
  String get readerClear => 'Bersihkan';

  @override
  String get readerUse => 'Pakai';

  @override
  String get readerErrSourceMissing => 'Berkas asalnya tidak ada';

  @override
  String get readerErrPdfUnreadable => 'PDF-nya tidak bisa dibaca';

  @override
  String get readerErrPageCopy => 'Halaman aslinya tidak bisa disalin';

  @override
  String get readerErrBlankPage => 'Halaman kosongnya tidak bisa dibuat';

  @override
  String get readerErrFileMissing => 'Berkasnya tidak ada';

  @override
  String get readerErrPdfWrite => 'PDF-nya gagal ditulis';

  @override
  String get readerErrPdfOpen => 'PDF-nya tidak bisa dibuka';

  @override
  String get readerErrPageRewrite => 'Isi halaman gagal ditulis ulang';

  @override
  String get readerErrRender => 'Halaman gagal dirender';

  @override
  String get readerErrPngEncode => 'PNG gagal dikodekan';

  @override
  String get readerErrPixels => 'Piksel gagal dibaca';

  @override
  String readerLoadAnnotationsFailed(String error) {
    return 'Gagal membaca anotasi: $error';
  }

  @override
  String readerNoteAnnotationsUnreadable(String error) {
    return 'Anotasi catatan ini tidak terbaca: $error';
  }

  @override
  String readerCharactersCopied(int count) {
    return '$count karakter disalin';
  }

  @override
  String readerRedoStep(String step) {
    return 'Ulangi: $step';
  }

  @override
  String readerPageColorInverted(String color) {
    return 'Warna halaman: $color — warna penanda ikut terbalik';
  }

  @override
  String readerPageColor(String color) {
    return 'Warna halaman: $color';
  }

  @override
  String readerResumedAtPage(int page) {
    return 'Dilanjutkan di halaman $page';
  }

  @override
  String readerUndone(String step) {
    return 'Diurungkan: $step';
  }

  @override
  String readerRedone(String step) {
    return 'Diulangi: $step';
  }

  @override
  String readerOriginalFolder(String folder) {
    return 'Folder berkas aslinya ($folder)';
  }

  @override
  String readerSavedFile(String name, String size) {
    return 'Tersimpan: $name ($size)';
  }

  @override
  String readerSaveFailed(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String readerPdfSaved(String size) {
    return 'PDF disimpan ($size)';
  }

  @override
  String get readerAddToCollectionExplain =>
      'Berkasnya disalin ke dalam library, dibuatkan item Zotero, lalu di-commit — jadi ikut tersinkron ke GitHub.';

  @override
  String readerNewSubcollectionIn(String name) {
    return 'Sub-koleksi baru di dalam $name';
  }

  @override
  String readerAddedButAnnotationsFailed(String error) {
    return 'Masuk library, tetapi anotasinya gagal disalin: $error';
  }

  @override
  String readerAddedAs(String key) {
    return 'Masuk library sebagai $key';
  }

  @override
  String readerAddedWithAnnotations(String key, int count) {
    return 'Masuk library sebagai $key beserta $count anotasi — terbaca juga di Zotero setelah dikirim';
  }

  @override
  String readerPreparingNotebook(String title) {
    return 'Menyiapkan buku catatan dari $title…';
  }

  @override
  String readerNotebookFailed(String error) {
    return 'Gagal membuat buku catatan: $error';
  }

  @override
  String readerSubcollectionIn(String name) {
    return 'Sub-koleksi di $name';
  }

  @override
  String get readerNoTextLayer =>
      'PDF ini tidak punya lapisan teks — kemungkinan hasil pindaian. Yang keluar hanya judulnya.';

  @override
  String readerMarkdownFailed(String error) {
    return 'Gagal mengubah ke Markdown: $error';
  }

  @override
  String get readerPrintExplain =>
      'Ada anotasi yang belum menyatu dengan halaman, jadi belum akan ikut tercetak. Simpan PDF dulu kalau anotasinya perlu ikut.';

  @override
  String readerPrintFailed(String error) {
    return 'Gagal mencetak: $error';
  }

  @override
  String get readerBlankPagesExplain =>
      'Seukuran halaman pertamanya. Berkas aslinya tidak disentuh — yang berubah adalah salinan kerja, sampai Anda menyimpannya.';

  @override
  String readerPagesAfter(int count, int page) {
    return '$count halaman setelah halaman $page';
  }

  @override
  String readerPagesAtEnd(int count) {
    return '$count halaman di akhir dokumen';
  }

  @override
  String readerBlankPagesAdded(int count) {
    return '$count halaman kosong ditambahkan di akhir — simpan lewat menu bagikan';
  }

  @override
  String readerBlankPagesInserted(int count, int page) {
    return '$count halaman kosong disisipkan setelah halaman $page — simpan lewat menu bagikan';
  }

  @override
  String readerAddPagesFailed(String error) {
    return 'Gagal menambah halaman: $error';
  }

  @override
  String readerShareFailed(String error) {
    return 'Gagal membagikan: $error';
  }

  @override
  String readerSavePage(int page) {
    return 'Simpan halaman $page';
  }

  @override
  String readerSaveImageError(String error) {
    return 'Gagal menyimpan gambar: $error';
  }

  @override
  String readerFilesSaved(int count) {
    return '$count berkas disimpan';
  }

  @override
  String readerPreparingPdfPages(int count) {
    return 'Menyiapkan PDF $count halaman…';
  }

  @override
  String readerPdfFailed(String error) {
    return 'Gagal membuat PDF: $error';
  }

  @override
  String readerUnsavedStandalone(String title) {
    return 'Coretan dan anotasi di $title belum disimpan ke berkas. Kalau keluar sekarang, semuanya hilang.';
  }

  @override
  String readerUndoStep(String step) {
    return 'Urungkan: $step';
  }

  @override
  String readerSaveMenuHintTo(String name) {
    return 'ke $name';
  }

  @override
  String readerStatus(int count, int page) {
    return '$count anotasi · halaman $page';
  }

  @override
  String readerStatusOf(int count, int page, int total) {
    return '$count anotasi · halaman $page dari $total';
  }

  @override
  String get readerCoachMark =>
      'Untuk menandai: tekan \"Tandai\", pilih warna, lalu sapukan jari di atas teks — begitu jari diangkat teks langsung berwarna. Untuk menyalin: biarkan \"Tandai\" mati, tekan lama di teks, lalu pilih Salin. Untuk catatan: tekan ikon catatan, lalu ketuk halaman.';

  @override
  String readerMarkingBannerTouch(String color) {
    return 'Sapukan jari di atas teks — lepas jari, langsung ditandai $color. Geser halaman dan salin teks nonaktif; tekan Selesai untuk kembali.';
  }

  @override
  String readerMarkingBannerMouse(String color) {
    return 'Seret mouse di atas teks — lepas tombolnya, langsung ditandai $color. Geser halaman dan salin teks nonaktif; tekan Selesai untuk kembali.';
  }

  @override
  String get readerEraserBanner =>
      'Penghapus: sapukan di atas coretan yang salah — goresan yang tersentuh dibuang utuh.';

  @override
  String get readerPenBanner =>
      'Gambar bebas di halaman dengan jari atau stylus.';

  @override
  String readerPenPending(int count, int page) {
    return '$count goresan di halaman $page — disimpan saat menekan Selesai.';
  }

  @override
  String readerSaveTo(String name) {
    return 'Simpan ke $name';
  }

  @override
  String readerPageNumber(int page) {
    return 'Halaman $page';
  }

  @override
  String readerImagePasted(int page) {
    return 'Gambar ditempel di halaman $page — seret sudutnya untuk mengubah ukuran';
  }

  @override
  String readerPastedOnPage(int page) {
    return 'Ditempel di halaman $page — seret untuk memindahkannya';
  }

  @override
  String readerPageRange(int count) {
    return 'Halaman 1 sampai $count';
  }

  @override
  String readerNoSuchPage(int page, int count) {
    return 'Tidak ada halaman $page — dokumen ini $count halaman';
  }

  @override
  String readerUndoMoveToPage(int page) {
    return 'memindahkan anotasi ke halaman $page';
  }

  @override
  String readerMovedToPage(int page) {
    return 'Dipindah ke halaman $page';
  }

  @override
  String readerPasteOnPage(int page) {
    return 'Tempel di halaman $page';
  }

  @override
  String readerTextOnPage(int page) {
    return 'Isi teks di halaman $page';
  }

  @override
  String readerNoteOnPage(int page) {
    return 'Catatan di halaman $page';
  }

  @override
  String readerAnnotationOnPage(String page) {
    return 'Anotasi halaman $page';
  }

  @override
  String readerUndoAdd(String type) {
    return 'menambah $type';
  }

  @override
  String readerNoteBubbleTitle(String page) {
    return 'Catatan · hal. $page';
  }

  @override
  String readerHighlightColor(String color) {
    return 'Warna stabilo: $color';
  }

  @override
  String readerStrokeWidth(String width) {
    return 'Tebal goresan: $width';
  }

  @override
  String readerOnlyPage(int page) {
    return 'Hanya halaman $page';
  }

  @override
  String readerOnePdfPages(int count) {
    return 'Satu PDF berisi $count halaman';
  }

  @override
  String readerFilesOnePerPage(int count) {
    return '$count berkas, satu per halaman';
  }

  @override
  String get readerExportExplain =>
      'Stabilo, garis bawah, dan coretan ikut tergambar. Berkas aslinya tidak disentuh.';

  @override
  String get readerExportPdfImages =>
      'Halaman disimpan sebagai gambar di dalam PDF, jadi teksnya tidak bisa dicari atau disalin lagi di salinan itu.';

  @override
  String readerExportLarge(int count) {
    return '$count halaman pada kerapatan ini akan makan waktu dan ruang penyimpanan yang tidak sedikit.';
  }

  @override
  String get readerNoAnnotationsYet =>
      'Belum ada anotasi.\n\nPilih teks pada halaman, lalu pilih Stabilo atau Stabilo + komentar.';

  @override
  String readerPageShort(String page) {
    return 'hal. $page';
  }

  @override
  String readerPageMustBeBetween(int count) {
    return 'Halaman harus antara 1 dan $count';
  }

  @override
  String readerOfPages(int count) {
    return 'dari $count';
  }

  @override
  String readerOpenPage(int page) {
    return 'Buka halaman $page';
  }

  @override
  String readerOverwriteOriginal(String name) {
    return '$name adalah berkas yang sedang dibuka. Menimpanya membuat versi aslinya hilang, dan coretannya melebur ke halaman.\n\nTimpa berkas aslinya?';
  }

  @override
  String readerOverwriteExisting(String name) {
    return '$name sudah ada di folder ini.\n\nTimpa dengan yang baru?';
  }

  @override
  String get readerSaveAsExplain =>
      'Berkas yang dibuka tidak disentuh. Setelah ini, Simpan menulis ke berkas baru ini.';

  @override
  String readerOutsideZoteroPalette(String name) {
    return '$name (di luar palet Zotero)';
  }

  @override
  String readerErrCannotRead(String path) {
    return 'Tidak bisa dibaca: $path';
  }

  @override
  String readerErrPageSize(String size) {
    return 'Ukuran halaman tidak masuk akal: $size';
  }

  @override
  String get readerEmbeddedLabel => 'Di dalam PDF · hanya dibaca';

  @override
  String get readerEmbeddedReadOnly =>
      'Anotasi ini tertanam di dalam PDF (dibuat di aplikasi lain); di sini hanya bisa dibaca.';

  @override
  String get tabsLibrary => 'Library';

  @override
  String get tabsClose => 'Tutup tab';

  @override
  String get tabsCloseOthers => 'Tutup tab lain';

  @override
  String get tabsMoveRight => 'Pindah ke panel kanan';

  @override
  String get tabsMoveLeft => 'Pindah ke panel kiri';

  @override
  String get tabsSplitHint =>
      'Seret tab ke sini, atau pilih \"Pindah ke panel kanan\", untuk membaca dua dokumen berdampingan';

  @override
  String get tabsBarToTop => 'Pindahkan bilah tab ke atas';

  @override
  String get tabsBarToBottom => 'Pindahkan bilah tab ke bawah';

  @override
  String get tabsOpenNew => 'Buka di tab baru';

  @override
  String get tabsOpen => 'Buka';

  @override
  String get tabsOpenRight => 'Buka di panel kanan';

  @override
  String workspaceSwitchRepoCount(int count) {
    return 'Ganti repositori ($count tersedia)';
  }

  @override
  String workspaceAddAnotherRepo(String remote) {
    return '$remote — tambah repositori lain';
  }

  @override
  String get workspaceManageRepos => 'Kelola repositori…';

  @override
  String get workspaceSwitchLibrary => 'Ganti library';

  @override
  String get workspaceFetchingLibrary => 'Mengambil…';

  @override
  String get workspaceFetchLibrary => 'Ambil library';

  @override
  String syncPullCount(int count) {
    return 'Tarik $count commit baru';
  }

  @override
  String get syncPull => 'Tarik perubahan';

  @override
  String get syncMenu => 'Sinkronisasi';

  @override
  String get syncCheck => 'Periksa perubahan';

  @override
  String get syncSend => 'Kirim perubahan';

  @override
  String get syncDetails => 'Detail sinkronisasi';

  @override
  String get syncCheckRemote => 'Periksa perubahan di remote';

  @override
  String get syncSendToGitHub => 'Kirim perubahan ke GitHub';

  @override
  String get syncBusyWait =>
      'Sinkronisasi sedang berjalan, tunggu sampai selesai.';

  @override
  String syncBusyPhaseWait(String phase) {
    return '$phase Tunggu sampai selesai.';
  }

  @override
  String get syncNothingToSend => 'Tidak ada perubahan untuk dikirim.';

  @override
  String syncTooltipBranch(String branch) {
    return 'Branch: $branch';
  }

  @override
  String syncTooltipLastCommit(String subject) {
    return 'Commit terakhir: $subject';
  }

  @override
  String syncTooltipLastSync(String time) {
    return 'Sinkron terakhir: $time';
  }

  @override
  String get workspaceReadingLibrary => 'Membaca library dari berkas…';

  @override
  String get syncCommitMessage => 'Pesan commit';

  @override
  String get syncCommitAndSend => 'Commit & kirim';

  @override
  String get workspaceCancel => 'Batal';

  @override
  String get workspaceAccessSshHttps => 'lewat SSH atau HTTPS';

  @override
  String get workspaceAccessToken => 'lewat token GitHub';

  @override
  String get workspaceNoRepoTitle => 'Belum ada repositori';

  @override
  String workspaceNoRepoBody(String access) {
    return 'ReadPaper membaca library Zotero yang disinkronkan ke GitHub oleh plugin zotero-github-sync. Tambahkan repositori ($access) untuk mulai membaca, menandai dan memberi komentar pada paper.';
  }

  @override
  String get workspaceAddRepo => 'Tambah repositori';

  @override
  String workspaceFetchLibraryNamed(String name) {
    return 'Ambil library \"$name\"';
  }

  @override
  String workspaceCloneNamed(String name) {
    return 'Clone \"$name\"';
  }

  @override
  String get workspaceResumeNote =>
      'Unduhan sebelumnya terputus. Melanjutkan hanya mengambil berkas yang belum sempat tersimpan.';

  @override
  String get workspaceLazyNote =>
      'Metadata library diunduh sekarang; berkas PDF menyusul saat papernya dibuka.';

  @override
  String workspaceWillSaveAt(String path) {
    return 'Akan disimpan di $path';
  }

  @override
  String get workspaceCheckConnection => 'Periksa koneksi';

  @override
  String get workspaceEditProfile => 'Ubah profil';

  @override
  String get workspaceDownloading => 'Mengunduh…';

  @override
  String get workspaceCloning => 'Meng-clone…';

  @override
  String get workspaceResume => 'Lanjutkan';

  @override
  String get workspaceFetchNow => 'Ambil sekarang';

  @override
  String get workspaceCloneNow => 'Clone sekarang';

  @override
  String get workspaceLibraryUnreadableTitle => 'Library tidak terbaca';

  @override
  String get workspaceLibraryUnreadableBody =>
      'Repositori sudah ada di lokal tetapi tidak ditemukan struktur Zotero (collections.json dan folder items/). Pastikan repositori memang hasil ekspor plugin Zotero GitHub Sync, lalu tarik perubahan terbaru.';

  @override
  String get workspaceReload => 'Baca ulang';

  @override
  String get workspacePull => 'Pull';

  @override
  String get workspaceRepository => 'Repositori';

  @override
  String get syncLfsMissing =>
      'git-lfs tidak terpasang; lampiran besar tetap berupa pointer';

  @override
  String get syncLfsPullAll => 'Unduh semua berkas LFS';

  @override
  String syncBranchLine(String branch) {
    return 'branch $branch';
  }

  @override
  String get syncTabChanges => 'Perubahan';

  @override
  String get syncTabHistory => 'Riwayat';

  @override
  String get syncTabLog => 'Log git';

  @override
  String get syncRecloneNotice =>
      'Salinan lokal ini masih menyimpan semua lampiran. Mengambilnya ulang hanya mengunduh metadata; PDF menyusul saat papernya dibuka.';

  @override
  String get syncReclone => 'Ambil ulang';

  @override
  String get syncRecloneTitle => 'Ambil ulang salinan lokal?';

  @override
  String get syncRecloneBody =>
      'Folder lokal dihapus lalu diambil lagi tanpa lampiran. Anotasi yang sudah dikirim ke GitHub tetap aman; yang belum dikirim akan hilang, jadi ini ditolak kalau masih ada perubahan tertunda.';

  @override
  String get syncNoLocalChanges => 'Tidak ada perubahan lokal.';

  @override
  String get syncNoCommits => 'Belum ada commit.';

  @override
  String get syncNoGitOutput => 'Belum ada keluaran git.';

  @override
  String get workspaceManageReposTooltip => 'Kelola repositori';

  @override
  String get workspaceReadingLibraryShort => 'Membaca library…';

  @override
  String get workspaceFillToken => 'Isi token';

  @override
  String get workspaceRetry => 'Coba lagi';

  @override
  String get workspaceClose => 'Tutup';

  @override
  String workspaceTransferRepoNotFetched(String name) {
    return 'Repositori \"$name\" belum diambil ke perangkat ini. Buka sekali dan ambil library-nya, lalu ulangi.';
  }

  @override
  String workspaceTransferLibraryMissing(String name) {
    return 'Library di \"$name\" belum ada di perangkat ini. Buka repositori itu sekali dan ambil library-nya, lalu ulangi.';
  }

  @override
  String get workspaceTransferTitle => 'Ke repositori lain';

  @override
  String get workspaceTransferNoOthers =>
      'Belum ada repositori lain. Tambahkan dulu di pengaturan Repositori.';

  @override
  String get workspaceTransferChange => 'Ganti';

  @override
  String get workspaceTransferMove => 'Pindahkan';

  @override
  String get workspaceTransferCopy => 'Salin';

  @override
  String get workspaceTransferMoveNote =>
      'Dihapus dari repositori ini setelah salinannya utuh di tujuan.';

  @override
  String get workspaceTransferCopyNote =>
      'Yang di sini tetap; tujuan mendapat salinannya.';

  @override
  String get workspaceTransferNotesRoot => 'Akar Catatan';

  @override
  String get workspaceTransferNotesUnfiled => 'Catatan, tanpa koleksi';

  @override
  String get workspaceTransferLibraryRoot => 'Akar library';

  @override
  String get workspaceTransferUnfiled => 'Tanpa koleksi';

  @override
  String get workspaceComputingSize => 'menghitung ukuran…';

  @override
  String get syncPhaseCounting => 'Menghitung objek';

  @override
  String get syncPhaseCompressing => 'Memampatkan objek';

  @override
  String get syncPhaseReceiving => 'Mengunduh objek';

  @override
  String get syncPhaseResolving => 'Menyusun delta';

  @override
  String get syncPhaseWritingFiles => 'Menulis berkas';

  @override
  String get syncPhaseFiltering => 'Mengunduh berkas besar';

  @override
  String get syncPhaseLfs => 'Mengunduh berkas LFS';

  @override
  String get syncPhaseSending => 'Mengirim objek';

  @override
  String get syncPhaseEnumerating => 'Mendata objek';

  @override
  String get workspaceStatsNotFetched => 'belum diambil ke perangkat ini';

  @override
  String workspaceStatsItems(String count) {
    return '$count item';
  }

  @override
  String workspaceStatsCollections(String count) {
    return '$count koleksi';
  }

  @override
  String workspaceStatsAttachments(String size) {
    return 'lampiran $size';
  }

  @override
  String workspaceStatsUnsent(int count) {
    return '$count belum terkirim';
  }

  @override
  String workspaceStatsBehind(int count) {
    return '$count baru di GitHub';
  }

  @override
  String get syncPhaseCloning => 'Meng-clone repositori…';

  @override
  String get syncPhaseFetching => 'Memeriksa perubahan…';

  @override
  String get syncPhasePulling => 'Menarik perubahan…';

  @override
  String get syncPhaseCommitting => 'Menyimpan perubahan…';

  @override
  String get syncPhasePushing => 'Mengirim perubahan…';

  @override
  String get syncChangeNew => 'baru';

  @override
  String get syncChangeAdded => 'ditambah';

  @override
  String get syncChangeModified => 'diubah';

  @override
  String get syncChangeDeleted => 'dihapus';

  @override
  String get syncChangeRenamed => 'dipindah';

  @override
  String get syncStatusNotCloned => 'Belum di-clone';

  @override
  String syncStatusLocalChanges(int count) {
    return '$count perubahan lokal';
  }

  @override
  String syncStatusAhead(int count) {
    return '$count commit belum di-push';
  }

  @override
  String syncStatusBehind(int count) {
    return '$count commit baru di remote';
  }

  @override
  String get syncStatusInSync => 'Sinkron';

  @override
  String get workspaceErrNoZoteroExport =>
      'Tidak menemukan ekspor Zotero di repositori ini. Struktur yang diharapkan: zotero/<library>/collections.json';

  @override
  String workspaceErrReadLibrary(String error) {
    return 'Gagal membaca library: $error';
  }

  @override
  String get workspaceErrNoRemoteUrl =>
      'URL remote belum diisi untuk profil ini.';

  @override
  String get workspaceErrUnsentBeforeReclone =>
      'Masih ada perubahan yang belum dikirim ke GitHub. Kirim dulu, baru ambil ulang.';

  @override
  String workspaceErrDeleteOldCopy(String error) {
    return 'Gagal menghapus salinan lama: $error';
  }

  @override
  String get workspaceErrAnnotationNoLibrary =>
      'Anotasi tidak tersimpan: tidak ada library aktif di aplikasi.';

  @override
  String get workspaceErrAnnotationUnchanged =>
      'Anotasi tidak tersimpan: berkas item tidak berubah.';

  @override
  String workspaceErrAnnotationSave(String error) {
    return 'Anotasi tidak tersimpan: $error';
  }

  @override
  String get workspaceErrAnnotationDeleteNoLibrary =>
      'Anotasi tidak dihapus: tidak ada library aktif.';

  @override
  String workspaceErrAnnotationDelete(String error) {
    return 'Anotasi tidak dihapus: $error';
  }

  @override
  String get workspaceErrPictureNoRepo =>
      'Gambar tidak tersimpan: tidak ada repositori aktif.';

  @override
  String workspaceErrPictureSave(String error) {
    return 'Gambar tidak tersimpan: $error';
  }

  @override
  String workspaceErrPictureDelete(String error) {
    return 'Gambar tidak dihapus: $error';
  }

  @override
  String get workspaceErrNoLibraryForFile =>
      'Tidak ada library aktif untuk menampung berkas ini.';

  @override
  String workspaceErrAddToLibrary(String error) {
    return 'Gagal menambahkan ke library: $error';
  }

  @override
  String get workspaceErrNoLibraryForFolder =>
      'Tidak ada library aktif untuk menampung folder ini.';

  @override
  String workspaceErrImportStopped(String error) {
    return 'Impor folder berhenti: $error';
  }

  @override
  String get workspaceErrNoLibrary => 'Tidak ada library aktif.';

  @override
  String workspaceErrCreateCollection(String error) {
    return 'Gagal membuat koleksi: $error';
  }

  @override
  String get workspaceErrSameRepo => 'Repositori tujuannya sama dengan asal.';

  @override
  String workspaceErrMoveFailed(String error) {
    return 'Gagal memindah: $error';
  }

  @override
  String workspaceErrCopyFailed(String error) {
    return 'Gagal menyalin: $error';
  }

  @override
  String get workspaceErrCollectionGone => 'Koleksinya tidak ada lagi.';

  @override
  String workspaceErrMissingAttachments(int count) {
    return '$count lampiran belum ada di perangkat ini — belum diunduh, atau masih penunjuk Git LFS. Buka papernya sekali supaya PDF-nya diunduh (di desktop: LFS pull), lalu ulangi. Tidak ada yang dipindah: tanpa PDF-nya, paper itu akan tiba kosong.';
  }

  @override
  String workspaceErrChangeCollection(String error) {
    return 'Gagal mengubah koleksi: $error';
  }

  @override
  String get workspaceErrTargetCollectionGone =>
      'Koleksi tujuan tidak ada lagi.';

  @override
  String workspaceErrMove(String error) {
    return 'Gagal memindahkan: $error';
  }

  @override
  String workspaceErrDelete(String error) {
    return 'Gagal menghapus: $error';
  }

  @override
  String workspaceErrDeleteClone(String error) {
    return 'Gagal menghapus clone lokal: $error';
  }

  @override
  String get syncGitCliLabel => 'git (CLI sistem)';

  @override
  String get syncFileAlreadyLocal => 'Berkas sudah ada di lokal';

  @override
  String get syncFileLocationUnknown => 'Lokasi berkas tidak dikenali.';

  @override
  String syncDownloadingFile(String name) {
    return 'Mengunduh $name…';
  }

  @override
  String get syncFileDownloaded => 'Berkas selesai diunduh';

  @override
  String get syncFileNotInRepo => 'Berkas tidak ada di repositori ini.';

  @override
  String get syncDownloadingLfs => 'Mengunduh berkas besar (Git LFS)…';

  @override
  String get syncRemoteReachable => 'Remote terjangkau';

  @override
  String syncConnected(String count) {
    return 'Terhubung · $count branch di remote';
  }

  @override
  String get syncTargetNotEmpty =>
      'Direktori tujuan sudah berisi berkas. Hapus atau pilih lokasi lain.';

  @override
  String get syncCloned => 'Repositori berhasil di-clone';

  @override
  String get syncPreparingMetadata => 'Menyiapkan berkas metadata…';

  @override
  String get syncMetadataReady => 'Metadata siap';

  @override
  String get syncRepoReadyLazy =>
      'Repositori siap. Lampiran diunduh saat papernya dibuka.';

  @override
  String get syncFetchDone => 'Fetch selesai';

  @override
  String get syncPullDone => 'Pull selesai';

  @override
  String syncInterruptedNotAborted(String operation, String backup) {
    return 'Sinkronisasi sebelumnya berhenti di tengah $operation dan tidak bisa dibatalkan otomatis. Keadaannya dicadangkan di $backup.';
  }

  @override
  String syncInterruptedRecovered(String backup) {
    return 'Sinkronisasi yang dulu berhenti di tengah sudah dipulihkan (cadangan: $backup)';
  }

  @override
  String syncConflict(String detail) {
    return 'Perubahan di sini dan di GitHub bentrok dan tidak bisa disatukan otomatis. Tidak ada yang hilang: perubahan lokal tetap di commit-nya$detail.';
  }

  @override
  String get syncRebasedOnGitHub =>
      'Perubahan lokal dipasang di atas versi GitHub';

  @override
  String syncAutoMerged(String files) {
    return 'Digabung otomatis: $files';
  }

  @override
  String syncGitHubCopies(String files) {
    return 'Versi GitHub disimpan sebagai $files';
  }

  @override
  String get syncNothingToCommit => 'Tidak ada perubahan untuk di-commit';

  @override
  String get syncCommitCreated => 'Commit dibuat';

  @override
  String get syncPushDone => 'Push selesai';

  @override
  String get syncLfsSkipped => 'git-lfs tidak terpasang, dilewati';

  @override
  String get syncLfsDownloaded => 'Berkas LFS diunduh';

  @override
  String get syncRemoteUpdated => 'Remote diperbarui';

  @override
  String syncGitCannotRun(String error) {
    return 'git tidak dapat dijalankan: $error';
  }

  @override
  String get syncErrSshRejected =>
      'SSH ditolak: kunci tidak diterima GitHub. Periksa path kunci di profil.';

  @override
  String get syncErrHttpsAuth =>
      'Autentikasi HTTPS gagal: token kosong atau tidak berlaku.';

  @override
  String get syncErrRepoNotFound =>
      'Repositori tidak ditemukan atau tidak punya akses.';

  @override
  String get syncErrMergeConflict =>
      'Ada konflik saat menggabungkan perubahan. Selesaikan konflik di repo lokal.';

  @override
  String get syncErrNoNetwork => 'Jaringan tidak tersedia.';

  @override
  String syncErrGitFailed(int code) {
    return 'git gagal (kode $code)';
  }

  @override
  String get syncUnknownUser => '(tidak diketahui)';

  @override
  String get syncErrTreeTooLarge =>
      'Daftar berkas repositori terlalu besar untuk dibaca sekaligus oleh API GitHub.';

  @override
  String syncErrBlobTooLarge(String size) {
    return 'Berkasnya $size MB, di atas batas 100 MB yang diterima API GitHub untuk satu berkas. Kirimkan lewat git biasa di komputer, atau simpan lampirannya di luar repositori.';
  }

  @override
  String syncErrConnectionLost(int attempts) {
    return 'Koneksi ke GitHub terputus dan tidak pulih setelah $attempts percobaan. Unduhan bisa dilanjutkan dari tempatnya berhenti.';
  }

  @override
  String get syncErrTokenRejected =>
      'Token GitHub ditolak. Periksa token di profil repositori.';

  @override
  String get syncErrQuota =>
      'Kuota permintaan GitHub habis. Coba lagi setelah kuota pulih (sekitar satu jam), atau pakai token dengan kuota lebih besar.';

  @override
  String get syncErrSlowDown =>
      'GitHub meminta pengiriman diperlambat karena terlalu banyak berkas beruntun. Tunggu beberapa menit lalu kirim lagi.';

  @override
  String get syncErrForbidden =>
      'Akses ditolak. Token perlu izin \"Contents: read and write\" untuk repositori ini.';

  @override
  String get syncErrNotFound =>
      'Repositori atau berkas tidak ditemukan. Untuk repositori privat, token harus punya akses ke repositori tersebut.';

  @override
  String get syncErrBranchMoved =>
      'Branch di GitHub sudah berubah. Tarik perubahan dulu, lalu kirim ulang.';

  @override
  String get syncErrRejectedNoReason =>
      'GitHub menolak perubahan ini (422), tanpa menyebut alasannya.';

  @override
  String syncErrRejected(String reason) {
    return 'GitHub menolak perubahan ini: $reason';
  }

  @override
  String syncErrStatus(int code) {
    return 'GitHub membalas dengan kode $code.';
  }

  @override
  String syncErrStatusReason(int code, String reason) {
    return 'GitHub membalas dengan kode $code: $reason';
  }

  @override
  String get syncGitHubApiLabel => 'GitHub API';

  @override
  String get syncErrRepoUrlUnknown => 'URL repositori tidak dikenali.';

  @override
  String get syncErrTokenMissing => 'Token GitHub belum diisi.';

  @override
  String syncConnectedAs(String login, String slug, String head, String quota) {
    return 'Terhubung sebagai $login · $slug pada $head$quota';
  }

  @override
  String syncQuotaLeft(String count) {
    return ' · sisa kuota $count';
  }

  @override
  String get syncErrNotGitHubUrl =>
      'URL repositori tidak dikenali sebagai repositori GitHub.';

  @override
  String get syncErrAndroidNeedsToken =>
      'Di Android sinkronisasi memakai token GitHub. Isi token pada profil repositori.';

  @override
  String syncReadingBranch(String branch, String slug) {
    return 'Membaca branch $branch di $slug…';
  }

  @override
  String syncMirrorReady(int files, int attachments) {
    return 'Mirror siap: $files berkas metadata, $attachments lampiran menunggu diunduh saat dibuka';
  }

  @override
  String syncPartialSaved(String error, int count) {
    return '$error $count berkas sudah tersimpan — tekan \"Lanjutkan\" untuk meneruskan.';
  }

  @override
  String get syncUpToDate => 'Sudah paling baru';

  @override
  String syncBehindWaiting(int count) {
    return '$count commit baru menunggu di GitHub';
  }

  @override
  String syncComparing(String head) {
    return 'Membandingkan dengan commit $head…';
  }

  @override
  String get syncNoMetadataChanges => 'Tidak ada perubahan metadata';

  @override
  String syncPullUpdated(int count) {
    return 'Pull selesai: $count berkas diperbarui';
  }

  @override
  String get syncLfsUnsupportedAndroid =>
      'Berkas Git LFS belum didukung pada sinkronisasi Android.';

  @override
  String syncAttachmentsSkippedOnly(int count) {
    return '$count lampiran dilewati; tidak ada perubahan lain untuk dikirim';
  }

  @override
  String syncReadyToSend(int count) {
    return '$count berkas siap dikirim';
  }

  @override
  String syncReadyToSendSkipped(int count, int skipped) {
    return '$count berkas siap dikirim; $skipped lampiran dilewati (kirim lewat git di komputer)';
  }

  @override
  String get syncNothingToSendShort => 'Tidak ada yang perlu dikirim';

  @override
  String get syncErrRemoteNewer =>
      'GitHub sudah punya commit lebih baru. Tarik perubahan dulu, lalu kirim ulang.';

  @override
  String get syncErrQueueOnlyAttachments =>
      'Antrean hanya berisi lampiran; tidak ada yang bisa dikirim lewat jalur ini.';

  @override
  String get syncUploading => 'Mengunggah berkas';

  @override
  String syncSentCount(int count) {
    return 'Terkirim: $count berkas';
  }

  @override
  String syncErrAttachmentNotInRepo(String path) {
    return 'Lampiran tidak ada di repositori: $path';
  }

  @override
  String get syncAllPdfsPresent => 'Semua PDF sudah ada di perangkat';

  @override
  String syncAllPdfsPresentLfs(int count) {
    return 'Semua PDF sudah ada; $count lampiran LFS diambil dari komputer';
  }

  @override
  String syncDownloadingPdfOf(int current, int total, String name) {
    return 'Mengunduh PDF $current dari $total: $name';
  }

  @override
  String syncPdfsDownloadedOffline(int count) {
    return '$count PDF diunduh untuk dibaca offline';
  }

  @override
  String syncMirrorAtCommit(String sha) {
    return 'Mirror pada commit $sha';
  }

  @override
  String get syncErrNotMirrored =>
      'Repositori belum di-mirror di perangkat ini.';

  @override
  String syncRejectedMore(int count) {
    return ' dan $count lainnya';
  }

  @override
  String get syncNothingSent => 'Tidak ada yang terkirim';

  @override
  String syncSentFiles(int count) {
    return '$count berkas terkirim';
  }

  @override
  String syncRejectedSummary(
    String head,
    int count,
    String names,
    String more,
    String reason,
  ) {
    return '$head; $count berkas ditolak GitHub dan tetap menunggu: $names$more. $reason';
  }

  @override
  String get syncResumingMetadata => 'Melanjutkan unduhan metadata';

  @override
  String get syncDownloadingMetadata => 'Mengunduh metadata';

  @override
  String syncErrCorruptDownload(String name) {
    return 'Berkas rusak saat diunduh: $name. Jalankan lagi untuk mengunduh ulang bagian yang gagal.';
  }

  @override
  String get syncErrGitHubUrlUnknown => 'URL repositori GitHub tidak dikenali.';

  @override
  String get syncErrTokenMissingProfile =>
      'Token GitHub belum diisi pada profil repositori.';

  @override
  String get syncInstallGitWindows =>
      'Git for Windows tidak ditemukan. Pasang dari git-scm.com, atau di PowerShell: winget install --id Git.Git -e — lalu tekan Coba lagi.';

  @override
  String get syncInstallGitMac =>
      'git tidak ditemukan. Jalankan di Terminal: xcode-select --install.';

  @override
  String get syncInstallGitLinux =>
      'git tidak ditemukan. Pasang git dan git-lfs — CachyOS/Arch: sudo pacman -S git git-lfs; Debian/Ubuntu: sudo apt install git git-lfs.';

  @override
  String syncStatusRejected(int count) {
    return '$count ditolak GitHub';
  }

  @override
  String get syncErrDecisionUnsupported =>
      'Berkas yang ditolak hanya bisa diatur dari sini untuk repositori yang disinkronkan lewat API GitHub (Android). Dengan git, keluarkan berkasnya dari commit (git rm --cached) dan tambahkan ke .gitignore, atau simpan lewat Git LFS.';

  @override
  String syncFilesExcluded(int count) {
    return '$count berkas dikecualikan: tetap di perangkat ini, tidak dikirim ke GitHub.';
  }

  @override
  String syncFilesIncluded(int count) {
    return '$count berkas ikut dikirim lagi pada Kirim berikutnya.';
  }

  @override
  String syncFilesRetry(int count) {
    return '$count berkas dicoba lagi pada Kirim berikutnya.';
  }

  @override
  String syncFilesRemoved(int count) {
    return '$count berkas dihapus dari perangkat dan dikeluarkan dari antrean kirim.';
  }

  @override
  String syncErrRemoveFile(String name, String reason) {
    return 'Tidak bisa menghapus $name: $reason';
  }

  @override
  String get syncTabExcluded => 'Dikecualikan';

  @override
  String syncTabRejected(int count) {
    return 'Ditolak ($count)';
  }

  @override
  String syncRemoveFilesTitle(int count) {
    return 'Hapus $count berkas dari perangkat?';
  }

  @override
  String get syncRemoveFilesBody =>
      'Berkasnya dihapus dari perangkat ini dan dikeluarkan dari antrean kirim. Ini tidak bisa dibatalkan.';

  @override
  String syncRemoveFilesOnRemote(int count) {
    return '$count di antaranya punya versi lama di GitHub; versi itu ikut terhapus di GitHub pada Kirim berikutnya.';
  }

  @override
  String get syncRemoveFile => 'Hapus dari perangkat';

  @override
  String get syncRejectedIntro =>
      'GitHub menolak berkas berikut — biasanya karena lebih dari 100 MB. Berkas lain sudah terkirim. Untuk setiap berkas, pilih: kecualikan (tetap di perangkat, tidak pernah dikirim), hapus dari perangkat, atau coba kirim lagi.';

  @override
  String get syncFileGone => 'sudah tidak ada di perangkat';

  @override
  String get syncFileOnRemote => 'versi lama ada di GitHub';

  @override
  String get syncFileDecision => 'Pilihan untuk berkas ini';

  @override
  String syncExcludeSelected(int count) {
    return 'Kecualikan ($count)';
  }

  @override
  String syncRemoveSelected(int count) {
    return 'Hapus ($count)';
  }

  @override
  String syncRetrySelected(int count) {
    return 'Coba lagi ($count)';
  }

  @override
  String get syncExcludedTitle => 'Dikecualikan dari sinkronisasi';

  @override
  String get syncExcludedIntro =>
      'Tetap di perangkat ini, tetapi tidak pernah dikirim ke GitHub dan tidak dihitung sebagai perubahan.';

  @override
  String get syncIncludeAgain => 'Sertakan lagi';

  @override
  String get syncExcludeFile => 'Kecualikan (jangan dikirim)';

  @override
  String get syncRetryFile => 'Coba kirim lagi';

  @override
  String get syncSeeRejected => 'Lihat berkas';
}
