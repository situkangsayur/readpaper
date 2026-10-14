import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../../core/errors/failure.dart';
import '../../../../core/l10n.dart';

/// One entry of a git tree as returned by the GitHub API.
class GitTreeEntry {
  const GitTreeEntry({
    required this.path,
    required this.sha,
    required this.type,
    required this.size,
    this.mode = '100644',
  });

  final String path;
  final String sha;

  /// `blob` or `tree`.
  final String type;
  final int size;
  final String mode;

  bool get isBlob => type == 'blob';
}

/// Identifies a repository on GitHub.
class GitHubRepoRef {
  const GitHubRepoRef({required this.owner, required this.repo, this.host = 'github.com'});

  /// Parses `git@github.com:owner/repo.git` or `https://github.com/owner/repo`.
  static GitHubRepoRef? parse(String remoteUrl) {
    var url = remoteUrl.trim();
    if (url.isEmpty) return null;
    if (url.endsWith('.git')) url = url.substring(0, url.length - 4);

    final ssh = RegExp(r'^(?:ssh://)?[^@]+@([^:/]+)[:/](.+)$').firstMatch(url);
    if (ssh != null) {
      final parts = ssh.group(2)!.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length < 2) return null;
      return GitHubRepoRef(owner: parts[parts.length - 2], repo: parts.last, host: ssh.group(1)!);
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.length < 2) return null;
    return GitHubRepoRef(
      owner: uri.pathSegments[uri.pathSegments.length - 2],
      repo: uri.pathSegments.last,
      host: uri.host.isEmpty ? 'github.com' : uri.host,
    );
  }

  final String owner;
  final String repo;
  final String host;

  /// REST root; GitHub Enterprise servers expose it under `/api/v3`.
  String get apiBase => host == 'github.com' ? 'https://api.github.com' : 'https://$host/api/v3';

  String get slug => '$owner/$repo';
}

/// Thin client over the pieces of the GitHub REST API this app needs.
///
/// Android has no `git` binary, so the whole sync is expressed with the git
/// data API: read a tree, read blobs, and write a new commit by posting blobs,
/// a tree, a commit and then moving the branch ref.
class GitHubApiClient {
  GitHubApiClient({
    required this.ref,
    required this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.maxAttempts = 3,
  }) : _client = client ?? http.Client();

  final GitHubRepoRef ref;
  final String? token;
  final http.Client _client;

  /// How long one request may take before it is abandoned.
  ///
  /// Without this a locked phone screen freezes the socket and the download
  /// hangs for good instead of failing and retrying.
  ///
  /// Ini batas untuk permintaan **kecil**. Mengunggah berkas besar memakai
  /// [timeoutForBytes], karena tiga puluh detik adalah batas yang masuk akal
  /// untuk membaca satu daftar, dan sama sekali tidak masuk akal untuk
  /// mengunggah buku tiga puluh megabita.
  final Duration timeout;

  /// Berapa lama sebuah unggahan sebesar [bytes] boleh berjalan.
  ///
  /// Satu buku PDF tiga puluh megabita menjadi empat puluh megabita setelah
  /// disandikan base64. Menghabiskannya dalam tiga puluh detik menuntut
  /// sebelas megabit per detik yang bertahan penuh — angka yang tidak dimiliki
  /// tablet di jaringan biasa. Yang terjadi kemudian bukan pesan yang
  /// menjelaskan, melainkan "koneksi terputus" setelah tiga kali mencoba dari
  /// awal, yang terdengar seperti jaringan rusak padahal batas waktunya yang
  /// keliru.
  ///
  /// Jatahnya: waktu dasar, ditambah satu menit untuk tiap megabita yang
  /// dikirim. Itu setara dengan 140 kbit/detik — cukup lambat untuk memaafkan
  /// jaringan yang buruk, dan tetap berbatas supaya soket yang benar-benar mati
  /// tidak menggantung selamanya.
  Duration timeoutForBytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    final allowance = timeout + Duration(seconds: (megabytes * 60).round());
    return allowance > _maxUploadTimeout ? _maxUploadTimeout : allowance;
  }

  static const Duration _maxUploadTimeout = Duration(minutes: 45);

  /// Attempts per request, for failures worth retrying (timeout, socket drop,
  /// 5xx, secondary rate limit).
  final int maxAttempts;

  /// Remaining requests reported by the last response, when known.
  int? rateLimitRemaining;

  /// Cheap reachability check used by the "periksa koneksi" button.
  ///
  /// Returns the authenticated login on success.
  Future<String> whoAmI() async {
    final uri = Uri.parse('${ref.apiBase}/user');
    final response = await _send(() => _client.get(uri, headers: _headers()), uri);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['login'] as String? ?? l10n.syncUnknownUser;
  }

  void close() => _client.close();

  Map<String, String> _headers({String accept = 'application/vnd.github+json'}) => <String, String>{
    'Accept': accept,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'ReadPaper',
    if ((token ?? '').isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '${ref.apiBase}/repos/${ref.owner}/${ref.repo}$path',
  ).replace(queryParameters: query);

  /// Commit sha the branch currently points at.
  Future<String> headSha(String branch) async {
    final response = await _get(_uri('/commits/${Uri.encodeComponent(branch)}'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['sha'] as String;
  }

  /// The default branch of the repository.
  Future<String> defaultBranch() async {
    final response = await _get(_uri(''));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['default_branch'] as String? ?? 'main';
  }

  /// Full recursive listing of a commit's tree.
  Future<List<GitTreeEntry>> tree(String commitSha) async {
    final response = await _get(_uri('/git/trees/$commitSha', <String, String>{'recursive': '1'}));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['truncated'] == true) {
      throw GitFailure(l10n.syncErrTreeTooLarge);
    }
    final entries = <GitTreeEntry>[];
    for (final item in (json['tree'] as List?) ?? const <dynamic>[]) {
      if (item is! Map) continue;
      entries.add(
        GitTreeEntry(
          path: item['path'] as String? ?? '',
          sha: item['sha'] as String? ?? '',
          type: item['type'] as String? ?? 'blob',
          size: (item['size'] as num?)?.toInt() ?? 0,
          mode: item['mode'] as String? ?? '100644',
        ),
      );
    }
    return entries;
  }

  /// Raw bytes of a blob. Works for private repositories through the token.
  Future<Uint8List> blob(String sha) async {
    final response = await _get(_uri('/git/blobs/$sha'), accept: 'application/vnd.github.raw');
    return response.bodyBytes;
  }

  /// Batas GitHub untuk satu blob lewat API git data.
  ///
  /// Di atas ini permintaannya ditolak, dan menolaknya lebih dulu di sini jauh
  /// lebih berguna daripada mengunggah empat puluh menit untuk mendapat 4xx.
  static const int maxBlobBytes = 100 * 1024 * 1024;

  /// Berkas di atas ini tidak dikirim lewat API blob, melainkan sebagai paket
  /// git ([_pushBlob]).
  ///
  /// Batas resmi API blob memang 100 MB, tetapi badan JSON-nya ditolak jauh
  /// sebelum itu dengan "Sorry, your input was too large to process" —
  /// terbukti di APK dengan dua slide kuliah PowerPoint. Batas sebenarnya
  /// tidak diumumkan, jadi angkanya dipilih jauh di bawah yang pernah gagal.
  static const int maxApiBlobBytes = 20 * 1024 * 1024;

  Future<String> createBlob(List<int> content) async {
    if (content.length > maxBlobBytes) {
      throw GitFailure(l10n.syncErrBlobTooLarge(_megabytes(content.length)), exitCode: 413);
    }
    if (content.length > maxApiBlobBytes) return _pushBlob(content);
    try {
      final response = await _post(
        _uri('/git/blobs'),
        <String, dynamic>{'content': base64Encode(content), 'encoding': 'base64'},
        // Base64 menambah sepertiga, dan itu yang benar-benar dikirim.
        timeoutOverride: timeoutForBytes(content.length * 4 ~/ 3),
      );
      return (jsonDecode(response.body) as Map<String, dynamic>)['sha'] as String;
    } on GitFailure catch (e) {
      // Batasnya tidak diumumkan; kalau ternyata lebih rendah dari
      // [maxApiBlobBytes], jalan paket git tetap bisa menampungnya.
      // Hanya penolakan badan permintaan ("your input was too large to
      // process"); berkas yang memang melewati batas GitHub tetap ditolak.
      if (!e.message.toLowerCase().contains('input was too large')) rethrow;
      return _pushBlob(content);
    }
  }

  /// Ref sementara yang menahan blob kiriman [_pushBlob], sampai commit yang
  /// memakainya terpasang di branch.
  final List<String> _parkedRefs = <String>[];

  /// Mengirim satu blob seperti `git push` dari klon lokal — saran GitHub
  /// sendiri untuk berkas yang terlalu besar bagi API.
  Future<String> _pushBlob(List<int> content) async =>
      (await pushBlobs(<Future<List<int>> Function()>[() async => content])).single;

  /// Batas isi satu kiriman [pushBlobs]: berkas-berkas besar dikumpulkan
  /// sampai sebesar ini lalu dikirim sekali jalan, seperti satu `git push`.
  ///
  /// GitHub sendiri menerima push sampai 2 GB, tetapi paketnya disusun di
  /// memori tablet; seratus megabita (juga batas GitHub untuk satu berkas)
  /// masih aman di sana.
  static const int maxPushBatchBytes = 100 * 1024 * 1024;

  /// Mengirim beberapa blob sekaligus sebagai satu paket git ke
  /// `git-receive-pack`, dan mengembalikan sha tiap blob sesuai urutannya.
  ///
  /// Android tidak punya `git`, jadi paketnya disusun di sini: blob-blob itu,
  /// sebuah pohon yang berisi semuanya, dan sebuah commit di atasnya, dikirim
  /// sebagai ref sementara `refs/readpaper/blob-<sha commit>`. Setelah itu
  /// blobnya ada di repositori dan bisa dipakai pohon biasa lewat API; ref
  /// sementaranya dihapus [releaseParkedBlobs] begitu commit sebenarnya
  /// terpasang.
  ///
  /// Isi tiap berkas dibaca lewat [contents] satu per satu, dipadatkan, lalu
  /// dilepas, dan badan permintaannya dialirkan per potong — yang tinggal di
  /// memori hanya versi padatnya, tidak tiga salinan seratus megabita.
  Future<List<String>> pushBlobs(List<Future<List<int>> Function()> contents) async {
    final chunks = <List<int>>[];
    final hash = _DigestSink();
    final packHash = sha1.startChunkedConversion(hash);
    void emit(List<int> data) {
      chunks.add(data);
      packHash.add(data);
    }

    emit(ascii.encode('PACK'));
    emit(_uint32(2));
    emit(_uint32(contents.length + 2));
    final ids = <Digest>[];
    for (final load in contents) {
      final content = await load();
      final blob = _gitObject('blob', content);
      ids.add(blob.id);
      _emitObject(blob, emit);
    }
    final treeBody = BytesBuilder(copy: false);
    for (var i = 0; i < ids.length; i++) {
      // Nama berurutan dengan lebar tetap: git meminta entri pohon terurut.
      treeBody
        ..add(utf8.encode('100644 b${i.toString().padLeft(6, '0')}\u0000'))
        ..add(ids[i].bytes);
    }
    final tree = _gitObject('tree', treeBody.takeBytes());
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const who = 'ReadPaper <readpaper@users.noreply.github.com>';
    final commit = _gitObject(
      'commit',
      utf8.encode(
        'tree ${tree.id}\nauthor $who $now +0000\ncommitter $who $now +0000\n\n'
        'ReadPaper: penampung sementara berkas besar\n',
      ),
    );
    _emitObject(tree, emit);
    _emitObject(commit, emit);
    packHash.close();
    chunks.add(hash.value.bytes);

    final refName = 'refs/readpaper/blob-${commit.id}';
    chunks.insert(0, utf8.encode('0000'));
    chunks.insert(
      0,
      _pktLine('${'0' * 40} ${commit.id} $refName\u0000report-status agent=readpaper\n'),
    );
    final length = chunks.fold<int>(0, (n, c) => n + c.length);
    final uri = Uri.parse('https://${ref.host}/${ref.owner}/${ref.repo}.git/git-receive-pack');
    final response = await _send(
      () async {
        final request = http.StreamedRequest('POST', uri)
          ..contentLength = length
          ..headers.addAll(<String, String>{
            'Content-Type': 'application/x-git-receive-pack-request',
            'Accept': 'application/x-git-receive-pack-result',
            'User-Agent': 'git/2.0 ReadPaper',
            if ((token ?? '').isNotEmpty)
              'Authorization': 'Basic ${base64Encode(utf8.encode('x-access-token:$token'))}',
          });
        final sent = _client.send(request);
        for (final chunk in chunks) {
          request.sink.add(chunk);
        }
        unawaited(request.sink.close());
        return http.Response.fromStream(await sent);
      },
      uri,
      timeoutOverride: timeoutForBytes(length),
    );
    final report = _pktLines(response.bodyBytes);
    final unpack = report.firstWhere((l) => l.startsWith('unpack '), orElse: () => '');
    final status = report.firstWhere(
      (l) => l.startsWith('ok ') || l.startsWith('ng '),
      orElse: () => '',
    );
    if (unpack != 'unpack ok' || !status.startsWith('ok ')) {
      final reason = status.startsWith('ng ')
          ? status.substring(3 + refName.length).trim()
          : unpack.replaceFirst('unpack ', '');
      throw GitFailure(
        l10n.syncErrRejected(reason.isEmpty ? report.join(' ') : reason),
        details: '${uri.path} → ${report.join(' | ')}',
        exitCode: 422,
      );
    }
    _parkedRefs.add(refName);
    return <String>[for (final id in ids) id.toString()];
  }

  /// Menghapus ref sementara dari [pushBlobs]. Gagal menghapus tidak apa-apa:
  /// yang tertinggal hanya ref tersembunyi yang tidak terlihat sebagai branch.
  Future<void> releaseParkedBlobs() async {
    final refs = List<String>.of(_parkedRefs);
    _parkedRefs.clear();
    for (final name in refs) {
      try {
        await _send(
          () => _client.delete(_uri('/git/$name'), headers: _headers()),
          _uri('/git/$name'),
        );
      } on GitFailure {
        // Lihat di atas.
      }
    }
  }

  static _GitObject _gitObject(String type, List<int> content) {
    // Bertahap, bukan disambung dulu: isi berkas bisa puluhan megabita.
    final sink = _DigestSink();
    sha1.startChunkedConversion(sink)
      ..add(utf8.encode('$type ${content.length}\u0000'))
      ..add(content)
      ..close();
    return _GitObject(type, content, sink.value);
  }

  static List<int> _pktLine(String line) {
    final data = utf8.encode(line);
    return <int>[...ascii.encode((data.length + 4).toRadixString(16).padLeft(4, '0')), ...data];
  }

  static List<String> _pktLines(List<int> bytes) {
    final lines = <String>[];
    var i = 0;
    while (i + 4 <= bytes.length) {
      final length = int.tryParse(
        ascii.decode(bytes.sublist(i, i + 4), allowInvalid: true),
        radix: 16,
      );
      if (length == null) break;
      if (length < 4) {
        i += 4;
        continue;
      }
      if (i + length > bytes.length) break;
      var payload = bytes.sublist(i + 4, i + length);
      // Pita samping: 1 = isi, 2 = kemajuan, 3 = galat.
      if (payload.isNotEmpty && payload.first <= 3) {
        if (payload.first == 1) {
          lines.addAll(_pktLines(payload.sublist(1)));
        } else if (payload.first == 3) {
          lines.add('unpack ${utf8.decode(payload.sublist(1), allowMalformed: true).trim()}');
        }
      } else {
        lines.add(utf8.decode(payload, allowMalformed: true).trim());
      }
      i += length;
    }
    return lines;
  }

  /// Satu objek dalam paket git versi 2, tanpa delta: kepala jenis dan
  /// ukuran, lalu isinya dipadatkan zlib.
  static void _emitObject(_GitObject object, void Function(List<int>) emit) {
    final type = switch (object.type) {
      'commit' => 1,
      'tree' => 2,
      _ => 3,
    };
    var size = object.content.length;
    final header = <int>[];
    var byte = (type << 4) | (size & 0x0f);
    size >>= 4;
    while (size > 0) {
      header.add(byte | 0x80);
      byte = size & 0x7f;
      size >>= 7;
    }
    header.add(byte);
    emit(header);
    emit(zlib.encode(object.content));
  }

  static List<int> _uint32(int value) => <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];

  static String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// Creates a tree on top of [baseTreeSha]; only [entries] are changed.
  ///
  /// A null `sha` in an entry deletes that path.
  Future<String> createTree(String baseTreeSha, List<Map<String, dynamic>> entries) async {
    final response = await _post(_uri('/git/trees'), <String, dynamic>{
      'base_tree': baseTreeSha,
      'tree': entries,
    });
    return (jsonDecode(response.body) as Map<String, dynamic>)['sha'] as String;
  }

  Future<String> createCommit({
    required String message,
    required String treeSha,
    required String parentSha,
    String? authorName,
    String? authorEmail,
  }) async {
    final response = await _post(_uri('/git/commits'), <String, dynamic>{
      'message': message,
      'tree': treeSha,
      'parents': <String>[parentSha],
      if ((authorName ?? '').isNotEmpty && (authorEmail ?? '').isNotEmpty)
        'author': <String, String>{'name': authorName!, 'email': authorEmail!},
    });
    return (jsonDecode(response.body) as Map<String, dynamic>)['sha'] as String;
  }

  /// Moves `refs/heads/<branch>` to [commitSha]. Never forces.
  Future<void> updateRef({required String branch, required String commitSha}) => _patch(
    _uri('/git/refs/heads/${Uri.encodeComponent(branch)}'),
    <String, dynamic>{'sha': commitSha, 'force': false},
  );

  /// The commit a tree belongs to, used to build the next commit.
  Future<String> treeShaOfCommit(String commitSha) async {
    final response = await _get(_uri('/git/commits/$commitSha'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['tree'] as Map<String, dynamic>)['sha'] as String;
  }

  /// Number of commits on [branch] that come after [sinceSha].
  Future<int> commitsAhead({required String branch, required String sinceSha}) async {
    final response = await _get(_uri('/compare/$sinceSha...${Uri.encodeComponent(branch)}'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['ahead_by'] as num?)?.toInt() ?? 0;
  }

  // ---------------------------------------------------------------- internals

  Future<http.Response> _get(Uri uri, {String accept = 'application/vnd.github+json'}) =>
      _send(() => _client.get(uri, headers: _headers(accept: accept)), uri);

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body, {Duration? timeoutOverride}) =>
      _send(
        () => _client.post(uri, headers: _headers(), body: jsonEncode(body)),
        uri,
        timeoutOverride: timeoutOverride,
      );

  Future<http.Response> _patch(Uri uri, Map<String, dynamic> body) =>
      _send(() => _client.patch(uri, headers: _headers(), body: jsonEncode(body)), uri);

  /// Runs one request with a timeout, retrying the failures that are worth it.
  ///
  /// A write that GitHub rejected is never retried: only transport faults and
  /// server-side hiccups are, so a commit is not applied twice.
  Future<http.Response> _send(
    Future<http.Response> Function() attempt,
    Uri uri, {
    Duration? timeoutOverride,
  }) async {
    final limit = timeoutOverride ?? timeout;
    Object? lastError;
    for (var tries = 1; tries <= maxAttempts; tries++) {
      try {
        final response = await attempt().timeout(limit);
        // Batas kecepatan sekunder: GitHub menahan tulisan yang datang
        // beruntun — ratusan berkas satu per satu, misalnya — dengan 403 atau
        // 429 dan memberi tahu berapa lama harus menunggu. Itu bukan penolakan;
        // menunggu sebentar lalu mencoba lagi memang jawabannya.
        final wait = _rateLimitWait(response);
        if (wait != null && tries < maxAttempts) {
          await Future<void>.delayed(wait);
          continue;
        }
        if (_isRetryableStatus(response.statusCode) && tries < maxAttempts) {
          await Future<void>.delayed(_backoff(tries));
          continue;
        }
        return _check(response, uri);
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      }
      if (tries < maxAttempts) await Future<void>.delayed(_backoff(tries));
    }
    throw GitFailure(l10n.syncErrConnectionLost(maxAttempts), details: '${uri.path} — $lastError');
  }

  /// Lama menunggu yang diminta GitHub, kalau jawaban ini batas kecepatan
  /// sekunder; `null` kalau bukan. Dibatasi satu menit supaya pengiriman
  /// tidak tampak macet tanpa sebab.
  static Duration? _rateLimitWait(http.Response response) {
    if (response.statusCode != 403 && response.statusCode != 429) return null;
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    final secondary = _isSecondaryLimit(response);
    if (retryAfter == null && !secondary) return null;
    final seconds = (retryAfter ?? 30).clamp(1, 60);
    return Duration(seconds: seconds);
  }

  static bool _isSecondaryLimit(http.Response response) =>
      response.body.toLowerCase().contains('secondary rate limit');

  static bool _isRetryableStatus(int code) => code >= 500 || code == 429 || code == 408;

  static Duration _backoff(int attempt) => Duration(milliseconds: 400 * attempt * attempt);

  http.Response _check(http.Response response, Uri uri) {
    final remaining = response.headers['x-ratelimit-remaining'];
    if (remaining != null) rateLimitRemaining = int.tryParse(remaining);

    if (response.statusCode >= 200 && response.statusCode < 300) return response;

    throw GitFailure(
      _message(response),
      details: '${uri.path} → ${response.statusCode}',
      exitCode: response.statusCode,
    );
  }

  String _message(http.Response response) {
    final remaining = response.headers['x-ratelimit-remaining'];
    switch (response.statusCode) {
      case 401:
        return l10n.syncErrTokenRejected;
      case 403:
        if (remaining == '0') {
          return l10n.syncErrQuota;
        }
        if (_isSecondaryLimit(response) || response.headers['retry-after'] != null) {
          return l10n.syncErrSlowDown;
        }
        return l10n.syncErrForbidden;
      case 404:
        return l10n.syncErrNotFound;
      case 409:
        return l10n.syncErrBranchMoved;
      case 422:
        // Dulu di sini tertulis "kemungkinan branch sudah bergerak, tarik
        // perubahan dulu" — sebuah tebakan, dan tebakan yang mahal. 422 juga
        // dipakai GitHub untuk menolak berkas yang terlalu besar, dan yang
        // membacanya lalu menarik perubahan berulang kali tanpa pernah bisa
        // berhasil. Sekarang alasan GitHub sendiri yang ditampilkan.
        final reason = _reasonFrom(response);
        return reason.isEmpty ? l10n.syncErrRejectedNoReason : l10n.syncErrRejected(reason);
      default:
        final reason = _reasonFrom(response);
        return reason.isEmpty
            ? l10n.syncErrStatus(response.statusCode)
            : l10n.syncErrStatusReason(response.statusCode, reason);
    }
  }

  /// Alasan yang ditulis GitHub sendiri di badan jawabannya.
  ///
  /// Bentuknya `{"message": "...", "errors": [{"message": "..."}]}`, dan yang
  /// di dalam `errors` biasanya lebih tepat menyebut apa yang salah.
  static String _reasonFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is! Map) return '';
      final errors = body['errors'];
      if (errors is List) {
        for (final error in errors) {
          if (error is Map && error['message'] is String) {
            return (error['message'] as String).trim();
          }
        }
      }
      final message = body['message'];
      return message is String ? message.trim() : '';
    } on FormatException {
      return '';
    }
  }
}

class _GitObject {
  const _GitObject(this.type, this.content, this.id);

  final String type;
  final List<int> content;
  final Digest id;
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
