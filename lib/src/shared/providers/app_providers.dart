import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/data/repositories/library_repository_impl.dart';
import '../../features/library/domain/repositories/library_repository.dart';
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/sync/data/datasources/git_cli_backend.dart';
import '../../features/sync/domain/repositories/git_backend.dart';

/// Data sources -------------------------------------------------------------

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>(
  (ref) => const SettingsLocalDataSource(),
);

/// Repositories --------------------------------------------------------------

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(settingsLocalDataSourceProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => const LibraryRepositoryImpl(),
);

/// The git implementation for the current platform.
///
/// Desktop shells out to the system `git`. An Android backend can be swapped
/// in here without touching the controllers.
final gitBackendProvider = Provider<GitBackend>((ref) => GitCliBackend());
