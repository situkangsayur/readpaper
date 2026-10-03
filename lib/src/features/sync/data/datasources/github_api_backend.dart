import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../domain/entities/git_entities.dart';
import '../../domain/entities/sync_progress.dart';
import '../../domain/repositories/git_backend.dart';
import 'github_api_client.dart';
import 'github_sync_state.dart';

/// Sync backend for platforms without a `git` binary — notably Android.
///
/// Instead of a real clone it keeps a **mirror**: every metadata file of the
/// Zotero export is downloaded (about 19 MB for a 1.700-item library), while
/// attachments — hundreds of megabytes of PDFs — are fetched only when a paper
/// is opened. Writing works through the git data API: post blobs, post a tree
/// on top of the last known commit, post a commit, then move the branch.
class GitHubApiBackend implements GitBackend {
  GitHubApiBackend({this.clientFactory = _defaultClientFactory, this.concurrency = 8});

  /// Injection point for tests.
  final GitHubApiClient Function(GitHubRepoRef ref, String? token) clientFactory;

  /// How many blobs are downloaded at the same time.
  final int concurrency;

  static GitHubApiClient _defaultClientFactory(GitHubRepoRef ref, String? token) =>
      GitHubApiClient(ref: ref, token: token);

  /// Directories that are never mirrored; their files come on demand.
  static const List<String> attachmentDirs = <String>['attachments', 'attachments-lfs'];

  @override
  String get label => 'GitHub API';

  @override
  Set<GitTransport> get supportedTransports => <GitTransport>{GitTransport.https};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isLfsAvailable() async => false;

  @override
  Future<GitResult> checkConnection({required GitAuth auth, String? repoPath}) async {
    final remote = auth.remoteUrl == null ? null : GitHubRepoRef.parse(auth.remoteUrl!);
    if (remote == null) {
      return const GitResult(ok: false, exitCode: 1, message: 'URL repositori tidak dikenali.');
    }
    if (!auth.hasHttpsCredentials) {
      return const GitResult(ok: false, exitCode: 1, message: 'Token GitHub belum diisi.');
    }
    final client = clientFactory(remote, auth.httpsToken);
    try {
      final login = await client.whoAmI();
      final head = await client.headSha(GitHubSyncState.load(repoPath ?? '')?.branch ?? 'main');
      return GitResult(
        ok: true,
        exitCode: 0,
        message:
            'Terhubung sebagai $login · ${remote.slug} pada ${head.substring(0, 7)}'
            '${client.rateLimitRemaining != null ? ' · sisa kuota ${client.rateLimitRemaining}' : ''}',
      );
    } on Failure catch (e) {
      return GitResult(ok: false, exitCode: 1, message: e.message, stderr: e.details ?? '');
    } on SocketException {
      return const GitResult(ok: false, exitCode: 1, message: 'Jaringan tidak tersedia.');
    } finally {
      client.close();
    }
  }

  // ------------------------------------------------------------------- clone

  @override
  Future<GitResult> clone({
    required String remoteUrl,
    required String targetPath,
    required GitAuth auth,
    String? branch,
    // The mirror never holds attachments, so this preference does not apply.
    bool lazyAttachments = true,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final ref = GitHubRepoRef.parse(remoteUrl);
    if (ref == null) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'URL repositori tidak dikenali sebagai repositori GitHub.',
      );
    }
    if (!auth.hasHttpsCredentials) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'Di Android sinkronisasi memakai token GitHub. Isi token pada profil repositori.',
      );
    }

    final target = Directory(targetPath);
    final resuming = GitHubSyncState.existsIn(targetPath);
    if (!resuming && target.existsSync() && target.listSync().isNotEmpty) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'Direktori tujuan sudah berisi berkas. Hapus atau pilih lokasi lain.',
      );
    }

    final client = clientFactory(ref, auth.httpsToken);
    try {
      await target.create(recursive: true);
      final targetBranch = (branch ?? '').isNotEmpty ? branch! : await client.defaultBranch();
      onProgress?.call(SyncProgress.message('Membaca branch $targetBranch di ${ref.slug}…'));

      final head = await client.headSha(targetBranch);
      final entries = await client.tree(head);
      // Resuming keeps what is already on disk: _mirror skips every file whose
      // blob id already matches, so an interrupted download carries on.
      final state =
          (resuming ? GitHubSyncState.load(targetPath) : null) ??
          GitHubSyncState(branch: targetBranch, commitSha: head);
      state
        ..branch = targetBranch
        ..commitSha = head;

      await _mirror(
        client: client,
        entries: entries,
        repoPath: targetPath,
        state: state,
        onProgress: onProgress,
      );
      await state.save(targetPath);

      return GitResult(
        ok: true,
        exitCode: 0,
        message:
            'Mirror siap: ${state.files.length} berkas metadata, '
            '${state.attachments.length} lampiran menunggu diunduh saat dibuka',
      );
    } on Failure catch (e) {
      // What is already downloaded stays put, together with its bookkeeping:
      // losing a connection halfway should cost the rest of the download, not
      // the part that already succeeded.
      final done = GitHubSyncState.load(targetPath)?.files.length ?? 0;
      return GitResult(
        ok: false,
        exitCode: 1,
        message: done > 0
            ? '${e.message} $done berkas sudah tersimpan — tekan "Lanjutkan" untuk meneruskan.'
            : e.message,
        stderr: e.details ?? '',
      );
    } finally {
      client.close();
    }
  }

  // ------------------------------------------------------------------ status

  @override
  Future<GitRepoStatus> status(String repoPath) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null) return GitRepoStatus.missing(repoPath);

    return GitRepoStatus(
      repoPath: repoPath,
      exists: true,
      branch: state.branch,
      remoteUrl: '',
      // "ahead" here means staged changes waiting to become a commit on GitHub.
      ahead: state.pending.length,
      behind: state.behind,
      changes: _localChanges(repoPath, state),
      lastCommitSubject: state.lastCommitSubject,
      lastCommitDate: state.lastCommitDate,
      hasUpstream: true,
      lfsAvailable: false,
      lazyAttachments: true,
    );
  }

  /// Files that differ from what was last synced.
  ///
  /// The cheap check is size + mtime; only when those moved is the git blob id
  /// recomputed, which keeps a status check fast even on a phone.
  List<GitChange> _localChanges(String repoPath, GitHubSyncState state) {
    final changes = <GitChange>[];
    final seen = <String>{};

    for (final entry in state.files.entries) {
      final file = File(p.join(repoPath, entry.key));
      seen.add(entry.key);
      if (!file.existsSync()) {
        changes.add(GitChange(status: ' D', path: entry.key));
        continue;
      }
      final stat = file.statSync();
      if (stat.size == entry.value.size &&
          stat.modified.millisecondsSinceEpoch == entry.value.mtimeMs &&
          !isRacilyClean(
            knownMtimeMs: entry.value.mtimeMs,
            stateFileMtimeMs: state.savedFileMtimeMs,
          )) {
        continue;
      }
      if (gitBlobShaOfFile(file) != entry.value.sha) {
        changes.add(GitChange(status: ' M', path: entry.key));
      }
    }

    for (final file in _mirroredFiles(repoPath)) {
      final relative = _repoRelative(file.path, repoPath);
      if (seen.contains(relative)) continue;
      changes.add(GitChange(status: '??', path: relative));
    }

    changes.sort((a, b) => a.path.compareTo(b.path));
    return changes;
  }

  /// Berkas yang "bersih karena balapan" — istilah git untuk keadaan ini.
  ///
  /// Pemeriksaan murah membandingkan ukuran dan waktu ubah, dan itu bisa
  /// salah: berkas yang disunting **di dalam detak jam berkas yang sama**
  /// dengan saat catatan sinkronisasi ditulis akan punya waktu ubah yang
  /// persis sama. Kalau ukurannya kebetulan juga sama — `{"a":1}` menjadi
  /// `{"a":2}` — perubahannya tidak pernah terlihat, dan yang menulisnya
  /// mengira sudah tersimpan.
  ///
  /// Di Linux waktu ubahnya sehalus nanodetik sehingga tabrakan itu hampir
  /// tidak pernah terjadi; di Windows jauh lebih kasar, dan runner-nya
  /// menangkapnya sebagai dua tes merah: perubahan yang tidak terdeteksi, dan
  /// push yang tidak menolak padahal GitHub sudah maju.
  ///
  /// Jadi berkas yang waktu ubahnya tidak lebih tua dari berkas catatan itu
  /// sendiri selalu dibaca isinya, tidak dipercaya begitu saja. Keduanya
  /// berasal dari jam berkas yang sama, jadi perbandingannya setara.
  @visibleForTesting
  static bool isRacilyClean({required int knownMtimeMs, required int stateFileMtimeMs}) =>
      stateFileMtimeMs != 0 && knownMtimeMs >= stateFileMtimeMs;

  /// Jalur relatif terhadap akar repositori, dalam bentuk yang dipakai git.
  ///
  /// Selalu garis miring maju, apa pun sistemnya. `p.relative` memakai pemisah
  /// platform, dan di Windows itu `\` — sementara GitHub, berkas catatan
  /// sinkronisasi, dan format Zotero semuanya memakai `/`. Tanpa penyeragaman
  /// ini **setiap** berkas tampak berubah, karena jalur yang dibandingkan
  /// tidak pernah cocok. Ketahuan saat tesnya dijalankan di runner Windows:
  /// status melaporkan tiga perubahan pada cermin yang sebenarnya bersih.
  String _repoRelative(String absolute, String repoPath) =>
      p.relative(absolute, from: repoPath).replaceAll(r'\', '/');

  /// Every metadata file in the mirror (attachments and bookkeeping excluded).
  Iterable<File> _mirroredFiles(String repoPath) sync* {
    final root = Directory(repoPath);
    if (!root.existsSync()) return;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = _repoRelative(entity.path, repoPath);
      if (relative.startsWith(GitHubSyncState.dirName)) continue;
      if (isAttachmentPath(relative)) continue;
      yield entity;
    }
  }

  // ------------------------------------------------------------- fetch / pull

  @override
  Future<GitResult> fetch({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null) return _notMirrored;

    return _withClient(repoPath, auth, (client, ref) async {
      final head = await client.headSha(state.branch);
      if (head == state.commitSha) {
        state.behind = 0;
        await state.save(repoPath);
        return const GitResult(ok: true, exitCode: 0, message: 'Sudah paling baru');
      }
      state.behind = await client.commitsAhead(branch: state.branch, sinceSha: state.commitSha);
      await state.save(repoPath);
      return GitResult(
        ok: true,
        exitCode: 0,
        message: '${state.behind} commit baru menunggu di GitHub',
      );
    });
  }

  @override
  Future<GitResult> pull({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null) return _notMirrored;

    return _withClient(repoPath, auth, (client, ref) async {
      final head = await client.headSha(state.branch);
      if (head == state.commitSha) {
        state.behind = 0;
        await state.save(repoPath);
        return const GitResult(ok: true, exitCode: 0, message: 'Sudah paling baru');
      }

      onProgress?.call(SyncProgress.message('Membandingkan dengan commit $head…'));
      final entries = await client.tree(head);
      final downloaded = await _mirror(
        client: client,
        entries: entries,
        repoPath: repoPath,
        state: state,
        onProgress: onProgress,
      );

      state.commitSha = head;
      state.behind = 0;
      await state.save(repoPath);
      return GitResult(
        ok: true,
        exitCode: 0,
        message: downloaded == 0
            ? 'Tidak ada perubahan metadata'
            : 'Pull selesai: $downloaded berkas diperbarui',
      );
    });
  }

  @override
  Future<GitResult> lfsPull({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async => const GitResult(
    ok: false,
    exitCode: 1,
    message: 'Berkas Git LFS belum didukung pada sinkronisasi Android.',
  );

  // ------------------------------------------------------------ commit / push

  @override
  Future<GitResult> commitAll({
    required String repoPath,
    required String message,
    String? authorName,
    String? authorEmail,
    List<String> paths = const <String>[],
  }) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null) return _notMirrored;

    // Lampiran tidak pernah ikut dikirim lewat jalur ini, dan ini bukan
    // kerapian melainkan keselamatan data. Berkas di `attachments-lfs/`
    // disimpan di repositori sebagai **penunjuk** Git LFS sepanjang seratus
    // bita, bukan sebagai isinya; mengirim PDF-nya sendiri ke sana akan
    // menimpa penunjuk itu dan merusak LFS repositorinya. Dan berkas di
    // `attachments/` berukuran puluhan megabita, yang ditolak API GitHub.
    //
    // Yang terjadi sebelum ini: satu berkas lampiran yang entah bagaimana
    // pernah masuk antrean akan terbawa terus — `commitAll` menyalin ulang
    // antrean lama setiap kali — dan setiap pengiriman berhenti di berkas itu
    // dengan galat yang menyuruh menarik perubahan, yang tidak pernah bisa
    // menolong. Antreannya tidak punya jalan keluar.
    final dropped = <String>{};
    final pendingPaths = <String>{
      for (final change in _localChanges(repoPath, state)) change.path,
      for (final change in state.pending.expand((c) => c.paths)) change,
    }..removeWhere((path) {
        if (!isAttachmentPath(path)) return false;
        dropped.add(path);
        return true;
      });
    if (paths.isNotEmpty) {
      pendingPaths.removeWhere((path) => !paths.contains(path));
    }
    if (pendingPaths.isEmpty) {
      // Antrean yang isinya hanya lampiran tetap harus dikosongkan, kalau
      // tidak ia akan dicoba lagi selamanya.
      if (dropped.isNotEmpty && state.pending.isNotEmpty) {
        state.pending.clear();
        await state.save(repoPath);
      }
      return GitResult(
        ok: true,
        exitCode: 0,
        message: dropped.isEmpty
            ? 'Tidak ada perubahan untuk di-commit'
            : '${dropped.length} lampiran dilewati; tidak ada perubahan lain untuk dikirim',
      );
    }

    // Changes are staged locally; [push] turns them into a commit on GitHub.
    state.pending
      ..clear()
      ..add(
        PendingChange(message: message, paths: pendingPaths.toList()..sort(), at: DateTime.now()),
      );
    await state.save(repoPath);
    return GitResult(
      ok: true,
      exitCode: 0,
      message: dropped.isEmpty
          ? '${pendingPaths.length} berkas siap dikirim'
          : '${pendingPaths.length} berkas siap dikirim; '
                '${dropped.length} lampiran dilewati (kirim lewat git di komputer)',
    );
  }

  @override
  Future<GitResult> push({
    required String repoPath,
    required GitAuth auth,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null) return _notMirrored;
    if (state.pending.isEmpty) {
      return const GitResult(ok: true, exitCode: 0, message: 'Tidak ada yang perlu dikirim');
    }

    return _withClient(repoPath, auth, (client, ref) async {
      final head = await client.headSha(state.branch);
      if (head != state.commitSha) {
        return const GitResult(
          ok: false,
          exitCode: 1,
          message: 'GitHub sudah punya commit lebih baru. Tarik perubahan dulu, lalu kirim ulang.',
        );
      }

      final pending = state.pending.first;
      final treeEntries = <Map<String, dynamic>>[];

      // Jaring pengaman untuk antrean yang sudah terlanjur tersimpan sebelum
      // penyaringan di commitAll ada: tanpa ini, memasang versi baru saja
      // tidak akan menyembuhkan perangkat yang antreannya sudah teracuni.
      final sendable = pending.paths.where((path) => !isAttachmentPath(path)).toList();
      if (sendable.isEmpty) {
        state.pending.clear();
        await state.save(repoPath);
        return const GitResult(
          ok: true,
          exitCode: 0,
          message: 'Antrean hanya berisi lampiran; tidak ada yang bisa dikirim lewat jalur ini.',
        );
      }

      // Berkas yang ditolak GitHub — terlalu besar, atau ditolak dengan 422 —
      // disisihkan, bukan menggagalkan seluruh pengiriman. Dulu satu buku PDF
      // di urutan ke-20 dari 32 membuat 31 berkas lain ikut tertahan, dan
      // karena antreannya terus bertambah, setiap percobaan berikutnya gagal
      // di tempat yang sama dengan antrean yang makin panjang.
      final rejectedNow = <String, RejectedFile>{};
      final sent = <String>[];
      var index = 0;
      for (final path in sendable) {
        index++;
        final file = File(p.join(repoPath, path));
        if (!file.existsSync()) {
          // Hanya jalur yang memang ada di commit induknya yang bisa dihapus.
          // Berkas yang dibuat lalu dihapus lagi sebelum sempat terkirim
          // tidak pernah ada di GitHub, dan meminta GitHub menghapusnya
          // dijawab dengan penolakan untuk seluruh pohonnya.
          if (state.files.containsKey(path)) {
            treeEntries.add(<String, dynamic>{
              'path': path,
              'mode': '100644',
              'type': 'blob',
              'sha': null,
            });
          }
          sent.add(path);
          continue;
        }
        final localSha = gitBlobShaOfFile(file);
        if (state.files[path]?.sha == localSha) {
          // Isinya sama dengan yang sudah ada di GitHub: tidak ada yang perlu
          // diunggah. Antrean lama sering berisi berkas seperti ini.
          sent.add(path);
          continue;
        }
        final known = state.rejected[path];
        if (known != null && known.sha == localSha) {
          rejectedNow[path] = known;
          continue;
        }
        onProgress?.call(
          SyncProgress(
            message: 'Mengunggah berkas',
            fraction: index / sendable.length,
            current: index,
            total: sendable.length,
            detail: p.basename(path),
          ),
        );
        final String blobSha;
        try {
          blobSha = await client.createBlob(await file.readAsBytes());
        } on GitFailure catch (e) {
          if (!_isRejection(e)) rethrow;
          rejectedNow[path] = RejectedFile(sha: localSha, reason: e.message);
          continue;
        }
        sent.add(path);
        treeEntries.add(<String, dynamic>{
          'path': path,
          'mode': '100644',
          'type': 'blob',
          'sha': blobSha,
        });
      }

      if (treeEntries.isEmpty) {
        // Tidak ada yang berubah di GitHub: entah semuanya ditolak, entah
        // semuanya ternyata sudah sama. Antreannya tetap dirapikan.
        state.pending
          ..clear()
          ..addAll(<PendingChange>[
            if (rejectedNow.isNotEmpty)
              PendingChange(message: pending.message, paths: rejectedNow.keys.toList(), at: pending.at),
          ]);
        state.rejected
          ..clear()
          ..addAll(rejectedNow);
        await state.save(repoPath);
        if (rejectedNow.isEmpty) {
          return const GitResult(ok: true, exitCode: 0, message: 'Tidak ada yang perlu dikirim');
        }
        return GitResult(
          ok: false,
          exitCode: 1,
          message: _rejectionMessage(rejectedNow, sentCount: 0),
          stderr: _rejectionDetails(rejectedNow),
        );
      }

      final baseTree = await client.treeShaOfCommit(state.commitSha);
      final newTree = await client.createTree(baseTree, treeEntries);
      final commitSha = await client.createCommit(
        message: pending.message,
        treeSha: newTree,
        parentSha: state.commitSha,
        authorName: auth.httpsUsername,
      );
      await client.updateRef(branch: state.branch, commitSha: commitSha);

      // The mirror now matches the new commit: refresh the bookkeeping so the
      // files stop showing up as local changes.
      for (final path in sent) {
        final file = File(p.join(repoPath, path));
        if (!file.existsSync()) {
          state.files.remove(path);
          continue;
        }
        final stat = file.statSync();
        state.files[path] = MirroredFile(
          sha: gitBlobShaOfFile(file),
          size: stat.size,
          mtimeMs: stat.modified.millisecondsSinceEpoch,
        );
      }
      state
        ..commitSha = commitSha
        ..lastCommitSubject = pending.message.split('\n').first
        ..lastCommitDate = DateTime.now()
        ..pending.clear();
      // Yang ditolak tetap menunggu di antrean — tidak dibuang diam-diam —
      // tetapi tidak lagi menghalangi yang lain.
      if (rejectedNow.isNotEmpty) {
        state.pending.add(
          PendingChange(message: pending.message, paths: rejectedNow.keys.toList(), at: pending.at),
        );
      }
      state.rejected
        ..clear()
        ..addAll(rejectedNow);
      await state.save(repoPath);

      if (rejectedNow.isNotEmpty) {
        return GitResult(
          ok: false,
          exitCode: 1,
          message: _rejectionMessage(rejectedNow, sentCount: sent.length),
          stderr: _rejectionDetails(rejectedNow),
        );
      }
      return GitResult(ok: true, exitCode: 0, message: 'Terkirim: ${sent.length} berkas');
    });
  }

  // ------------------------------------------------------------- attachments

  @override
  Future<GitResult> fetchAttachment({
    required String repoPath,
    required GitAuth auth,
    required String absoluteFilePath,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null) return _notMirrored;

    final relative = _repoRelative(absoluteFilePath, repoPath);
    final known = state.attachments[relative];
    if (known == null) {
      return GitResult(
        ok: false,
        exitCode: 1,
        message: 'Lampiran tidak ada di repositori: $relative',
      );
    }

    return _withClient(repoPath, auth, (client, ref) async {
      onProgress?.call(SyncProgress.message('Mengunduh ${p.basename(relative)}…'));
      final bytes = await client.blob(known.sha);
      final file = File(absoluteFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return const GitResult(ok: true, exitCode: 0, message: 'Berkas selesai diunduh');
    });
  }

  // ------------------------------------------------------------------- misc

  @override
  Future<GitResult> setRemote({required String repoPath, required String remoteUrl}) async {
    // The remote lives in the profile; nothing is stored inside the mirror.
    return const GitResult(ok: true, exitCode: 0, message: 'Remote diperbarui');
  }

  @override
  Future<List<GitCommitInfo>> log({required String repoPath, int limit = 20}) async {
    final state = GitHubSyncState.load(repoPath);
    if (state == null || state.commitSha.isEmpty) return const <GitCommitInfo>[];
    return <GitCommitInfo>[
      GitCommitInfo(
        hash: state.commitSha,
        subject: state.lastCommitSubject.isEmpty
            ? 'Mirror pada commit ${state.commitSha.substring(0, 7)}'
            : state.lastCommitSubject,
        author: '',
        date: state.lastCommitDate ?? DateTime.now(),
      ),
    ];
  }

  // --------------------------------------------------------------- internals

  static const GitResult _notMirrored = GitResult(
    ok: false,
    exitCode: 1,
    message: 'Repositori belum di-mirror di perangkat ini.',
  );

  /// True for paths inside `attachments/` or `attachments-lfs/`.
  /// GitHub menolak isi berkas ini sendiri — bukan jaringan, bukan token.
  ///
  /// 413 dipakai pemeriksaan ukuran sebelum mengunggah; 422 adalah jawaban
  /// GitHub untuk berkas yang tidak mau diterimanya.
  static bool _isRejection(GitFailure failure) =>
      failure.exitCode == 413 || failure.exitCode == 422;

  static String _rejectionMessage(Map<String, RejectedFile> rejected, {required int sentCount}) {
    final names = rejected.keys.map(p.basename).toList();
    final shown = names.take(3).join(', ');
    final more = names.length > 3 ? ' dan ${names.length - 3} lainnya' : '';
    final reason = rejected.values.first.reason;
    final head = sentCount == 0
        ? 'Tidak ada yang terkirim'
        : '$sentCount berkas terkirim';
    return '$head; ${names.length} berkas ditolak GitHub dan tetap menunggu: '
        '$shown$more. $reason';
  }

  static String _rejectionDetails(Map<String, RejectedFile> rejected) => <String>[
    for (final entry in rejected.entries) '${entry.key} — ${entry.value.reason}',
  ].join('\n');

  static bool isAttachmentPath(String path) {
    final segments = p.split(path);
    return segments.any(attachmentDirs.contains);
  }

  /// Downloads every metadata blob whose id differs from the mirror, records
  /// attachment ids for later, and deletes files that are gone upstream.
  Future<int> _mirror({
    required GitHubApiClient client,
    required List<GitTreeEntry> entries,
    required String repoPath,
    required GitHubSyncState state,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final wanted = <GitTreeEntry>[];
    final remotePaths = <String>{};

    state.attachments.clear();
    for (final entry in entries) {
      if (!entry.isBlob) continue;
      if (isAttachmentPath(entry.path)) {
        state.attachments[entry.path] = MirroredFile(sha: entry.sha, size: entry.size, mtimeMs: 0);
        continue;
      }
      remotePaths.add(entry.path);
      final mirrored = state.files[entry.path];
      final file = File(p.join(repoPath, entry.path));
      if (mirrored != null && mirrored.sha == entry.sha && file.existsSync()) continue;
      wanted.add(entry);
    }

    for (final path in state.files.keys.toList()) {
      if (remotePaths.contains(path)) continue;
      final file = File(p.join(repoPath, path));
      if (file.existsSync()) await file.delete();
      state.files.remove(path);
    }

    // Nothing left to fetch means the mirror is already complete.
    if (wanted.isEmpty) {
      await state.save(repoPath);
      return 0;
    }

    var done = 0;
    var sinceCheckpoint = 0;
    final total = wanted.length;
    final alreadyHave = state.files.length;
    onProgress?.call(
      SyncProgress(
        message: alreadyHave > 0 ? 'Melanjutkan unduhan metadata' : 'Mengunduh metadata',
        fraction: 0,
        current: 0,
        total: total,
      ),
    );

    Future<void> worker(Iterable<GitTreeEntry> slice) async {
      for (final entry in slice) {
        final bytes = await client.blob(entry.sha);

        // GitHub told us the blob id; if what arrived does not hash to it the
        // transfer was truncated, and writing it would leave a file that looks
        // downloaded but is broken.
        if (gitBlobSha(bytes) != entry.sha) {
          throw GitFailure(
            'Berkas rusak saat diunduh: ${p.basename(entry.path)}. '
            'Jalankan lagi untuk mengunduh ulang bagian yang gagal.',
            details: entry.path,
          );
        }

        final file = File(p.join(repoPath, entry.path));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        final stat = file.statSync();
        state.files[entry.path] = MirroredFile(
          sha: entry.sha,
          size: stat.size,
          mtimeMs: stat.modified.millisecondsSinceEpoch,
        );
        done++;
        sinceCheckpoint++;

        // Persist regularly so an interruption costs at most a few files.
        if (sinceCheckpoint >= 50) {
          sinceCheckpoint = 0;
          await state.save(repoPath);
        }
        if (done % 10 == 0 || done == total) {
          onProgress?.call(
            SyncProgress(
              message: 'Mengunduh metadata',
              fraction: done / total,
              current: done,
              total: total,
            ),
          );
        }
      }
    }

    final lanes = List<List<GitTreeEntry>>.generate(concurrency, (_) => <GitTreeEntry>[]);
    for (var i = 0; i < wanted.length; i++) {
      lanes[i % concurrency].add(wanted[i]);
    }
    try {
      await Future.wait(lanes.where((l) => l.isNotEmpty).map(worker));
    } finally {
      // Whether it finished or failed, keep what was downloaded.
      await state.save(repoPath);
    }
    return total;
  }

  Future<GitResult> _withClient(
    String repoPath,
    GitAuth auth,
    Future<GitResult> Function(GitHubApiClient client, GitHubRepoRef ref) action,
  ) async {
    final remote = _remoteFor(repoPath, auth);
    if (remote == null) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'URL repositori GitHub tidak dikenali.',
      );
    }
    if (!auth.hasHttpsCredentials) {
      return const GitResult(
        ok: false,
        exitCode: 1,
        message: 'Token GitHub belum diisi pada profil repositori.',
      );
    }
    final client = clientFactory(remote, auth.httpsToken);
    try {
      return await action(client, remote);
    } on Failure catch (e) {
      return GitResult(ok: false, exitCode: 1, message: e.message, stderr: e.details ?? '');
    } on SocketException {
      return const GitResult(ok: false, exitCode: 1, message: 'Jaringan tidak tersedia.');
    } finally {
      client.close();
    }
  }

  /// The repository this mirror belongs to; [GitAuth.remoteUrl] carries it.
  GitHubRepoRef? _remoteFor(String repoPath, GitAuth auth) =>
      auth.remoteUrl == null ? null : GitHubRepoRef.parse(auth.remoteUrl!);
}
