import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/tree_signature.dart';
import '../../../notes/data/notes_store.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import 'workspace_controller.dart';

/// Membaca ulang library dan catatan begitu isinya berubah di disk dari luar
/// aplikasi — `git pull` di terminal, Zotero yang mengekspor, berkas yang
/// disalin pengelola berkas, sinkronisasi lain.
///
/// Sebelumnya library hanya dibaca saat profil dibuka dan sesudah tindakan
/// ReadPaper sendiri, sehingga paper dan folder baru dari luar baru tampil
/// setelah aplikasinya ditutup dan dibuka lagi.
///
/// Diperiksa dengan [treeSignatureSync] setiap beberapa detik selama jendela
/// terlihat, dan seketika saat aplikasi kembali ke depan.
class DiskWatch {
  DiskWatch(this._ref) {
    _timer = Timer.periodic(interval, (_) => check());
    _lifecycle = AppLifecycleListener(onResume: check);
  }

  final Ref _ref;
  late final Timer _timer;
  late final AppLifecycleListener _lifecycle;

  /// Lebih jarang di ponsel dan tablet: baterainya lebih berharga daripada
  /// beberapa detik, dan kembali ke aplikasi selalu memeriksa seketika.
  static Duration get interval => Platform.isAndroid || Platform.isIOS
      ? const Duration(seconds: 15)
      : const Duration(seconds: 3);

  bool _checking = false;
  int _ownWrites = 0;
  String? _notesDir;
  String? _notes;

  Future<void> check() async {
    if (_checking) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final ws = _ref.read(workspaceControllerProvider);
    final libraryDir = ws.library?.directoryPath;
    final repo = ws.profile?.localPath;
    // Selama tarik, kirim, atau baca library berjalan, berkasnya memang sedang
    // berubah, dan tindakan itu sendiri membaca ulang sesudahnya.
    if (libraryDir == null || repo == null || ws.isBusy || ws.loadingLibrary) return;

    _checking = true;
    try {
      final notesDir = NotesStore.directoryFor(repo);
      final signatures = await Isolate.run(
        () => (
          library: treeSignatureSync(librarySignaturePaths(libraryDir)),
          notes: treeSignatureSync(<String>[
            p.join(notesDir, 'koleksi.json'),
            p.join(notesDir, 'item'),
          ]),
        ),
      );
      final controller = _ref.read(workspaceControllerProvider.notifier);
      final now = _ref.read(workspaceControllerProvider);
      if (now.isBusy || now.loadingLibrary || now.library?.directoryPath != libraryDir) return;

      // ReadPaper sendiri baru menulis anotasi tanpa membaca ulang library:
      // keadaan sekarang jadi patokan baru.
      if (controller.ownWrites != _ownWrites) {
        _ownWrites = controller.ownWrites;
        controller.librarySignature = signatures.library;
      } else if (signatures.library != controller.librarySignature) {
        await controller.reloadLibrary();
        await controller.refreshGitStatus();
      }

      // Catatan dibaca oleh controller-nya sendiri; patokannya pemeriksaan
      // pertama di folder ini.
      if (_notesDir != notesDir) {
        _notesDir = notesDir;
        _notes = signatures.notes;
      } else if (signatures.notes != _notes) {
        _notes = signatures.notes;
        await _ref.read(notesControllerProvider.notifier).reload();
      }
    } catch (_) {
      // Pemeriksaan latar belakang tidak pernah boleh memunculkan galat.
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _timer.cancel();
    _lifecycle.dispose();
  }
}

/// Hidup selama aplikasi berjalan; didengarkan dari `ReadPaperApp`.
final diskWatchProvider = Provider<DiskWatch>((ref) {
  final watch = DiskWatch(ref);
  ref.onDispose(watch.dispose);
  return watch;
});
