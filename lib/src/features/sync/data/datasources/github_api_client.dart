import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/errors/failure.dart';

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
  GitHubApiClient({required this.ref, required this.token, http.Client? client})
    : _client = client ?? http.Client();

  final GitHubRepoRef ref;
  final String? token;
  final http.Client _client;

  /// Remaining requests reported by the last response, when known.
  int? rateLimitRemaining;

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
      throw const GitFailure(
        'Daftar berkas repositori terlalu besar untuk dibaca sekaligus oleh API GitHub.',
      );
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

  Future<String> createBlob(List<int> content) async {
    final response = await _post(_uri('/git/blobs'), <String, dynamic>{
      'content': base64Encode(content),
      'encoding': 'base64',
    });
    return (jsonDecode(response.body) as Map<String, dynamic>)['sha'] as String;
  }

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

  Future<http.Response> _get(Uri uri, {String accept = 'application/vnd.github+json'}) async {
    final response = await _client.get(uri, headers: _headers(accept: accept));
    return _check(response, uri);
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body) async {
    final response = await _client.post(uri, headers: _headers(), body: jsonEncode(body));
    return _check(response, uri);
  }

  Future<http.Response> _patch(Uri uri, Map<String, dynamic> body) async {
    final response = await _client.patch(uri, headers: _headers(), body: jsonEncode(body));
    return _check(response, uri);
  }

  http.Response _check(http.Response response, Uri uri) {
    final remaining = response.headers['x-ratelimit-remaining'];
    if (remaining != null) rateLimitRemaining = int.tryParse(remaining);

    if (response.statusCode >= 200 && response.statusCode < 300) return response;

    throw GitFailure(_message(response), details: '${uri.path} → ${response.statusCode}');
  }

  String _message(http.Response response) {
    final remaining = response.headers['x-ratelimit-remaining'];
    switch (response.statusCode) {
      case 401:
        return 'Token GitHub ditolak. Periksa token di profil repositori.';
      case 403:
        if (remaining == '0') {
          return 'Kuota permintaan GitHub habis. Coba lagi setelah kuota pulih '
              '(sekitar satu jam), atau pakai token dengan kuota lebih besar.';
        }
        return 'Akses ditolak. Token perlu izin "Contents: read and write" untuk repositori ini.';
      case 404:
        return 'Repositori atau berkas tidak ditemukan. Untuk repositori privat, '
            'token harus punya akses ke repositori tersebut.';
      case 409:
        return 'Branch di GitHub sudah berubah. Tarik perubahan dulu, lalu kirim ulang.';
      case 422:
        return 'GitHub menolak perubahan (kemungkinan branch sudah bergerak). '
            'Tarik perubahan dulu, lalu kirim ulang.';
      default:
        return 'GitHub membalas dengan kode ${response.statusCode}.';
    }
  }
}
