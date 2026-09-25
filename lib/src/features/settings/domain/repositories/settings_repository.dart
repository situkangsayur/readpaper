import '../entities/repo_profile.dart';

/// Persistence of repository profiles and app preferences.
abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<AppSettings> saveProfile(RepoProfile profile, {String? httpsToken});

  Future<AppSettings> deleteProfile(String profileId);

  Future<AppSettings> setActiveProfile(String profileId);

  Future<AppSettings> updatePreferences({String? themeMode, String? lastAnnotationColor});

  /// Records a paper as opened, or moves it back to the front of the history.
  Future<AppSettings> rememberRecent(RecentPaper entry);

  /// Forgets one paper, or the whole history when [entry] is null.
  Future<AppSettings> forgetRecent({RecentPaper? entry});

  Future<String?> tokenFor(String profileId);
}
