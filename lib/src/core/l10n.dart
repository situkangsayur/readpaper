import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// `context.l10n.namaKunci` — teks antarmuka dalam bahasa yang dipilih di
/// Pengaturan (Indonesia atau English).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

AppLocalizations _current = lookupAppLocalizations(const Locale('id'));

/// Teks dalam bahasa yang sedang aktif, untuk kode yang tidak punya
/// `BuildContext`: controller, backend git, pesan galat. Diperbarui oleh
/// aplikasi setiap kali bahasanya berganti; sebelum itu (dan di uji unit)
/// berbahasa Indonesia.
AppLocalizations get l10n => _current;

/// Dipanggil aplikasi saat bahasa antarmuka ditentukan atau berganti.
void setCurrentL10n(AppLocalizations value) => _current = value;

/// Locale untuk pilihan bahasa di pengaturan; null berarti ikut sistem.
Locale? localeFor(String language) => switch (language) {
  'en' => const Locale('en'),
  'system' => null,
  _ => const Locale('id'),
};
