import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'ReadPaper'**
  String get appTitle;

  /// No description provided for @languageMenu.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get languageMenu;

  /// No description provided for @languageSystem.
  ///
  /// In id, this message translates to:
  /// **'Ikuti sistem'**
  String get languageSystem;

  /// No description provided for @languageIndonesian.
  ///
  /// In id, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeMenu.
  ///
  /// In id, this message translates to:
  /// **'Tema'**
  String get themeMenu;

  /// No description provided for @themeSystem.
  ///
  /// In id, this message translates to:
  /// **'Ikut sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In id, this message translates to:
  /// **'Terang'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In id, this message translates to:
  /// **'Gelap'**
  String get themeDark;

  /// No description provided for @filesCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get filesCancel;

  /// No description provided for @filesSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get filesSave;

  /// No description provided for @filesCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat'**
  String get filesCreate;

  /// No description provided for @filesDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get filesDelete;

  /// No description provided for @filesRename.
  ///
  /// In id, this message translates to:
  /// **'Ganti nama'**
  String get filesRename;

  /// No description provided for @filesOpen.
  ///
  /// In id, this message translates to:
  /// **'Buka'**
  String get filesOpen;

  /// No description provided for @filesShare.
  ///
  /// In id, this message translates to:
  /// **'Bagikan'**
  String get filesShare;

  /// No description provided for @filesPickWorkFolder.
  ///
  /// In id, this message translates to:
  /// **'Pilih folder kerja'**
  String get filesPickWorkFolder;

  /// No description provided for @filesWorkFolderNotReady.
  ///
  /// In id, this message translates to:
  /// **'Folder kerjanya belum siap. Pilih folder lain lewat ikon folder.'**
  String get filesWorkFolderNotReady;

  /// No description provided for @filesPickFilesToCopy.
  ///
  /// In id, this message translates to:
  /// **'Pilih berkas untuk disalin ke sini'**
  String get filesPickFilesToCopy;

  /// No description provided for @filesCopiedHere.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas disalin ke sini'**
  String filesCopiedHere(int count);

  /// No description provided for @filesNameTaken.
  ///
  /// In id, this message translates to:
  /// **'Sudah ada berkas atau folder bernama itu'**
  String get filesNameTaken;

  /// No description provided for @filesRenameFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengganti nama: {error}'**
  String filesRenameFailed(String error);

  /// No description provided for @filesCannotDeleteRoot.
  ///
  /// In id, this message translates to:
  /// **'Folder kerja itu sendiri tidak bisa dihapus dari sini.'**
  String get filesCannotDeleteRoot;

  /// No description provided for @filesDeleteFolderTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus folder ini?'**
  String get filesDeleteFolderTitle;

  /// No description provided for @filesFolderEmpty.
  ///
  /// In id, this message translates to:
  /// **'Foldernya kosong.'**
  String get filesFolderEmpty;

  /// No description provided for @filesFolderUncountable.
  ///
  /// In id, this message translates to:
  /// **'Isinya tidak bisa dihitung.'**
  String get filesFolderUncountable;

  /// No description provided for @filesFolderDeletesCount.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas di dalamnya ikut terhapus.'**
  String filesFolderDeletesCount(int count);

  /// No description provided for @filesLibraryCopiesUntouched.
  ///
  /// In id, this message translates to:
  /// **'Salinan yang sudah masuk library tidak tersentuh.'**
  String get filesLibraryCopiesUntouched;

  /// No description provided for @filesDeleteCount.
  ///
  /// In id, this message translates to:
  /// **'Hapus {count} berkas'**
  String filesDeleteCount(int count);

  /// No description provided for @filesDeleteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus: {error}'**
  String filesDeleteFailed(String error);

  /// No description provided for @filesDeleteFileTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus berkas ini?'**
  String get filesDeleteFileTitle;

  /// No description provided for @filesDeleteFileBody.
  ///
  /// In id, this message translates to:
  /// **'{name}\n\nDihapus dari folder ini. Salinan yang sudah masuk library tidak tersentuh.'**
  String filesDeleteFileBody(String name);

  /// No description provided for @filesNewBoardTitle.
  ///
  /// In id, this message translates to:
  /// **'Papan tulis baru'**
  String get filesNewBoardTitle;

  /// No description provided for @filesNewBoardBody.
  ///
  /// In id, this message translates to:
  /// **'Berlembar-lembar, bisa dicoreti, lalu disimpan sebagai PDF di folder ini.'**
  String get filesNewBoardBody;

  /// No description provided for @filesPortrait.
  ///
  /// In id, this message translates to:
  /// **'Tegak'**
  String get filesPortrait;

  /// No description provided for @filesLandscape.
  ///
  /// In id, this message translates to:
  /// **'Mendatar'**
  String get filesLandscape;

  /// No description provided for @filesSavedHere.
  ///
  /// In id, this message translates to:
  /// **'{name} tersimpan di folder ini'**
  String filesSavedHere(String name);

  /// No description provided for @filesNewFolderTitle.
  ///
  /// In id, this message translates to:
  /// **'Folder baru'**
  String get filesNewFolderTitle;

  /// No description provided for @filesNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get filesNameLabel;

  /// No description provided for @filesNewMarkdownTitle.
  ///
  /// In id, this message translates to:
  /// **'Berkas Markdown baru'**
  String get filesNewMarkdownTitle;

  /// No description provided for @filesFileNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama berkas'**
  String get filesFileNameLabel;

  /// No description provided for @filesNewNotebookTitle.
  ///
  /// In id, this message translates to:
  /// **'Buku catatan baru'**
  String get filesNewNotebookTitle;

  /// No description provided for @filesHeader.
  ///
  /// In id, this message translates to:
  /// **'Berkas'**
  String get filesHeader;

  /// No description provided for @filesUpOneLevel.
  ///
  /// In id, this message translates to:
  /// **'Naik satu tingkat'**
  String get filesUpOneLevel;

  /// No description provided for @filesCreateHere.
  ///
  /// In id, this message translates to:
  /// **'Buat baru di folder ini'**
  String get filesCreateHere;

  /// No description provided for @filesWhiteboard.
  ///
  /// In id, this message translates to:
  /// **'Papan tulis'**
  String get filesWhiteboard;

  /// No description provided for @filesNotebook.
  ///
  /// In id, this message translates to:
  /// **'Buku catatan'**
  String get filesNotebook;

  /// No description provided for @filesMarkdownFile.
  ///
  /// In id, this message translates to:
  /// **'Berkas Markdown'**
  String get filesMarkdownFile;

  /// No description provided for @filesFolder.
  ///
  /// In id, this message translates to:
  /// **'Folder'**
  String get filesFolder;

  /// No description provided for @filesCopyInTooltip.
  ///
  /// In id, this message translates to:
  /// **'Salin berkas atau folder ke sini — dari mana pun di perangkat'**
  String get filesCopyInTooltip;

  /// No description provided for @filesPickFolderToCopy.
  ///
  /// In id, this message translates to:
  /// **'Pilih folder untuk disalin ke sini'**
  String get filesPickFolderToCopy;

  /// No description provided for @filesCopyFiles.
  ///
  /// In id, this message translates to:
  /// **'Salin berkas…'**
  String get filesCopyFiles;

  /// No description provided for @filesCopyFolder.
  ///
  /// In id, this message translates to:
  /// **'Salin folder (beserta isinya)…'**
  String get filesCopyFolder;

  /// No description provided for @filesOpenOtherFolder.
  ///
  /// In id, this message translates to:
  /// **'Buka folder lain'**
  String get filesOpenOtherFolder;

  /// No description provided for @filesEmptyFolderHint.
  ///
  /// In id, this message translates to:
  /// **'Folder ini kosong.\n\nBuat papan tulis, atau salin PDF ke sini dengan tombol unduh di atas — lalu seret ke sebuah koleksi untuk memasukkannya ke library.'**
  String get filesEmptyFolderHint;

  /// No description provided for @filesFolderActions.
  ///
  /// In id, this message translates to:
  /// **'Tindakan folder'**
  String get filesFolderActions;

  /// No description provided for @filesDeleteFolder.
  ///
  /// In id, this message translates to:
  /// **'Hapus folder'**
  String get filesDeleteFolder;

  /// No description provided for @filesFileActions.
  ///
  /// In id, this message translates to:
  /// **'Tindakan berkas'**
  String get filesFileActions;

  /// No description provided for @filesDeleteFile.
  ///
  /// In id, this message translates to:
  /// **'Hapus berkas'**
  String get filesDeleteFile;

  /// No description provided for @filesCannotOpenExt.
  ///
  /// In id, this message translates to:
  /// **'Berkas {ext} belum bisa dibuka di dalam ReadPaper. Yang bisa: PDF, EPUB, gambar, CSV, dan Excel.'**
  String filesCannotOpenExt(String ext);

  /// No description provided for @filesCannotOpenThis.
  ///
  /// In id, this message translates to:
  /// **'Berkas ini belum bisa dibuka di dalam ReadPaper. Yang bisa: PDF, EPUB, gambar, CSV, dan Excel.'**
  String get filesCannotOpenThis;

  /// No description provided for @filesNoAppForExt.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada aplikasi di sistem ini yang membuka berkas {ext}.'**
  String filesNoAppForExt(String ext);

  /// No description provided for @filesNoAppForThis.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada aplikasi di sistem ini yang membuka berkas ini.'**
  String get filesNoAppForThis;

  /// No description provided for @filesOpenWithOtherApp.
  ///
  /// In id, this message translates to:
  /// **'Buka dengan aplikasi lain'**
  String get filesOpenWithOtherApp;

  /// No description provided for @filesTableUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Tabel ini tidak bisa dibaca: {error}'**
  String filesTableUnreadable(String error);

  /// No description provided for @filesNoSheets.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada lembar di berkas ini.'**
  String get filesNoSheets;

  /// No description provided for @filesSheetEmpty.
  ///
  /// In id, this message translates to:
  /// **'Lembar ini kosong.'**
  String get filesSheetEmpty;

  /// No description provided for @filesOnlyFirstRows.
  ///
  /// In id, this message translates to:
  /// **'Hanya {count} baris pertama yang ditampilkan. Buka dengan aplikasi lain untuk melihat semuanya.'**
  String filesOnlyFirstRows(int count);

  /// No description provided for @settingsRepositories.
  ///
  /// In id, this message translates to:
  /// **'Repositori'**
  String get settingsRepositories;

  /// No description provided for @settingsAddRepository.
  ///
  /// In id, this message translates to:
  /// **'Tambah repositori'**
  String get settingsAddRepository;

  /// No description provided for @settingsNoRepositories.
  ///
  /// In id, this message translates to:
  /// **'Belum ada repositori.'**
  String get settingsNoRepositories;

  /// No description provided for @settingsDeleteProfileTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus \"{name}\"?'**
  String settingsDeleteProfileTitle(String name);

  /// No description provided for @settingsDeleteProfileBody.
  ///
  /// In id, this message translates to:
  /// **'Profil akan dihapus dari ReadPaper.'**
  String get settingsDeleteProfileBody;

  /// No description provided for @settingsDeleteCloneToo.
  ///
  /// In id, this message translates to:
  /// **'Hapus juga folder clone lokal'**
  String get settingsDeleteCloneToo;

  /// No description provided for @settingsUrlTransportMismatch.
  ///
  /// In id, this message translates to:
  /// **'URL tidak cocok dengan mode {mode}.'**
  String settingsUrlTransportMismatch(String mode);

  /// No description provided for @settingsMakeActive.
  ///
  /// In id, this message translates to:
  /// **'Jadikan aktif'**
  String get settingsMakeActive;

  /// No description provided for @settingsLicense.
  ///
  /// In id, this message translates to:
  /// **'Perangkat lunak bebas, lisensi AGPL-3.0-or-later.\nKode sumber: github.com/situkangsayur/readpaper'**
  String get settingsLicense;

  /// No description provided for @settingsEditRepository.
  ///
  /// In id, this message translates to:
  /// **'Ubah repositori'**
  String get settingsEditRepository;

  /// No description provided for @settingsRepoUrl.
  ///
  /// In id, this message translates to:
  /// **'URL repositori'**
  String get settingsRepoUrl;

  /// No description provided for @settingsUrlRequired.
  ///
  /// In id, this message translates to:
  /// **'URL tidak boleh kosong'**
  String get settingsUrlRequired;

  /// No description provided for @settingsApiTokenNote.
  ///
  /// In id, this message translates to:
  /// **'Perangkat ini menyinkronkan lewat GitHub API, jadi aksesnya memakai token HTTPS.'**
  String get settingsApiTokenNote;

  /// No description provided for @settingsDisplayName.
  ///
  /// In id, this message translates to:
  /// **'Nama tampilan'**
  String get settingsDisplayName;

  /// No description provided for @settingsNameRequired.
  ///
  /// In id, this message translates to:
  /// **'Nama tidak boleh kosong'**
  String get settingsNameRequired;

  /// No description provided for @settingsSshKeyOptional.
  ///
  /// In id, this message translates to:
  /// **'Kunci privat SSH (opsional)'**
  String get settingsSshKeyOptional;

  /// No description provided for @settingsSshKeyHelper.
  ///
  /// In id, this message translates to:
  /// **'Kosongkan untuk memakai ssh-agent atau kunci bawaan.'**
  String get settingsSshKeyHelper;

  /// No description provided for @settingsGithubUsername.
  ///
  /// In id, this message translates to:
  /// **'Username GitHub'**
  String get settingsGithubUsername;

  /// No description provided for @settingsAccessToken.
  ///
  /// In id, this message translates to:
  /// **'Personal access token'**
  String get settingsAccessToken;

  /// No description provided for @settingsTokenHelper.
  ///
  /// In id, this message translates to:
  /// **'Disimpan terpisah di credentials.json (izin 600).'**
  String get settingsTokenHelper;

  /// No description provided for @settingsLocalCloneFolder.
  ///
  /// In id, this message translates to:
  /// **'Folder clone lokal'**
  String get settingsLocalCloneFolder;

  /// No description provided for @settingsPrivateStorage.
  ///
  /// In id, this message translates to:
  /// **'Data disimpan di penyimpanan privat aplikasi.'**
  String get settingsPrivateStorage;

  /// No description provided for @settingsCommitIdentity.
  ///
  /// In id, this message translates to:
  /// **'Identitas commit'**
  String get settingsCommitIdentity;

  /// No description provided for @settingsNameLabel.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get settingsNameLabel;

  /// No description provided for @settingsAuthorHint.
  ///
  /// In id, this message translates to:
  /// **'kosong = pakai konfigurasi git'**
  String get settingsAuthorHint;

  /// No description provided for @settingsLazyPdfTitle.
  ///
  /// In id, this message translates to:
  /// **'Unduh PDF hanya saat dibuka'**
  String get settingsLazyPdfTitle;

  /// No description provided for @settingsLazyPdfSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Ambil metadata library dulu (puluhan MB); berkas PDF menyusul satu per satu. Matikan kalau ingin semua PDF diunduh sekaligus sesudah ambil dan pull, supaya bisa dibaca offline.'**
  String get settingsLazyPdfSubtitle;

  /// No description provided for @settingsAutoPushTitle.
  ///
  /// In id, this message translates to:
  /// **'Push otomatis setelah menyimpan anotasi'**
  String get settingsAutoPushTitle;

  /// No description provided for @settingsAutoPushSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Setiap highlight/komentar langsung dikirim ke GitHub.'**
  String get settingsAutoPushSubtitle;

  /// No description provided for @settingsPickSshKey.
  ///
  /// In id, this message translates to:
  /// **'Pilih kunci privat SSH'**
  String get settingsPickSshKey;

  /// No description provided for @settingsPickCloneFolder.
  ///
  /// In id, this message translates to:
  /// **'Pilih folder clone'**
  String get settingsPickCloneFolder;

  /// No description provided for @citationRunningAt.
  ///
  /// In id, this message translates to:
  /// **'Berjalan di {address}'**
  String citationRunningAt(String address);

  /// No description provided for @citationOff.
  ///
  /// In id, this message translates to:
  /// **'Mati. Add-in Word dan OnlyOffice tidak bisa tersambung.'**
  String get citationOff;

  /// No description provided for @citationStarting.
  ///
  /// In id, this message translates to:
  /// **'Menyalakan…'**
  String get citationStarting;

  /// No description provided for @citationTitle.
  ///
  /// In id, this message translates to:
  /// **'Sitasi di Word & OnlyOffice'**
  String get citationTitle;

  /// No description provided for @citationSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Server lokal yang dipakai add-in untuk mencari dan menyitasi.'**
  String get citationSubtitle;

  /// No description provided for @citationRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get citationRetry;

  /// No description provided for @citationAddress.
  ///
  /// In id, this message translates to:
  /// **'Alamat'**
  String get citationAddress;

  /// No description provided for @citationCopyAddress.
  ///
  /// In id, this message translates to:
  /// **'Salin alamat'**
  String get citationCopyAddress;

  /// No description provided for @citationAddressCopied.
  ///
  /// In id, this message translates to:
  /// **'Alamat disalin.'**
  String get citationAddressCopied;

  /// No description provided for @citationNoToken.
  ///
  /// In id, this message translates to:
  /// **'Belum ada'**
  String get citationNoToken;

  /// No description provided for @citationHideToken.
  ///
  /// In id, this message translates to:
  /// **'Sembunyikan token'**
  String get citationHideToken;

  /// No description provided for @citationShowToken.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan token'**
  String get citationShowToken;

  /// No description provided for @citationCopyToken.
  ///
  /// In id, this message translates to:
  /// **'Salin token'**
  String get citationCopyToken;

  /// No description provided for @citationTokenCopied.
  ///
  /// In id, this message translates to:
  /// **'Token disalin.'**
  String get citationTokenCopied;

  /// No description provided for @citationNewToken.
  ///
  /// In id, this message translates to:
  /// **'Buat token baru'**
  String get citationNewToken;

  /// No description provided for @citationPasteHint.
  ///
  /// In id, this message translates to:
  /// **'Tempel alamat dan token ini di add-in. Panduannya: docs/api-sitasi.md di repositori ReadPaper.'**
  String get citationPasteHint;

  /// No description provided for @citationNewTokenTitle.
  ///
  /// In id, this message translates to:
  /// **'Buat token baru?'**
  String get citationNewTokenTitle;

  /// No description provided for @citationNewTokenBody.
  ///
  /// In id, this message translates to:
  /// **'Token lama langsung tidak berlaku. Add-in Word dan OnlyOffice yang sudah tersambung harus diberi token baru.'**
  String get citationNewTokenBody;

  /// No description provided for @citationCreateNew.
  ///
  /// In id, this message translates to:
  /// **'Buat baru'**
  String get citationCreateNew;

  /// No description provided for @citationTokenSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Token baru tidak bisa disimpan: {error}'**
  String citationTokenSaveFailed(String error);

  /// No description provided for @citationSettingsUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan server sitasi tidak terbaca: {error}'**
  String citationSettingsUnreadable(String error);

  /// No description provided for @citationPortInUse.
  ///
  /// In id, this message translates to:
  /// **'Port {port} sudah dipakai program lain (mungkin ReadPaper lain yang sedang terbuka). {reason}'**
  String citationPortInUse(int port, String reason);

  /// No description provided for @citationEmptyCollection.
  ///
  /// In id, this message translates to:
  /// **'Koleksi ini belum berisi paper.'**
  String get citationEmptyCollection;

  /// No description provided for @citationBibWritten.
  ///
  /// In id, this message translates to:
  /// **'{count} entri ditulis ke {file} di folder kerja'**
  String citationBibWritten(int count, String file);

  /// No description provided for @citationBibCopied.
  ///
  /// In id, this message translates to:
  /// **'BibTeX disalin — kuncinya {key}'**
  String citationBibCopied(String key);

  /// No description provided for @commonColorYellow.
  ///
  /// In id, this message translates to:
  /// **'Kuning'**
  String get commonColorYellow;

  /// No description provided for @commonColorRed.
  ///
  /// In id, this message translates to:
  /// **'Merah'**
  String get commonColorRed;

  /// No description provided for @commonColorGreen.
  ///
  /// In id, this message translates to:
  /// **'Hijau'**
  String get commonColorGreen;

  /// No description provided for @commonColorBlue.
  ///
  /// In id, this message translates to:
  /// **'Biru'**
  String get commonColorBlue;

  /// No description provided for @commonColorPurple.
  ///
  /// In id, this message translates to:
  /// **'Ungu'**
  String get commonColorPurple;

  /// No description provided for @commonColorMagenta.
  ///
  /// In id, this message translates to:
  /// **'Magenta'**
  String get commonColorMagenta;

  /// No description provided for @commonColorOrange.
  ///
  /// In id, this message translates to:
  /// **'Oranye'**
  String get commonColorOrange;

  /// No description provided for @commonColorGray.
  ///
  /// In id, this message translates to:
  /// **'Abu-abu'**
  String get commonColorGray;

  /// No description provided for @commonColorTeal.
  ///
  /// In id, this message translates to:
  /// **'Tosca'**
  String get commonColorTeal;

  /// No description provided for @commonColorPink.
  ///
  /// In id, this message translates to:
  /// **'Merah muda'**
  String get commonColorPink;

  /// No description provided for @commonColorBrown.
  ///
  /// In id, this message translates to:
  /// **'Cokelat'**
  String get commonColorBrown;

  /// No description provided for @commonColorInk.
  ///
  /// In id, this message translates to:
  /// **'Tinta'**
  String get commonColorInk;

  /// No description provided for @commonColorWhite.
  ///
  /// In id, this message translates to:
  /// **'Putih'**
  String get commonColorWhite;

  /// No description provided for @commonColorBlack.
  ///
  /// In id, this message translates to:
  /// **'Hitam'**
  String get commonColorBlack;

  /// No description provided for @commonColorGrayShort.
  ///
  /// In id, this message translates to:
  /// **'Abu'**
  String get commonColorGrayShort;

  /// No description provided for @commonColorOrangeInk.
  ///
  /// In id, this message translates to:
  /// **'Jingga'**
  String get commonColorOrangeInk;

  /// No description provided for @commonColorLightGreen.
  ///
  /// In id, this message translates to:
  /// **'Hijau muda'**
  String get commonColorLightGreen;

  /// No description provided for @commonColorSkyBlue.
  ///
  /// In id, this message translates to:
  /// **'Biru langit'**
  String get commonColorSkyBlue;

  /// No description provided for @commonColorNavyBlue.
  ///
  /// In id, this message translates to:
  /// **'Biru malam'**
  String get commonColorNavyBlue;

  /// No description provided for @commonFilePickUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Berkas itu tidak bisa dibaca dari tempatnya. Salin dulu ke folder kerja.'**
  String get commonFilePickUnreadable;

  /// No description provided for @commonFilePickerFailed.
  ///
  /// In id, this message translates to:
  /// **'Pemilih berkas gagal dibuka: {error}'**
  String commonFilePickerFailed(String error);

  /// No description provided for @commonFolderPickerFailed.
  ///
  /// In id, this message translates to:
  /// **'Pemilih folder gagal dibuka: {error}'**
  String commonFolderPickerFailed(String error);

  /// No description provided for @commonLinuxPickerHelp.
  ///
  /// In id, this message translates to:
  /// **'Dialog pilih berkas tidak bisa dibuka ({error}). Pasang xdg-desktop-portal beserta backend-nya (mis. xdg-desktop-portal-gtk), atau zenity.'**
  String commonLinuxPickerHelp(String error);

  /// No description provided for @commonShareUnsupported.
  ///
  /// In id, this message translates to:
  /// **'Berbagi berkas belum didukung di sini ({error}). Berkasnya ada di {path}'**
  String commonShareUnsupported(String error, String path);

  /// No description provided for @commonJustNow.
  ///
  /// In id, this message translates to:
  /// **'baru saja'**
  String get commonJustNow;

  /// No description provided for @commonMinutesAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} menit lalu'**
  String commonMinutesAgo(int count);

  /// No description provided for @commonHoursAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} jam lalu'**
  String commonHoursAgo(int count);

  /// No description provided for @commonDaysAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} hari lalu'**
  String commonDaysAgo(int count);

  /// No description provided for @commonWeeksAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} pekan lalu'**
  String commonWeeksAgo(int count);

  /// No description provided for @commonMonthsAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} bulan lalu'**
  String commonMonthsAgo(int count);

  /// No description provided for @commonYearsAgo.
  ///
  /// In id, this message translates to:
  /// **'{count} tahun lalu'**
  String commonYearsAgo(int count);

  /// No description provided for @commonWorkFolder.
  ///
  /// In id, this message translates to:
  /// **'Folder kerja'**
  String get commonWorkFolder;

  /// No description provided for @commonYesterday.
  ///
  /// In id, this message translates to:
  /// **'kemarin'**
  String get commonYesterday;

  /// No description provided for @commonShapeRectangle.
  ///
  /// In id, this message translates to:
  /// **'Kotak'**
  String get commonShapeRectangle;

  /// No description provided for @commonShapeEllipse.
  ///
  /// In id, this message translates to:
  /// **'Bulat'**
  String get commonShapeEllipse;

  /// No description provided for @commonShapeDiamond.
  ///
  /// In id, this message translates to:
  /// **'Belah ketupat'**
  String get commonShapeDiamond;

  /// No description provided for @commonShapeTriangle.
  ///
  /// In id, this message translates to:
  /// **'Segitiga'**
  String get commonShapeTriangle;

  /// No description provided for @commonShapeLine.
  ///
  /// In id, this message translates to:
  /// **'Garis'**
  String get commonShapeLine;

  /// No description provided for @commonShapeArrow.
  ///
  /// In id, this message translates to:
  /// **'Panah'**
  String get commonShapeArrow;

  /// No description provided for @findTooltip.
  ///
  /// In id, this message translates to:
  /// **'Cari di dokumen (Ctrl+F)'**
  String get findTooltip;

  /// No description provided for @findHint.
  ///
  /// In id, this message translates to:
  /// **'Cari kata…'**
  String get findHint;

  /// No description provided for @findSearching.
  ///
  /// In id, this message translates to:
  /// **'Mencari…'**
  String get findSearching;

  /// No description provided for @findNoResults.
  ///
  /// In id, this message translates to:
  /// **'Tidak ditemukan'**
  String get findNoResults;

  /// No description provided for @findCount.
  ///
  /// In id, this message translates to:
  /// **'{current} dari {total}'**
  String findCount(int current, int total);

  /// No description provided for @findPrevious.
  ///
  /// In id, this message translates to:
  /// **'Sebelumnya (Shift+Enter)'**
  String get findPrevious;

  /// No description provided for @findNext.
  ///
  /// In id, this message translates to:
  /// **'Berikutnya (Enter)'**
  String get findNext;

  /// No description provided for @findClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup pencarian (Esc)'**
  String get findClose;

  /// No description provided for @findInChapter.
  ///
  /// In id, this message translates to:
  /// **'Bab {chapter}'**
  String findInChapter(int chapter);

  /// No description provided for @githubLoginButton.
  ///
  /// In id, this message translates to:
  /// **'Masuk dengan GitHub'**
  String get githubLoginButton;

  /// No description provided for @githubLoginButtonHint.
  ///
  /// In id, this message translates to:
  /// **'Tanpa membuat token: masuk lewat browser, lalu pilih atau buat repositori library.'**
  String get githubLoginButtonHint;

  /// No description provided for @githubLoginTitle.
  ///
  /// In id, this message translates to:
  /// **'Masuk dengan GitHub'**
  String get githubLoginTitle;

  /// No description provided for @githubLoginCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get githubLoginCancel;

  /// No description provided for @githubLoginRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get githubLoginRetry;

  /// No description provided for @githubLoginStep1.
  ///
  /// In id, this message translates to:
  /// **'Buka GitHub, masukkan kode ini, lalu tekan Authorize. Kodenya sudah disalin ke papan klip.'**
  String get githubLoginStep1;

  /// No description provided for @githubLoginCopyCode.
  ///
  /// In id, this message translates to:
  /// **'Salin kode'**
  String get githubLoginCopyCode;

  /// No description provided for @githubLoginOpen.
  ///
  /// In id, this message translates to:
  /// **'Buka GitHub'**
  String get githubLoginOpen;

  /// No description provided for @githubLoginWaiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu persetujuan di GitHub…'**
  String get githubLoginWaiting;

  /// No description provided for @githubLoginSignedIn.
  ///
  /// In id, this message translates to:
  /// **'Masuk sebagai {login}'**
  String githubLoginSignedIn(String login);

  /// No description provided for @githubLoginChooseRepo.
  ///
  /// In id, this message translates to:
  /// **'Pilih repositori library:'**
  String get githubLoginChooseRepo;

  /// No description provided for @githubLoginSearchRepo.
  ///
  /// In id, this message translates to:
  /// **'Cari repositori…'**
  String get githubLoginSearchRepo;

  /// No description provided for @githubLoginNoRepos.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada repositori yang bisa ditulisi. Buat yang baru di bawah.'**
  String get githubLoginNoRepos;

  /// No description provided for @githubLoginCreateTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum punya repositorinya?'**
  String get githubLoginCreateTitle;

  /// No description provided for @githubLoginCreateHint.
  ///
  /// In id, this message translates to:
  /// **'ReadPaper membuatkannya di akun GitHub Anda, lengkap dengan README supaya langsung bisa diambil.'**
  String get githubLoginCreateHint;

  /// No description provided for @githubLoginRepoName.
  ///
  /// In id, this message translates to:
  /// **'Nama repositori baru'**
  String get githubLoginRepoName;

  /// No description provided for @githubLoginPrivate.
  ///
  /// In id, this message translates to:
  /// **'Privat (hanya Anda yang bisa melihat)'**
  String get githubLoginPrivate;

  /// No description provided for @githubLoginCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat repositori'**
  String get githubLoginCreate;

  /// No description provided for @githubLoginExpired.
  ///
  /// In id, this message translates to:
  /// **'Kodenya kedaluwarsa sebelum disetujui. Coba lagi.'**
  String get githubLoginExpired;

  /// No description provided for @githubLoginDenied.
  ///
  /// In id, this message translates to:
  /// **'Akses ditolak di GitHub.'**
  String get githubLoginDenied;

  /// No description provided for @githubLoginFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal masuk ke GitHub: {detail}'**
  String githubLoginFailed(String detail);

  /// No description provided for @githubRepoNameTaken.
  ///
  /// In id, this message translates to:
  /// **'Repositori \"{name}\" sudah ada di akun ini, atau namanya tidak valid. Pilih nama lain, atau pilih repositorinya dari daftar di atas.'**
  String githubRepoNameTaken(String name);

  /// No description provided for @githubLoginDone.
  ///
  /// In id, this message translates to:
  /// **'Masuk sebagai {login} — repositori {repo} dipilih. Periksa lalu Simpan.'**
  String githubLoginDone(String login, String repo);

  /// No description provided for @githubLoginChooseAccount.
  ///
  /// In id, this message translates to:
  /// **'Pakai akun yang sudah masuk, atau masuk dengan akun lain:'**
  String get githubLoginChooseAccount;

  /// No description provided for @githubLoginUseAccount.
  ///
  /// In id, this message translates to:
  /// **'Pakai akun {login}'**
  String githubLoginUseAccount(String login);

  /// No description provided for @githubLoginForgetAccount.
  ///
  /// In id, this message translates to:
  /// **'Lupakan akun ini di perangkat ini'**
  String get githubLoginForgetAccount;

  /// No description provided for @githubLoginOtherAccount.
  ///
  /// In id, this message translates to:
  /// **'Masuk dengan akun lain'**
  String get githubLoginOtherAccount;

  /// No description provided for @libraryAddToLibraryTooltip.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan berkas atau folder ke library'**
  String get libraryAddToLibraryTooltip;

  /// No description provided for @libraryAddFiles.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan berkas…'**
  String get libraryAddFiles;

  /// No description provided for @libraryAddFolderAsCollection.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan folder (jadi koleksi)…'**
  String get libraryAddFolderAsCollection;

  /// No description provided for @libraryNewPaperCollection.
  ///
  /// In id, this message translates to:
  /// **'Koleksi paper baru'**
  String get libraryNewPaperCollection;

  /// No description provided for @libraryUnfiled.
  ///
  /// In id, this message translates to:
  /// **'Tanpa koleksi'**
  String get libraryUnfiled;

  /// No description provided for @libraryNotesRoot.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get libraryNotesRoot;

  /// No description provided for @libraryNewNoteCollection.
  ///
  /// In id, this message translates to:
  /// **'Koleksi catatan baru'**
  String get libraryNewNoteCollection;

  /// No description provided for @libraryItemsAndCollections.
  ///
  /// In id, this message translates to:
  /// **'{items} item · {collections} koleksi'**
  String libraryItemsAndCollections(int items, int collections);

  /// No description provided for @libraryIncludeSubOn.
  ///
  /// In id, this message translates to:
  /// **'Sertakan item sub-koleksi: aktif'**
  String get libraryIncludeSubOn;

  /// No description provided for @libraryIncludeSubOff.
  ///
  /// In id, this message translates to:
  /// **'Sertakan item sub-koleksi: nonaktif'**
  String get libraryIncludeSubOff;

  /// No description provided for @libraryCollapseAll.
  ///
  /// In id, this message translates to:
  /// **'Tutup semua'**
  String get libraryCollapseAll;

  /// No description provided for @libraryExpandAll.
  ///
  /// In id, this message translates to:
  /// **'Buka semua'**
  String get libraryExpandAll;

  /// No description provided for @libraryNoNoteCollections.
  ///
  /// In id, this message translates to:
  /// **'Belum ada koleksi catatan. Catatan disimpan di folder tersendiri di dalam repositori, terpisah dari paper.'**
  String get libraryNoNoteCollections;

  /// No description provided for @libraryNewSubcollectionHere.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi baru di sini'**
  String get libraryNewSubcollectionHere;

  /// No description provided for @libraryCollectionMenu.
  ///
  /// In id, this message translates to:
  /// **'Ubah nama, pindahkan, atau hapus'**
  String get libraryCollectionMenu;

  /// No description provided for @libraryNewPaperSubcollection.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi paper baru'**
  String get libraryNewPaperSubcollection;

  /// No description provided for @libraryNewCollectionHint.
  ///
  /// In id, this message translates to:
  /// **'Ditulis ke collections.json, ikut tersinkron ke GitHub'**
  String get libraryNewCollectionHint;

  /// No description provided for @libraryCreateCollectionFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat koleksi'**
  String get libraryCreateCollectionFailed;

  /// No description provided for @libraryNewNoteSubcollection.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi catatan baru'**
  String get libraryNewNoteSubcollection;

  /// No description provided for @libraryAddFilesHere.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan berkas ke sini…'**
  String get libraryAddFilesHere;

  /// No description provided for @libraryAnyTypeOrDrag.
  ///
  /// In id, this message translates to:
  /// **'jenis apa pun, beberapa sekaligus; atau seret dari pengelola berkas'**
  String get libraryAnyTypeOrDrag;

  /// No description provided for @libraryAnyTypeSeveral.
  ///
  /// In id, this message translates to:
  /// **'jenis apa pun, beberapa sekaligus'**
  String get libraryAnyTypeSeveral;

  /// No description provided for @libraryAddFolderHere.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan folder ke sini…'**
  String get libraryAddFolderHere;

  /// No description provided for @librarySubfoldersBecomeSub.
  ///
  /// In id, this message translates to:
  /// **'subfolder jadi sub-koleksi'**
  String get librarySubfoldersBecomeSub;

  /// No description provided for @libraryNewSubcollection.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi baru'**
  String get libraryNewSubcollection;

  /// No description provided for @libraryRename.
  ///
  /// In id, this message translates to:
  /// **'Ubah nama'**
  String get libraryRename;

  /// No description provided for @libraryMoveTo.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan ke…'**
  String get libraryMoveTo;

  /// No description provided for @libraryTransferToRepo.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan atau salin ke repositori lain…'**
  String get libraryTransferToRepo;

  /// No description provided for @libraryWithSubsAndPapers.
  ///
  /// In id, this message translates to:
  /// **'beserta sub-koleksi dan paper-nya'**
  String get libraryWithSubsAndPapers;

  /// No description provided for @libraryExportBibtex.
  ///
  /// In id, this message translates to:
  /// **'Ekspor ke BibTeX (.bib)'**
  String get libraryExportBibtex;

  /// No description provided for @libraryExportBibtexHint.
  ///
  /// In id, this message translates to:
  /// **'untuk naskah LaTeX; sub-koleksi ikut'**
  String get libraryExportBibtexHint;

  /// No description provided for @libraryDeleteCollection.
  ///
  /// In id, this message translates to:
  /// **'Hapus koleksi'**
  String get libraryDeleteCollection;

  /// No description provided for @libraryPapersKept.
  ///
  /// In id, this message translates to:
  /// **'Paper di dalamnya tidak ikut terhapus'**
  String get libraryPapersKept;

  /// No description provided for @libraryChangeCollectionFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengubah koleksi'**
  String get libraryChangeCollectionFailed;

  /// No description provided for @libraryRenameCollection.
  ///
  /// In id, this message translates to:
  /// **'Ubah nama koleksi'**
  String get libraryRenameCollection;

  /// No description provided for @libraryRenameCollectionHint.
  ///
  /// In id, this message translates to:
  /// **'Paper di dalamnya tetap; jalur sub-koleksinya ikut berubah'**
  String get libraryRenameCollectionHint;

  /// No description provided for @libraryCollectionRenamed.
  ///
  /// In id, this message translates to:
  /// **'Koleksi diubah namanya jadi \"{name}\"'**
  String libraryCollectionRenamed(String name);

  /// No description provided for @libraryRoot.
  ///
  /// In id, this message translates to:
  /// **'akar'**
  String get libraryRoot;

  /// No description provided for @libraryCollectionMoved.
  ///
  /// In id, this message translates to:
  /// **'Koleksi dipindah ke {parent}'**
  String libraryCollectionMoved(String parent);

  /// No description provided for @libraryTransferWhatCollection.
  ///
  /// In id, this message translates to:
  /// **'Koleksi {path}, beserta sub-koleksi dan paper-nya'**
  String libraryTransferWhatCollection(String path);

  /// No description provided for @libraryCollectionMovedToRepo.
  ///
  /// In id, this message translates to:
  /// **'Koleksi \"{name}\" dipindahkan ke {repo}'**
  String libraryCollectionMovedToRepo(String name, String repo);

  /// No description provided for @libraryCollectionCopiedToRepo.
  ///
  /// In id, this message translates to:
  /// **'Koleksi \"{name}\" disalin ke {repo}'**
  String libraryCollectionCopiedToRepo(String name, String repo);

  /// No description provided for @libraryConfirmDeleteCollection.
  ///
  /// In id, this message translates to:
  /// **'Yakin hapus koleksi \"{name}\"?'**
  String libraryConfirmDeleteCollection(String name);

  /// No description provided for @libraryDeleteKeepsPapers.
  ///
  /// In id, this message translates to:
  /// **'{count} paper di dalamnya tidak ikut terhapus — hanya dilepas dari koleksi ini, sama seperti di Zotero.'**
  String libraryDeleteKeepsPapers(int count);

  /// No description provided for @libraryDeleteHasChildren.
  ///
  /// In id, this message translates to:
  /// **'Koleksi ini punya {count} sub-koleksi. Ikut dihapus, atau naik satu tingkat?'**
  String libraryDeleteHasChildren(int count);

  /// No description provided for @libraryCollectionEmpty.
  ///
  /// In id, this message translates to:
  /// **'Koleksinya kosong.'**
  String get libraryCollectionEmpty;

  /// No description provided for @libraryCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get libraryCancel;

  /// No description provided for @librarySubsMoveUp.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi naik'**
  String get librarySubsMoveUp;

  /// No description provided for @libraryYesDeleteAll.
  ///
  /// In id, this message translates to:
  /// **'Ya, hapus semuanya'**
  String get libraryYesDeleteAll;

  /// No description provided for @libraryYesDelete.
  ///
  /// In id, this message translates to:
  /// **'Ya, hapus'**
  String get libraryYesDelete;

  /// No description provided for @libraryCollectionDeleted.
  ///
  /// In id, this message translates to:
  /// **'Koleksi \"{name}\" dihapus; paper-nya tetap ada'**
  String libraryCollectionDeleted(String name);

  /// No description provided for @libraryMoveNameTo.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan \"{name}\" ke…'**
  String libraryMoveNameTo(String name);

  /// No description provided for @libraryLibraryRoot.
  ///
  /// In id, this message translates to:
  /// **'Akar library'**
  String get libraryLibraryRoot;

  /// No description provided for @libraryNoParent.
  ///
  /// In id, this message translates to:
  /// **'tanpa induk'**
  String get libraryNoParent;

  /// No description provided for @libraryWithSubsAndNotes.
  ///
  /// In id, this message translates to:
  /// **'beserta sub-koleksi dan catatannya'**
  String get libraryWithSubsAndNotes;

  /// No description provided for @libraryNotesKept.
  ///
  /// In id, this message translates to:
  /// **'Catatannya tidak ikut terhapus'**
  String get libraryNotesKept;

  /// No description provided for @libraryTransferWhatNoteCollection.
  ///
  /// In id, this message translates to:
  /// **'Koleksi catatan \"{name}\", beserta sub-koleksi dan catatannya'**
  String libraryTransferWhatNoteCollection(String name);

  /// No description provided for @libraryNoteCollectionMovedToRepo.
  ///
  /// In id, this message translates to:
  /// **'Koleksi catatan \"{name}\" dipindahkan ke {repo}'**
  String libraryNoteCollectionMovedToRepo(String name, String repo);

  /// No description provided for @libraryNoteCollectionCopiedToRepo.
  ///
  /// In id, this message translates to:
  /// **'Koleksi catatan \"{name}\" disalin ke {repo}'**
  String libraryNoteCollectionCopiedToRepo(String name, String repo);

  /// No description provided for @libraryConfirmDeleteNoteCollection.
  ///
  /// In id, this message translates to:
  /// **'Hapus koleksi catatan \"{name}\"?'**
  String libraryConfirmDeleteNoteCollection(String name);

  /// No description provided for @libraryNoteCollectionHolds.
  ///
  /// In id, this message translates to:
  /// **'Berisi {count} catatan. Catatannya tidak ikut terhapus — pindah ke \"Tanpa koleksi\" bila tidak ada di koleksi lain.'**
  String libraryNoteCollectionHolds(int count);

  /// No description provided for @librarySubsDeletedToo.
  ///
  /// In id, this message translates to:
  /// **'{count} sub-koleksi di dalamnya ikut terhapus.'**
  String librarySubsDeletedToo(int count);

  /// No description provided for @libraryName.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get libraryName;

  /// No description provided for @librarySave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get librarySave;

  /// No description provided for @libraryNoItems.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada item.'**
  String get libraryNoItems;

  /// No description provided for @librarySearchHelpTitle.
  ///
  /// In id, this message translates to:
  /// **'Mempersempit pencarian'**
  String get librarySearchHelpTitle;

  /// No description provided for @librarySearchHelpIntro.
  ///
  /// In id, this message translates to:
  /// **'Kata biasa dicari di judul, pengarang, jurnal, tag, koleksi, DOI, dan abstrak. Beberapa kata berarti semuanya harus cocok.'**
  String get librarySearchHelpIntro;

  /// No description provided for @librarySearchOpAuthor.
  ///
  /// In id, this message translates to:
  /// **'hanya di nama pengarang'**
  String get librarySearchOpAuthor;

  /// No description provided for @librarySearchOpTitle.
  ///
  /// In id, this message translates to:
  /// **'frasa utuh di judul'**
  String get librarySearchOpTitle;

  /// No description provided for @librarySearchOpYear.
  ///
  /// In id, this message translates to:
  /// **'tahun persis'**
  String get librarySearchOpYear;

  /// No description provided for @librarySearchOpTag.
  ///
  /// In id, this message translates to:
  /// **'hanya di tag'**
  String get librarySearchOpTag;

  /// No description provided for @librarySearchOpType.
  ///
  /// In id, this message translates to:
  /// **'jenis item Zotero'**
  String get librarySearchOpType;

  /// No description provided for @librarySearchOpJournal.
  ///
  /// In id, this message translates to:
  /// **'nama publikasi'**
  String get librarySearchOpJournal;

  /// No description provided for @librarySearchOpAbstract.
  ///
  /// In id, this message translates to:
  /// **'hanya di abstrak'**
  String get librarySearchOpAbstract;

  /// No description provided for @librarySearchOpCollection.
  ///
  /// In id, this message translates to:
  /// **'nama koleksi'**
  String get librarySearchOpCollection;

  /// No description provided for @librarySearchOpExclude.
  ///
  /// In id, this message translates to:
  /// **'kecualikan yang mengandungnya'**
  String get librarySearchOpExclude;

  /// No description provided for @librarySearchHelpEnglish.
  ///
  /// In id, this message translates to:
  /// **'Nama bidang boleh bahasa Inggris juga: author, title, year, type, journal, abstract, collection.'**
  String get librarySearchHelpEnglish;

  /// No description provided for @libraryClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get libraryClose;

  /// No description provided for @librarySearchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari judul, pengarang, abstrak, DOI…'**
  String get librarySearchHint;

  /// No description provided for @librarySearchHelpTooltip.
  ///
  /// In id, this message translates to:
  /// **'Cara mempersempit pencarian'**
  String get librarySearchHelpTooltip;

  /// No description provided for @libraryOpenAnyFile.
  ///
  /// In id, this message translates to:
  /// **'Buka berkas dari perangkat ini (tanpa memasukkannya ke library)'**
  String get libraryOpenAnyFile;

  /// No description provided for @libraryPickFileToOpen.
  ///
  /// In id, this message translates to:
  /// **'Pilih berkas untuk dibuka'**
  String get libraryPickFileToOpen;

  /// No description provided for @libraryFindDuplicates.
  ///
  /// In id, this message translates to:
  /// **'Cari item yang masuk lebih dari sekali'**
  String get libraryFindDuplicates;

  /// No description provided for @libraryPossibleDuplicates.
  ///
  /// In id, this message translates to:
  /// **'{count} kemungkinan duplikat'**
  String libraryPossibleDuplicates(int count);

  /// No description provided for @libraryStats.
  ///
  /// In id, this message translates to:
  /// **'Statistik library'**
  String get libraryStats;

  /// No description provided for @libraryBrowseByAuthor.
  ///
  /// In id, this message translates to:
  /// **'Telusuri berdasarkan pengarang'**
  String get libraryBrowseByAuthor;

  /// No description provided for @librarySortBy.
  ///
  /// In id, this message translates to:
  /// **'Urutkan: {label}'**
  String librarySortBy(String label);

  /// No description provided for @libraryItemCount.
  ///
  /// In id, this message translates to:
  /// **'{count} item'**
  String libraryItemCount(int count);

  /// No description provided for @libraryHasFile.
  ///
  /// In id, this message translates to:
  /// **'berkas'**
  String get libraryHasFile;

  /// No description provided for @libraryNoFile.
  ///
  /// In id, this message translates to:
  /// **'tidak ada berkas'**
  String get libraryNoFile;

  /// No description provided for @libraryPickPaper.
  ///
  /// In id, this message translates to:
  /// **'Pilih satu paper untuk melihat detailnya.'**
  String get libraryPickPaper;

  /// No description provided for @libraryAbstract.
  ///
  /// In id, this message translates to:
  /// **'Abstrak'**
  String get libraryAbstract;

  /// No description provided for @libraryAnnotationsCount.
  ///
  /// In id, this message translates to:
  /// **'Anotasi ({count})'**
  String libraryAnnotationsCount(int count);

  /// No description provided for @libraryNotesCount.
  ///
  /// In id, this message translates to:
  /// **'Catatan ({count})'**
  String libraryNotesCount(int count);

  /// No description provided for @libraryCopyBibtex.
  ///
  /// In id, this message translates to:
  /// **'Salin BibTeX'**
  String get libraryCopyBibtex;

  /// No description provided for @libraryDeleteDocument.
  ///
  /// In id, this message translates to:
  /// **'Hapus dokumen ini dari library'**
  String get libraryDeleteDocument;

  /// No description provided for @libraryBackToList.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke daftar'**
  String get libraryBackToList;

  /// No description provided for @libraryNoAttachments.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada lampiran.'**
  String get libraryNoAttachments;

  /// No description provided for @libraryAnnotationCount.
  ///
  /// In id, this message translates to:
  /// **'{count} anotasi'**
  String libraryAnnotationCount(int count);

  /// No description provided for @libraryOnGithubNotDownloaded.
  ///
  /// In id, this message translates to:
  /// **'ada di GitHub, belum diunduh'**
  String get libraryOnGithubNotDownloaded;

  /// No description provided for @libraryFileNotDownloaded.
  ///
  /// In id, this message translates to:
  /// **'berkas belum diunduh'**
  String get libraryFileNotDownloaded;

  /// No description provided for @libraryLfsPointer.
  ///
  /// In id, this message translates to:
  /// **'pointer Git LFS — jalankan LFS pull'**
  String get libraryLfsPointer;

  /// No description provided for @libraryCannotOpenFormat.
  ///
  /// In id, this message translates to:
  /// **'format belum bisa dibuka di perangkat ini'**
  String get libraryCannotOpenFormat;

  /// No description provided for @libraryRead.
  ///
  /// In id, this message translates to:
  /// **'Baca'**
  String get libraryRead;

  /// No description provided for @libraryOpen.
  ///
  /// In id, this message translates to:
  /// **'Buka'**
  String get libraryOpen;

  /// No description provided for @libraryDownload.
  ///
  /// In id, this message translates to:
  /// **'Unduh'**
  String get libraryDownload;

  /// No description provided for @libraryFieldAuthors.
  ///
  /// In id, this message translates to:
  /// **'Pengarang'**
  String get libraryFieldAuthors;

  /// No description provided for @libraryFieldPublication.
  ///
  /// In id, this message translates to:
  /// **'Publikasi'**
  String get libraryFieldPublication;

  /// No description provided for @libraryFieldDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get libraryFieldDate;

  /// No description provided for @libraryFieldPublisher.
  ///
  /// In id, this message translates to:
  /// **'Penerbit'**
  String get libraryFieldPublisher;

  /// No description provided for @libraryFieldTags.
  ///
  /// In id, this message translates to:
  /// **'Tag'**
  String get libraryFieldTags;

  /// No description provided for @libraryFieldCollections.
  ///
  /// In id, this message translates to:
  /// **'Koleksi'**
  String get libraryFieldCollections;

  /// No description provided for @libraryFieldAdded.
  ///
  /// In id, this message translates to:
  /// **'Ditambahkan'**
  String get libraryFieldAdded;

  /// No description provided for @libraryDetails.
  ///
  /// In id, this message translates to:
  /// **'Detail'**
  String get libraryDetails;

  /// No description provided for @libraryAnnotationPage.
  ///
  /// In id, this message translates to:
  /// **'hal. {page} · {type}'**
  String libraryAnnotationPage(String page, String type);

  /// No description provided for @libraryMovingTo.
  ///
  /// In id, this message translates to:
  /// **'Memindah ke {target}…'**
  String libraryMovingTo(String target);

  /// No description provided for @libraryCopyingTo.
  ///
  /// In id, this message translates to:
  /// **'Menyalin ke {target}…'**
  String libraryCopyingTo(String target);

  /// No description provided for @libraryMovedTo.
  ///
  /// In id, this message translates to:
  /// **'Dipindahkan ke {where}'**
  String libraryMovedTo(String where);

  /// No description provided for @libraryCopiedTo.
  ///
  /// In id, this message translates to:
  /// **'Disalin ke {where}'**
  String libraryCopiedTo(String where);

  /// No description provided for @libraryConfirmDeleteDocument.
  ///
  /// In id, this message translates to:
  /// **'Hapus dokumen ini?'**
  String get libraryConfirmDeleteDocument;

  /// No description provided for @libraryConfirmDeleteDocumentBody.
  ///
  /// In id, this message translates to:
  /// **'Berkas item, lampirannya, dan catatannya dihapus dari library, lalu perubahannya di-commit.\n\n\"{title}\"\n\nKoleksi dan dokumen lain tidak tersentuh.'**
  String libraryConfirmDeleteDocumentBody(String title);

  /// No description provided for @libraryDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get libraryDelete;

  /// No description provided for @libraryDocumentDeleted.
  ///
  /// In id, this message translates to:
  /// **'Dokumen dihapus'**
  String get libraryDocumentDeleted;

  /// No description provided for @libraryDeleteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus'**
  String get libraryDeleteFailed;

  /// No description provided for @libraryRecentlyRead.
  ///
  /// In id, this message translates to:
  /// **'Terakhir dibaca'**
  String get libraryRecentlyRead;

  /// No description provided for @libraryClearHistory.
  ///
  /// In id, this message translates to:
  /// **'Bersihkan'**
  String get libraryClearHistory;

  /// No description provided for @libraryPageN.
  ///
  /// In id, this message translates to:
  /// **'halaman {page}'**
  String libraryPageN(int page);

  /// No description provided for @libraryRemoveFromHistory.
  ///
  /// In id, this message translates to:
  /// **'Hapus dari riwayat'**
  String get libraryRemoveFromHistory;

  /// No description provided for @libraryAuthorsCount.
  ///
  /// In id, this message translates to:
  /// **'Pengarang ({count})'**
  String libraryAuthorsCount(int count);

  /// No description provided for @libraryMostWorks.
  ///
  /// In id, this message translates to:
  /// **'Terbanyak'**
  String get libraryMostWorks;

  /// No description provided for @libraryFilterNames.
  ///
  /// In id, this message translates to:
  /// **'Saring nama'**
  String get libraryFilterNames;

  /// No description provided for @libraryNoLibraryRead.
  ///
  /// In id, this message translates to:
  /// **'Belum ada library yang terbaca.'**
  String get libraryNoLibraryRead;

  /// No description provided for @libraryNoMatchingNames.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada nama yang cocok.'**
  String get libraryNoMatchingNames;

  /// No description provided for @libraryDuplicatesTitle.
  ///
  /// In id, this message translates to:
  /// **'Kemungkinan duplikat'**
  String get libraryDuplicatesTitle;

  /// No description provided for @libraryDuplicatesNone.
  ///
  /// In id, this message translates to:
  /// **'{count} item diperiksa, tidak ada yang mencurigakan.'**
  String libraryDuplicatesNone(int count);

  /// No description provided for @libraryDuplicatesSummary.
  ///
  /// In id, this message translates to:
  /// **'{groups} kelompok · {copies} salinan dari {items} item'**
  String libraryDuplicatesSummary(int groups, int copies, int items);

  /// No description provided for @libraryDuplicatesRisky.
  ///
  /// In id, this message translates to:
  /// **' · {count} perlu hati-hati'**
  String libraryDuplicatesRisky(int count);

  /// No description provided for @libraryNothingDuplicated.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang tampak ganda.'**
  String get libraryNothingDuplicated;

  /// No description provided for @libraryDuplicatesHow.
  ///
  /// In id, this message translates to:
  /// **'Dicocokkan lewat DOI, lalu ISBN, lalu judul bersama tahun dan nama pengarang pertama.'**
  String get libraryDuplicatesHow;

  /// No description provided for @libraryDuplicatesFooter.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang dihapus dari sini. Penggabungan dikerjakan di Zotero, tempat riwayat dan lampirannya ikut dipindahkan — daftar ini gunanya menunjukkan mana yang perlu dilihat.'**
  String get libraryDuplicatesFooter;

  /// No description provided for @libraryCopiesCount.
  ///
  /// In id, this message translates to:
  /// **'{count} salinan'**
  String libraryCopiesCount(int count);

  /// No description provided for @libraryAnnotationsOnSeveral.
  ///
  /// In id, this message translates to:
  /// **'Anotasi ada di lebih dari satu salinan — menggabungkan bisa menghilangkan sebagiannya.'**
  String get libraryAnnotationsOnSeveral;

  /// No description provided for @libraryHasFileFact.
  ///
  /// In id, this message translates to:
  /// **'ada berkas'**
  String get libraryHasFileFact;

  /// No description provided for @libraryStatsEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada item untuk dihitung.'**
  String get libraryStatsEmpty;

  /// No description provided for @libraryStatsByYear.
  ///
  /// In id, this message translates to:
  /// **'Per tahun terbit'**
  String get libraryStatsByYear;

  /// No description provided for @libraryStatsWithoutYear.
  ///
  /// In id, this message translates to:
  /// **'{count} item tanpa tahun tidak ikut dihitung di sini.'**
  String libraryStatsWithoutYear(int count);

  /// No description provided for @libraryStatsByType.
  ///
  /// In id, this message translates to:
  /// **'Per jenis'**
  String get libraryStatsByType;

  /// No description provided for @libraryStatsTopAuthors.
  ///
  /// In id, this message translates to:
  /// **'Pengarang tersering'**
  String get libraryStatsTopAuthors;

  /// No description provided for @libraryStatsTopTags.
  ///
  /// In id, this message translates to:
  /// **'Tag tersering'**
  String get libraryStatsTopTags;

  /// No description provided for @libraryStatsItems.
  ///
  /// In id, this message translates to:
  /// **'Item'**
  String get libraryStatsItems;

  /// No description provided for @libraryStatsWithFile.
  ///
  /// In id, this message translates to:
  /// **'Berkasnya ada'**
  String get libraryStatsWithFile;

  /// No description provided for @libraryStatsWithAnnotations.
  ///
  /// In id, this message translates to:
  /// **'Ada anotasi'**
  String get libraryStatsWithAnnotations;

  /// No description provided for @libraryStatsYearSpan.
  ///
  /// In id, this message translates to:
  /// **'Rentang tahun'**
  String get libraryStatsYearSpan;

  /// No description provided for @libraryStatsUntitled.
  ///
  /// In id, this message translates to:
  /// **'Tanpa judul'**
  String get libraryStatsUntitled;

  /// No description provided for @librarySortTitle.
  ///
  /// In id, this message translates to:
  /// **'Judul'**
  String get librarySortTitle;

  /// No description provided for @librarySortYear.
  ///
  /// In id, this message translates to:
  /// **'Tahun'**
  String get librarySortYear;

  /// No description provided for @librarySortCreator.
  ///
  /// In id, this message translates to:
  /// **'Pengarang'**
  String get librarySortCreator;

  /// No description provided for @librarySortDateAdded.
  ///
  /// In id, this message translates to:
  /// **'Ditambahkan'**
  String get librarySortDateAdded;

  /// No description provided for @librarySortAnnotations.
  ///
  /// In id, this message translates to:
  /// **'Anotasi'**
  String get librarySortAnnotations;

  /// No description provided for @libraryPickFolderFor.
  ///
  /// In id, this message translates to:
  /// **'Pilih folder untuk {name}'**
  String libraryPickFolderFor(String name);

  /// No description provided for @libraryPickFilesFor.
  ///
  /// In id, this message translates to:
  /// **'Pilih berkas untuk {name}'**
  String libraryPickFilesFor(String name);

  /// No description provided for @libraryFilesAdded.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas masuk ke {name}'**
  String libraryFilesAdded(int count, String name);

  /// No description provided for @libraryFilesAddedPartly.
  ///
  /// In id, this message translates to:
  /// **'{added} dari {total} berkas masuk ke {name}. Gagal: {failed}. '**
  String libraryFilesAddedPartly(
    int added,
    int total,
    String name,
    String failed,
  );

  /// No description provided for @libraryMovingInto.
  ///
  /// In id, this message translates to:
  /// **'Memindahkan ke {name}…'**
  String libraryMovingInto(String name);

  /// No description provided for @libraryMovedInto.
  ///
  /// In id, this message translates to:
  /// **'Pindah ke {name}'**
  String libraryMovedInto(String name);

  /// No description provided for @libraryMoveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memindahkan'**
  String get libraryMoveFailed;

  /// No description provided for @libraryAddingInto.
  ///
  /// In id, this message translates to:
  /// **'Memasukkan ke {name}…'**
  String libraryAddingInto(String name);

  /// No description provided for @libraryAddFileFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memasukkan berkas'**
  String get libraryAddFileFailed;

  /// No description provided for @libraryAddedInto.
  ///
  /// In id, this message translates to:
  /// **'Masuk ke {name}'**
  String libraryAddedInto(String name);

  /// No description provided for @libraryPapersStayInLibrary.
  ///
  /// In id, this message translates to:
  /// **'Paper tinggal di akar paper: item Zotero punya rujukan dan bibliografi yang dijaga plugin sinkronisasi, dan folder catatan tidak mengenalnya. Yang bisa dipindahkan ke sini adalah catatan.'**
  String get libraryPapersStayInLibrary;

  /// No description provided for @libraryMoveNoteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memindahkan catatan'**
  String get libraryMoveNoteFailed;

  /// No description provided for @librarySaveNoteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan catatan'**
  String get librarySaveNoteFailed;

  /// No description provided for @libraryFolderEmpty.
  ///
  /// In id, this message translates to:
  /// **'Folder {name} tidak berisi berkas.'**
  String libraryFolderEmpty(String name);

  /// No description provided for @libraryImportFolderQuestion.
  ///
  /// In id, this message translates to:
  /// **'Impor folder \"{folder}\" ke {name}?'**
  String libraryImportFolderQuestion(String folder, String name);

  /// No description provided for @libraryFolderSummary.
  ///
  /// In id, this message translates to:
  /// **'{files} berkas dalam {folders} folder ({size}).'**
  String libraryFolderSummary(int files, int folders, String size);

  /// No description provided for @libraryFolderToNotes.
  ///
  /// In id, this message translates to:
  /// **'Folder ini jadi koleksi catatan, subfoldernya jadi sub-koleksi, dan setiap berkas jadi catatan.'**
  String get libraryFolderToNotes;

  /// No description provided for @libraryFolderToLibrary.
  ///
  /// In id, this message translates to:
  /// **'Folder ini jadi koleksi, subfoldernya jadi sub-koleksi, dan setiap berkas jadi item Zotero dengan lampirannya — terlihat juga di Zotero.'**
  String get libraryFolderToLibrary;

  /// No description provided for @libraryFolderReuses.
  ///
  /// In id, this message translates to:
  /// **'Koleksi yang namanya sudah ada di tempat yang sama dipakai, bukan digandakan.'**
  String get libraryFolderReuses;

  /// No description provided for @libraryFolderLarge.
  ///
  /// In id, this message translates to:
  /// **'Ukurannya besar. Semua berkas ini masuk repositori git dan ikut terkirim ke GitHub.'**
  String get libraryFolderLarge;

  /// No description provided for @libraryImport.
  ///
  /// In id, this message translates to:
  /// **'Impor'**
  String get libraryImport;

  /// No description provided for @libraryImporting.
  ///
  /// In id, this message translates to:
  /// **'Mengimpor {name}…'**
  String libraryImporting(String name);

  /// No description provided for @libraryProgress.
  ///
  /// In id, this message translates to:
  /// **'{done} dari {total} berkas'**
  String libraryProgress(int done, int total);

  /// No description provided for @libraryImportFailed.
  ///
  /// In id, this message translates to:
  /// **'Impor folder gagal'**
  String get libraryImportFailed;

  /// No description provided for @libraryImportDone.
  ///
  /// In id, this message translates to:
  /// **'{added} berkas masuk, {collections} koleksi baru.'**
  String libraryImportDone(int added, int collections);

  /// No description provided for @libraryImportFailedSome.
  ///
  /// In id, this message translates to:
  /// **'Gagal ({count}): {names}'**
  String libraryImportFailedSome(int count, String names);

  /// No description provided for @libraryAddToTooltip.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan berkas atau folder ke {name}'**
  String libraryAddToTooltip(String name);

  /// No description provided for @libraryAnyTypeMany.
  ///
  /// In id, this message translates to:
  /// **'jenis apa pun, bisa beberapa sekaligus'**
  String get libraryAnyTypeMany;

  /// No description provided for @libraryAddFolder.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan folder…'**
  String get libraryAddFolder;

  /// No description provided for @libraryAddFolderHint.
  ///
  /// In id, this message translates to:
  /// **'jadi koleksi di {name}, subfolder jadi sub-koleksi'**
  String libraryAddFolderHint(String name);

  /// No description provided for @libraryTypeJournalArticle.
  ///
  /// In id, this message translates to:
  /// **'Artikel jurnal'**
  String get libraryTypeJournalArticle;

  /// No description provided for @libraryTypeConferencePaper.
  ///
  /// In id, this message translates to:
  /// **'Makalah konferensi'**
  String get libraryTypeConferencePaper;

  /// No description provided for @libraryTypeBook.
  ///
  /// In id, this message translates to:
  /// **'Buku'**
  String get libraryTypeBook;

  /// No description provided for @libraryTypeBookSection.
  ///
  /// In id, this message translates to:
  /// **'Bab buku'**
  String get libraryTypeBookSection;

  /// No description provided for @libraryTypeThesis.
  ///
  /// In id, this message translates to:
  /// **'Tesis / disertasi'**
  String get libraryTypeThesis;

  /// No description provided for @libraryTypeReport.
  ///
  /// In id, this message translates to:
  /// **'Laporan'**
  String get libraryTypeReport;

  /// No description provided for @libraryTypePreprint.
  ///
  /// In id, this message translates to:
  /// **'Pracetak'**
  String get libraryTypePreprint;

  /// No description provided for @libraryTypeWebpage.
  ///
  /// In id, this message translates to:
  /// **'Halaman web'**
  String get libraryTypeWebpage;

  /// No description provided for @libraryTypeManuscript.
  ///
  /// In id, this message translates to:
  /// **'Naskah'**
  String get libraryTypeManuscript;

  /// No description provided for @libraryTypeDocument.
  ///
  /// In id, this message translates to:
  /// **'Dokumen'**
  String get libraryTypeDocument;

  /// No description provided for @libraryTypePresentation.
  ///
  /// In id, this message translates to:
  /// **'Presentasi'**
  String get libraryTypePresentation;

  /// No description provided for @libraryTypeDataset.
  ///
  /// In id, this message translates to:
  /// **'Data'**
  String get libraryTypeDataset;

  /// No description provided for @libraryTypeStandard.
  ///
  /// In id, this message translates to:
  /// **'Standar'**
  String get libraryTypeStandard;

  /// No description provided for @libraryTypePatent.
  ///
  /// In id, this message translates to:
  /// **'Paten'**
  String get libraryTypePatent;

  /// No description provided for @libraryTypeMagazineArticle.
  ///
  /// In id, this message translates to:
  /// **'Artikel majalah'**
  String get libraryTypeMagazineArticle;

  /// No description provided for @libraryTypeNewspaperArticle.
  ///
  /// In id, this message translates to:
  /// **'Artikel koran'**
  String get libraryTypeNewspaperArticle;

  /// No description provided for @libraryTypeEncyclopediaArticle.
  ///
  /// In id, this message translates to:
  /// **'Artikel ensiklopedia'**
  String get libraryTypeEncyclopediaArticle;

  /// No description provided for @libraryTypeBlogPost.
  ///
  /// In id, this message translates to:
  /// **'Tulisan blog'**
  String get libraryTypeBlogPost;

  /// No description provided for @libraryTypeComputerProgram.
  ///
  /// In id, this message translates to:
  /// **'Perangkat lunak'**
  String get libraryTypeComputerProgram;

  /// No description provided for @libraryTypeAttachment.
  ///
  /// In id, this message translates to:
  /// **'Lampiran'**
  String get libraryTypeAttachment;

  /// No description provided for @libraryTypeNote.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get libraryTypeNote;

  /// No description provided for @libraryReasonDoi.
  ///
  /// In id, this message translates to:
  /// **'DOI-nya sama'**
  String get libraryReasonDoi;

  /// No description provided for @libraryReasonIsbn.
  ///
  /// In id, this message translates to:
  /// **'ISBN-nya sama'**
  String get libraryReasonIsbn;

  /// No description provided for @libraryReasonTitleYearAuthor.
  ///
  /// In id, this message translates to:
  /// **'Judul, tahun, dan pengarangnya sama'**
  String get libraryReasonTitleYearAuthor;

  /// No description provided for @libraryErrItemNotFound.
  ///
  /// In id, this message translates to:
  /// **'Berkas item tidak ditemukan'**
  String get libraryErrItemNotFound;

  /// No description provided for @libraryErrLibraryDirMissing.
  ///
  /// In id, this message translates to:
  /// **'Direktori library tidak ada'**
  String get libraryErrLibraryDirMissing;

  /// No description provided for @libraryErrItemInvalid.
  ///
  /// In id, this message translates to:
  /// **'Berkas item tidak valid'**
  String get libraryErrItemInvalid;

  /// No description provided for @libraryErrAttachmentsMissing.
  ///
  /// In id, this message translates to:
  /// **'{count} lampiran belum ada di perangkat ini (belum diunduh, atau masih penunjuk Git LFS): {names}'**
  String libraryErrAttachmentsMissing(int count, String names);

  /// No description provided for @libraryErrItemNoKey.
  ///
  /// In id, this message translates to:
  /// **'Berkas item tidak punya kunci Zotero'**
  String get libraryErrItemNoKey;

  /// No description provided for @libraryErrItemExistsInTarget.
  ///
  /// In id, this message translates to:
  /// **'Item ini sudah ada di repositori tujuan (kunci {itemKey}). Tidak disalin dua kali.'**
  String libraryErrItemExistsInTarget(String itemKey);

  /// No description provided for @libraryErrCollectionGone.
  ///
  /// In id, this message translates to:
  /// **'Koleksi tidak ada lagi'**
  String get libraryErrCollectionGone;

  /// No description provided for @libraryErrTargetCollectionMissing.
  ///
  /// In id, this message translates to:
  /// **'Koleksi tujuan tidak ada'**
  String get libraryErrTargetCollectionMissing;

  /// No description provided for @libraryErrTargetHasCollection.
  ///
  /// In id, this message translates to:
  /// **'Di tempat tujuan sudah ada koleksi bernama \"{name}\". Ganti namanya dulu.'**
  String libraryErrTargetHasCollection(String name);

  /// No description provided for @libraryErrItemTitleExists.
  ///
  /// In id, this message translates to:
  /// **'Item {title} sudah ada di repositori tujuan.'**
  String libraryErrItemTitleExists(String title);

  /// No description provided for @libraryErrCollectionsNotList.
  ///
  /// In id, this message translates to:
  /// **'collections.json tidak berisi daftar koleksi'**
  String get libraryErrCollectionsNotList;

  /// No description provided for @libraryErrRefuseDeleteNotItem.
  ///
  /// In id, this message translates to:
  /// **'Menolak menghapus: berkas ini bukan item di dalam items/'**
  String get libraryErrRefuseDeleteNotItem;

  /// No description provided for @libraryErrCollectionNameEmpty.
  ///
  /// In id, this message translates to:
  /// **'Nama koleksi tidak boleh kosong'**
  String get libraryErrCollectionNameEmpty;

  /// No description provided for @libraryErrCollectionNameSlash.
  ///
  /// In id, this message translates to:
  /// **'Nama koleksi tidak boleh memuat garis miring'**
  String get libraryErrCollectionNameSlash;

  /// No description provided for @libraryErrCollectionsNotListRefuse.
  ///
  /// In id, this message translates to:
  /// **'collections.json tidak berisi daftar koleksi — menolak menulisinya'**
  String get libraryErrCollectionsNotListRefuse;

  /// No description provided for @libraryErrCollectionsBadEntry.
  ///
  /// In id, this message translates to:
  /// **'Ada entri di collections.json yang bukan koleksi — menolak menulisinya'**
  String get libraryErrCollectionsBadEntry;

  /// No description provided for @libraryErrParentMissing.
  ///
  /// In id, this message translates to:
  /// **'Koleksi induk tidak ada'**
  String get libraryErrParentMissing;

  /// No description provided for @libraryErrCollectionExists.
  ///
  /// In id, this message translates to:
  /// **'Sudah ada koleksi bernama \"{name}\" di tempat yang sama'**
  String libraryErrCollectionExists(String name);

  /// No description provided for @libraryErrCollectionKey.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat kunci koleksi baru'**
  String get libraryErrCollectionKey;

  /// No description provided for @libraryErrMoveIntoSelf.
  ///
  /// In id, this message translates to:
  /// **'Koleksi tidak bisa dipindah ke dalam dirinya sendiri'**
  String get libraryErrMoveIntoSelf;

  /// No description provided for @libraryErrCollectionsMissing.
  ///
  /// In id, this message translates to:
  /// **'collections.json tidak ada'**
  String get libraryErrCollectionsMissing;

  /// No description provided for @libraryErrItemNoZotero.
  ///
  /// In id, this message translates to:
  /// **'Berkas item tidak punya bagian zotero'**
  String get libraryErrItemNoZotero;

  /// No description provided for @libraryErrFileNotFound.
  ///
  /// In id, this message translates to:
  /// **'Berkas tidak ditemukan'**
  String get libraryErrFileNotFound;

  /// No description provided for @notesUnfiledTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan tanpa koleksi'**
  String get notesUnfiledTitle;

  /// No description provided for @notesRootTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get notesRootTitle;

  /// No description provided for @notesAllTitle.
  ///
  /// In id, this message translates to:
  /// **'Semua catatan'**
  String get notesAllTitle;

  /// No description provided for @notesCount.
  ///
  /// In id, this message translates to:
  /// **'{count} catatan'**
  String notesCount(int count);

  /// No description provided for @notesNewNotebook.
  ///
  /// In id, this message translates to:
  /// **'Buku catatan baru'**
  String get notesNewNotebook;

  /// No description provided for @notesNewMarkdown.
  ///
  /// In id, this message translates to:
  /// **'Catatan Markdown baru'**
  String get notesNewMarkdown;

  /// No description provided for @notesEmpty.
  ///
  /// In id, this message translates to:
  /// **'Belum ada catatan di sini. Seret berkas dari panel berkas, atau pakai tombol tambah di atas. Tarik ke bawah untuk mengambil perubahan dari GitHub.'**
  String get notesEmpty;

  /// No description provided for @notesActions.
  ///
  /// In id, this message translates to:
  /// **'Tindakan'**
  String get notesActions;

  /// No description provided for @notesClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get notesClose;

  /// No description provided for @notesNotebookDefaultTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get notesNotebookDefaultTitle;

  /// No description provided for @notesNewNotebookFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat buku catatan'**
  String get notesNewNotebookFailed;

  /// No description provided for @notesNewNoteTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan baru'**
  String get notesNewNoteTitle;

  /// No description provided for @notesNewNoteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat catatan'**
  String get notesNewNoteFailed;

  /// No description provided for @notesRename.
  ///
  /// In id, this message translates to:
  /// **'Ubah judul'**
  String get notesRename;

  /// No description provided for @notesShare.
  ///
  /// In id, this message translates to:
  /// **'Bagikan'**
  String get notesShare;

  /// No description provided for @notesShareAsPdf.
  ///
  /// In id, this message translates to:
  /// **'sebagai PDF'**
  String get notesShareAsPdf;

  /// No description provided for @notesShareToApps.
  ///
  /// In id, this message translates to:
  /// **'ke aplikasi lain'**
  String get notesShareToApps;

  /// No description provided for @notesMoveToCollection.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan ke koleksi'**
  String get notesMoveToCollection;

  /// No description provided for @notesTransferToRepo.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan atau salin ke repositori lain…'**
  String get notesTransferToRepo;

  /// No description provided for @notesDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus catatan'**
  String get notesDelete;

  /// No description provided for @notesDeleteSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Berkasnya ikut terhapus'**
  String get notesDeleteSubtitle;

  /// No description provided for @notesTransferWhat.
  ///
  /// In id, this message translates to:
  /// **'Catatan \"{title}\"'**
  String notesTransferWhat(String title);

  /// No description provided for @notesMoved.
  ///
  /// In id, this message translates to:
  /// **'Catatan dipindahkan ke {target}'**
  String notesMoved(String target);

  /// No description provided for @notesCopied.
  ///
  /// In id, this message translates to:
  /// **'Catatan disalin ke {target}'**
  String notesCopied(String target);

  /// No description provided for @notesDeleteConfirmTitle.
  ///
  /// In id, this message translates to:
  /// **'Hapus catatan?'**
  String get notesDeleteConfirmTitle;

  /// No description provided for @notesDeleteConfirmBody.
  ///
  /// In id, this message translates to:
  /// **'“{title}” beserta berkasnya akan dihapus dari repositori.'**
  String notesDeleteConfirmBody(String title);

  /// No description provided for @notesCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get notesCancel;

  /// No description provided for @notesDeleteButton.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get notesDeleteButton;

  /// No description provided for @notesNoCollection.
  ///
  /// In id, this message translates to:
  /// **'Tanpa koleksi'**
  String get notesNoCollection;

  /// No description provided for @notesTitleField.
  ///
  /// In id, this message translates to:
  /// **'Judul'**
  String get notesTitleField;

  /// No description provided for @notesSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get notesSave;

  /// No description provided for @notesNoActiveRepo.
  ///
  /// In id, this message translates to:
  /// **'Belum ada repositori aktif.'**
  String get notesNoActiveRepo;

  /// No description provided for @notesNoteGone.
  ///
  /// In id, this message translates to:
  /// **'Catatannya tidak ada lagi.'**
  String get notesNoteGone;

  /// No description provided for @notesCollectionGone.
  ///
  /// In id, this message translates to:
  /// **'Koleksinya tidak ada lagi.'**
  String get notesCollectionGone;

  /// No description provided for @notesNoRepoToSave.
  ///
  /// In id, this message translates to:
  /// **'Belum ada repositori aktif untuk menyimpan catatan.'**
  String get notesNoRepoToSave;

  /// No description provided for @notesErrEmptyCollectionName.
  ///
  /// In id, this message translates to:
  /// **'Nama koleksi catatan tidak boleh kosong'**
  String get notesErrEmptyCollectionName;

  /// No description provided for @notesErrParentMissing.
  ///
  /// In id, this message translates to:
  /// **'Koleksi induk tidak ada'**
  String get notesErrParentMissing;

  /// No description provided for @notesErrCollectionMissing.
  ///
  /// In id, this message translates to:
  /// **'Koleksi catatan tidak ada'**
  String get notesErrCollectionMissing;

  /// No description provided for @notesErrFileNotFound.
  ///
  /// In id, this message translates to:
  /// **'Berkas catatan tidak ditemukan'**
  String get notesErrFileNotFound;

  /// No description provided for @notesErrNoteMissing.
  ///
  /// In id, this message translates to:
  /// **'Catatan tidak ada'**
  String get notesErrNoteMissing;

  /// No description provided for @notesErrEmptyTitle.
  ///
  /// In id, this message translates to:
  /// **'Judul catatan tidak boleh kosong'**
  String get notesErrEmptyTitle;

  /// No description provided for @notesErrTargetCollectionMissing.
  ///
  /// In id, this message translates to:
  /// **'Koleksi catatan tujuan tidak ada'**
  String get notesErrTargetCollectionMissing;

  /// No description provided for @notesErrFileOutside.
  ///
  /// In id, this message translates to:
  /// **'Berkas catatan ada di luar folder catatan'**
  String get notesErrFileOutside;

  /// No description provided for @notesErrFileNotOnDevice.
  ///
  /// In id, this message translates to:
  /// **'Berkas catatan tidak ada di perangkat ini'**
  String get notesErrFileNotOnDevice;

  /// No description provided for @notesErrTargetNameTaken.
  ///
  /// In id, this message translates to:
  /// **'Di tempat tujuan sudah ada koleksi catatan bernama \"{name}\". Ganti namanya dulu.'**
  String notesErrTargetNameTaken(String name);

  /// No description provided for @notesErrNamedFileNotOnDevice.
  ///
  /// In id, this message translates to:
  /// **'Berkas catatan \"{title}\" tidak ada di perangkat ini'**
  String notesErrNamedFileNotOnDevice(String title);

  /// No description provided for @notesErrNoNewKey.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat kunci catatan baru'**
  String get notesErrNoNewKey;

  /// No description provided for @notesTargetRefusal.
  ///
  /// In id, this message translates to:
  /// **'Catatan hanya bisa disimpan di akar \"Catatan\". Akar paper berisi item Zotero — item di sana punya properti rujukan dan bibliografi, dan formatnya dijaga oleh plugin sinkronisasi Zotero. Pilih koleksi di bawah akar Catatan, atau buat satu lebih dulu.'**
  String get notesTargetRefusal;

  /// No description provided for @notesImageMissing.
  ///
  /// In id, this message translates to:
  /// **'Berkas gambarnya tidak ada lagi:\n{path}'**
  String notesImageMissing(String path);

  /// No description provided for @epubThemeLight.
  ///
  /// In id, this message translates to:
  /// **'Terang'**
  String get epubThemeLight;

  /// No description provided for @epubThemeSepia.
  ///
  /// In id, this message translates to:
  /// **'Sepia'**
  String get epubThemeSepia;

  /// No description provided for @epubThemeDark.
  ///
  /// In id, this message translates to:
  /// **'Gelap'**
  String get epubThemeDark;

  /// No description provided for @epubUnreadable.
  ///
  /// In id, this message translates to:
  /// **'EPUB ini tidak bisa dibaca: {error}'**
  String epubUnreadable(String error);

  /// No description provided for @epubSmallerText.
  ///
  /// In id, this message translates to:
  /// **'Perkecil huruf'**
  String get epubSmallerText;

  /// No description provided for @epubLargerText.
  ///
  /// In id, this message translates to:
  /// **'Perbesar huruf'**
  String get epubLargerText;

  /// No description provided for @epubPageColor.
  ///
  /// In id, this message translates to:
  /// **'Warna halaman: {name}'**
  String epubPageColor(String name);

  /// No description provided for @epubContents.
  ///
  /// In id, this message translates to:
  /// **'Daftar isi'**
  String get epubContents;

  /// No description provided for @epubNoChapters.
  ///
  /// In id, this message translates to:
  /// **'EPUB ini tidak punya bab yang bisa dibaca.'**
  String get epubNoChapters;

  /// No description provided for @epubPrevChapter.
  ///
  /// In id, this message translates to:
  /// **'Bab sebelumnya'**
  String get epubPrevChapter;

  /// No description provided for @epubNextChapter.
  ///
  /// In id, this message translates to:
  /// **'Bab berikutnya'**
  String get epubNextChapter;

  /// No description provided for @epubChapterN.
  ///
  /// In id, this message translates to:
  /// **'Bab {number}'**
  String epubChapterN(int number);

  /// No description provided for @epubErrNoContainer.
  ///
  /// In id, this message translates to:
  /// **'Bukan EPUB: META-INF/container.xml tidak ada.'**
  String get epubErrNoContainer;

  /// No description provided for @epubErrNoOpf.
  ///
  /// In id, this message translates to:
  /// **'Bukan EPUB: berkas OPF tidak ditemukan.'**
  String get epubErrNoOpf;

  /// No description provided for @markdownReadFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membaca berkas: {error}'**
  String markdownReadFailed(String error);

  /// No description provided for @markdownSaved.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan: {name}'**
  String markdownSaved(String name);

  /// No description provided for @markdownSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan: {error}'**
  String markdownSaveFailed(String error);

  /// No description provided for @markdownWritingPdf.
  ///
  /// In id, this message translates to:
  /// **'Menulis PDF…'**
  String get markdownWritingPdf;

  /// No description provided for @markdownPdfSaved.
  ///
  /// In id, this message translates to:
  /// **'PDF tersimpan: {name}'**
  String markdownPdfSaved(String name);

  /// No description provided for @markdownPrint.
  ///
  /// In id, this message translates to:
  /// **'Cetak'**
  String get markdownPrint;

  /// No description provided for @markdownPdfFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menulis PDF: {error}'**
  String markdownPdfFailed(String error);

  /// No description provided for @markdownSaveFirstTitle.
  ///
  /// In id, this message translates to:
  /// **'Simpan dulu?'**
  String get markdownSaveFirstTitle;

  /// No description provided for @markdownUnsavedBody.
  ///
  /// In id, this message translates to:
  /// **'Ada perubahan yang belum disimpan.'**
  String get markdownUnsavedBody;

  /// No description provided for @markdownKeepEditing.
  ///
  /// In id, this message translates to:
  /// **'Kembali menyunting'**
  String get markdownKeepEditing;

  /// No description provided for @markdownDiscard.
  ///
  /// In id, this message translates to:
  /// **'Buang perubahan'**
  String get markdownDiscard;

  /// No description provided for @markdownSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get markdownSave;

  /// No description provided for @markdownUnsaved.
  ///
  /// In id, this message translates to:
  /// **'Belum disimpan'**
  String get markdownUnsaved;

  /// No description provided for @markdownEdit.
  ///
  /// In id, this message translates to:
  /// **'Sunting'**
  String get markdownEdit;

  /// No description provided for @markdownPreview.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau'**
  String get markdownPreview;

  /// No description provided for @markdownBoth.
  ///
  /// In id, this message translates to:
  /// **'Keduanya'**
  String get markdownBoth;

  /// No description provided for @markdownMore.
  ///
  /// In id, this message translates to:
  /// **'Lainnya'**
  String get markdownMore;

  /// No description provided for @markdownSaveAsPdf.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai PDF'**
  String get markdownSaveAsPdf;

  /// No description provided for @markdownShareFile.
  ///
  /// In id, this message translates to:
  /// **'Bagikan berkas Markdown'**
  String get markdownShareFile;

  /// No description provided for @markdownShareAsPdf.
  ///
  /// In id, this message translates to:
  /// **'Bagikan sebagai PDF'**
  String get markdownShareAsPdf;

  /// No description provided for @markdownCopyAll.
  ///
  /// In id, this message translates to:
  /// **'Salin seluruh teks'**
  String get markdownCopyAll;

  /// No description provided for @markdownHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis di sini. Markdown: # tajuk, **tebal**, - daftar, ```mermaid diagram.'**
  String get markdownHint;

  /// No description provided for @markdownHeading.
  ///
  /// In id, this message translates to:
  /// **'Tajuk'**
  String get markdownHeading;

  /// No description provided for @markdownBold.
  ///
  /// In id, this message translates to:
  /// **'Tebal'**
  String get markdownBold;

  /// No description provided for @markdownItalic.
  ///
  /// In id, this message translates to:
  /// **'Miring'**
  String get markdownItalic;

  /// No description provided for @markdownList.
  ///
  /// In id, this message translates to:
  /// **'Daftar'**
  String get markdownList;

  /// No description provided for @markdownTaskList.
  ///
  /// In id, this message translates to:
  /// **'Daftar tugas'**
  String get markdownTaskList;

  /// No description provided for @markdownQuote.
  ///
  /// In id, this message translates to:
  /// **'Kutipan'**
  String get markdownQuote;

  /// No description provided for @markdownCode.
  ///
  /// In id, this message translates to:
  /// **'Kode'**
  String get markdownCode;

  /// No description provided for @markdownTable.
  ///
  /// In id, this message translates to:
  /// **'Tabel'**
  String get markdownTable;

  /// No description provided for @markdownTableTemplate.
  ///
  /// In id, this message translates to:
  /// **'| Kolom | Nilai |\n| --- | --- |\n|  |  |\n'**
  String get markdownTableTemplate;

  /// No description provided for @markdownMermaid.
  ///
  /// In id, this message translates to:
  /// **'Diagram mermaid'**
  String get markdownMermaid;

  /// No description provided for @markdownMermaidEmpty.
  ///
  /// In id, this message translates to:
  /// **'Diagram kosong.'**
  String get markdownMermaidEmpty;

  /// No description provided for @markdownMermaidUnsupported.
  ///
  /// In id, this message translates to:
  /// **'Jenis diagram \"{kind}\" belum digambar — yang sudah: graph dan flowchart. Sumbernya tetap ditampilkan apa adanya.'**
  String markdownMermaidUnsupported(String kind);

  /// No description provided for @markdownMermaidNoNodes.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada simpul yang bisa dibaca dari diagram ini.'**
  String get markdownMermaidNoNodes;

  /// No description provided for @markdownMermaidCannotDraw.
  ///
  /// In id, this message translates to:
  /// **'Diagram ini belum bisa digambar.'**
  String get markdownMermaidCannotDraw;

  /// No description provided for @markdownPdfEmpty.
  ///
  /// In id, this message translates to:
  /// **'(dokumen kosong)'**
  String get markdownPdfEmpty;

  /// No description provided for @markdownPdfImageMissing.
  ///
  /// In id, this message translates to:
  /// **'[gambar tidak ditemukan: {path}]'**
  String markdownPdfImageMissing(String path);

  /// No description provided for @markdownEmptyDoc.
  ///
  /// In id, this message translates to:
  /// **'Dokumen masih kosong.'**
  String get markdownEmptyDoc;

  /// No description provided for @whiteboardPortrait.
  ///
  /// In id, this message translates to:
  /// **'Tegak'**
  String get whiteboardPortrait;

  /// No description provided for @whiteboardLandscape.
  ///
  /// In id, this message translates to:
  /// **'Mendatar'**
  String get whiteboardLandscape;

  /// No description provided for @whiteboardBgWhite.
  ///
  /// In id, this message translates to:
  /// **'Putih'**
  String get whiteboardBgWhite;

  /// No description provided for @whiteboardBgBlack.
  ///
  /// In id, this message translates to:
  /// **'Hitam'**
  String get whiteboardBgBlack;

  /// No description provided for @whiteboardBgGreen.
  ///
  /// In id, this message translates to:
  /// **'Hijau papan'**
  String get whiteboardBgGreen;

  /// No description provided for @whiteboardBgCream.
  ///
  /// In id, this message translates to:
  /// **'Krem'**
  String get whiteboardBgCream;

  /// No description provided for @whiteboardBgNavy.
  ///
  /// In id, this message translates to:
  /// **'Biru malam'**
  String get whiteboardBgNavy;

  /// No description provided for @whiteboardTurned.
  ///
  /// In id, this message translates to:
  /// **'Kertas jadi {orientation} — coretannya ikut berputar, tidak ada yang hilang.'**
  String whiteboardTurned(String orientation);

  /// No description provided for @whiteboardSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan: {error}'**
  String whiteboardSaveFailed(String error);

  /// No description provided for @whiteboardShareFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membagikan: {error}'**
  String whiteboardShareFailed(String error);

  /// No description provided for @whiteboardSavedAs.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan sebagai {name}'**
  String whiteboardSavedAs(String name);

  /// No description provided for @notesCannotSaveAsNote.
  ///
  /// In id, this message translates to:
  /// **'Belum bisa disimpan sebagai catatan'**
  String get notesCannotSaveAsNote;

  /// No description provided for @notesUnderstood.
  ///
  /// In id, this message translates to:
  /// **'Mengerti'**
  String get notesUnderstood;

  /// No description provided for @whiteboardSaveNoteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan catatan'**
  String get whiteboardSaveNoteFailed;

  /// No description provided for @whiteboardSavedAsNote.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan sebagai catatan'**
  String get whiteboardSavedAsNote;

  /// No description provided for @whiteboardLeaveTitle.
  ///
  /// In id, this message translates to:
  /// **'Tinggalkan papan ini?'**
  String get whiteboardLeaveTitle;

  /// No description provided for @whiteboardLeaveBody.
  ///
  /// In id, this message translates to:
  /// **'Coretannya belum disimpan, dan tidak bisa dikembalikan.'**
  String get whiteboardLeaveBody;

  /// No description provided for @whiteboardKeepDrawing.
  ///
  /// In id, this message translates to:
  /// **'Kembali menggambar'**
  String get whiteboardKeepDrawing;

  /// No description provided for @whiteboardLeave.
  ///
  /// In id, this message translates to:
  /// **'Tinggalkan'**
  String get whiteboardLeave;

  /// No description provided for @whiteboardTitle.
  ///
  /// In id, this message translates to:
  /// **'Papan tulis'**
  String get whiteboardTitle;

  /// No description provided for @whiteboardSheetStatus.
  ///
  /// In id, this message translates to:
  /// **'Lembar {page} dari {count} · kertas {orientation}'**
  String whiteboardSheetStatus(int page, int count, String orientation);

  /// No description provided for @whiteboardFreehand.
  ///
  /// In id, this message translates to:
  /// **'Tangan bebas'**
  String get whiteboardFreehand;

  /// No description provided for @whiteboardShape.
  ///
  /// In id, this message translates to:
  /// **'Bangun: {shape}'**
  String whiteboardShape(String shape);

  /// No description provided for @whiteboardFingerOn.
  ///
  /// In id, this message translates to:
  /// **'Jari + stylus boleh menggambar — ketuk untuk hanya stylus'**
  String get whiteboardFingerOn;

  /// No description provided for @whiteboardStylusOnly.
  ///
  /// In id, this message translates to:
  /// **'Stylus saja — sentuhan tangan tidak menggambar apa pun'**
  String get whiteboardStylusOnly;

  /// No description provided for @whiteboardBackToWriting.
  ///
  /// In id, this message translates to:
  /// **'Kembali menulis'**
  String get whiteboardBackToWriting;

  /// No description provided for @whiteboardEraserHint.
  ///
  /// In id, this message translates to:
  /// **'Penghapus — sapukan di atas goresan'**
  String get whiteboardEraserHint;

  /// No description provided for @whiteboardEraser.
  ///
  /// In id, this message translates to:
  /// **'Penghapus'**
  String get whiteboardEraser;

  /// No description provided for @whiteboardPortraitTurn.
  ///
  /// In id, this message translates to:
  /// **'Kertas tegak — ketuk untuk memutar jadi mendatar'**
  String get whiteboardPortraitTurn;

  /// No description provided for @whiteboardLandscapeTurn.
  ///
  /// In id, this message translates to:
  /// **'Kertas mendatar — ketuk untuk memutar jadi tegak'**
  String get whiteboardLandscapeTurn;

  /// No description provided for @notesUndo.
  ///
  /// In id, this message translates to:
  /// **'Urungkan'**
  String get notesUndo;

  /// No description provided for @notesRedo.
  ///
  /// In id, this message translates to:
  /// **'Ulangi'**
  String get notesRedo;

  /// No description provided for @whiteboardClearSheet.
  ///
  /// In id, this message translates to:
  /// **'Kosongkan lembar ini'**
  String get whiteboardClearSheet;

  /// No description provided for @notesShareAsPdf2.
  ///
  /// In id, this message translates to:
  /// **'Bagikan sebagai PDF'**
  String get notesShareAsPdf2;

  /// No description provided for @whiteboardSaveAsNote.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai catatan'**
  String get whiteboardSaveAsNote;

  /// No description provided for @whiteboardSavePdf.
  ///
  /// In id, this message translates to:
  /// **'Simpan PDF'**
  String get whiteboardSavePdf;

  /// No description provided for @whiteboardSheet.
  ///
  /// In id, this message translates to:
  /// **'Lembar'**
  String get whiteboardSheet;

  /// No description provided for @whiteboardStrokeWidth.
  ///
  /// In id, this message translates to:
  /// **'Tebal goresan'**
  String get whiteboardStrokeWidth;

  /// No description provided for @notesPenColor.
  ///
  /// In id, this message translates to:
  /// **'Warna pena'**
  String get notesPenColor;

  /// No description provided for @markdownMermaidStart.
  ///
  /// In id, this message translates to:
  /// **'Mulai'**
  String get markdownMermaidStart;

  /// No description provided for @markdownMermaidDone.
  ///
  /// In id, this message translates to:
  /// **'Sudah?'**
  String get markdownMermaidDone;

  /// No description provided for @markdownMermaidYes.
  ///
  /// In id, this message translates to:
  /// **'ya'**
  String get markdownMermaidYes;

  /// No description provided for @markdownMermaidFinish.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get markdownMermaidFinish;

  /// No description provided for @markdownMermaidNo.
  ///
  /// In id, this message translates to:
  /// **'belum'**
  String get markdownMermaidNo;

  /// No description provided for @notebookHandwritingAlt.
  ///
  /// In id, this message translates to:
  /// **'tulisan tangan'**
  String get notebookHandwritingAlt;

  /// No description provided for @notebookPageAlt.
  ///
  /// In id, this message translates to:
  /// **'Halaman {number}'**
  String notebookPageAlt(int number);

  /// No description provided for @notebookErrUnknownContent.
  ///
  /// In id, this message translates to:
  /// **'Isi berkas catatan tidak dikenali'**
  String get notebookErrUnknownContent;

  /// No description provided for @notebookErrNewerFormat.
  ///
  /// In id, this message translates to:
  /// **'Catatan ini ditulis versi ReadPaper yang lebih baru (format {version}). Perbarui aplikasinya dulu supaya isinya tidak rusak.'**
  String notebookErrNewerFormat(int version);

  /// No description provided for @notebookImageMissing.
  ///
  /// In id, this message translates to:
  /// **'gambar hilang'**
  String get notebookImageMissing;

  /// No description provided for @notebookDragMove.
  ///
  /// In id, this message translates to:
  /// **'Seret untuk memindahkan'**
  String get notebookDragMove;

  /// No description provided for @notebookDragResize.
  ///
  /// In id, this message translates to:
  /// **'Seret untuk mengubah ukuran'**
  String get notebookDragResize;

  /// No description provided for @notebookDragRotate.
  ///
  /// In id, this message translates to:
  /// **'Seret untuk memutar'**
  String get notebookDragRotate;

  /// No description provided for @notebookTapSecond.
  ///
  /// In id, this message translates to:
  /// **'Sekarang ketuk benda yang kedua.'**
  String get notebookTapSecond;

  /// No description provided for @notebookNewText.
  ///
  /// In id, this message translates to:
  /// **'Teks baru'**
  String get notebookNewText;

  /// No description provided for @notebookTextHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis teksnya'**
  String get notebookTextHint;

  /// No description provided for @notebookNewDiagram.
  ///
  /// In id, this message translates to:
  /// **'Diagram baru'**
  String get notebookNewDiagram;

  /// No description provided for @notebookMermaidSource.
  ///
  /// In id, this message translates to:
  /// **'Sumber Mermaid'**
  String get notebookMermaidSource;

  /// No description provided for @notebookPickImage.
  ///
  /// In id, this message translates to:
  /// **'Pilih gambar untuk catatan'**
  String get notebookPickImage;

  /// No description provided for @notebookImagePlaced.
  ///
  /// In id, this message translates to:
  /// **'Gambar ditaruh — sekarang bisa digeser, diubah ukuran, atau dihapus.'**
  String get notebookImagePlaced;

  /// No description provided for @notebookEditText.
  ///
  /// In id, this message translates to:
  /// **'Ubah teks'**
  String get notebookEditText;

  /// No description provided for @notebookEditDiagram.
  ///
  /// In id, this message translates to:
  /// **'Ubah diagram'**
  String get notebookEditDiagram;

  /// No description provided for @notebookPickPdf.
  ///
  /// In id, this message translates to:
  /// **'Pilih PDF untuk disisipkan sebagai lembar'**
  String get notebookPickPdf;

  /// No description provided for @notebookPreparingSheets.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan lembar dari {name}…'**
  String notebookPreparingSheets(String name);

  /// No description provided for @notebookPdfNoPages.
  ///
  /// In id, this message translates to:
  /// **'PDF itu tidak punya halaman yang bisa dibaca.'**
  String get notebookPdfNoPages;

  /// No description provided for @notebookSheetsInserted.
  ///
  /// In id, this message translates to:
  /// **'{count} lembar disisipkan dari {name}.'**
  String notebookSheetsInserted(int count, String name);

  /// No description provided for @notebookInsertPdfFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyisipkan PDF: {error}'**
  String notebookInsertPdfFailed(String error);

  /// No description provided for @notebookMarkdownSaved.
  ///
  /// In id, this message translates to:
  /// **'Markdown tersimpan: {name}'**
  String notebookMarkdownSaved(String name);

  /// No description provided for @notebookMarkdownFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menulis Markdown: {error}'**
  String notebookMarkdownFailed(String error);

  /// No description provided for @notebookSaveToCollectionFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan ke koleksi'**
  String get notebookSaveToCollectionFailed;

  /// No description provided for @notebookSavedToCollection.
  ///
  /// In id, this message translates to:
  /// **'Masuk ke koleksi catatan'**
  String get notebookSavedToCollection;

  /// No description provided for @notebookUnsavedBody.
  ///
  /// In id, this message translates to:
  /// **'Ada tulisan yang belum disimpan.'**
  String get notebookUnsavedBody;

  /// No description provided for @notebookKeepWriting.
  ///
  /// In id, this message translates to:
  /// **'Kembali menulis'**
  String get notebookKeepWriting;

  /// No description provided for @notebookDiscard.
  ///
  /// In id, this message translates to:
  /// **'Buang'**
  String get notebookDiscard;

  /// No description provided for @notebookStatus.
  ///
  /// In id, this message translates to:
  /// **'Lembar {page} dari {count} · {paper} {orientation} · alat: {tool}'**
  String notebookStatus(
    int page,
    int count,
    String paper,
    String orientation,
    String tool,
  );

  /// No description provided for @notebookUnsavedSuffix.
  ///
  /// In id, this message translates to:
  /// **' · belum disimpan'**
  String get notebookUnsavedSuffix;

  /// No description provided for @notebookZoomOut.
  ///
  /// In id, this message translates to:
  /// **'Perkecil'**
  String get notebookZoomOut;

  /// No description provided for @notebookZoomIn.
  ///
  /// In id, this message translates to:
  /// **'Perbesar'**
  String get notebookZoomIn;

  /// No description provided for @notebookFit.
  ///
  /// In id, this message translates to:
  /// **'Pas ke layar — kembalikan zum'**
  String get notebookFit;

  /// No description provided for @notebookSaveAndShare.
  ///
  /// In id, this message translates to:
  /// **'Simpan dan bagikan'**
  String get notebookSaveAndShare;

  /// No description provided for @notebookSaveAsMarkdown.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai Markdown'**
  String get notebookSaveAsMarkdown;

  /// No description provided for @notebookSaveToNoteCollection.
  ///
  /// In id, this message translates to:
  /// **'Simpan ke koleksi catatan'**
  String get notebookSaveToNoteCollection;

  /// No description provided for @notebookGuideLines.
  ///
  /// In id, this message translates to:
  /// **'Garis bantu lembar'**
  String get notebookGuideLines;

  /// No description provided for @notebookPlaceText.
  ///
  /// In id, this message translates to:
  /// **'teks'**
  String get notebookPlaceText;

  /// No description provided for @notebookPlaceImage.
  ///
  /// In id, this message translates to:
  /// **'gambar'**
  String get notebookPlaceImage;

  /// No description provided for @notebookPlaceDiagram.
  ///
  /// In id, this message translates to:
  /// **'diagram'**
  String get notebookPlaceDiagram;

  /// No description provided for @notebookTapToPlace.
  ///
  /// In id, this message translates to:
  /// **'Ketuk lembar untuk menaruh {what}.'**
  String notebookTapToPlace(String what);

  /// No description provided for @notebookTapFirstThenSecond.
  ///
  /// In id, this message translates to:
  /// **'Ketuk benda pertama, lalu benda kedua.'**
  String get notebookTapFirstThenSecond;

  /// No description provided for @notebookPickedCount.
  ///
  /// In id, this message translates to:
  /// **'{count} benda dipilih'**
  String notebookPickedCount(int count);

  /// No description provided for @notebookRelease.
  ///
  /// In id, this message translates to:
  /// **'Lepas'**
  String get notebookRelease;

  /// No description provided for @notebookPaperChanged.
  ///
  /// In id, this message translates to:
  /// **'Kertas jadi {paper}. {count} benda sekarang di luar kertas.'**
  String notebookPaperChanged(String paper, int count);

  /// No description provided for @notebookTurned.
  ///
  /// In id, this message translates to:
  /// **'Kertas jadi {orientation} — isinya ikut berputar, tidak ada yang keluar tepi.'**
  String notebookTurned(String orientation);

  /// No description provided for @notebookIdleTool.
  ///
  /// In id, this message translates to:
  /// **'Alat sekarang \"{tool}\" — pilih ikon pena untuk menggambar.'**
  String notebookIdleTool(String tool);

  /// No description provided for @notebookToolPen.
  ///
  /// In id, this message translates to:
  /// **'Pena'**
  String get notebookToolPen;

  /// No description provided for @notebookToolEraseStroke.
  ///
  /// In id, this message translates to:
  /// **'Hapus goresan'**
  String get notebookToolEraseStroke;

  /// No description provided for @notebookToolErasePart.
  ///
  /// In id, this message translates to:
  /// **'Hapus sebagian'**
  String get notebookToolErasePart;

  /// No description provided for @notebookToolSelect.
  ///
  /// In id, this message translates to:
  /// **'Pilih'**
  String get notebookToolSelect;

  /// No description provided for @notebookToolConnectTwo.
  ///
  /// In id, this message translates to:
  /// **'Hubungkan dua benda'**
  String get notebookToolConnectTwo;

  /// No description provided for @notebookToolText.
  ///
  /// In id, this message translates to:
  /// **'Teks'**
  String get notebookToolText;

  /// No description provided for @notebookToolDiagram.
  ///
  /// In id, this message translates to:
  /// **'Diagram'**
  String get notebookToolDiagram;

  /// No description provided for @notebookToolImage.
  ///
  /// In id, this message translates to:
  /// **'Gambar'**
  String get notebookToolImage;

  /// No description provided for @notebookComponentColor.
  ///
  /// In id, this message translates to:
  /// **'Warna komponen'**
  String get notebookComponentColor;

  /// No description provided for @notebookPenWidth.
  ///
  /// In id, this message translates to:
  /// **'Tebal pena'**
  String get notebookPenWidth;

  /// No description provided for @notebookEraserSize.
  ///
  /// In id, this message translates to:
  /// **'Ukuran penghapus'**
  String get notebookEraserSize;

  /// No description provided for @notebookWidthValue.
  ///
  /// In id, this message translates to:
  /// **'Tebal {value}'**
  String notebookWidthValue(String value);

  /// No description provided for @notebookEraserValue.
  ///
  /// In id, this message translates to:
  /// **'Penghapus {value}'**
  String notebookEraserValue(String value);

  /// No description provided for @notebookOpacity.
  ///
  /// In id, this message translates to:
  /// **'Kepekatan'**
  String get notebookOpacity;

  /// No description provided for @notebookPaperSize.
  ///
  /// In id, this message translates to:
  /// **'Ukuran kertas: {paper}'**
  String notebookPaperSize(String paper);

  /// No description provided for @notebookPortraitTap.
  ///
  /// In id, this message translates to:
  /// **'Kertas tegak — ketuk untuk mendatar'**
  String get notebookPortraitTap;

  /// No description provided for @notebookLandscapeTap.
  ///
  /// In id, this message translates to:
  /// **'Kertas mendatar — ketuk untuk tegak'**
  String get notebookLandscapeTap;

  /// No description provided for @notebookToolShape.
  ///
  /// In id, this message translates to:
  /// **'Bangun'**
  String get notebookToolShape;

  /// No description provided for @notebookToolConnect.
  ///
  /// In id, this message translates to:
  /// **'Hubungkan'**
  String get notebookToolConnect;

  /// No description provided for @notebookFingerOn.
  ///
  /// In id, this message translates to:
  /// **'Jari dan stylus sama-sama menggambar. Ketuk untuk hanya stylus — jari lalu dipakai menggeser dan memperbesar saja.'**
  String get notebookFingerOn;

  /// No description provided for @notebookStylusOnly.
  ///
  /// In id, this message translates to:
  /// **'Stylus menggambar, jari menggeser dan memperbesar. Ketuk untuk mengizinkan jari menggambar lagi.'**
  String get notebookStylusOnly;

  /// No description provided for @notebookFingerChip.
  ///
  /// In id, this message translates to:
  /// **'Jari + stylus'**
  String get notebookFingerChip;

  /// No description provided for @notebookStylusChip.
  ///
  /// In id, this message translates to:
  /// **'Stylus saja'**
  String get notebookStylusChip;

  /// No description provided for @notebookPrevSheet.
  ///
  /// In id, this message translates to:
  /// **'Lembar sebelumnya'**
  String get notebookPrevSheet;

  /// No description provided for @notebookNextSheet.
  ///
  /// In id, this message translates to:
  /// **'Lembar berikutnya'**
  String get notebookNextSheet;

  /// No description provided for @notebookNewSheet.
  ///
  /// In id, this message translates to:
  /// **'Lembar kosong baru'**
  String get notebookNewSheet;

  /// No description provided for @notebookInsertPdfSheet.
  ///
  /// In id, this message translates to:
  /// **'Sisipkan halaman PDF sebagai lembar'**
  String get notebookInsertPdfSheet;

  /// No description provided for @notebookDeleteSheet.
  ///
  /// In id, this message translates to:
  /// **'Hapus lembar ini'**
  String get notebookDeleteSheet;

  /// No description provided for @whiteboardErrPngEncode.
  ///
  /// In id, this message translates to:
  /// **'PNG gagal dikodekan'**
  String get whiteboardErrPngEncode;

  /// No description provided for @whiteboardErrPixels.
  ///
  /// In id, this message translates to:
  /// **'Piksel gagal dibaca'**
  String get whiteboardErrPixels;

  /// No description provided for @notesUpTo.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke {name}'**
  String notesUpTo(String name);

  /// No description provided for @notesSubcollectionSummary.
  ///
  /// In id, this message translates to:
  /// **'{notes, plural, =0{kosong} other{{notes} catatan}}{subs, plural, =0{} other{ · {subs} sub-koleksi}}'**
  String notesSubcollectionSummary(int notes, int subs);

  /// No description provided for @notesEditDetails.
  ///
  /// In id, this message translates to:
  /// **'Ubah keterangan'**
  String get notesEditDetails;

  /// No description provided for @notesOpen.
  ///
  /// In id, this message translates to:
  /// **'Buka'**
  String get notesOpen;

  /// No description provided for @notesPickNote.
  ///
  /// In id, this message translates to:
  /// **'Pilih catatan untuk melihat keterangannya.'**
  String get notesPickNote;

  /// No description provided for @notesDetails.
  ///
  /// In id, this message translates to:
  /// **'Keterangan'**
  String get notesDetails;

  /// No description provided for @notesNoDetails.
  ///
  /// In id, this message translates to:
  /// **'Belum ada keterangan. Tambahkan penulis, tanggal, tag, atau sumber supaya catatan ini mudah dikenali dan dicari.'**
  String get notesNoDetails;

  /// No description provided for @notesAddDetails.
  ///
  /// In id, this message translates to:
  /// **'Tambah keterangan'**
  String get notesAddDetails;

  /// No description provided for @notesFieldAuthors.
  ///
  /// In id, this message translates to:
  /// **'Penulis / pengajar'**
  String get notesFieldAuthors;

  /// No description provided for @notesFieldAuthorsHint.
  ///
  /// In id, this message translates to:
  /// **'Satu nama per baris'**
  String get notesFieldAuthorsHint;

  /// No description provided for @notesFieldDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get notesFieldDate;

  /// No description provided for @notesFieldDateHint.
  ///
  /// In id, this message translates to:
  /// **'mis. 14 Okt 2026, atau Minggu 3'**
  String get notesFieldDateHint;

  /// No description provided for @notesFieldTags.
  ///
  /// In id, this message translates to:
  /// **'Tag'**
  String get notesFieldTags;

  /// No description provided for @notesFieldTagsHint.
  ///
  /// In id, this message translates to:
  /// **'Pisahkan dengan koma'**
  String get notesFieldTagsHint;

  /// No description provided for @notesFieldSource.
  ///
  /// In id, this message translates to:
  /// **'Sumber'**
  String get notesFieldSource;

  /// No description provided for @notesFieldSourceHint.
  ///
  /// In id, this message translates to:
  /// **'Tautan, mata kuliah, atau acara'**
  String get notesFieldSourceHint;

  /// No description provided for @notesFieldDescription.
  ///
  /// In id, this message translates to:
  /// **'Uraian'**
  String get notesFieldDescription;

  /// No description provided for @notesFieldCollections.
  ///
  /// In id, this message translates to:
  /// **'Koleksi'**
  String get notesFieldCollections;

  /// No description provided for @notesFieldAdded.
  ///
  /// In id, this message translates to:
  /// **'Ditambahkan'**
  String get notesFieldAdded;

  /// No description provided for @notesFieldModified.
  ///
  /// In id, this message translates to:
  /// **'Diubah'**
  String get notesFieldModified;

  /// No description provided for @notesFieldFile.
  ///
  /// In id, this message translates to:
  /// **'Berkas'**
  String get notesFieldFile;

  /// No description provided for @notesMoreActions.
  ///
  /// In id, this message translates to:
  /// **'Tindakan lain'**
  String get notesMoreActions;

  /// No description provided for @notesBackToList.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke daftar'**
  String get notesBackToList;

  /// No description provided for @officeUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Dokumen ini tidak bisa dibaca: {error}'**
  String officeUnreadable(String error);

  /// No description provided for @officeEmpty.
  ///
  /// In id, this message translates to:
  /// **'Dokumennya kosong.'**
  String get officeEmpty;

  /// No description provided for @officeTextSmaller.
  ///
  /// In id, this message translates to:
  /// **'Perkecil teks'**
  String get officeTextSmaller;

  /// No description provided for @officeTextLarger.
  ///
  /// In id, this message translates to:
  /// **'Perbesar teks'**
  String get officeTextLarger;

  /// No description provided for @officeOpenExact.
  ///
  /// In id, this message translates to:
  /// **'Tampilan persis — ubah ke PDF lewat LibreOffice, lalu bisa dicari, ditandai, dan disajikan'**
  String get officeOpenExact;

  /// No description provided for @officeConvertFailed.
  ///
  /// In id, this message translates to:
  /// **'LibreOffice gagal mengubahnya ke PDF: {error}'**
  String officeConvertFailed(String error);

  /// No description provided for @officeTextOnly.
  ///
  /// In id, this message translates to:
  /// **'Format Office lama: hanya teksnya yang terbaca di sini. Untuk tampilan lengkap, buka di aplikasi Office.'**
  String get officeTextOnly;

  /// No description provided for @officeTextOnlyWithExact.
  ///
  /// In id, this message translates to:
  /// **'Format Office lama: hanya teksnya yang terbaca di sini. Tombol PDF di atas menampilkannya persis, lewat LibreOffice.'**
  String get officeTextOnlyWithExact;

  /// No description provided for @officeSlideN.
  ///
  /// In id, this message translates to:
  /// **'Slide {number}'**
  String officeSlideN(int number);

  /// No description provided for @officeSpeakerNotes.
  ///
  /// In id, this message translates to:
  /// **'Catatan pembicara'**
  String get officeSpeakerNotes;

  /// No description provided for @officePlay.
  ///
  /// In id, this message translates to:
  /// **'Putar presentasi'**
  String get officePlay;

  /// No description provided for @officeOpenAsPdf.
  ///
  /// In id, this message translates to:
  /// **'Buka sebagai PDF — mode menyajikan, mode baca, tandai'**
  String get officeOpenAsPdf;

  /// No description provided for @officeSaveAsPdf.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai PDF…'**
  String get officeSaveAsPdf;

  /// No description provided for @officeMakingPdf.
  ///
  /// In id, this message translates to:
  /// **'Membuat PDF…'**
  String get officeMakingPdf;

  /// No description provided for @officeMakingPdfSlides.
  ///
  /// In id, this message translates to:
  /// **'Membuat PDF… slide {done} dari {total}'**
  String officeMakingPdfSlides(int done, int total);

  /// No description provided for @officePdfSaved.
  ///
  /// In id, this message translates to:
  /// **'PDF tersimpan.'**
  String get officePdfSaved;

  /// No description provided for @officePdfNotSaved.
  ///
  /// In id, this message translates to:
  /// **'PDF tidak disimpan.'**
  String get officePdfNotSaved;

  /// No description provided for @officePdfFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat PDF: {error}'**
  String officePdfFailed(String error);

  /// No description provided for @officeSaveOriginal.
  ///
  /// In id, this message translates to:
  /// **'Simpan berkas asli…'**
  String get officeSaveOriginal;

  /// No description provided for @officeOriginalSaved.
  ///
  /// In id, this message translates to:
  /// **'Berkas asli tersimpan.'**
  String get officeOriginalSaved;

  /// No description provided for @officeOriginalNotSaved.
  ///
  /// In id, this message translates to:
  /// **'Berkas asli tidak disimpan.'**
  String get officeOriginalNotSaved;

  /// No description provided for @officeOriginalFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan berkas asli: {error}'**
  String officeOriginalFailed(String error);

  /// No description provided for @officeDownload.
  ///
  /// In id, this message translates to:
  /// **'Unduh…'**
  String get officeDownload;

  /// No description provided for @officeDownloadOriginal.
  ///
  /// In id, this message translates to:
  /// **'Berkas asli ({ext})'**
  String officeDownloadOriginal(String ext);

  /// No description provided for @officeDownloadPdf.
  ///
  /// In id, this message translates to:
  /// **'Sebagai PDF'**
  String get officeDownloadPdf;

  /// No description provided for @presenterAudienceWaiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu presenter…'**
  String get presenterAudienceWaiting;

  /// No description provided for @presenterSlideOf.
  ///
  /// In id, this message translates to:
  /// **'Slide {page} dari {total}'**
  String presenterSlideOf(int page, int total);

  /// No description provided for @presenterResetTimer.
  ///
  /// In id, this message translates to:
  /// **'Waktu berjalan — ketuk untuk mengulang dari nol'**
  String get presenterResetTimer;

  /// No description provided for @presenterNextSlide.
  ///
  /// In id, this message translates to:
  /// **'Slide berikutnya'**
  String get presenterNextSlide;

  /// No description provided for @presenterLastSlide.
  ///
  /// In id, this message translates to:
  /// **'Ini slide terakhir'**
  String get presenterLastSlide;

  /// No description provided for @presenterNotes.
  ///
  /// In id, this message translates to:
  /// **'Catatan presenter (hanya terlihat di sini)'**
  String get presenterNotes;

  /// No description provided for @presenterNotesHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis catatan untuk slide ini…'**
  String get presenterNotesHint;

  /// No description provided for @presenterBlank.
  ///
  /// In id, this message translates to:
  /// **'Layar hitam'**
  String get presenterBlank;

  /// No description provided for @presenterFullSlide.
  ///
  /// In id, this message translates to:
  /// **'Slide penuh'**
  String get presenterFullSlide;

  /// No description provided for @presenterStopAudience.
  ///
  /// In id, this message translates to:
  /// **'Tutup layar audiens'**
  String get presenterStopAudience;

  /// No description provided for @presenterOpenAudience.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan di layar lain (monitor kedua / proyektor)'**
  String get presenterOpenAudience;

  /// No description provided for @presenterShowPanel.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan panel presenter'**
  String get presenterShowPanel;

  /// No description provided for @presenterNoExternalDisplay.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada layar eksternal. Sambungkan monitor/proyektor (HDMI, USB-C) atau cast layar, lalu coba lagi.'**
  String get presenterNoExternalDisplay;

  /// No description provided for @presenterAudienceOpened.
  ///
  /// In id, this message translates to:
  /// **'Layar audiens terbuka — tekan F11 di jendela itu bila belum layar penuh'**
  String get presenterAudienceOpened;

  /// No description provided for @presenterAudienceClosed.
  ///
  /// In id, this message translates to:
  /// **'Layar audiens ditutup'**
  String get presenterAudienceClosed;

  /// No description provided for @presenterNotesSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Catatan presenter gagal disimpan: {error}'**
  String presenterNotesSaveFailed(String error);

  /// No description provided for @presenterNotesChanged.
  ///
  /// In id, this message translates to:
  /// **'Catatan presenter: {title}'**
  String presenterNotesChanged(String title);

  /// No description provided for @presenterPointer.
  ///
  /// In id, this message translates to:
  /// **'Penunjuk'**
  String get presenterPointer;

  /// No description provided for @presenterPointerTrail.
  ///
  /// In id, this message translates to:
  /// **'Buntut penunjuk'**
  String get presenterPointerTrail;

  /// No description provided for @presenterTrailOff.
  ///
  /// In id, this message translates to:
  /// **'Tanpa buntut'**
  String get presenterTrailOff;

  /// No description provided for @presenterTrailSeconds.
  ///
  /// In id, this message translates to:
  /// **'{seconds} detik'**
  String presenterTrailSeconds(String seconds);

  /// No description provided for @readerStylusOnlyOn.
  ///
  /// In id, this message translates to:
  /// **'Stylus saja: tangan yang bertumpu tidak akan menggambar.'**
  String get readerStylusOnlyOn;

  /// No description provided for @readerStylusOnlyOff.
  ///
  /// In id, this message translates to:
  /// **'Jari dan stylus dua-duanya boleh menggambar.'**
  String get readerStylusOnlyOff;

  /// No description provided for @readerCopyNotAllowed.
  ///
  /// In id, this message translates to:
  /// **'Dokumen ini tidak mengizinkan penyalinan'**
  String get readerCopyNotAllowed;

  /// No description provided for @readerNothingSelected.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada teks terpilih — tekan lama tepat di atas sebuah kata'**
  String get readerNothingSelected;

  /// No description provided for @readerEraserOn.
  ///
  /// In id, this message translates to:
  /// **'Penghapus aktif — sapukan di atas coretan'**
  String get readerEraserOn;

  /// No description provided for @readerBackToWriting.
  ///
  /// In id, this message translates to:
  /// **'Kembali menulis'**
  String get readerBackToWriting;

  /// No description provided for @readerEraserTooltip.
  ///
  /// In id, this message translates to:
  /// **'Penghapus — sapukan di atas coretan yang salah'**
  String get readerEraserTooltip;

  /// No description provided for @readerEraser.
  ///
  /// In id, this message translates to:
  /// **'Penghapus'**
  String get readerEraser;

  /// No description provided for @readerBackToPreviousColor.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke warna sebelumnya'**
  String get readerBackToPreviousColor;

  /// No description provided for @readerWhiteInk.
  ///
  /// In id, this message translates to:
  /// **'Tinta putih — menutup coretan'**
  String get readerWhiteInk;

  /// No description provided for @readerUndoEraseInk.
  ///
  /// In id, this message translates to:
  /// **'menghapus coretan'**
  String get readerUndoEraseInk;

  /// No description provided for @readerUndoEraseStroke.
  ///
  /// In id, this message translates to:
  /// **'menghapus goresan'**
  String get readerUndoEraseStroke;

  /// No description provided for @readerEraserMissed.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada coretan yang tersentuh penghapus'**
  String get readerEraserMissed;

  /// No description provided for @readerRedoStroke.
  ///
  /// In id, this message translates to:
  /// **'Ulangi goresan'**
  String get readerRedoStroke;

  /// No description provided for @readerNothingToRedo.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang bisa diulangi'**
  String get readerNothingToRedo;

  /// No description provided for @readerTapToPlaceSignature.
  ///
  /// In id, this message translates to:
  /// **'Ketuk halaman di tempat tanda tangannya ditaruh'**
  String get readerTapToPlaceSignature;

  /// No description provided for @readerCannotOverwriteAttachment.
  ///
  /// In id, this message translates to:
  /// **'Lampiran library tidak bisa ditimpa — pilih nama lain'**
  String get readerCannotOverwriteAttachment;

  /// No description provided for @readerPreparingPdf.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan PDF…'**
  String get readerPreparingPdf;

  /// No description provided for @readerSavePdf.
  ///
  /// In id, this message translates to:
  /// **'Simpan PDF'**
  String get readerSavePdf;

  /// No description provided for @readerNotSaved.
  ///
  /// In id, this message translates to:
  /// **'Tidak jadi disimpan'**
  String get readerNotSaved;

  /// No description provided for @readerNoLibraryOpen.
  ///
  /// In id, this message translates to:
  /// **'Belum ada library yang terbuka di aplikasi ini.'**
  String get readerNoLibraryOpen;

  /// No description provided for @readerUnsavedNotIncluded.
  ///
  /// In id, this message translates to:
  /// **'Anotasi yang belum disimpan tidak ikut. Simpan PDF dulu bila perlu.'**
  String get readerUnsavedNotIncluded;

  /// No description provided for @readerAddToCollectionTitle.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan ke koleksi'**
  String get readerAddToCollectionTitle;

  /// No description provided for @readerNoCollection.
  ///
  /// In id, this message translates to:
  /// **'Tanpa koleksi'**
  String get readerNoCollection;

  /// No description provided for @readerNoCollectionHint.
  ///
  /// In id, this message translates to:
  /// **'masuk library, tidak masuk koleksi mana pun'**
  String get readerNoCollectionHint;

  /// No description provided for @readerNewCollectionEllipsis.
  ///
  /// In id, this message translates to:
  /// **'Koleksi baru…'**
  String get readerNewCollectionEllipsis;

  /// No description provided for @readerNewCollectionHint.
  ///
  /// In id, this message translates to:
  /// **'dibuat lalu langsung dipakai'**
  String get readerNewCollectionHint;

  /// No description provided for @readerCreateCollectionFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat koleksi'**
  String get readerCreateCollectionFailed;

  /// No description provided for @readerDocumentTitle.
  ///
  /// In id, this message translates to:
  /// **'Judul dokumen'**
  String get readerDocumentTitle;

  /// No description provided for @readerCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get readerCancel;

  /// No description provided for @readerAdd.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan'**
  String get readerAdd;

  /// No description provided for @readerAddingToLibrary.
  ///
  /// In id, this message translates to:
  /// **'Menambahkan ke library…'**
  String get readerAddingToLibrary;

  /// No description provided for @readerAddFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menambahkan'**
  String get readerAddFailed;

  /// No description provided for @readerNewCollection.
  ///
  /// In id, this message translates to:
  /// **'Koleksi baru'**
  String get readerNewCollection;

  /// No description provided for @readerCollectionName.
  ///
  /// In id, this message translates to:
  /// **'Nama koleksi'**
  String get readerCollectionName;

  /// No description provided for @readerCollectionNameHelper.
  ///
  /// In id, this message translates to:
  /// **'Ditulis ke collections.json, ikut tersinkron ke GitHub'**
  String get readerCollectionNameHelper;

  /// No description provided for @readerCreate.
  ///
  /// In id, this message translates to:
  /// **'Buat'**
  String get readerCreate;

  /// No description provided for @readerReadingPageText.
  ///
  /// In id, this message translates to:
  /// **'Membaca teks halaman…'**
  String get readerReadingPageText;

  /// No description provided for @readerPrintWithoutLatest.
  ///
  /// In id, this message translates to:
  /// **'Cetak tanpa anotasi terbaru?'**
  String get readerPrintWithoutLatest;

  /// No description provided for @readerPrintAsIs.
  ///
  /// In id, this message translates to:
  /// **'Cetak apa adanya'**
  String get readerPrintAsIs;

  /// No description provided for @readerAddBlankPages.
  ///
  /// In id, this message translates to:
  /// **'Tambah halaman kosong'**
  String get readerAddBlankPages;

  /// No description provided for @readerPdfSavedAsImages.
  ///
  /// In id, this message translates to:
  /// **'PDF ini tidak bisa ditulisi langsung; halamannya disimpan sebagai gambar.'**
  String get readerPdfSavedAsImages;

  /// No description provided for @readerPreparingFile.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan berkas…'**
  String get readerPreparingFile;

  /// No description provided for @readerNothingSaved.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang disimpan'**
  String get readerNothingSaved;

  /// No description provided for @readerSaveAnnotatedCopy.
  ///
  /// In id, this message translates to:
  /// **'Simpan salinan beranotasi'**
  String get readerSaveAnnotatedCopy;

  /// No description provided for @readerSaveChangesFirst.
  ///
  /// In id, this message translates to:
  /// **'Simpan perubahan dulu?'**
  String get readerSaveChangesFirst;

  /// No description provided for @readerUnsavedStrokes.
  ///
  /// In id, this message translates to:
  /// **'Ada goresan yang belum disimpan. Kalau keluar sekarang, goresan itu hilang.'**
  String get readerUnsavedStrokes;

  /// No description provided for @readerLeaveWithoutSaving.
  ///
  /// In id, this message translates to:
  /// **'Keluar tanpa menyimpan'**
  String get readerLeaveWithoutSaving;

  /// No description provided for @readerSaveEllipsis.
  ///
  /// In id, this message translates to:
  /// **'Simpan…'**
  String get readerSaveEllipsis;

  /// No description provided for @readerSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get readerSave;

  /// No description provided for @readerMarking.
  ///
  /// In id, this message translates to:
  /// **'Menandai'**
  String get readerMarking;

  /// No description provided for @readerMark.
  ///
  /// In id, this message translates to:
  /// **'Tandai'**
  String get readerMark;

  /// No description provided for @readerTapToPlaceNote.
  ///
  /// In id, this message translates to:
  /// **'Ketuk halaman untuk menaruh catatan (ketuk lagi untuk batal)'**
  String get readerTapToPlaceNote;

  /// No description provided for @readerPlaceNote.
  ///
  /// In id, this message translates to:
  /// **'Tempel catatan di halaman'**
  String get readerPlaceNote;

  /// No description provided for @readerDoneDrawing.
  ///
  /// In id, this message translates to:
  /// **'Selesai menggambar'**
  String get readerDoneDrawing;

  /// No description provided for @readerDrawOnPage.
  ///
  /// In id, this message translates to:
  /// **'Tulis atau gambar di halaman'**
  String get readerDrawOnPage;

  /// No description provided for @readerTapToPlaceText.
  ///
  /// In id, this message translates to:
  /// **'Ketuk halaman untuk menaruh teks (ketuk lagi untuk batal)'**
  String get readerTapToPlaceText;

  /// No description provided for @readerFillText.
  ///
  /// In id, this message translates to:
  /// **'Isi teks di halaman — untuk mengisi formulir'**
  String get readerFillText;

  /// No description provided for @readerKeepScreenOnActive.
  ///
  /// In id, this message translates to:
  /// **'Layar tetap menyala — tekan untuk mematikan'**
  String get readerKeepScreenOnActive;

  /// No description provided for @readerKeepScreenOn.
  ///
  /// In id, this message translates to:
  /// **'Biarkan layar menyala selama membaca'**
  String get readerKeepScreenOn;

  /// No description provided for @readerKeepScreenOnEnabled.
  ///
  /// In id, this message translates to:
  /// **'Layar akan tetap menyala selama membaca'**
  String get readerKeepScreenOnEnabled;

  /// No description provided for @readerKeepScreenOnDisabled.
  ///
  /// In id, this message translates to:
  /// **'Layar kembali mati sendiri'**
  String get readerKeepScreenOnDisabled;

  /// No description provided for @readerPresent.
  ///
  /// In id, this message translates to:
  /// **'Sajikan — satu halaman penuh layar'**
  String get readerPresent;

  /// No description provided for @readerNothingToUndo.
  ///
  /// In id, this message translates to:
  /// **'Belum ada yang bisa diurungkan'**
  String get readerNothingToUndo;

  /// No description provided for @readerNothingToRedoYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada yang bisa diulangi'**
  String get readerNothingToRedoYet;

  /// No description provided for @readerSignature.
  ///
  /// In id, this message translates to:
  /// **'Tanda tangan'**
  String get readerSignature;

  /// No description provided for @readerSaveAndShare.
  ///
  /// In id, this message translates to:
  /// **'Simpan dan bagikan'**
  String get readerSaveAndShare;

  /// No description provided for @readerAddToCollectionMenu.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan ke koleksi…'**
  String get readerAddToCollectionMenu;

  /// No description provided for @readerAddToCollectionMenuHint.
  ///
  /// In id, this message translates to:
  /// **'masuk library dan ikut tersinkron'**
  String get readerAddToCollectionMenuHint;

  /// No description provided for @readerPrintMenu.
  ///
  /// In id, this message translates to:
  /// **'Cetak…'**
  String get readerPrintMenu;

  /// No description provided for @readerPrintMenuHint.
  ///
  /// In id, this message translates to:
  /// **'ke pencetak, atau simpan sebagai PDF'**
  String get readerPrintMenuHint;

  /// No description provided for @readerToMarkdown.
  ///
  /// In id, this message translates to:
  /// **'Ubah ke Markdown'**
  String get readerToMarkdown;

  /// No description provided for @readerToMarkdownHint.
  ///
  /// In id, this message translates to:
  /// **'teksnya jadi dokumen yang bisa disunting'**
  String get readerToMarkdownHint;

  /// No description provided for @readerToNotebook.
  ///
  /// In id, this message translates to:
  /// **'Jadikan buku catatan'**
  String get readerToNotebook;

  /// No description provided for @readerToNotebookHint.
  ///
  /// In id, this message translates to:
  /// **'halamannya jadi alas, bisa disunting lagi'**
  String get readerToNotebookHint;

  /// No description provided for @readerBlankPagesMenuHint.
  ///
  /// In id, this message translates to:
  /// **'papan tulis di akhir dokumen'**
  String get readerBlankPagesMenuHint;

  /// No description provided for @readerSaveMenuHintNew.
  ///
  /// In id, this message translates to:
  /// **'pilih nama dan tempat; yang asli aman'**
  String get readerSaveMenuHintNew;

  /// No description provided for @readerSaveAsMenu.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai…'**
  String get readerSaveAsMenu;

  /// No description provided for @readerSaveAsMenuHint.
  ///
  /// In id, this message translates to:
  /// **'nama atau tempat lain'**
  String get readerSaveAsMenuHint;

  /// No description provided for @readerExportPagesMenu.
  ///
  /// In id, this message translates to:
  /// **'Ekspor halaman…'**
  String get readerExportPagesMenu;

  /// No description provided for @readerExportPagesMenuHint.
  ///
  /// In id, this message translates to:
  /// **'PDF, PNG, atau JPG'**
  String get readerExportPagesMenuHint;

  /// No description provided for @readerShare.
  ///
  /// In id, this message translates to:
  /// **'Bagikan'**
  String get readerShare;

  /// No description provided for @readerShareHint.
  ///
  /// In id, this message translates to:
  /// **'chat, surel, atau aplikasi lain'**
  String get readerShareHint;

  /// No description provided for @readerStylusOnlyTooltip.
  ///
  /// In id, this message translates to:
  /// **'Stylus saja — sentuhan tangan tidak menggambar'**
  String get readerStylusOnlyTooltip;

  /// No description provided for @readerFingerAndStylusTooltip.
  ///
  /// In id, this message translates to:
  /// **'Jari + stylus boleh menggambar — ketuk untuk stylus saja'**
  String get readerFingerAndStylusTooltip;

  /// No description provided for @readerAddBlankSheet.
  ///
  /// In id, this message translates to:
  /// **'Tambah lembar kosong'**
  String get readerAddBlankSheet;

  /// No description provided for @readerReadMode.
  ///
  /// In id, this message translates to:
  /// **'Mode baca — sembunyikan semua bilah'**
  String get readerReadMode;

  /// No description provided for @readerSaveAnnotatedCopyFormats.
  ///
  /// In id, this message translates to:
  /// **'Simpan salinan beranotasi (PNG, JPG, PDF)'**
  String get readerSaveAnnotatedCopyFormats;

  /// No description provided for @readerZoomOut.
  ///
  /// In id, this message translates to:
  /// **'Perkecil'**
  String get readerZoomOut;

  /// No description provided for @readerZoomIn.
  ///
  /// In id, this message translates to:
  /// **'Perbesar'**
  String get readerZoomIn;

  /// No description provided for @readerAnnotationPanel.
  ///
  /// In id, this message translates to:
  /// **'Panel anotasi'**
  String get readerAnnotationPanel;

  /// No description provided for @readerGotIt.
  ///
  /// In id, this message translates to:
  /// **'Mengerti'**
  String get readerGotIt;

  /// No description provided for @readerDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get readerDone;

  /// No description provided for @readerUndoLastStroke.
  ///
  /// In id, this message translates to:
  /// **'Urungkan goresan terakhir'**
  String get readerUndoLastStroke;

  /// No description provided for @readerDiscardStrokes.
  ///
  /// In id, this message translates to:
  /// **'Buang semua goresan yang belum disimpan'**
  String get readerDiscardStrokes;

  /// No description provided for @readerTapWhereNote.
  ///
  /// In id, this message translates to:
  /// **'Ketuk tempat di halaman untuk menaruh catatan.'**
  String get readerTapWhereNote;

  /// No description provided for @readerPreviousPage.
  ///
  /// In id, this message translates to:
  /// **'Halaman sebelumnya'**
  String get readerPreviousPage;

  /// No description provided for @readerNextPage.
  ///
  /// In id, this message translates to:
  /// **'Halaman berikutnya'**
  String get readerNextPage;

  /// No description provided for @readerFingerAndStylusShort.
  ///
  /// In id, this message translates to:
  /// **'Jari + stylus — ketuk untuk stylus saja'**
  String get readerFingerAndStylusShort;

  /// No description provided for @readerFitPage.
  ///
  /// In id, this message translates to:
  /// **'Pas satu halaman ke layar'**
  String get readerFitPage;

  /// No description provided for @readerScribble.
  ///
  /// In id, this message translates to:
  /// **'Coret-coret di halaman'**
  String get readerScribble;

  /// No description provided for @readerUndo.
  ///
  /// In id, this message translates to:
  /// **'Urungkan'**
  String get readerUndo;

  /// No description provided for @readerSaveChooseTooltip.
  ///
  /// In id, this message translates to:
  /// **'Simpan… (pilih nama dan tempat)'**
  String get readerSaveChooseTooltip;

  /// No description provided for @readerAddScribbleSheet.
  ///
  /// In id, this message translates to:
  /// **'Tambah lembar kosong untuk dicoreti'**
  String get readerAddScribbleSheet;

  /// No description provided for @readerExitPresent.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari mode menyajikan'**
  String get readerExitPresent;

  /// No description provided for @readerExitReadMode.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari mode baca'**
  String get readerExitReadMode;

  /// No description provided for @readerClipboardFallback.
  ///
  /// In id, this message translates to:
  /// **'Anotasi ReadPaper'**
  String get readerClipboardFallback;

  /// No description provided for @readerClipboardEmpty.
  ///
  /// In id, this message translates to:
  /// **'Papan klip tidak berisi gambar atau anotasi'**
  String get readerClipboardEmpty;

  /// No description provided for @readerPasteImageUnsupported.
  ///
  /// In id, this message translates to:
  /// **'Menempel gambar belum bisa di perangkat ini — pakai \"Pilih berkas gambar\"'**
  String get readerPasteImageUnsupported;

  /// No description provided for @readerClipboardNoImage.
  ///
  /// In id, this message translates to:
  /// **'Papan klip tidak berisi gambar. Di peramban: klik kanan gambar → Salin gambar.'**
  String get readerClipboardNoImage;

  /// No description provided for @readerChooseImage.
  ///
  /// In id, this message translates to:
  /// **'Pilih gambar'**
  String get readerChooseImage;

  /// No description provided for @readerPreparingImage.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan gambar…'**
  String get readerPreparingImage;

  /// No description provided for @readerNotAnImage.
  ///
  /// In id, this message translates to:
  /// **'Isi papan klip atau berkasnya bukan gambar yang bisa dibaca'**
  String get readerNotAnImage;

  /// No description provided for @readerUndoPasteImage.
  ///
  /// In id, this message translates to:
  /// **'menempel gambar'**
  String get readerUndoPasteImage;

  /// No description provided for @readerInsertImage.
  ///
  /// In id, this message translates to:
  /// **'Sisipkan gambar'**
  String get readerInsertImage;

  /// No description provided for @readerPasteImage.
  ///
  /// In id, this message translates to:
  /// **'Tempel gambar dari papan klip'**
  String get readerPasteImage;

  /// No description provided for @readerPasteImageHint.
  ///
  /// In id, this message translates to:
  /// **'mis. \"Salin gambar\" di peramban — Ctrl+V'**
  String get readerPasteImageHint;

  /// No description provided for @readerChooseImageFile.
  ///
  /// In id, this message translates to:
  /// **'Pilih berkas gambar…'**
  String get readerChooseImageFile;

  /// No description provided for @readerAnnotationCopied.
  ///
  /// In id, this message translates to:
  /// **'Anotasi disalin — buka halaman tujuan, lalu Tempel'**
  String get readerAnnotationCopied;

  /// No description provided for @readerUndoCut.
  ///
  /// In id, this message translates to:
  /// **'memotong anotasi'**
  String get readerUndoCut;

  /// No description provided for @readerAnnotationCut.
  ///
  /// In id, this message translates to:
  /// **'Anotasi dipotong — buka halaman tujuan, lalu Tempel'**
  String get readerAnnotationCut;

  /// No description provided for @readerUndoPaste.
  ///
  /// In id, this message translates to:
  /// **'menempel anotasi'**
  String get readerUndoPaste;

  /// No description provided for @readerMoveToPage.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan ke halaman'**
  String get readerMoveToPage;

  /// No description provided for @readerMove.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan'**
  String get readerMove;

  /// No description provided for @readerCopy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get readerCopy;

  /// No description provided for @readerCut.
  ///
  /// In id, this message translates to:
  /// **'Potong'**
  String get readerCut;

  /// No description provided for @readerToPage.
  ///
  /// In id, this message translates to:
  /// **'Ke halaman…'**
  String get readerToPage;

  /// No description provided for @readerPaste.
  ///
  /// In id, this message translates to:
  /// **'Tempel'**
  String get readerPaste;

  /// No description provided for @readerDeselect.
  ///
  /// In id, this message translates to:
  /// **'Batal pilih'**
  String get readerDeselect;

  /// No description provided for @readerClearClipboard.
  ///
  /// In id, this message translates to:
  /// **'Kosongkan papan klip'**
  String get readerClearClipboard;

  /// No description provided for @readerDropOnPage.
  ///
  /// In id, this message translates to:
  /// **'Lepaskan di atas halaman untuk memindahkannya'**
  String get readerDropOnPage;

  /// No description provided for @readerOutsidePage.
  ///
  /// In id, this message translates to:
  /// **'Di luar halaman'**
  String get readerOutsidePage;

  /// No description provided for @readerUndoReshape.
  ///
  /// In id, this message translates to:
  /// **'mengubah bentuk anotasi'**
  String get readerUndoReshape;

  /// No description provided for @readerUndoMove.
  ///
  /// In id, this message translates to:
  /// **'memindahkan anotasi'**
  String get readerUndoMove;

  /// No description provided for @readerHighlight.
  ///
  /// In id, this message translates to:
  /// **'Stabilo'**
  String get readerHighlight;

  /// No description provided for @readerHighlightComment.
  ///
  /// In id, this message translates to:
  /// **'Stabilo + komentar'**
  String get readerHighlightComment;

  /// No description provided for @readerUnderline.
  ///
  /// In id, this message translates to:
  /// **'Garis bawah'**
  String get readerUnderline;

  /// No description provided for @readerText.
  ///
  /// In id, this message translates to:
  /// **'Teks'**
  String get readerText;

  /// No description provided for @readerComment.
  ///
  /// In id, this message translates to:
  /// **'Komentar'**
  String get readerComment;

  /// No description provided for @readerTextHint.
  ///
  /// In id, this message translates to:
  /// **'Yang ditulis di halaman…'**
  String get readerTextHint;

  /// No description provided for @readerCommentHint.
  ///
  /// In id, this message translates to:
  /// **'Catatan untuk bagian ini…'**
  String get readerCommentHint;

  /// No description provided for @readerUndoEdit.
  ///
  /// In id, this message translates to:
  /// **'mengubah anotasi'**
  String get readerUndoEdit;

  /// No description provided for @readerDeleteAnnotationQuestion.
  ///
  /// In id, this message translates to:
  /// **'Hapus anotasi?'**
  String get readerDeleteAnnotationQuestion;

  /// No description provided for @readerDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get readerDelete;

  /// No description provided for @readerUndoDelete.
  ///
  /// In id, this message translates to:
  /// **'menghapus anotasi'**
  String get readerUndoDelete;

  /// No description provided for @readerAnnotationDeleted.
  ///
  /// In id, this message translates to:
  /// **'Anotasi dihapus'**
  String get readerAnnotationDeleted;

  /// No description provided for @readerDeleteFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus anotasi'**
  String get readerDeleteFailed;

  /// No description provided for @readerSaveImageFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan gambar'**
  String get readerSaveImageFailed;

  /// No description provided for @readerSaved.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan'**
  String get readerSaved;

  /// No description provided for @readerChangesSaved.
  ///
  /// In id, this message translates to:
  /// **'Perubahan tersimpan'**
  String get readerChangesSaved;

  /// No description provided for @readerAddedNotSaved.
  ///
  /// In id, this message translates to:
  /// **'Ditambahkan — belum disimpan ke berkas'**
  String get readerAddedNotSaved;

  /// No description provided for @readerAdded.
  ///
  /// In id, this message translates to:
  /// **'Ditambahkan'**
  String get readerAdded;

  /// No description provided for @readerSaveAnnotationFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan anotasi'**
  String get readerSaveAnnotationFailed;

  /// No description provided for @readerEditNote.
  ///
  /// In id, this message translates to:
  /// **'Sunting catatan'**
  String get readerEditNote;

  /// No description provided for @readerCloseNote.
  ///
  /// In id, this message translates to:
  /// **'Tutup catatan'**
  String get readerCloseNote;

  /// No description provided for @readerDragToMove.
  ///
  /// In id, this message translates to:
  /// **'Seret untuk memindahkan'**
  String get readerDragToMove;

  /// No description provided for @readerDragToResize.
  ///
  /// In id, this message translates to:
  /// **'Seret untuk mengubah ukuran'**
  String get readerDragToResize;

  /// No description provided for @readerDragToRotate.
  ///
  /// In id, this message translates to:
  /// **'Seret untuk memutar'**
  String get readerDragToRotate;

  /// No description provided for @readerEditCommentColor.
  ///
  /// In id, this message translates to:
  /// **'Ubah komentar / warna'**
  String get readerEditCommentColor;

  /// No description provided for @readerDpiScreen.
  ///
  /// In id, this message translates to:
  /// **'Layar (72 dpi)'**
  String get readerDpiScreen;

  /// No description provided for @readerDpiGood.
  ///
  /// In id, this message translates to:
  /// **'Baik (144 dpi)'**
  String get readerDpiGood;

  /// No description provided for @readerDpiPrint.
  ///
  /// In id, this message translates to:
  /// **'Cetak (288 dpi)'**
  String get readerDpiPrint;

  /// No description provided for @readerFormat.
  ///
  /// In id, this message translates to:
  /// **'Format'**
  String get readerFormat;

  /// No description provided for @readerDensity.
  ///
  /// In id, this message translates to:
  /// **'Kerapatan'**
  String get readerDensity;

  /// No description provided for @readerWholeDocument.
  ///
  /// In id, this message translates to:
  /// **'Seluruh dokumen'**
  String get readerWholeDocument;

  /// No description provided for @readerJumpToPage.
  ///
  /// In id, this message translates to:
  /// **'Lompat ke halaman'**
  String get readerJumpToPage;

  /// No description provided for @readerPage.
  ///
  /// In id, this message translates to:
  /// **'Halaman'**
  String get readerPage;

  /// No description provided for @readerGo.
  ///
  /// In id, this message translates to:
  /// **'Pergi'**
  String get readerGo;

  /// No description provided for @readerTableOfContents.
  ///
  /// In id, this message translates to:
  /// **'Daftar isi'**
  String get readerTableOfContents;

  /// No description provided for @readerNoTableOfContents.
  ///
  /// In id, this message translates to:
  /// **'Berkas ini tidak membawa daftar isi.'**
  String get readerNoTableOfContents;

  /// No description provided for @readerUntitled.
  ///
  /// In id, this message translates to:
  /// **'(tanpa judul)'**
  String get readerUntitled;

  /// No description provided for @readerTintNormal.
  ///
  /// In id, this message translates to:
  /// **'Normal'**
  String get readerTintNormal;

  /// No description provided for @readerTintSepia.
  ///
  /// In id, this message translates to:
  /// **'Sepia'**
  String get readerTintSepia;

  /// No description provided for @readerTintDim.
  ///
  /// In id, this message translates to:
  /// **'Redup'**
  String get readerTintDim;

  /// No description provided for @readerTintInvert.
  ///
  /// In id, this message translates to:
  /// **'Balik warna'**
  String get readerTintInvert;

  /// No description provided for @readerSaveInFolder.
  ///
  /// In id, this message translates to:
  /// **'Simpan di folder'**
  String get readerSaveInFolder;

  /// No description provided for @readerFileNameTaken.
  ///
  /// In id, this message translates to:
  /// **'Nama berkas sudah dipakai'**
  String get readerFileNameTaken;

  /// No description provided for @readerNo.
  ///
  /// In id, this message translates to:
  /// **'Tidak'**
  String get readerNo;

  /// No description provided for @readerYesOverwrite.
  ///
  /// In id, this message translates to:
  /// **'Ya, timpa'**
  String get readerYesOverwrite;

  /// No description provided for @readerSaveAs.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai'**
  String get readerSaveAs;

  /// No description provided for @readerFileName.
  ///
  /// In id, this message translates to:
  /// **'Nama berkas'**
  String get readerFileName;

  /// No description provided for @readerSaveIn.
  ///
  /// In id, this message translates to:
  /// **'Simpan di'**
  String get readerSaveIn;

  /// No description provided for @readerChooseOtherFolder.
  ///
  /// In id, this message translates to:
  /// **'Pilih folder lain…'**
  String get readerChooseOtherFolder;

  /// No description provided for @readerOtherPlace.
  ///
  /// In id, this message translates to:
  /// **'Tempat lain…'**
  String get readerOtherPlace;

  /// No description provided for @readerClearSelection.
  ///
  /// In id, this message translates to:
  /// **'Batalkan pilihan'**
  String get readerClearSelection;

  /// No description provided for @readerSignatureHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis di sini, lalu ketuk halaman untuk menaruhnya.'**
  String get readerSignatureHint;

  /// No description provided for @readerClear.
  ///
  /// In id, this message translates to:
  /// **'Bersihkan'**
  String get readerClear;

  /// No description provided for @readerUse.
  ///
  /// In id, this message translates to:
  /// **'Pakai'**
  String get readerUse;

  /// No description provided for @readerErrSourceMissing.
  ///
  /// In id, this message translates to:
  /// **'Berkas asalnya tidak ada'**
  String get readerErrSourceMissing;

  /// No description provided for @readerErrPdfUnreadable.
  ///
  /// In id, this message translates to:
  /// **'PDF-nya tidak bisa dibaca'**
  String get readerErrPdfUnreadable;

  /// No description provided for @readerErrPageCopy.
  ///
  /// In id, this message translates to:
  /// **'Halaman aslinya tidak bisa disalin'**
  String get readerErrPageCopy;

  /// No description provided for @readerErrBlankPage.
  ///
  /// In id, this message translates to:
  /// **'Halaman kosongnya tidak bisa dibuat'**
  String get readerErrBlankPage;

  /// No description provided for @readerErrFileMissing.
  ///
  /// In id, this message translates to:
  /// **'Berkasnya tidak ada'**
  String get readerErrFileMissing;

  /// No description provided for @readerErrPdfWrite.
  ///
  /// In id, this message translates to:
  /// **'PDF-nya gagal ditulis'**
  String get readerErrPdfWrite;

  /// No description provided for @readerErrPdfOpen.
  ///
  /// In id, this message translates to:
  /// **'PDF-nya tidak bisa dibuka'**
  String get readerErrPdfOpen;

  /// No description provided for @readerErrPageRewrite.
  ///
  /// In id, this message translates to:
  /// **'Isi halaman gagal ditulis ulang'**
  String get readerErrPageRewrite;

  /// No description provided for @readerErrRender.
  ///
  /// In id, this message translates to:
  /// **'Halaman gagal dirender'**
  String get readerErrRender;

  /// No description provided for @readerErrPngEncode.
  ///
  /// In id, this message translates to:
  /// **'PNG gagal dikodekan'**
  String get readerErrPngEncode;

  /// No description provided for @readerErrPixels.
  ///
  /// In id, this message translates to:
  /// **'Piksel gagal dibaca'**
  String get readerErrPixels;

  /// No description provided for @readerLoadAnnotationsFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membaca anotasi: {error}'**
  String readerLoadAnnotationsFailed(String error);

  /// No description provided for @readerNoteAnnotationsUnreadable.
  ///
  /// In id, this message translates to:
  /// **'Anotasi catatan ini tidak terbaca: {error}'**
  String readerNoteAnnotationsUnreadable(String error);

  /// No description provided for @readerCharactersCopied.
  ///
  /// In id, this message translates to:
  /// **'{count} karakter disalin'**
  String readerCharactersCopied(int count);

  /// No description provided for @readerRedoStep.
  ///
  /// In id, this message translates to:
  /// **'Ulangi: {step}'**
  String readerRedoStep(String step);

  /// No description provided for @readerPageColorInverted.
  ///
  /// In id, this message translates to:
  /// **'Warna halaman: {color} — warna penanda ikut terbalik'**
  String readerPageColorInverted(String color);

  /// No description provided for @readerPageColor.
  ///
  /// In id, this message translates to:
  /// **'Warna halaman: {color}'**
  String readerPageColor(String color);

  /// No description provided for @readerResumedAtPage.
  ///
  /// In id, this message translates to:
  /// **'Dilanjutkan di halaman {page}'**
  String readerResumedAtPage(int page);

  /// No description provided for @readerUndone.
  ///
  /// In id, this message translates to:
  /// **'Diurungkan: {step}'**
  String readerUndone(String step);

  /// No description provided for @readerRedone.
  ///
  /// In id, this message translates to:
  /// **'Diulangi: {step}'**
  String readerRedone(String step);

  /// No description provided for @readerOriginalFolder.
  ///
  /// In id, this message translates to:
  /// **'Folder berkas aslinya ({folder})'**
  String readerOriginalFolder(String folder);

  /// No description provided for @readerSavedFile.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan: {name} ({size})'**
  String readerSavedFile(String name, String size);

  /// No description provided for @readerSaveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan: {error}'**
  String readerSaveFailed(String error);

  /// No description provided for @readerPdfSaved.
  ///
  /// In id, this message translates to:
  /// **'PDF disimpan ({size})'**
  String readerPdfSaved(String size);

  /// No description provided for @readerAddToCollectionExplain.
  ///
  /// In id, this message translates to:
  /// **'Berkasnya disalin ke dalam library, dibuatkan item Zotero, lalu di-commit — jadi ikut tersinkron ke GitHub.'**
  String get readerAddToCollectionExplain;

  /// No description provided for @readerNewSubcollectionIn.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi baru di dalam {name}'**
  String readerNewSubcollectionIn(String name);

  /// No description provided for @readerAddedButAnnotationsFailed.
  ///
  /// In id, this message translates to:
  /// **'Masuk library, tetapi anotasinya gagal disalin: {error}'**
  String readerAddedButAnnotationsFailed(String error);

  /// No description provided for @readerAddedAs.
  ///
  /// In id, this message translates to:
  /// **'Masuk library sebagai {key}'**
  String readerAddedAs(String key);

  /// No description provided for @readerAddedWithAnnotations.
  ///
  /// In id, this message translates to:
  /// **'Masuk library sebagai {key} beserta {count} anotasi — terbaca juga di Zotero setelah dikirim'**
  String readerAddedWithAnnotations(String key, int count);

  /// No description provided for @readerPreparingNotebook.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan buku catatan dari {title}…'**
  String readerPreparingNotebook(String title);

  /// No description provided for @readerNotebookFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat buku catatan: {error}'**
  String readerNotebookFailed(String error);

  /// No description provided for @readerSubcollectionIn.
  ///
  /// In id, this message translates to:
  /// **'Sub-koleksi di {name}'**
  String readerSubcollectionIn(String name);

  /// No description provided for @readerNoTextLayer.
  ///
  /// In id, this message translates to:
  /// **'PDF ini tidak punya lapisan teks — kemungkinan hasil pindaian. Yang keluar hanya judulnya.'**
  String get readerNoTextLayer;

  /// No description provided for @readerMarkdownFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengubah ke Markdown: {error}'**
  String readerMarkdownFailed(String error);

  /// No description provided for @readerPrintExplain.
  ///
  /// In id, this message translates to:
  /// **'Ada anotasi yang belum menyatu dengan halaman, jadi belum akan ikut tercetak. Simpan PDF dulu kalau anotasinya perlu ikut.'**
  String get readerPrintExplain;

  /// No description provided for @readerPrintFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mencetak: {error}'**
  String readerPrintFailed(String error);

  /// No description provided for @readerBlankPagesExplain.
  ///
  /// In id, this message translates to:
  /// **'Seukuran halaman pertamanya. Berkas aslinya tidak disentuh — yang berubah adalah salinan kerja, sampai Anda menyimpannya.'**
  String get readerBlankPagesExplain;

  /// No description provided for @readerPagesAfter.
  ///
  /// In id, this message translates to:
  /// **'{count} halaman setelah halaman {page}'**
  String readerPagesAfter(int count, int page);

  /// No description provided for @readerPagesAtEnd.
  ///
  /// In id, this message translates to:
  /// **'{count} halaman di akhir dokumen'**
  String readerPagesAtEnd(int count);

  /// No description provided for @readerBlankPagesAdded.
  ///
  /// In id, this message translates to:
  /// **'{count} halaman kosong ditambahkan di akhir — simpan lewat menu bagikan'**
  String readerBlankPagesAdded(int count);

  /// No description provided for @readerBlankPagesInserted.
  ///
  /// In id, this message translates to:
  /// **'{count} halaman kosong disisipkan setelah halaman {page} — simpan lewat menu bagikan'**
  String readerBlankPagesInserted(int count, int page);

  /// No description provided for @readerAddPagesFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menambah halaman: {error}'**
  String readerAddPagesFailed(String error);

  /// No description provided for @readerShareFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membagikan: {error}'**
  String readerShareFailed(String error);

  /// No description provided for @readerSavePage.
  ///
  /// In id, this message translates to:
  /// **'Simpan halaman {page}'**
  String readerSavePage(int page);

  /// No description provided for @readerSaveImageError.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyimpan gambar: {error}'**
  String readerSaveImageError(String error);

  /// No description provided for @readerFilesSaved.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas disimpan'**
  String readerFilesSaved(int count);

  /// No description provided for @readerPreparingPdfPages.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan PDF {count} halaman…'**
  String readerPreparingPdfPages(int count);

  /// No description provided for @readerPdfFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat PDF: {error}'**
  String readerPdfFailed(String error);

  /// No description provided for @readerUnsavedStandalone.
  ///
  /// In id, this message translates to:
  /// **'Coretan dan anotasi di {title} belum disimpan ke berkas. Kalau keluar sekarang, semuanya hilang.'**
  String readerUnsavedStandalone(String title);

  /// No description provided for @readerUndoStep.
  ///
  /// In id, this message translates to:
  /// **'Urungkan: {step}'**
  String readerUndoStep(String step);

  /// No description provided for @readerSaveMenuHintTo.
  ///
  /// In id, this message translates to:
  /// **'ke {name}'**
  String readerSaveMenuHintTo(String name);

  /// No description provided for @readerStatus.
  ///
  /// In id, this message translates to:
  /// **'{count} anotasi · halaman {page}'**
  String readerStatus(int count, int page);

  /// No description provided for @readerStatusOf.
  ///
  /// In id, this message translates to:
  /// **'{count} anotasi · halaman {page} dari {total}'**
  String readerStatusOf(int count, int page, int total);

  /// No description provided for @readerCoachMark.
  ///
  /// In id, this message translates to:
  /// **'Untuk menandai: tekan \"Tandai\", pilih warna, lalu sapukan jari di atas teks — begitu jari diangkat teks langsung berwarna. Untuk menyalin: biarkan \"Tandai\" mati, tekan lama di teks, lalu pilih Salin. Untuk catatan: tekan ikon catatan, lalu ketuk halaman.'**
  String get readerCoachMark;

  /// No description provided for @readerMarkingBannerTouch.
  ///
  /// In id, this message translates to:
  /// **'Sapukan jari di atas teks — lepas jari, langsung ditandai {color}. Geser halaman dan salin teks nonaktif; tekan Selesai untuk kembali.'**
  String readerMarkingBannerTouch(String color);

  /// No description provided for @readerMarkingBannerMouse.
  ///
  /// In id, this message translates to:
  /// **'Seret mouse di atas teks — lepas tombolnya, langsung ditandai {color}. Geser halaman dan salin teks nonaktif; tekan Selesai untuk kembali.'**
  String readerMarkingBannerMouse(String color);

  /// No description provided for @readerEraserBanner.
  ///
  /// In id, this message translates to:
  /// **'Penghapus: sapukan di atas coretan yang salah — goresan yang tersentuh dibuang utuh.'**
  String get readerEraserBanner;

  /// No description provided for @readerPenBanner.
  ///
  /// In id, this message translates to:
  /// **'Gambar bebas di halaman dengan jari atau stylus.'**
  String get readerPenBanner;

  /// No description provided for @readerPenPending.
  ///
  /// In id, this message translates to:
  /// **'{count} goresan di halaman {page} — disimpan saat menekan Selesai.'**
  String readerPenPending(int count, int page);

  /// No description provided for @readerSaveTo.
  ///
  /// In id, this message translates to:
  /// **'Simpan ke {name}'**
  String readerSaveTo(String name);

  /// No description provided for @readerPageNumber.
  ///
  /// In id, this message translates to:
  /// **'Halaman {page}'**
  String readerPageNumber(int page);

  /// No description provided for @readerImagePasted.
  ///
  /// In id, this message translates to:
  /// **'Gambar ditempel di halaman {page} — seret sudutnya untuk mengubah ukuran'**
  String readerImagePasted(int page);

  /// No description provided for @readerPastedOnPage.
  ///
  /// In id, this message translates to:
  /// **'Ditempel di halaman {page} — seret untuk memindahkannya'**
  String readerPastedOnPage(int page);

  /// No description provided for @readerPageRange.
  ///
  /// In id, this message translates to:
  /// **'Halaman 1 sampai {count}'**
  String readerPageRange(int count);

  /// No description provided for @readerNoSuchPage.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada halaman {page} — dokumen ini {count} halaman'**
  String readerNoSuchPage(int page, int count);

  /// No description provided for @readerUndoMoveToPage.
  ///
  /// In id, this message translates to:
  /// **'memindahkan anotasi ke halaman {page}'**
  String readerUndoMoveToPage(int page);

  /// No description provided for @readerMovedToPage.
  ///
  /// In id, this message translates to:
  /// **'Dipindah ke halaman {page}'**
  String readerMovedToPage(int page);

  /// No description provided for @readerPasteOnPage.
  ///
  /// In id, this message translates to:
  /// **'Tempel di halaman {page}'**
  String readerPasteOnPage(int page);

  /// No description provided for @readerTextOnPage.
  ///
  /// In id, this message translates to:
  /// **'Isi teks di halaman {page}'**
  String readerTextOnPage(int page);

  /// No description provided for @readerNoteOnPage.
  ///
  /// In id, this message translates to:
  /// **'Catatan di halaman {page}'**
  String readerNoteOnPage(int page);

  /// No description provided for @readerAnnotationOnPage.
  ///
  /// In id, this message translates to:
  /// **'Anotasi halaman {page}'**
  String readerAnnotationOnPage(String page);

  /// No description provided for @readerUndoAdd.
  ///
  /// In id, this message translates to:
  /// **'menambah {type}'**
  String readerUndoAdd(String type);

  /// No description provided for @readerNoteBubbleTitle.
  ///
  /// In id, this message translates to:
  /// **'Catatan · hal. {page}'**
  String readerNoteBubbleTitle(String page);

  /// No description provided for @readerHighlightColor.
  ///
  /// In id, this message translates to:
  /// **'Warna stabilo: {color}'**
  String readerHighlightColor(String color);

  /// No description provided for @readerStrokeWidth.
  ///
  /// In id, this message translates to:
  /// **'Tebal goresan: {width}'**
  String readerStrokeWidth(String width);

  /// No description provided for @readerOnlyPage.
  ///
  /// In id, this message translates to:
  /// **'Hanya halaman {page}'**
  String readerOnlyPage(int page);

  /// No description provided for @readerOnePdfPages.
  ///
  /// In id, this message translates to:
  /// **'Satu PDF berisi {count} halaman'**
  String readerOnePdfPages(int count);

  /// No description provided for @readerFilesOnePerPage.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas, satu per halaman'**
  String readerFilesOnePerPage(int count);

  /// No description provided for @readerExportExplain.
  ///
  /// In id, this message translates to:
  /// **'Stabilo, garis bawah, dan coretan ikut tergambar. Berkas aslinya tidak disentuh.'**
  String get readerExportExplain;

  /// No description provided for @readerExportPdfImages.
  ///
  /// In id, this message translates to:
  /// **'Halaman disimpan sebagai gambar di dalam PDF, jadi teksnya tidak bisa dicari atau disalin lagi di salinan itu.'**
  String get readerExportPdfImages;

  /// No description provided for @readerExportLarge.
  ///
  /// In id, this message translates to:
  /// **'{count} halaman pada kerapatan ini akan makan waktu dan ruang penyimpanan yang tidak sedikit.'**
  String readerExportLarge(int count);

  /// No description provided for @readerNoAnnotationsYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada anotasi.\n\nPilih teks pada halaman, lalu pilih Stabilo atau Stabilo + komentar.'**
  String get readerNoAnnotationsYet;

  /// No description provided for @readerPageShort.
  ///
  /// In id, this message translates to:
  /// **'hal. {page}'**
  String readerPageShort(String page);

  /// No description provided for @readerPageMustBeBetween.
  ///
  /// In id, this message translates to:
  /// **'Halaman harus antara 1 dan {count}'**
  String readerPageMustBeBetween(int count);

  /// No description provided for @readerOfPages.
  ///
  /// In id, this message translates to:
  /// **'dari {count}'**
  String readerOfPages(int count);

  /// No description provided for @readerOpenPage.
  ///
  /// In id, this message translates to:
  /// **'Buka halaman {page}'**
  String readerOpenPage(int page);

  /// No description provided for @readerOverwriteOriginal.
  ///
  /// In id, this message translates to:
  /// **'{name} adalah berkas yang sedang dibuka. Menimpanya membuat versi aslinya hilang, dan coretannya melebur ke halaman.\n\nTimpa berkas aslinya?'**
  String readerOverwriteOriginal(String name);

  /// No description provided for @readerOverwriteExisting.
  ///
  /// In id, this message translates to:
  /// **'{name} sudah ada di folder ini.\n\nTimpa dengan yang baru?'**
  String readerOverwriteExisting(String name);

  /// No description provided for @readerSaveAsExplain.
  ///
  /// In id, this message translates to:
  /// **'Berkas yang dibuka tidak disentuh. Setelah ini, Simpan menulis ke berkas baru ini.'**
  String get readerSaveAsExplain;

  /// No description provided for @readerOutsideZoteroPalette.
  ///
  /// In id, this message translates to:
  /// **'{name} (di luar palet Zotero)'**
  String readerOutsideZoteroPalette(String name);

  /// No description provided for @readerErrCannotRead.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa dibaca: {path}'**
  String readerErrCannotRead(String path);

  /// No description provided for @readerErrPageSize.
  ///
  /// In id, this message translates to:
  /// **'Ukuran halaman tidak masuk akal: {size}'**
  String readerErrPageSize(String size);

  /// No description provided for @readerEmbeddedLabel.
  ///
  /// In id, this message translates to:
  /// **'Di dalam PDF · hanya dibaca'**
  String get readerEmbeddedLabel;

  /// No description provided for @readerEmbeddedReadOnly.
  ///
  /// In id, this message translates to:
  /// **'Anotasi ini tertanam di dalam PDF (dibuat di aplikasi lain); di sini hanya bisa dibaca.'**
  String get readerEmbeddedReadOnly;

  /// No description provided for @tabsLibrary.
  ///
  /// In id, this message translates to:
  /// **'Library'**
  String get tabsLibrary;

  /// No description provided for @tabsClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup tab'**
  String get tabsClose;

  /// No description provided for @tabsCloseOthers.
  ///
  /// In id, this message translates to:
  /// **'Tutup tab lain'**
  String get tabsCloseOthers;

  /// No description provided for @tabsMoveRight.
  ///
  /// In id, this message translates to:
  /// **'Pindah ke panel kanan'**
  String get tabsMoveRight;

  /// No description provided for @tabsMoveLeft.
  ///
  /// In id, this message translates to:
  /// **'Pindah ke panel kiri'**
  String get tabsMoveLeft;

  /// No description provided for @tabsSplitHint.
  ///
  /// In id, this message translates to:
  /// **'Seret tab ke sini, atau pilih \"Pindah ke panel kanan\", untuk membaca dua dokumen berdampingan'**
  String get tabsSplitHint;

  /// No description provided for @workspaceSwitchRepoCount.
  ///
  /// In id, this message translates to:
  /// **'Ganti repositori ({count} tersedia)'**
  String workspaceSwitchRepoCount(int count);

  /// No description provided for @workspaceAddAnotherRepo.
  ///
  /// In id, this message translates to:
  /// **'{remote} — tambah repositori lain'**
  String workspaceAddAnotherRepo(String remote);

  /// No description provided for @workspaceManageRepos.
  ///
  /// In id, this message translates to:
  /// **'Kelola repositori…'**
  String get workspaceManageRepos;

  /// No description provided for @workspaceSwitchLibrary.
  ///
  /// In id, this message translates to:
  /// **'Ganti library'**
  String get workspaceSwitchLibrary;

  /// No description provided for @workspaceFetchingLibrary.
  ///
  /// In id, this message translates to:
  /// **'Mengambil…'**
  String get workspaceFetchingLibrary;

  /// No description provided for @workspaceFetchLibrary.
  ///
  /// In id, this message translates to:
  /// **'Ambil library'**
  String get workspaceFetchLibrary;

  /// No description provided for @syncPullCount.
  ///
  /// In id, this message translates to:
  /// **'Tarik {count} commit baru'**
  String syncPullCount(int count);

  /// No description provided for @syncPull.
  ///
  /// In id, this message translates to:
  /// **'Tarik perubahan'**
  String get syncPull;

  /// No description provided for @syncMenu.
  ///
  /// In id, this message translates to:
  /// **'Sinkronisasi'**
  String get syncMenu;

  /// No description provided for @syncCheck.
  ///
  /// In id, this message translates to:
  /// **'Periksa perubahan'**
  String get syncCheck;

  /// No description provided for @syncSend.
  ///
  /// In id, this message translates to:
  /// **'Kirim perubahan'**
  String get syncSend;

  /// No description provided for @syncDetails.
  ///
  /// In id, this message translates to:
  /// **'Detail sinkronisasi'**
  String get syncDetails;

  /// No description provided for @syncCheckRemote.
  ///
  /// In id, this message translates to:
  /// **'Periksa perubahan di remote'**
  String get syncCheckRemote;

  /// No description provided for @syncSendToGitHub.
  ///
  /// In id, this message translates to:
  /// **'Kirim perubahan ke GitHub'**
  String get syncSendToGitHub;

  /// No description provided for @syncBusyWait.
  ///
  /// In id, this message translates to:
  /// **'Sinkronisasi sedang berjalan, tunggu sampai selesai.'**
  String get syncBusyWait;

  /// No description provided for @syncBusyPhaseWait.
  ///
  /// In id, this message translates to:
  /// **'{phase} Tunggu sampai selesai.'**
  String syncBusyPhaseWait(String phase);

  /// No description provided for @syncNothingToSend.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada perubahan untuk dikirim.'**
  String get syncNothingToSend;

  /// No description provided for @syncTooltipBranch.
  ///
  /// In id, this message translates to:
  /// **'Branch: {branch}'**
  String syncTooltipBranch(String branch);

  /// No description provided for @syncTooltipLastCommit.
  ///
  /// In id, this message translates to:
  /// **'Commit terakhir: {subject}'**
  String syncTooltipLastCommit(String subject);

  /// No description provided for @syncTooltipLastSync.
  ///
  /// In id, this message translates to:
  /// **'Sinkron terakhir: {time}'**
  String syncTooltipLastSync(String time);

  /// No description provided for @workspaceReadingLibrary.
  ///
  /// In id, this message translates to:
  /// **'Membaca library dari berkas…'**
  String get workspaceReadingLibrary;

  /// No description provided for @syncCommitMessage.
  ///
  /// In id, this message translates to:
  /// **'Pesan commit'**
  String get syncCommitMessage;

  /// No description provided for @syncCommitAndSend.
  ///
  /// In id, this message translates to:
  /// **'Commit & kirim'**
  String get syncCommitAndSend;

  /// No description provided for @workspaceCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get workspaceCancel;

  /// No description provided for @workspaceAccessSshHttps.
  ///
  /// In id, this message translates to:
  /// **'lewat SSH atau HTTPS'**
  String get workspaceAccessSshHttps;

  /// No description provided for @workspaceAccessToken.
  ///
  /// In id, this message translates to:
  /// **'lewat token GitHub'**
  String get workspaceAccessToken;

  /// No description provided for @workspaceNoRepoTitle.
  ///
  /// In id, this message translates to:
  /// **'Belum ada repositori'**
  String get workspaceNoRepoTitle;

  /// No description provided for @workspaceNoRepoBody.
  ///
  /// In id, this message translates to:
  /// **'ReadPaper membaca library Zotero yang disinkronkan ke GitHub oleh plugin zotero-github-sync. Tambahkan repositori ({access}) untuk mulai membaca, menandai dan memberi komentar pada paper.'**
  String workspaceNoRepoBody(String access);

  /// No description provided for @workspaceAddRepo.
  ///
  /// In id, this message translates to:
  /// **'Tambah repositori'**
  String get workspaceAddRepo;

  /// No description provided for @workspaceFetchLibraryNamed.
  ///
  /// In id, this message translates to:
  /// **'Ambil library \"{name}\"'**
  String workspaceFetchLibraryNamed(String name);

  /// No description provided for @workspaceCloneNamed.
  ///
  /// In id, this message translates to:
  /// **'Clone \"{name}\"'**
  String workspaceCloneNamed(String name);

  /// No description provided for @workspaceResumeNote.
  ///
  /// In id, this message translates to:
  /// **'Unduhan sebelumnya terputus. Melanjutkan hanya mengambil berkas yang belum sempat tersimpan.'**
  String get workspaceResumeNote;

  /// No description provided for @workspaceLazyNote.
  ///
  /// In id, this message translates to:
  /// **'Metadata library diunduh sekarang; berkas PDF menyusul saat papernya dibuka.'**
  String get workspaceLazyNote;

  /// No description provided for @workspaceWillSaveAt.
  ///
  /// In id, this message translates to:
  /// **'Akan disimpan di {path}'**
  String workspaceWillSaveAt(String path);

  /// No description provided for @workspaceCheckConnection.
  ///
  /// In id, this message translates to:
  /// **'Periksa koneksi'**
  String get workspaceCheckConnection;

  /// No description provided for @workspaceEditProfile.
  ///
  /// In id, this message translates to:
  /// **'Ubah profil'**
  String get workspaceEditProfile;

  /// No description provided for @workspaceDownloading.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh…'**
  String get workspaceDownloading;

  /// No description provided for @workspaceCloning.
  ///
  /// In id, this message translates to:
  /// **'Meng-clone…'**
  String get workspaceCloning;

  /// No description provided for @workspaceResume.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan'**
  String get workspaceResume;

  /// No description provided for @workspaceFetchNow.
  ///
  /// In id, this message translates to:
  /// **'Ambil sekarang'**
  String get workspaceFetchNow;

  /// No description provided for @workspaceCloneNow.
  ///
  /// In id, this message translates to:
  /// **'Clone sekarang'**
  String get workspaceCloneNow;

  /// No description provided for @workspaceLibraryUnreadableTitle.
  ///
  /// In id, this message translates to:
  /// **'Library tidak terbaca'**
  String get workspaceLibraryUnreadableTitle;

  /// No description provided for @workspaceLibraryUnreadableBody.
  ///
  /// In id, this message translates to:
  /// **'Repositori sudah ada di lokal tetapi tidak ditemukan struktur Zotero (collections.json dan folder items/). Pastikan repositori memang hasil ekspor plugin Zotero GitHub Sync, lalu tarik perubahan terbaru.'**
  String get workspaceLibraryUnreadableBody;

  /// No description provided for @workspaceReload.
  ///
  /// In id, this message translates to:
  /// **'Baca ulang'**
  String get workspaceReload;

  /// No description provided for @workspacePull.
  ///
  /// In id, this message translates to:
  /// **'Pull'**
  String get workspacePull;

  /// No description provided for @workspaceRepository.
  ///
  /// In id, this message translates to:
  /// **'Repositori'**
  String get workspaceRepository;

  /// No description provided for @syncLfsMissing.
  ///
  /// In id, this message translates to:
  /// **'git-lfs tidak terpasang; lampiran besar tetap berupa pointer'**
  String get syncLfsMissing;

  /// No description provided for @syncLfsPullAll.
  ///
  /// In id, this message translates to:
  /// **'Unduh semua berkas LFS'**
  String get syncLfsPullAll;

  /// No description provided for @syncBranchLine.
  ///
  /// In id, this message translates to:
  /// **'branch {branch}'**
  String syncBranchLine(String branch);

  /// No description provided for @syncTabChanges.
  ///
  /// In id, this message translates to:
  /// **'Perubahan'**
  String get syncTabChanges;

  /// No description provided for @syncTabHistory.
  ///
  /// In id, this message translates to:
  /// **'Riwayat'**
  String get syncTabHistory;

  /// No description provided for @syncTabLog.
  ///
  /// In id, this message translates to:
  /// **'Log git'**
  String get syncTabLog;

  /// No description provided for @syncRecloneNotice.
  ///
  /// In id, this message translates to:
  /// **'Salinan lokal ini masih menyimpan semua lampiran. Mengambilnya ulang hanya mengunduh metadata; PDF menyusul saat papernya dibuka.'**
  String get syncRecloneNotice;

  /// No description provided for @syncReclone.
  ///
  /// In id, this message translates to:
  /// **'Ambil ulang'**
  String get syncReclone;

  /// No description provided for @syncRecloneTitle.
  ///
  /// In id, this message translates to:
  /// **'Ambil ulang salinan lokal?'**
  String get syncRecloneTitle;

  /// No description provided for @syncRecloneBody.
  ///
  /// In id, this message translates to:
  /// **'Folder lokal dihapus lalu diambil lagi tanpa lampiran. Anotasi yang sudah dikirim ke GitHub tetap aman; yang belum dikirim akan hilang, jadi ini ditolak kalau masih ada perubahan tertunda.'**
  String get syncRecloneBody;

  /// No description provided for @syncNoLocalChanges.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada perubahan lokal.'**
  String get syncNoLocalChanges;

  /// No description provided for @syncNoCommits.
  ///
  /// In id, this message translates to:
  /// **'Belum ada commit.'**
  String get syncNoCommits;

  /// No description provided for @syncNoGitOutput.
  ///
  /// In id, this message translates to:
  /// **'Belum ada keluaran git.'**
  String get syncNoGitOutput;

  /// No description provided for @workspaceManageReposTooltip.
  ///
  /// In id, this message translates to:
  /// **'Kelola repositori'**
  String get workspaceManageReposTooltip;

  /// No description provided for @workspaceReadingLibraryShort.
  ///
  /// In id, this message translates to:
  /// **'Membaca library…'**
  String get workspaceReadingLibraryShort;

  /// No description provided for @workspaceFillToken.
  ///
  /// In id, this message translates to:
  /// **'Isi token'**
  String get workspaceFillToken;

  /// No description provided for @workspaceRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get workspaceRetry;

  /// No description provided for @workspaceClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get workspaceClose;

  /// No description provided for @workspaceTransferRepoNotFetched.
  ///
  /// In id, this message translates to:
  /// **'Repositori \"{name}\" belum diambil ke perangkat ini. Buka sekali dan ambil library-nya, lalu ulangi.'**
  String workspaceTransferRepoNotFetched(String name);

  /// No description provided for @workspaceTransferLibraryMissing.
  ///
  /// In id, this message translates to:
  /// **'Library di \"{name}\" belum ada di perangkat ini. Buka repositori itu sekali dan ambil library-nya, lalu ulangi.'**
  String workspaceTransferLibraryMissing(String name);

  /// No description provided for @workspaceTransferTitle.
  ///
  /// In id, this message translates to:
  /// **'Ke repositori lain'**
  String get workspaceTransferTitle;

  /// No description provided for @workspaceTransferNoOthers.
  ///
  /// In id, this message translates to:
  /// **'Belum ada repositori lain. Tambahkan dulu di pengaturan Repositori.'**
  String get workspaceTransferNoOthers;

  /// No description provided for @workspaceTransferChange.
  ///
  /// In id, this message translates to:
  /// **'Ganti'**
  String get workspaceTransferChange;

  /// No description provided for @workspaceTransferMove.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan'**
  String get workspaceTransferMove;

  /// No description provided for @workspaceTransferCopy.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get workspaceTransferCopy;

  /// No description provided for @workspaceTransferMoveNote.
  ///
  /// In id, this message translates to:
  /// **'Dihapus dari repositori ini setelah salinannya utuh di tujuan.'**
  String get workspaceTransferMoveNote;

  /// No description provided for @workspaceTransferCopyNote.
  ///
  /// In id, this message translates to:
  /// **'Yang di sini tetap; tujuan mendapat salinannya.'**
  String get workspaceTransferCopyNote;

  /// No description provided for @workspaceTransferNotesRoot.
  ///
  /// In id, this message translates to:
  /// **'Akar Catatan'**
  String get workspaceTransferNotesRoot;

  /// No description provided for @workspaceTransferNotesUnfiled.
  ///
  /// In id, this message translates to:
  /// **'Catatan, tanpa koleksi'**
  String get workspaceTransferNotesUnfiled;

  /// No description provided for @workspaceTransferLibraryRoot.
  ///
  /// In id, this message translates to:
  /// **'Akar library'**
  String get workspaceTransferLibraryRoot;

  /// No description provided for @workspaceTransferUnfiled.
  ///
  /// In id, this message translates to:
  /// **'Tanpa koleksi'**
  String get workspaceTransferUnfiled;

  /// No description provided for @workspaceComputingSize.
  ///
  /// In id, this message translates to:
  /// **'menghitung ukuran…'**
  String get workspaceComputingSize;

  /// No description provided for @syncPhaseCounting.
  ///
  /// In id, this message translates to:
  /// **'Menghitung objek'**
  String get syncPhaseCounting;

  /// No description provided for @syncPhaseCompressing.
  ///
  /// In id, this message translates to:
  /// **'Memampatkan objek'**
  String get syncPhaseCompressing;

  /// No description provided for @syncPhaseReceiving.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh objek'**
  String get syncPhaseReceiving;

  /// No description provided for @syncPhaseResolving.
  ///
  /// In id, this message translates to:
  /// **'Menyusun delta'**
  String get syncPhaseResolving;

  /// No description provided for @syncPhaseWritingFiles.
  ///
  /// In id, this message translates to:
  /// **'Menulis berkas'**
  String get syncPhaseWritingFiles;

  /// No description provided for @syncPhaseFiltering.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh berkas besar'**
  String get syncPhaseFiltering;

  /// No description provided for @syncPhaseLfs.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh berkas LFS'**
  String get syncPhaseLfs;

  /// No description provided for @syncPhaseSending.
  ///
  /// In id, this message translates to:
  /// **'Mengirim objek'**
  String get syncPhaseSending;

  /// No description provided for @syncPhaseEnumerating.
  ///
  /// In id, this message translates to:
  /// **'Mendata objek'**
  String get syncPhaseEnumerating;

  /// No description provided for @workspaceStatsNotFetched.
  ///
  /// In id, this message translates to:
  /// **'belum diambil ke perangkat ini'**
  String get workspaceStatsNotFetched;

  /// No description provided for @workspaceStatsItems.
  ///
  /// In id, this message translates to:
  /// **'{count} item'**
  String workspaceStatsItems(String count);

  /// No description provided for @workspaceStatsCollections.
  ///
  /// In id, this message translates to:
  /// **'{count} koleksi'**
  String workspaceStatsCollections(String count);

  /// No description provided for @workspaceStatsAttachments.
  ///
  /// In id, this message translates to:
  /// **'lampiran {size}'**
  String workspaceStatsAttachments(String size);

  /// No description provided for @workspaceStatsUnsent.
  ///
  /// In id, this message translates to:
  /// **'{count} belum terkirim'**
  String workspaceStatsUnsent(int count);

  /// No description provided for @workspaceStatsBehind.
  ///
  /// In id, this message translates to:
  /// **'{count} baru di GitHub'**
  String workspaceStatsBehind(int count);

  /// No description provided for @syncPhaseCloning.
  ///
  /// In id, this message translates to:
  /// **'Meng-clone repositori…'**
  String get syncPhaseCloning;

  /// No description provided for @syncPhaseFetching.
  ///
  /// In id, this message translates to:
  /// **'Memeriksa perubahan…'**
  String get syncPhaseFetching;

  /// No description provided for @syncPhasePulling.
  ///
  /// In id, this message translates to:
  /// **'Menarik perubahan…'**
  String get syncPhasePulling;

  /// No description provided for @syncPhaseCommitting.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan perubahan…'**
  String get syncPhaseCommitting;

  /// No description provided for @syncPhasePushing.
  ///
  /// In id, this message translates to:
  /// **'Mengirim perubahan…'**
  String get syncPhasePushing;

  /// No description provided for @syncChangeNew.
  ///
  /// In id, this message translates to:
  /// **'baru'**
  String get syncChangeNew;

  /// No description provided for @syncChangeAdded.
  ///
  /// In id, this message translates to:
  /// **'ditambah'**
  String get syncChangeAdded;

  /// No description provided for @syncChangeModified.
  ///
  /// In id, this message translates to:
  /// **'diubah'**
  String get syncChangeModified;

  /// No description provided for @syncChangeDeleted.
  ///
  /// In id, this message translates to:
  /// **'dihapus'**
  String get syncChangeDeleted;

  /// No description provided for @syncChangeRenamed.
  ///
  /// In id, this message translates to:
  /// **'dipindah'**
  String get syncChangeRenamed;

  /// No description provided for @syncStatusNotCloned.
  ///
  /// In id, this message translates to:
  /// **'Belum di-clone'**
  String get syncStatusNotCloned;

  /// No description provided for @syncStatusLocalChanges.
  ///
  /// In id, this message translates to:
  /// **'{count} perubahan lokal'**
  String syncStatusLocalChanges(int count);

  /// No description provided for @syncStatusAhead.
  ///
  /// In id, this message translates to:
  /// **'{count} commit belum di-push'**
  String syncStatusAhead(int count);

  /// No description provided for @syncStatusBehind.
  ///
  /// In id, this message translates to:
  /// **'{count} commit baru di remote'**
  String syncStatusBehind(int count);

  /// No description provided for @syncStatusInSync.
  ///
  /// In id, this message translates to:
  /// **'Sinkron'**
  String get syncStatusInSync;

  /// No description provided for @workspaceErrNoZoteroExport.
  ///
  /// In id, this message translates to:
  /// **'Tidak menemukan ekspor Zotero di repositori ini. Struktur yang diharapkan: zotero/<library>/collections.json'**
  String get workspaceErrNoZoteroExport;

  /// No description provided for @workspaceErrReadLibrary.
  ///
  /// In id, this message translates to:
  /// **'Gagal membaca library: {error}'**
  String workspaceErrReadLibrary(String error);

  /// No description provided for @workspaceErrNoRemoteUrl.
  ///
  /// In id, this message translates to:
  /// **'URL remote belum diisi untuk profil ini.'**
  String get workspaceErrNoRemoteUrl;

  /// No description provided for @workspaceErrUnsentBeforeReclone.
  ///
  /// In id, this message translates to:
  /// **'Masih ada perubahan yang belum dikirim ke GitHub. Kirim dulu, baru ambil ulang.'**
  String get workspaceErrUnsentBeforeReclone;

  /// No description provided for @workspaceErrDeleteOldCopy.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus salinan lama: {error}'**
  String workspaceErrDeleteOldCopy(String error);

  /// No description provided for @workspaceErrAnnotationNoLibrary.
  ///
  /// In id, this message translates to:
  /// **'Anotasi tidak tersimpan: tidak ada library aktif di aplikasi.'**
  String get workspaceErrAnnotationNoLibrary;

  /// No description provided for @workspaceErrAnnotationUnchanged.
  ///
  /// In id, this message translates to:
  /// **'Anotasi tidak tersimpan: berkas item tidak berubah.'**
  String get workspaceErrAnnotationUnchanged;

  /// No description provided for @workspaceErrAnnotationSave.
  ///
  /// In id, this message translates to:
  /// **'Anotasi tidak tersimpan: {error}'**
  String workspaceErrAnnotationSave(String error);

  /// No description provided for @workspaceErrAnnotationDeleteNoLibrary.
  ///
  /// In id, this message translates to:
  /// **'Anotasi tidak dihapus: tidak ada library aktif.'**
  String get workspaceErrAnnotationDeleteNoLibrary;

  /// No description provided for @workspaceErrAnnotationDelete.
  ///
  /// In id, this message translates to:
  /// **'Anotasi tidak dihapus: {error}'**
  String workspaceErrAnnotationDelete(String error);

  /// No description provided for @workspaceErrPictureNoRepo.
  ///
  /// In id, this message translates to:
  /// **'Gambar tidak tersimpan: tidak ada repositori aktif.'**
  String get workspaceErrPictureNoRepo;

  /// No description provided for @workspaceErrPictureSave.
  ///
  /// In id, this message translates to:
  /// **'Gambar tidak tersimpan: {error}'**
  String workspaceErrPictureSave(String error);

  /// No description provided for @workspaceErrPictureDelete.
  ///
  /// In id, this message translates to:
  /// **'Gambar tidak dihapus: {error}'**
  String workspaceErrPictureDelete(String error);

  /// No description provided for @workspaceErrNoLibraryForFile.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada library aktif untuk menampung berkas ini.'**
  String get workspaceErrNoLibraryForFile;

  /// No description provided for @workspaceErrAddToLibrary.
  ///
  /// In id, this message translates to:
  /// **'Gagal menambahkan ke library: {error}'**
  String workspaceErrAddToLibrary(String error);

  /// No description provided for @workspaceErrNoLibraryForFolder.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada library aktif untuk menampung folder ini.'**
  String get workspaceErrNoLibraryForFolder;

  /// No description provided for @workspaceErrImportStopped.
  ///
  /// In id, this message translates to:
  /// **'Impor folder berhenti: {error}'**
  String workspaceErrImportStopped(String error);

  /// No description provided for @workspaceErrNoLibrary.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada library aktif.'**
  String get workspaceErrNoLibrary;

  /// No description provided for @workspaceErrCreateCollection.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuat koleksi: {error}'**
  String workspaceErrCreateCollection(String error);

  /// No description provided for @workspaceErrSameRepo.
  ///
  /// In id, this message translates to:
  /// **'Repositori tujuannya sama dengan asal.'**
  String get workspaceErrSameRepo;

  /// No description provided for @workspaceErrMoveFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memindah: {error}'**
  String workspaceErrMoveFailed(String error);

  /// No description provided for @workspaceErrCopyFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyalin: {error}'**
  String workspaceErrCopyFailed(String error);

  /// No description provided for @workspaceErrCollectionGone.
  ///
  /// In id, this message translates to:
  /// **'Koleksinya tidak ada lagi.'**
  String get workspaceErrCollectionGone;

  /// No description provided for @workspaceErrMissingAttachments.
  ///
  /// In id, this message translates to:
  /// **'{count} lampiran belum ada di perangkat ini — belum diunduh, atau masih penunjuk Git LFS. Buka papernya sekali supaya PDF-nya diunduh (di desktop: LFS pull), lalu ulangi. Tidak ada yang dipindah: tanpa PDF-nya, paper itu akan tiba kosong.'**
  String workspaceErrMissingAttachments(int count);

  /// No description provided for @workspaceErrChangeCollection.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengubah koleksi: {error}'**
  String workspaceErrChangeCollection(String error);

  /// No description provided for @workspaceErrTargetCollectionGone.
  ///
  /// In id, this message translates to:
  /// **'Koleksi tujuan tidak ada lagi.'**
  String get workspaceErrTargetCollectionGone;

  /// No description provided for @workspaceErrMove.
  ///
  /// In id, this message translates to:
  /// **'Gagal memindahkan: {error}'**
  String workspaceErrMove(String error);

  /// No description provided for @workspaceErrDelete.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus: {error}'**
  String workspaceErrDelete(String error);

  /// No description provided for @workspaceErrDeleteClone.
  ///
  /// In id, this message translates to:
  /// **'Gagal menghapus clone lokal: {error}'**
  String workspaceErrDeleteClone(String error);

  /// No description provided for @syncGitCliLabel.
  ///
  /// In id, this message translates to:
  /// **'git (CLI sistem)'**
  String get syncGitCliLabel;

  /// No description provided for @syncFileAlreadyLocal.
  ///
  /// In id, this message translates to:
  /// **'Berkas sudah ada di lokal'**
  String get syncFileAlreadyLocal;

  /// No description provided for @syncFileLocationUnknown.
  ///
  /// In id, this message translates to:
  /// **'Lokasi berkas tidak dikenali.'**
  String get syncFileLocationUnknown;

  /// No description provided for @syncDownloadingFile.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh {name}…'**
  String syncDownloadingFile(String name);

  /// No description provided for @syncFileDownloaded.
  ///
  /// In id, this message translates to:
  /// **'Berkas selesai diunduh'**
  String get syncFileDownloaded;

  /// No description provided for @syncFileNotInRepo.
  ///
  /// In id, this message translates to:
  /// **'Berkas tidak ada di repositori ini.'**
  String get syncFileNotInRepo;

  /// No description provided for @syncDownloadingLfs.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh berkas besar (Git LFS)…'**
  String get syncDownloadingLfs;

  /// No description provided for @syncRemoteReachable.
  ///
  /// In id, this message translates to:
  /// **'Remote terjangkau'**
  String get syncRemoteReachable;

  /// No description provided for @syncConnected.
  ///
  /// In id, this message translates to:
  /// **'Terhubung · {count} branch di remote'**
  String syncConnected(String count);

  /// No description provided for @syncTargetNotEmpty.
  ///
  /// In id, this message translates to:
  /// **'Direktori tujuan sudah berisi berkas. Hapus atau pilih lokasi lain.'**
  String get syncTargetNotEmpty;

  /// No description provided for @syncCloned.
  ///
  /// In id, this message translates to:
  /// **'Repositori berhasil di-clone'**
  String get syncCloned;

  /// No description provided for @syncPreparingMetadata.
  ///
  /// In id, this message translates to:
  /// **'Menyiapkan berkas metadata…'**
  String get syncPreparingMetadata;

  /// No description provided for @syncMetadataReady.
  ///
  /// In id, this message translates to:
  /// **'Metadata siap'**
  String get syncMetadataReady;

  /// No description provided for @syncRepoReadyLazy.
  ///
  /// In id, this message translates to:
  /// **'Repositori siap. Lampiran diunduh saat papernya dibuka.'**
  String get syncRepoReadyLazy;

  /// No description provided for @syncFetchDone.
  ///
  /// In id, this message translates to:
  /// **'Fetch selesai'**
  String get syncFetchDone;

  /// No description provided for @syncPullDone.
  ///
  /// In id, this message translates to:
  /// **'Pull selesai'**
  String get syncPullDone;

  /// No description provided for @syncInterruptedNotAborted.
  ///
  /// In id, this message translates to:
  /// **'Sinkronisasi sebelumnya berhenti di tengah {operation} dan tidak bisa dibatalkan otomatis. Keadaannya dicadangkan di {backup}.'**
  String syncInterruptedNotAborted(String operation, String backup);

  /// No description provided for @syncInterruptedRecovered.
  ///
  /// In id, this message translates to:
  /// **'Sinkronisasi yang dulu berhenti di tengah sudah dipulihkan (cadangan: {backup})'**
  String syncInterruptedRecovered(String backup);

  /// No description provided for @syncConflict.
  ///
  /// In id, this message translates to:
  /// **'Perubahan di sini dan di GitHub bentrok dan tidak bisa disatukan otomatis. Tidak ada yang hilang: perubahan lokal tetap di commit-nya{detail}.'**
  String syncConflict(String detail);

  /// No description provided for @syncRebasedOnGitHub.
  ///
  /// In id, this message translates to:
  /// **'Perubahan lokal dipasang di atas versi GitHub'**
  String get syncRebasedOnGitHub;

  /// No description provided for @syncAutoMerged.
  ///
  /// In id, this message translates to:
  /// **'Digabung otomatis: {files}'**
  String syncAutoMerged(String files);

  /// No description provided for @syncGitHubCopies.
  ///
  /// In id, this message translates to:
  /// **'Versi GitHub disimpan sebagai {files}'**
  String syncGitHubCopies(String files);

  /// No description provided for @syncNothingToCommit.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada perubahan untuk di-commit'**
  String get syncNothingToCommit;

  /// No description provided for @syncCommitCreated.
  ///
  /// In id, this message translates to:
  /// **'Commit dibuat'**
  String get syncCommitCreated;

  /// No description provided for @syncPushDone.
  ///
  /// In id, this message translates to:
  /// **'Push selesai'**
  String get syncPushDone;

  /// No description provided for @syncLfsSkipped.
  ///
  /// In id, this message translates to:
  /// **'git-lfs tidak terpasang, dilewati'**
  String get syncLfsSkipped;

  /// No description provided for @syncLfsDownloaded.
  ///
  /// In id, this message translates to:
  /// **'Berkas LFS diunduh'**
  String get syncLfsDownloaded;

  /// No description provided for @syncRemoteUpdated.
  ///
  /// In id, this message translates to:
  /// **'Remote diperbarui'**
  String get syncRemoteUpdated;

  /// No description provided for @syncGitCannotRun.
  ///
  /// In id, this message translates to:
  /// **'git tidak dapat dijalankan: {error}'**
  String syncGitCannotRun(String error);

  /// No description provided for @syncErrSshRejected.
  ///
  /// In id, this message translates to:
  /// **'SSH ditolak: kunci tidak diterima GitHub. Periksa path kunci di profil.'**
  String get syncErrSshRejected;

  /// No description provided for @syncErrHttpsAuth.
  ///
  /// In id, this message translates to:
  /// **'Autentikasi HTTPS gagal: token kosong atau tidak berlaku.'**
  String get syncErrHttpsAuth;

  /// No description provided for @syncErrRepoNotFound.
  ///
  /// In id, this message translates to:
  /// **'Repositori tidak ditemukan atau tidak punya akses.'**
  String get syncErrRepoNotFound;

  /// No description provided for @syncErrMergeConflict.
  ///
  /// In id, this message translates to:
  /// **'Ada konflik saat menggabungkan perubahan. Selesaikan konflik di repo lokal.'**
  String get syncErrMergeConflict;

  /// No description provided for @syncErrNoNetwork.
  ///
  /// In id, this message translates to:
  /// **'Jaringan tidak tersedia.'**
  String get syncErrNoNetwork;

  /// No description provided for @syncErrGitFailed.
  ///
  /// In id, this message translates to:
  /// **'git gagal (kode {code})'**
  String syncErrGitFailed(int code);

  /// No description provided for @syncUnknownUser.
  ///
  /// In id, this message translates to:
  /// **'(tidak diketahui)'**
  String get syncUnknownUser;

  /// No description provided for @syncErrTreeTooLarge.
  ///
  /// In id, this message translates to:
  /// **'Daftar berkas repositori terlalu besar untuk dibaca sekaligus oleh API GitHub.'**
  String get syncErrTreeTooLarge;

  /// No description provided for @syncErrBlobTooLarge.
  ///
  /// In id, this message translates to:
  /// **'Berkasnya {size} MB, di atas batas 100 MB yang diterima API GitHub untuk satu berkas. Kirimkan lewat git biasa di komputer, atau simpan lampirannya di luar repositori.'**
  String syncErrBlobTooLarge(String size);

  /// No description provided for @syncErrConnectionLost.
  ///
  /// In id, this message translates to:
  /// **'Koneksi ke GitHub terputus dan tidak pulih setelah {attempts} percobaan. Unduhan bisa dilanjutkan dari tempatnya berhenti.'**
  String syncErrConnectionLost(int attempts);

  /// No description provided for @syncErrTokenRejected.
  ///
  /// In id, this message translates to:
  /// **'Token GitHub ditolak. Periksa token di profil repositori.'**
  String get syncErrTokenRejected;

  /// No description provided for @syncErrQuota.
  ///
  /// In id, this message translates to:
  /// **'Kuota permintaan GitHub habis. Coba lagi setelah kuota pulih (sekitar satu jam), atau pakai token dengan kuota lebih besar.'**
  String get syncErrQuota;

  /// No description provided for @syncErrSlowDown.
  ///
  /// In id, this message translates to:
  /// **'GitHub meminta pengiriman diperlambat karena terlalu banyak berkas beruntun. Tunggu beberapa menit lalu kirim lagi.'**
  String get syncErrSlowDown;

  /// No description provided for @syncErrForbidden.
  ///
  /// In id, this message translates to:
  /// **'Akses ditolak. Token perlu izin \"Contents: read and write\" untuk repositori ini.'**
  String get syncErrForbidden;

  /// No description provided for @syncErrNotFound.
  ///
  /// In id, this message translates to:
  /// **'Repositori atau berkas tidak ditemukan. Untuk repositori privat, token harus punya akses ke repositori tersebut.'**
  String get syncErrNotFound;

  /// No description provided for @syncErrBranchMoved.
  ///
  /// In id, this message translates to:
  /// **'Branch di GitHub sudah berubah. Tarik perubahan dulu, lalu kirim ulang.'**
  String get syncErrBranchMoved;

  /// No description provided for @syncErrRejectedNoReason.
  ///
  /// In id, this message translates to:
  /// **'GitHub menolak perubahan ini (422), tanpa menyebut alasannya.'**
  String get syncErrRejectedNoReason;

  /// No description provided for @syncErrRejected.
  ///
  /// In id, this message translates to:
  /// **'GitHub menolak perubahan ini: {reason}'**
  String syncErrRejected(String reason);

  /// No description provided for @syncErrStatus.
  ///
  /// In id, this message translates to:
  /// **'GitHub membalas dengan kode {code}.'**
  String syncErrStatus(int code);

  /// No description provided for @syncErrStatusReason.
  ///
  /// In id, this message translates to:
  /// **'GitHub membalas dengan kode {code}: {reason}'**
  String syncErrStatusReason(int code, String reason);

  /// No description provided for @syncGitHubApiLabel.
  ///
  /// In id, this message translates to:
  /// **'GitHub API'**
  String get syncGitHubApiLabel;

  /// No description provided for @syncErrRepoUrlUnknown.
  ///
  /// In id, this message translates to:
  /// **'URL repositori tidak dikenali.'**
  String get syncErrRepoUrlUnknown;

  /// No description provided for @syncErrTokenMissing.
  ///
  /// In id, this message translates to:
  /// **'Token GitHub belum diisi.'**
  String get syncErrTokenMissing;

  /// No description provided for @syncConnectedAs.
  ///
  /// In id, this message translates to:
  /// **'Terhubung sebagai {login} · {slug} pada {head}{quota}'**
  String syncConnectedAs(String login, String slug, String head, String quota);

  /// No description provided for @syncQuotaLeft.
  ///
  /// In id, this message translates to:
  /// **' · sisa kuota {count}'**
  String syncQuotaLeft(String count);

  /// No description provided for @syncErrNotGitHubUrl.
  ///
  /// In id, this message translates to:
  /// **'URL repositori tidak dikenali sebagai repositori GitHub.'**
  String get syncErrNotGitHubUrl;

  /// No description provided for @syncErrAndroidNeedsToken.
  ///
  /// In id, this message translates to:
  /// **'Di Android sinkronisasi memakai token GitHub. Isi token pada profil repositori.'**
  String get syncErrAndroidNeedsToken;

  /// No description provided for @syncReadingBranch.
  ///
  /// In id, this message translates to:
  /// **'Membaca branch {branch} di {slug}…'**
  String syncReadingBranch(String branch, String slug);

  /// No description provided for @syncMirrorReady.
  ///
  /// In id, this message translates to:
  /// **'Mirror siap: {files} berkas metadata, {attachments} lampiran menunggu diunduh saat dibuka'**
  String syncMirrorReady(int files, int attachments);

  /// No description provided for @syncPartialSaved.
  ///
  /// In id, this message translates to:
  /// **'{error} {count} berkas sudah tersimpan — tekan \"Lanjutkan\" untuk meneruskan.'**
  String syncPartialSaved(String error, int count);

  /// No description provided for @syncUpToDate.
  ///
  /// In id, this message translates to:
  /// **'Sudah paling baru'**
  String get syncUpToDate;

  /// No description provided for @syncBehindWaiting.
  ///
  /// In id, this message translates to:
  /// **'{count} commit baru menunggu di GitHub'**
  String syncBehindWaiting(int count);

  /// No description provided for @syncComparing.
  ///
  /// In id, this message translates to:
  /// **'Membandingkan dengan commit {head}…'**
  String syncComparing(String head);

  /// No description provided for @syncNoMetadataChanges.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada perubahan metadata'**
  String get syncNoMetadataChanges;

  /// No description provided for @syncPullUpdated.
  ///
  /// In id, this message translates to:
  /// **'Pull selesai: {count} berkas diperbarui'**
  String syncPullUpdated(int count);

  /// No description provided for @syncLfsUnsupportedAndroid.
  ///
  /// In id, this message translates to:
  /// **'Berkas Git LFS belum didukung pada sinkronisasi Android.'**
  String get syncLfsUnsupportedAndroid;

  /// No description provided for @syncAttachmentsSkippedOnly.
  ///
  /// In id, this message translates to:
  /// **'{count} lampiran dilewati; tidak ada perubahan lain untuk dikirim'**
  String syncAttachmentsSkippedOnly(int count);

  /// No description provided for @syncReadyToSend.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas siap dikirim'**
  String syncReadyToSend(int count);

  /// No description provided for @syncReadyToSendSkipped.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas siap dikirim; {skipped} lampiran dilewati (kirim lewat git di komputer)'**
  String syncReadyToSendSkipped(int count, int skipped);

  /// No description provided for @syncNothingToSendShort.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang perlu dikirim'**
  String get syncNothingToSendShort;

  /// No description provided for @syncErrRemoteNewer.
  ///
  /// In id, this message translates to:
  /// **'GitHub sudah punya commit lebih baru. Tarik perubahan dulu, lalu kirim ulang.'**
  String get syncErrRemoteNewer;

  /// No description provided for @syncErrQueueOnlyAttachments.
  ///
  /// In id, this message translates to:
  /// **'Antrean hanya berisi lampiran; tidak ada yang bisa dikirim lewat jalur ini.'**
  String get syncErrQueueOnlyAttachments;

  /// No description provided for @syncUploading.
  ///
  /// In id, this message translates to:
  /// **'Mengunggah berkas'**
  String get syncUploading;

  /// No description provided for @syncSentCount.
  ///
  /// In id, this message translates to:
  /// **'Terkirim: {count} berkas'**
  String syncSentCount(int count);

  /// No description provided for @syncErrAttachmentNotInRepo.
  ///
  /// In id, this message translates to:
  /// **'Lampiran tidak ada di repositori: {path}'**
  String syncErrAttachmentNotInRepo(String path);

  /// No description provided for @syncAllPdfsPresent.
  ///
  /// In id, this message translates to:
  /// **'Semua PDF sudah ada di perangkat'**
  String get syncAllPdfsPresent;

  /// No description provided for @syncAllPdfsPresentLfs.
  ///
  /// In id, this message translates to:
  /// **'Semua PDF sudah ada; {count} lampiran LFS diambil dari komputer'**
  String syncAllPdfsPresentLfs(int count);

  /// No description provided for @syncDownloadingPdfOf.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh PDF {current} dari {total}: {name}'**
  String syncDownloadingPdfOf(int current, int total, String name);

  /// No description provided for @syncPdfsDownloadedOffline.
  ///
  /// In id, this message translates to:
  /// **'{count} PDF diunduh untuk dibaca offline'**
  String syncPdfsDownloadedOffline(int count);

  /// No description provided for @syncMirrorAtCommit.
  ///
  /// In id, this message translates to:
  /// **'Mirror pada commit {sha}'**
  String syncMirrorAtCommit(String sha);

  /// No description provided for @syncErrNotMirrored.
  ///
  /// In id, this message translates to:
  /// **'Repositori belum di-mirror di perangkat ini.'**
  String get syncErrNotMirrored;

  /// No description provided for @syncRejectedMore.
  ///
  /// In id, this message translates to:
  /// **' dan {count} lainnya'**
  String syncRejectedMore(int count);

  /// No description provided for @syncNothingSent.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang terkirim'**
  String get syncNothingSent;

  /// No description provided for @syncSentFiles.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas terkirim'**
  String syncSentFiles(int count);

  /// No description provided for @syncRejectedSummary.
  ///
  /// In id, this message translates to:
  /// **'{head}; {count} berkas ditolak GitHub dan tetap menunggu: {names}{more}. {reason}'**
  String syncRejectedSummary(
    String head,
    int count,
    String names,
    String more,
    String reason,
  );

  /// No description provided for @syncResumingMetadata.
  ///
  /// In id, this message translates to:
  /// **'Melanjutkan unduhan metadata'**
  String get syncResumingMetadata;

  /// No description provided for @syncDownloadingMetadata.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh metadata'**
  String get syncDownloadingMetadata;

  /// No description provided for @syncErrCorruptDownload.
  ///
  /// In id, this message translates to:
  /// **'Berkas rusak saat diunduh: {name}. Jalankan lagi untuk mengunduh ulang bagian yang gagal.'**
  String syncErrCorruptDownload(String name);

  /// No description provided for @syncErrGitHubUrlUnknown.
  ///
  /// In id, this message translates to:
  /// **'URL repositori GitHub tidak dikenali.'**
  String get syncErrGitHubUrlUnknown;

  /// No description provided for @syncErrTokenMissingProfile.
  ///
  /// In id, this message translates to:
  /// **'Token GitHub belum diisi pada profil repositori.'**
  String get syncErrTokenMissingProfile;

  /// No description provided for @syncInstallGitWindows.
  ///
  /// In id, this message translates to:
  /// **'Git for Windows tidak ditemukan. Pasang dari git-scm.com, atau di PowerShell: winget install --id Git.Git -e — lalu tekan Coba lagi.'**
  String get syncInstallGitWindows;

  /// No description provided for @syncInstallGitMac.
  ///
  /// In id, this message translates to:
  /// **'git tidak ditemukan. Jalankan di Terminal: xcode-select --install.'**
  String get syncInstallGitMac;

  /// No description provided for @syncInstallGitLinux.
  ///
  /// In id, this message translates to:
  /// **'git tidak ditemukan. Pasang git dan git-lfs — CachyOS/Arch: sudo pacman -S git git-lfs; Debian/Ubuntu: sudo apt install git git-lfs.'**
  String get syncInstallGitLinux;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
