import '../entities/repo_profile.dart';

/// Persistence of repository profiles and app preferences.
abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<AppSettings> saveProfile(RepoProfile profile, {String? httpsToken});

  Future<AppSettings> deleteProfile(String profileId);

  Future<AppSettings> setActiveProfile(String profileId);

  Future<AppSettings> updatePreferences({String? themeMode, String? lastAnnotationColor});

  Future<String?> tokenFor(String profileId);
}
