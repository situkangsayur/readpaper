import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/l10n.dart';

/// Masuk ke GitHub tanpa membuat token sendiri: OAuth Device Flow, cara yang
/// sama dengan `gh auth login`.
///
/// Aplikasi meminta kode singkat, pengguna membuka github.com/login/device dan
/// memasukkannya, lalu aplikasi menerima token akses. Tokennya disimpan sama
/// seperti token yang diketik tangan (credentials.json), jadi seluruh jalur
/// sinkronisasi tidak berubah.
///
/// Client ID milik OAuth App "ReadPaper" (didaftarkan di akun pengembang,
/// Device Flow dinyalakan). Client ID memang publik; tidak ada client secret
/// di aplikasi, dan Device Flow tidak membutuhkannya.
class GitHubDeviceFlow {
  GitHubDeviceFlow({http.Client? client, this.clientId = defaultClientId})
    : _client = client ?? http.Client();

  static const String defaultClientId = 'Ov23liUSe8XukSHIBi34';

  /// `repo`: membaca dan menulis repositori (juga yang privat) dan membuat
  /// repositori baru — persis yang dibutuhkan sinkronisasi library.
  static const String scope = 'repo';

  final String clientId;
  final http.Client _client;

  static const Map<String, String> _json = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  /// Langkah 1: kode untuk dimasukkan pengguna di [DeviceCode.verificationUri].
  Future<DeviceCode> start() async {
    final res = await _client.post(
      Uri.parse('https://github.com/login/device/code'),
      headers: _json,
      body: jsonEncode(<String, String>{'client_id': clientId, 'scope': scope}),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['device_code'] == null) {
      throw GitHubLoginFailure(_describe(body, res.statusCode));
    }
    return DeviceCode(
      deviceCode: body['device_code'] as String,
      userCode: body['user_code'] as String,
      verificationUri: body['verification_uri'] as String? ?? 'https://github.com/login/device',
      expiresIn: Duration(seconds: (body['expires_in'] as num?)?.toInt() ?? 900),
      interval: Duration(seconds: (body['interval'] as num?)?.toInt() ?? 5),
    );
  }

  /// Langkah 2: menunggu pengguna menyetujui, lalu mengembalikan token akses.
  ///
  /// Mengikuti aturan GitHub: bertanya tiap [DeviceCode.interval], memperlambat
  /// bila diminta (`slow_down`), dan berhenti bila kodenya kedaluwarsa,
  /// ditolak, atau [cancelled] menjadi benar.
  Future<String> waitForToken(
    DeviceCode code, {
    bool Function()? cancelled,
    Future<void> Function(Duration)? sleep,
  }) async {
    final wait = sleep ?? (d) => Future<void>.delayed(d);
    var interval = code.interval;
    final deadline = DateTime.now().add(code.expiresIn);
    while (DateTime.now().isBefore(deadline)) {
      await wait(interval);
      if (cancelled?.call() ?? false) throw const GitHubLoginCancelled();
      final res = await _client.post(
        Uri.parse('https://github.com/login/oauth/access_token'),
        headers: _json,
        body: jsonEncode(<String, String>{
          'client_id': clientId,
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        }),
      );
      final body = _decode(res);
      final token = body['access_token'];
      if (token is String && token.isNotEmpty) return token;
      switch (body['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += const Duration(seconds: 5);
          continue;
        case 'expired_token':
          throw GitHubLoginFailure(l10n.githubLoginExpired);
        case 'access_denied':
          throw GitHubLoginFailure(l10n.githubLoginDenied);
        default:
          throw GitHubLoginFailure(_describe(body, res.statusCode));
      }
    }
    throw GitHubLoginFailure(l10n.githubLoginExpired);
  }

  /// Akun pemilik token: nama login, nama tampilan, dan surel untuk commit.
  Future<GitHubAccount> account(String token) async {
    final res = await _client.get(Uri.parse('https://api.github.com/user'), headers: _api(token));
    final body = _decode(res);
    if (res.statusCode != 200) throw GitHubLoginFailure(_describe(body, res.statusCode));
    final login = body['login'] as String;
    final id = (body['id'] as num?)?.toInt() ?? 0;
    final email = body['email'] as String?;
    return GitHubAccount(
      login: login,
      name: (body['name'] as String?)?.trim().isNotEmpty ?? false ? body['name'] as String : login,
      // Surel publik bila ada; kalau tidak, alamat noreply GitHub — yang
      // memang dipakai GitHub untuk mengaitkan commit ke akunnya.
      email: email ?? '$id+$login@users.noreply.github.com',
    );
  }

  /// Repositori yang bisa ditulisi akun ini, yang terakhir diubah lebih dulu.
  Future<List<GitHubRepoInfo>> repositories(String token) async {
    final out = <GitHubRepoInfo>[];
    for (var page = 1; page <= 5; page++) {
      final res = await _client.get(
        Uri.parse(
          'https://api.github.com/user/repos?per_page=100&page=$page&sort=updated'
          '&affiliation=owner,collaborator,organization_member',
        ),
        headers: _api(token),
      );
      if (res.statusCode != 200) {
        throw GitHubLoginFailure(_describe(_decode(res), res.statusCode));
      }
      final list = jsonDecode(res.body) as List<dynamic>;
      for (final entry in list.cast<Map<String, dynamic>>()) {
        final perms = entry['permissions'] as Map<String, dynamic>?;
        if (perms != null && perms['push'] != true) continue;
        out.add(GitHubRepoInfo.fromJson(entry));
      }
      if (list.length < 100) break;
    }
    return out;
  }

  /// Membuat repositori baru di akun ini, sudah berisi README supaya bisa
  /// langsung di-clone.
  Future<GitHubRepoInfo> createRepository(
    String token, {
    required String name,
    bool private = true,
  }) async {
    final res = await _client.post(
      Uri.parse('https://api.github.com/user/repos'),
      headers: _api(token),
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'private': private,
        'auto_init': true,
        'description': 'Library Zotero untuk ReadPaper',
      }),
    );
    final body = _decode(res);
    if (res.statusCode != 201) {
      throw GitHubLoginFailure(
        res.statusCode == 422 ? l10n.githubRepoNameTaken(name) : _describe(body, res.statusCode),
      );
    }
    return GitHubRepoInfo.fromJson(body);
  }

  void close() => _client.close();

  static Map<String, String> _api(String token) => <String, String>{
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $token',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static String _describe(Map<String, dynamic> body, int status) {
    final detail = body['error_description'] ?? body['message'] ?? body['error'];
    return l10n.githubLoginFailed(detail?.toString() ?? 'HTTP $status');
  }
}

class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final Duration expiresIn;
  final Duration interval;
}

class GitHubAccount {
  const GitHubAccount({required this.login, required this.name, required this.email});

  final String login;
  final String name;
  final String email;
}

class GitHubRepoInfo {
  const GitHubRepoInfo({
    required this.fullName,
    required this.name,
    required this.private,
    required this.defaultBranch,
    required this.cloneUrl,
  });

  factory GitHubRepoInfo.fromJson(Map<String, dynamic> json) => GitHubRepoInfo(
    fullName: json['full_name'] as String,
    name: json['name'] as String,
    private: json['private'] as bool? ?? false,
    defaultBranch: json['default_branch'] as String? ?? 'main',
    cloneUrl: json['clone_url'] as String? ?? 'https://github.com/${json['full_name']}.git',
  );

  final String fullName;
  final String name;
  final bool private;
  final String defaultBranch;
  final String cloneUrl;
}

class GitHubLoginFailure implements Exception {
  const GitHubLoginFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class GitHubLoginCancelled implements Exception {
  const GitHubLoginCancelled();
}
