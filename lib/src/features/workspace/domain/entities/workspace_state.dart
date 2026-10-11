import 'package:meta/meta.dart';

import '../../../library/domain/entities/library_index.dart';
import '../../../settings/domain/entities/repo_profile.dart';
import '../../../sync/domain/entities/git_entities.dart';
import '../../../sync/domain/entities/sync_progress.dart';
import '../../../../core/l10n.dart';

/// What the app is currently doing with the remote.
enum SyncPhase { idle, cloning, fetching, pulling, committing, pushing }

/// Everything the shell needs to render: active repo, its libraries, the parsed
/// index and the git state of the clone.
@immutable
class WorkspaceState {
  const WorkspaceState({
    this.settings = const AppSettings(),
    this.profile,
    this.layout,
    this.library,
    this.index,
    this.gitStatus,
    this.phase = SyncPhase.idle,
    this.progress,
    this.progressLabel = '',
    this.progressLines = const <String>[],
    this.message,
    this.error,
    this.loadingLibrary = false,
  });

  final AppSettings settings;
  final RepoProfile? profile;
  final RepoLayout? layout;
  final LibraryRef? library;
  final LibraryIndex? index;
  final GitRepoStatus? gitStatus;
  final SyncPhase phase;

  /// Latest progress report of the running operation, when it is measurable.
  final SyncProgress? progress;

  /// The newest line of output, measurable or not.
  ///
  /// Kept apart from [progress] so the text keeps moving during a long step
  /// that reports no percentage — otherwise the screen looks frozen at
  /// whatever number came last.
  final String progressLabel;
  final List<String> progressLines;
  final String? message;
  final String? error;
  final bool loadingLibrary;

  bool get isBusy => phase != SyncPhase.idle;
  bool get hasProfile => profile != null;
  bool get isCloned => gitStatus?.exists ?? false;
  bool get hasLibrary => index != null;

  String get phaseLabel => switch (phase) {
    SyncPhase.idle => '',
    SyncPhase.cloning => l10n.syncPhaseCloning,
    SyncPhase.fetching => l10n.syncPhaseFetching,
    SyncPhase.pulling => l10n.syncPhasePulling,
    SyncPhase.committing => l10n.syncPhaseCommitting,
    SyncPhase.pushing => l10n.syncPhasePushing,
  };

  WorkspaceState copyWith({
    AppSettings? settings,
    RepoProfile? profile,
    RepoLayout? layout,
    LibraryRef? library,
    LibraryIndex? index,
    GitRepoStatus? gitStatus,
    SyncPhase? phase,
    SyncProgress? progress,
    String? progressLabel,
    List<String>? progressLines,
    String? message,
    String? error,
    bool? loadingLibrary,
    bool clearProfile = false,
    bool clearLayout = false,
    bool clearLibrary = false,
    bool clearIndex = false,
    bool clearMessage = false,
    bool clearError = false,
    bool clearProgress = false,
  }) => WorkspaceState(
    settings: settings ?? this.settings,
    profile: clearProfile ? null : (profile ?? this.profile),
    layout: clearLayout ? null : (layout ?? this.layout),
    library: clearLibrary ? null : (library ?? this.library),
    index: clearIndex ? null : (index ?? this.index),
    gitStatus: gitStatus ?? this.gitStatus,
    phase: phase ?? this.phase,
    progress: clearProgress ? null : (progress ?? this.progress),
    progressLabel: clearProgress ? '' : (progressLabel ?? this.progressLabel),
    progressLines: progressLines ?? this.progressLines,
    message: clearMessage ? null : (message ?? this.message),
    error: clearError ? null : (error ?? this.error),
    loadingLibrary: loadingLibrary ?? this.loadingLibrary,
  );
}
