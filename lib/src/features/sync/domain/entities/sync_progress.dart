import 'package:meta/meta.dart';

/// A progress report from a running sync operation.
///
/// [fraction] is null while the step cannot be measured; the UI then falls
/// back to an indeterminate bar instead of showing a fake percentage.
@immutable
class SyncProgress {
  const SyncProgress({required this.message, this.fraction, this.current, this.total, this.detail});

  /// A line that carries no measurable progress (plain log output).
  const SyncProgress.message(this.message)
    : fraction = null,
      current = null,
      total = null,
      detail = null;

  final String message;

  /// 0.0 … 1.0, or null when unknown.
  final double? fraction;
  final int? current;
  final int? total;

  /// Extra information such as `120.5 MiB | 3.2 MiB/s`.
  final String? detail;

  bool get isMeasurable => fraction != null;

  int get percent => ((fraction ?? 0) * 100).round();

  /// One-line summary for the status bar.
  String get label {
    final buffer = StringBuffer(message);
    if (fraction != null) buffer.write(' $percent%');
    if (current != null && total != null) buffer.write(' ($current/$total)');
    if (detail != null && detail!.isNotEmpty) buffer.write(' · $detail');
    return buffer.toString();
  }

  @override
  String toString() => label;
}

/// Turns `git --progress` output into [SyncProgress].
///
/// Git reports as `Receiving objects:  45% (1234/2700), 120.50 MiB | 3.20 MiB/s`,
/// separated by carriage returns, which is why the app can show a real
/// percentage for a clone instead of a spinner.
class GitProgressParser {
  const GitProgressParser._();

  static final RegExp _pattern = RegExp(
    r'^(?:remote:\s*)?([A-Za-z][A-Za-z ]+?):\s+(\d+)%\s*\((\d+)/(\d+)\)(?:,\s*(.*?))?\.?\s*$',
  );

  /// Human readable names for the phases git reports.
  static const Map<String, String> _phases = <String, String>{
    'counting objects': 'Menghitung objek',
    'compressing objects': 'Memampatkan objek',
    'receiving objects': 'Mengunduh objek',
    'resolving deltas': 'Menyusun delta',
    'updating files': 'Menulis berkas',
    'checking out files': 'Menulis berkas',
    'filtering content': 'Mengunduh berkas besar',
    'downloading lfs objects': 'Mengunduh berkas LFS',
    'writing objects': 'Mengirim objek',
    'enumerating objects': 'Mendata objek',
  };

  /// Parses one output line; returns a plain message when it has no percentage.
  static SyncProgress parse(String line) {
    final trimmed = line.trim();
    final match = _pattern.firstMatch(trimmed);
    if (match == null) return SyncProgress.message(trimmed);

    final phase = match.group(1)!.toLowerCase().trim();
    final percent = int.tryParse(match.group(2)!) ?? 0;
    final current = int.tryParse(match.group(3)!);
    final total = int.tryParse(match.group(4)!);
    var detail = match.group(5)?.trim();
    if (detail != null && (detail.isEmpty || detail == 'done')) detail = null;

    return SyncProgress(
      message: _phases[phase] ?? match.group(1)!.trim(),
      fraction: (percent / 100).clamp(0.0, 1.0),
      current: current,
      total: total,
      detail: detail,
    );
  }
}
