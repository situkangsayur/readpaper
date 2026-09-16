import 'dart:convert';
import 'dart:io';

import '../../../../core/utils/app_paths.dart';
import '../../domain/entities/repo_profile.dart';

/// Reads and writes the settings file and the (separate) credential store.
///
/// HTTPS tokens never go into `config.json`; they live in
/// `credentials.json` with `0600` permissions so the settings file stays safe
/// to copy around or inspect.
class SettingsLocalDataSource {
  const SettingsLocalDataSource();

  Future<AppSettings> load() async {
    final file = File(AppPaths.instance.configFile);
    if (!file.existsSync()) return const AppSettings();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return const AppSettings();
      return AppSettings.fromJson(json.cast<String, dynamic>());
    } on FormatException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = File(AppPaths.instance.configFile);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(settings.toJson())}\n', flush: true);
  }

  Future<Map<String, String>> loadCredentials() async {
    final file = File(AppPaths.instance.credentialsFile);
    if (!file.existsSync()) return <String, String>{};
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return <String, String>{};
      return json.map((key, value) => MapEntry(key.toString(), value.toString()));
    } on FormatException {
      return <String, String>{};
    }
  }

  Future<void> saveToken({required String profileId, required String? token}) async {
    final credentials = await loadCredentials();
    if (token == null || token.isEmpty) {
      credentials.remove(profileId);
    } else {
      credentials[profileId] = token;
    }
    final file = File(AppPaths.instance.credentialsFile);
    await file.parent.create(recursive: true);
    await file.writeAsString('${jsonEncode(credentials)}\n', flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', file.path]);
    }
  }

  Future<String?> tokenFor(String profileId) async => (await loadCredentials())[profileId];
}
