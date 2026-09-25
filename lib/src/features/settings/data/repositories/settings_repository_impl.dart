import '../../domain/entities/repo_profile.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._local);

  final SettingsLocalDataSource _local;

  @override
  Future<AppSettings> load() => _local.load();

  @override
  Future<AppSettings> saveProfile(RepoProfile profile, {String? httpsToken}) async {
    final settings = await _local.load();
    final profiles = <RepoProfile>[...settings.profiles];
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    final updated = settings.copyWith(
      profiles: profiles,
      activeProfileId: settings.activeProfileId ?? profile.id,
    );
    await _local.save(updated);
    if (httpsToken != null) {
      await _local.saveToken(profileId: profile.id, token: httpsToken);
    }
    return updated;
  }

  @override
  Future<AppSettings> deleteProfile(String profileId) async {
    final settings = await _local.load();
    final profiles = settings.profiles.where((p) => p.id != profileId).toList();
    final active = settings.activeProfileId == profileId
        ? (profiles.isEmpty ? null : profiles.first.id)
        : settings.activeProfileId;
    final updated = AppSettings(
      profiles: profiles,
      activeProfileId: active,
      themeMode: settings.themeMode,
      lastAnnotationColor: settings.lastAnnotationColor,
    );
    await _local.save(updated);
    await _local.saveToken(profileId: profileId, token: null);
    return updated;
  }

  @override
  Future<AppSettings> setActiveProfile(String profileId) async {
    final settings = await _local.load();
    final updated = settings.copyWith(activeProfileId: profileId);
    await _local.save(updated);
    return updated;
  }

  @override
  Future<AppSettings> updatePreferences({String? themeMode, String? lastAnnotationColor}) async {
    final settings = await _local.load();
    final updated = settings.copyWith(
      themeMode: themeMode,
      lastAnnotationColor: lastAnnotationColor,
    );
    await _local.save(updated);
    return updated;
  }

  @override
  Future<AppSettings> rememberRecent(RecentPaper entry) async {
    // Reloaded rather than taken from memory: the reader writes here while
    // the sync panel may have written a profile a moment earlier.
    final settings = await _local.load();
    final updated = settings.withRecent(entry);
    await _local.save(updated);
    return updated;
  }

  @override
  Future<AppSettings> forgetRecent({RecentPaper? entry}) async {
    final settings = await _local.load();
    final updated = entry == null
        ? settings.copyWith(recents: const <RecentPaper>[])
        : settings.copyWith(recents: settings.recents.where((r) => !r.sameFileAs(entry)).toList());
    await _local.save(updated);
    return updated;
  }

  @override
  Future<String?> tokenFor(String profileId) => _local.tokenFor(profileId);
}
