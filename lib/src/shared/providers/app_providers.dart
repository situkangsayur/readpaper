import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/data/repositories/library_repository_impl.dart';
import '../../features/library/domain/repositories/library_repository.dart';
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/sync/data/datasources/git_cli_backend.dart';
import '../../features/sync/data/datasources/github_api_backend.dart';
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

/// The sync implementation for the current platform.
///
/// Desktop shells out to the system `git`. Android and iOS have no `git`
/// binary, so they mirror the repository through the GitHub REST API instead.
final gitBackendProvider = Provider<GitBackend>(
  (ref) => Platform.isAndroid || Platform.isIOS ? GitHubApiBackend() : GitCliBackend(),
);
