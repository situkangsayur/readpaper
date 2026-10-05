import 'dart:convert';
import 'dart:math';

import '../../settings/data/datasources/settings_local_datasource.dart';

/// Token yang wajib dibawa add-in Word dan plugin OnlyOffice.
///
/// Disimpan di `credentials.json`, bersebelahan dengan token HTTPS GitHub,
/// karena sifatnya sama: rahasia yang tidak boleh ikut tersalin bersama
/// `config.json`. Kuncinya sengaja tidak mungkin bertabrakan dengan id profil,
/// yang selalu berupa UUID.
class CitationTokenStore {
  const CitationTokenStore(this._local);

  static const String credentialKey = 'readpaper:citation-server-token';

  final SettingsLocalDataSource _local;

  /// Token yang tersimpan, atau token baru yang langsung disimpan.
  ///
  /// Dibuat sekali per pemasangan: kalau berubah setiap kali aplikasi dibuka,
  /// orang harus menyalinnya ulang ke Word setiap pagi.
  Future<String> loadOrCreate() async {
    final existing = await _local.tokenFor(credentialKey);
    if (existing != null && existing.length >= 32) return existing;
    return regenerate();
  }

  /// Membuat dan menyimpan token baru; token lama langsung tidak berlaku.
  Future<String> regenerate() async {
    final token = generate();
    await _local.saveToken(profileId: credentialKey, token: token);
    return token;
  }

  /// 32 bait acak dari sumber yang aman, ditulis base64url tanpa `=`:
  /// 43 huruf yang aman ditempel di kolom isian mana pun.
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
