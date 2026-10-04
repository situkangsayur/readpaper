import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/errors/failure.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_api_backend.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_api_client.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_sync_state.dart';
import 'package:readpaper/src/features/sync/domain/entities/git_entities.dart';

/// An in-memory stand-in for the GitHub git data API.
///
/// It records the write calls so the tests can assert the exact sequence a
/// push has to perform: blobs, then a tree, then a commit, then the ref.
class FakeGitHub {
  FakeGitHub({required this.branch, required this.commitSha});

  String branch;
  String commitSha;
  String treeSha = 'tree-0';

  /// Repository contents: path → bytes.
  final Map<String, List<int>> blobs = <String, List<int>>{};

  final List<String> calls = <String>[];
  final List<Map<String, dynamic>> createdTrees = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> createdCommits = <Map<String, dynamic>>[];
  final Map<String, List<int>> uploadedBlobs = <String, List<int>>{};

  void put(String path, String content) => blobs[path] = utf8.encode(content);

  String shaOf(String path) => gitBlobSha(blobs[path]!);

  http.Client get client => MockClient(handle);

  /// The handler itself, so a test can wrap it to simulate a flaky network.
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    calls.add('${request.method} $path');

    if (request.method == 'GET' && path.endsWith('/commits/$branch')) {
      return _json(<String, dynamic>{'sha': commitSha});
    }
    if (request.method == 'GET' && path.endsWith('/git/commits/$commitSha')) {
      return _json(<String, dynamic>{
        'sha': commitSha,
        'tree': <String, dynamic>{'sha': treeSha},
      });
    }
    if (request.method == 'GET' && path.contains('/git/trees/')) {
      return _json(<String, dynamic>{
        'sha': treeSha,
        'truncated': false,
        'tree': <dynamic>[
          for (final entry in blobs.entries)
            <String, dynamic>{
              'path': entry.key,
              'sha': gitBlobSha(entry.value),
              'type': 'blob',
              'size': entry.value.length,
              'mode': '100644',
            },
        ],
      });
    }
    if (request.method == 'GET' && path.contains('/git/blobs/')) {
      final sha = path.split('/').last;
      for (final entry in blobs.entries) {
        if (gitBlobSha(entry.value) == sha) {
          return http.Response.bytes(entry.value, 200);
        }
      }
      return http.Response('not found', 404);
    }
    if (request.method == 'POST' && path.endsWith('/git/blobs')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final bytes = base64Decode(body['content'] as String);
      final sha = gitBlobSha(bytes);
      uploadedBlobs[sha] = bytes;
      return _json(<String, dynamic>{'sha': sha});
    }
    if (request.method == 'POST' && path.endsWith('/git/trees')) {
      createdTrees.add(jsonDecode(request.body) as Map<String, dynamic>);
      treeSha = 'tree-${createdTrees.length}';
      return _json(<String, dynamic>{'sha': treeSha});
    }
    if (request.method == 'POST' && path.endsWith('/git/commits')) {
      createdCommits.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json(<String, dynamic>{'sha': 'commit-${createdCommits.length}'});
    }
    if (request.method == 'PATCH' && path.contains('/git/refs/heads/')) {
      commitSha = (jsonDecode(request.body) as Map<String, dynamic>)['sha'] as String;
      return _json(<String, dynamic>{'ref': 'refs/heads/$branch'});
    }
    if (request.method == 'GET' && path.endsWith('/situkangsayur/zotero-hendri')) {
      return _json(<String, dynamic>{'default_branch': branch});
    }
    return http.Response('unhandled ${request.method} $path', 500);
  }

  http.Response _json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json', 'x-ratelimit-remaining': '4999'},
  );
}

void main() {
  const remote = 'git@github.com:situkangsayur/zotero-hendri.git';
  const auth = GitAuth(
    transport: GitTransport.https,
    httpsToken: 'token-123',
    httpsUsername: 'situkangsayur',
    remoteUrl: remote,
  );

  late Directory mirror;
  late FakeGitHub server;
  late GitHubApiBackend backend;

  setUp(() {
    mirror = Directory.systemTemp.createTempSync('readpaper_mirror_');
    server = FakeGitHub(branch: 'main', commitSha: 'commit-0')
      ..put('zotero/my-library/collections.json', '[]\n')
      ..put('zotero/my-library/items/IT/ITEMKEY1.json', '{"a":1}\n')
      ..put('zotero/my-library/notes/M/Migrasi (ITEMKEY1).md', '# Migrasi\n')
      ..put('zotero/my-library/attachments/AT/ATTACH01/paper.pdf', '%PDF-1.4 dummy')
      ..put('zotero/my-library/attachments-lfs/BI/BIG00001/book.pdf', 'lfs pointer');
    backend = GitHubApiBackend(
      clientFactory: (ref, token) => GitHubApiClient(ref: ref, token: token, client: server.client),
      concurrency: 2,
    );
  });

  tearDown(() => mirror.deleteSync(recursive: true));

  String path(String relative) => p.join(mirror.path, relative);

  group('git blob ids', () {
    test('match what git itself computes', () {
      // `printf 'halo readpaper\n' | git hash-object --stdin`
      expect(
        gitBlobSha(utf8.encode('halo readpaper\n')),
        'de47c1347015e33ded88fd02a524122c3f6844ba',
      );
    });
  });

  group('repository URLs', () {
    test('are parsed from both SSH and HTTPS forms', () {
      final ssh = GitHubRepoRef.parse('git@github.com:situkangsayur/zotero-hendri.git')!;
      expect(ssh.owner, 'situkangsayur');
      expect(ssh.repo, 'zotero-hendri');
      expect(ssh.apiBase, 'https://api.github.com');

      final https = GitHubRepoRef.parse('https://github.com/situkangsayur/readpaper')!;
      expect(https.owner, 'situkangsayur');
      expect(https.repo, 'readpaper');

      expect(
        GitHubRepoRef.parse('git@git.example.com:team/lib.git')!.apiBase,
        'https://git.example.com/api/v3',
      );
      expect(GitHubRepoRef.parse('bukan-url'), isNull);
    });
  });

  group('lampiran tidak pernah dikirim lewat API', () {
    test('lampiran LFS di antrean lama tidak lagi menggagalkan pengiriman', () async {
      // Berkas di attachments-lfs/ disimpan di repositori sebagai penunjuk Git
      // LFS sepanjang seratus bita, bukan sebagai isinya. Mengirim PDF-nya ke
      // sana akan menimpa penunjuk itu; dan kalaupun tidak, API GitHub
      // menolaknya karena ukurannya. Yang dulu terjadi: berkasnya terbawa
      // terus di antrean, dan setiap pengiriman berhenti di situ dengan galat
      // yang menyuruh menarik perubahan — yang tidak pernah bisa menolong.
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');

      final lfs = 'zotero/my-library/attachments-lfs/BI/BIG00001/book.pdf';
      File(path(lfs))
        ..createSync(recursive: true)
        ..writeAsStringSync('isi buku yang sebenarnya, bukan penunjuk');

      final state = GitHubSyncState.load(mirror.path)!;
      state.pending.add(
        PendingChange(message: 'Antrean lama', paths: <String>[lfs], at: DateTime.now()),
      );
      await state.save(mirror.path);

      final pushed = await backend.push(repoPath: mirror.path, auth: auth);
      expect(pushed.ok, isTrue, reason: 'antreannya harus punya jalan keluar');
      expect(pushed.message, contains('lampiran'));
      expect(server.createdCommits, isEmpty, reason: 'tidak ada yang pantas dikirim');
      expect(
        GitHubSyncState.load(mirror.path)!.pending,
        isEmpty,
        reason: 'antrean yang tidak bisa dikirim harus dikosongkan, bukan dicoba selamanya',
      );
    });

    test('lampiran tidak ikut disiapkan saat commit', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');

      final lfs = 'zotero/my-library/attachments-lfs/BI/BIG00001/book.pdf';
      File(path(lfs))
        ..createSync(recursive: true)
        ..writeAsStringSync('isi buku');
      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).writeAsStringSync('{"a":9}\n');

      final committed = await backend.commitAll(
        repoPath: mirror.path,
        message: 'Ubah item dan lampiran',
        paths: <String>[lfs, 'zotero/my-library/items/IT/ITEMKEY1.json'],
      );
      expect(committed.ok, isTrue);

      final pending = GitHubSyncState.load(mirror.path)!.pending.single;
      expect(pending.paths, <String>['zotero/my-library/items/IT/ITEMKEY1.json']);
    });
  });

  group('batas waktu unggahan', () {
    GitHubApiClient client() =>
        GitHubApiClient(ref: GitHubRepoRef.parse(remote)!, token: 'x', client: server.client);

    test('permintaan kecil tetap memakai batas waktu yang pendek', () {
      // Membaca satu daftar tidak pantas menunggu lama; kalau diam, ia memang
      // tersangkut.
      expect(client().timeoutForBytes(0), const Duration(seconds: 30));
    });

    test('unggahan besar diberi waktu sebanding dengan ukurannya', () {
      // Satu buku tiga puluh megabita tidak akan pernah selesai dalam tiga
      // puluh detik dari tablet di jaringan biasa, dan yang terjadi kemudian
      // bukan pesan yang menjelaskan melainkan "koneksi terputus" setelah tiga
      // kali mencoba dari awal.
      const tigaPuluhMB = 30 * 1024 * 1024;
      final jatah = client().timeoutForBytes(tigaPuluhMB);
      expect(jatah.inMinutes, greaterThanOrEqualTo(30));
    });

    test('tetap berbatas, supaya soket yang mati tidak menggantung selamanya', () {
      const duaGigabita = 2 * 1024 * 1024 * 1024;
      expect(client().timeoutForBytes(duaGigabita), const Duration(minutes: 45));
    });

    test('berkas di atas batas GitHub ditolak sebelum diunggah', () async {
      // Mengunggah empat puluh menit untuk mendapat penolakan di ujungnya
      // adalah cara terburuk menyampaikan kabar yang sudah bisa diketahui di
      // awal.
      final terlaluBesar = List<int>.filled(GitHubApiClient.maxBlobBytes + 1, 0);
      await expectLater(
        client().createBlob(terlaluBesar),
        throwsA(
          isA<GitFailure>().having(
            (e) => e.message,
            'pesan',
            allOf(contains('100 MB'), contains('git biasa')),
          ),
        ),
      );
    });
  });

  group('clone', () {
    test('mirrors metadata but leaves attachments on GitHub', () async {
      final progress = <String>[];
      final result = await backend.clone(
        remoteUrl: remote,
        targetPath: mirror.path,
        auth: auth,
        branch: 'main',
        onProgress: (p) => progress.add(p.label),
      );

      expect(result.ok, isTrue, reason: result.message);
      expect(File(path('zotero/my-library/collections.json')).existsSync(), isTrue);
      expect(File(path('zotero/my-library/items/IT/ITEMKEY1.json')).existsSync(), isTrue);
      expect(File(path('zotero/my-library/notes/M/Migrasi (ITEMKEY1).md')).existsSync(), isTrue);

      expect(
        File(path('zotero/my-library/attachments/AT/ATTACH01/paper.pdf')).existsSync(),
        isFalse,
        reason: 'PDFs must not be downloaded during a clone',
      );

      final state = GitHubSyncState.load(mirror.path)!;
      expect(state.commitSha, 'commit-0');
      expect(state.files, hasLength(3));
      expect(state.attachments, hasLength(2), reason: 'both attachment roots are recorded');
      expect(progress, isNotEmpty);
    });

    test('refuses without a token', () async {
      final result = await backend.clone(
        remoteUrl: remote,
        targetPath: mirror.path,
        auth: const GitAuth(transport: GitTransport.https, remoteUrl: remote),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('token'));
    });
  });

  group('status', () {
    test('berkas yang bersih karena balapan selalu dibaca ulang isinya', () {
      // Pemeriksaan murah "ukuran dan waktu ubahnya sama" bisa salah kalau
      // berkasnya disunting di dalam detak jam berkas yang sama dengan saat
      // catatan sinkronisasi ditulis. Di Linux waktu ubahnya sehalus
      // nanodetik sehingga hampir tidak pernah bertabrakan; di Windows jauh
      // lebih kasar, dan runner-nya menangkapnya sebagai dua tes merah —
      // perubahan yang tidak terdeteksi, dan push yang tidak menolak padahal
      // GitHub sudah maju. Aturannya diuji langsung supaya tidak bergantung
      // pada kehalusan jam mesin yang menjalankan tes ini.
      const catatan = 1000;

      // Lebih tua dari catatannya: aman dipercaya.
      expect(GitHubApiBackend.isRacilyClean(knownMtimeMs: 999, stateFileMtimeMs: catatan), isFalse);
      // Sedetak dengan catatannya: tidak bisa dibedakan, harus dibaca.
      expect(GitHubApiBackend.isRacilyClean(knownMtimeMs: 1000, stateFileMtimeMs: catatan), isTrue);
      // Lebih baru dari catatannya: jelas harus dibaca.
      expect(GitHubApiBackend.isRacilyClean(knownMtimeMs: 1001, stateFileMtimeMs: catatan), isTrue);
      // Catatan lama yang waktunya tidak diketahui: perilakunya seperti dulu,
      // bukan tiba-tiba membaca ulang seluruh library.
      expect(GitHubApiBackend.isRacilyClean(knownMtimeMs: 5000, stateFileMtimeMs: 0), isFalse);
    });

    test('reports files edited since the last sync', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');

      var status = await backend.status(mirror.path);
      expect(status.exists, isTrue);
      expect(status.changes, isEmpty);
      expect(status.branch, 'main');

      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).writeAsStringSync('{"a":2}\n');
      status = await backend.status(mirror.path);
      expect(status.changes, hasLength(1));
      expect(status.changes.single.path, 'zotero/my-library/items/IT/ITEMKEY1.json');
      expect(status.isDirty, isTrue);
    });

    test('ignores a rewrite that produces identical content', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      final file = File(path('zotero/my-library/items/IT/ITEMKEY1.json'));
      file.writeAsStringSync('{"a":1}\n');

      final status = await backend.status(mirror.path);
      expect(status.changes, isEmpty, reason: 'same bytes means nothing to push');
    });
  });

  group('commit and push', () {
    test('stages locally, then writes one commit through the API', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).writeAsStringSync('{"a":2}\n');

      final staged = await backend.commitAll(
        repoPath: mirror.path,
        message: 'Tambah highlight p.1',
      );
      expect(staged.ok, isTrue);
      expect(GitHubSyncState.load(mirror.path)!.pending, hasLength(1));
      expect(server.createdCommits, isEmpty, reason: 'nothing reaches GitHub until push');

      final pushed = await backend.push(repoPath: mirror.path, auth: auth);
      expect(pushed.ok, isTrue, reason: pushed.message);

      expect(server.uploadedBlobs, hasLength(1));
      expect(server.createdTrees, hasLength(1));
      expect(server.createdTrees.single['base_tree'], 'tree-0');
      final treeEntry = (server.createdTrees.single['tree'] as List).single as Map;
      expect(treeEntry['path'], 'zotero/my-library/items/IT/ITEMKEY1.json');
      expect(treeEntry['mode'], '100644');

      expect(server.createdCommits.single['message'], 'Tambah highlight p.1');
      expect(server.createdCommits.single['parents'], <String>['commit-0']);
      expect(server.commitSha, 'commit-1', reason: 'the branch ref moved');

      final state = GitHubSyncState.load(mirror.path)!;
      expect(state.pending, isEmpty);
      expect(state.commitSha, 'commit-1');

      final status = await backend.status(mirror.path);
      expect(status.changes, isEmpty, reason: 'the mirror matches the new commit');
    });

    test('refuses to push when GitHub moved ahead', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).writeAsStringSync('{"a":3}\n');
      await backend.commitAll(repoPath: mirror.path, message: 'Ubah anotasi');

      server.commitSha = 'commit-dari-perangkat-lain';

      final pushed = await backend.push(repoPath: mirror.path, auth: auth);
      expect(pushed.ok, isFalse);
      expect(pushed.message, contains('Tarik perubahan dulu'));
      expect(server.createdCommits, isEmpty);
    });

    test('deletes a file upstream when it is gone locally', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).deleteSync();

      await backend.commitAll(repoPath: mirror.path, message: 'Hapus item');
      await backend.push(repoPath: mirror.path, auth: auth);

      final treeEntry = (server.createdTrees.single['tree'] as List).single as Map;
      expect(treeEntry['sha'], isNull, reason: 'a null sha removes the path');
    });
  });

  group('berkas yang ditolak GitHub', () {
    test('tidak menahan berkas lain, dan tidak diunggah ulang selama isinya sama', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      const book = 'catatan/berkas/CP/CPGBOOK1/Introduction to CpG.pdf';
      File(path(book))
        ..createSync(recursive: true)
        ..writeAsStringSync('buku yang ditolak');
      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).writeAsStringSync('{"a":5}\n');

      var bookUploads = 0;
      backend = GitHubApiBackend(
        clientFactory: (ref, token) => GitHubApiClient(
          ref: ref,
          token: token,
          client: MockClient((request) async {
            if (request.method == 'POST' && request.url.path.endsWith('/git/blobs')) {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              if (utf8.decode(base64Decode(body['content'] as String)) == 'buku yang ditolak') {
                bookUploads++;
                return http.Response(
                  jsonEncode(<String, dynamic>{'message': 'content is too large'}),
                  422,
                );
              }
            }
            return server.handle(request);
          }),
        ),
        concurrency: 2,
      );

      await backend.commitAll(repoPath: mirror.path, message: 'Catatan dan buku');
      final pushed = await backend.push(repoPath: mirror.path, auth: auth);
      expect(pushed.ok, isFalse, reason: 'yang tertinggal harus terlihat');
      expect(pushed.message, contains('1 berkas terkirim'));
      expect(pushed.message, contains('Introduction to CpG.pdf'));
      expect(pushed.message, contains('content is too large'));

      final entries = (server.createdTrees.single['tree'] as List).cast<Map>();
      expect(entries.map((e) => e['path']), <String>['zotero/my-library/items/IT/ITEMKEY1.json']);
      expect(server.commitSha, 'commit-1', reason: 'yang lain tetap sampai');

      final state = GitHubSyncState.load(mirror.path)!;
      expect(state.pending.single.paths, <String>[book], reason: 'tidak dibuang diam-diam');

      await backend.commitAll(repoPath: mirror.path, message: 'Coba lagi');
      final again = await backend.push(repoPath: mirror.path, auth: auth);
      expect(again.ok, isFalse);
      expect(bookUploads, 1, reason: 'isi yang sama tidak diunggah lagi untuk ditolak lagi');
    });

    test('jalur yang tidak pernah ada di GitHub tidak diminta dihapus', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      File(path('zotero/my-library/items/IT/ITEMKEY1.json')).writeAsStringSync('{"a":6}\n');
      final state = GitHubSyncState.load(mirror.path)!;
      state.pending.add(
        PendingChange(
          message: 'Antrean lama',
          paths: <String>['catatan/item/XX/SEMENTARA.json', 'zotero/my-library/collections.json'],
          at: DateTime.now(),
        ),
      );
      await state.save(mirror.path);

      await backend.commitAll(repoPath: mirror.path, message: 'Ubah item');
      final pushed = await backend.push(repoPath: mirror.path, auth: auth);
      expect(pushed.ok, isTrue, reason: pushed.message);
      final entries = (server.createdTrees.single['tree'] as List).cast<Map>();
      expect(
        entries.map((e) => e['path']),
        <String>['zotero/my-library/items/IT/ITEMKEY1.json'],
        reason: 'berkas sementara tidak dihapus, berkas yang tidak berubah tidak diunggah',
      );
    });
  });

  group('attachments', () {
    test('are downloaded on demand', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      final target = path('zotero/my-library/attachments/AT/ATTACH01/paper.pdf');
      expect(File(target).existsSync(), isFalse);

      final result = await backend.fetchAttachment(
        repoPath: mirror.path,
        auth: auth,
        absoluteFilePath: target,
      );

      expect(result.ok, isTrue, reason: result.message);
      expect(File(target).readAsStringSync(), '%PDF-1.4 dummy');
    });

    test('report a clear error when the path is not in the repository', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      final result = await backend.fetchAttachment(
        repoPath: mirror.path,
        auth: auth,
        absoluteFilePath: path('zotero/my-library/attachments/XX/XXXX/tidak-ada.pdf'),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('tidak ada di repositori'));
    });
  });

  group('unduhan yang terputus', () {
    test('menyimpan apa yang sudah terunduh lalu melanjutkannya', () async {
      // Putuskan koneksi setelah dua blob, seperti layar terkunci di tengah jalan.
      var served = 0;
      final flaky = GitHubApiBackend(
        clientFactory: (ref, token) => GitHubApiClient(
          ref: ref,
          token: token,
          maxAttempts: 1,
          client: MockClient((request) async {
            if (request.url.path.contains('/git/blobs/') && ++served > 2) {
              throw const SocketException('jaringan hilang');
            }
            return server.handle(request);
          }),
        ),
        concurrency: 1,
      );

      final gagal = await flaky.clone(
        remoteUrl: remote,
        targetPath: mirror.path,
        auth: auth,
        branch: 'main',
      );
      expect(gagal.ok, isFalse);
      expect(gagal.message, contains('Lanjutkan'));

      final sebagian = GitHubSyncState.load(mirror.path);
      expect(sebagian, isNotNull, reason: 'pembukuan harus tersimpan, bukan terhapus');
      expect(sebagian!.files, hasLength(2), reason: 'dua berkas pertama tetap ada');
      expect(Directory(mirror.path).existsSync(), isTrue, reason: 'folder tidak boleh dihapus');

      // Jaringan pulih: jalankan lagi, harus melanjutkan bukan mengulang.
      final lanjut = await backend.clone(
        remoteUrl: remote,
        targetPath: mirror.path,
        auth: auth,
        branch: 'main',
      );
      expect(lanjut.ok, isTrue, reason: lanjut.message);
      expect(GitHubSyncState.load(mirror.path)!.files, hasLength(3));
      expect(await backend.status(mirror.path).then((s) => s.changes), isEmpty);
    });

    test('menolak berkas yang rusak saat transfer', () async {
      final rusak = GitHubApiBackend(
        clientFactory: (ref, token) => GitHubApiClient(
          ref: ref,
          token: token,
          maxAttempts: 1,
          client: MockClient((request) async {
            if (request.url.path.contains('/git/blobs/')) {
              return http.Response('isi yang salah', 200);
            }
            return server.handle(request);
          }),
        ),
        concurrency: 1,
      );

      final hasil = await rusak.clone(
        remoteUrl: remote,
        targetPath: mirror.path,
        auth: auth,
        branch: 'main',
      );
      expect(hasil.ok, isFalse);
      expect(hasil.message, contains('rusak'));
    });
  });

  group('pull', () {
    test('brings down changed files and removes deleted ones', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');

      server
        ..put('zotero/my-library/items/IT/ITEMKEY1.json', '{"a":99}\n')
        ..put('zotero/my-library/items/IT/ITEMKEY2.json', '{"b":1}\n')
        ..blobs.remove('zotero/my-library/notes/M/Migrasi (ITEMKEY1).md');
      server.commitSha = 'commit-baru';

      final result = await backend.pull(repoPath: mirror.path, auth: auth);
      expect(result.ok, isTrue, reason: result.message);

      expect(
        File(path('zotero/my-library/items/IT/ITEMKEY1.json')).readAsStringSync(),
        '{"a":99}\n',
      );
      expect(File(path('zotero/my-library/items/IT/ITEMKEY2.json')).existsSync(), isTrue);
      expect(File(path('zotero/my-library/notes/M/Migrasi (ITEMKEY1).md')).existsSync(), isFalse);

      final state = GitHubSyncState.load(mirror.path)!;
      expect(state.commitSha, 'commit-baru');
      expect(state.behind, 0);
      expect(await backend.status(mirror.path).then((s) => s.changes), isEmpty);
    });

    test('does nothing when already up to date', () async {
      await backend.clone(remoteUrl: remote, targetPath: mirror.path, auth: auth, branch: 'main');
      final result = await backend.pull(repoPath: mirror.path, auth: auth);
      expect(result.message, 'Sudah paling baru');
    });
  });
}
