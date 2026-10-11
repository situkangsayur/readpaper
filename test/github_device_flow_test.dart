import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_device_flow.dart';

void main() {
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );

  const code = DeviceCode(
    deviceCode: 'DEV',
    userCode: 'ABCD-1234',
    verificationUri: 'https://github.com/login/device',
    expiresIn: Duration(minutes: 15),
    interval: Duration(seconds: 5),
  );

  test('kode perangkat diminta dengan client ID dan cakupan repo', () async {
    late Map<String, dynamic> sent;
    final flow = GitHubDeviceFlow(
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://github.com/login/device/code');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return json(<String, dynamic>{
          'device_code': 'DEV',
          'user_code': 'ABCD-1234',
          'verification_uri': 'https://github.com/login/device',
          'expires_in': 900,
          'interval': 5,
        });
      }),
    );
    final c = await flow.start();
    expect(sent, <String, String>{'client_id': GitHubDeviceFlow.defaultClientId, 'scope': 'repo'});
    expect(c.userCode, 'ABCD-1234');
    expect(c.interval, const Duration(seconds: 5));
  });

  test('menunggu, diperlambat bila diminta, lalu menerima token', () async {
    final answers = <Map<String, dynamic>>[
      <String, dynamic>{'error': 'authorization_pending'},
      <String, dynamic>{'error': 'slow_down'},
      <String, dynamic>{'access_token': 'gho_rahasia', 'token_type': 'bearer'},
    ];
    final waits = <Duration>[];
    final flow = GitHubDeviceFlow(client: MockClient((req) async => json(answers.removeAt(0))));
    final token = await flow.waitForToken(code, sleep: (d) async => waits.add(d));
    expect(token, 'gho_rahasia');
    expect(waits, <Duration>[
      const Duration(seconds: 5),
      const Duration(seconds: 5),
      const Duration(seconds: 10),
    ]);
  });

  test('kode kedaluwarsa dan akses ditolak menjadi pesan yang jelas', () async {
    for (final error in <String>['expired_token', 'access_denied']) {
      final flow = GitHubDeviceFlow(
        client: MockClient((req) async => json(<String, dynamic>{'error': error})),
      );
      await expectLater(
        flow.waitForToken(code, sleep: (_) async {}),
        throwsA(isA<GitHubLoginFailure>()),
      );
    }
  });

  test('dibatalkan selagi menunggu', () async {
    final flow = GitHubDeviceFlow(
      client: MockClient((req) async => json(<String, dynamic>{'error': 'authorization_pending'})),
    );
    await expectLater(
      flow.waitForToken(code, sleep: (_) async {}, cancelled: () => true),
      throwsA(isA<GitHubLoginCancelled>()),
    );
  });

  test('akun tanpa surel publik memakai alamat noreply GitHub', () async {
    final flow = GitHubDeviceFlow(
      client: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer gho_x');
        return json(<String, dynamic>{
          'login': 'situkangsayur',
          'id': 42,
          'name': null,
          'email': null,
        });
      }),
    );
    final a = await flow.account('gho_x');
    expect(a.login, 'situkangsayur');
    expect(a.name, 'situkangsayur');
    expect(a.email, '42+situkangsayur@users.noreply.github.com');
  });

  test('daftar repo: hanya yang bisa ditulisi, dan halaman berikutnya diikuti', () async {
    Map<String, dynamic> repo(int i, {bool push = true}) => <String, dynamic>{
      'full_name': 'u/r$i',
      'name': 'r$i',
      'private': i.isEven,
      'default_branch': 'main',
      'clone_url': 'https://github.com/u/r$i.git',
      'permissions': <String, bool>{'push': push},
    };
    final pages = <String>[];
    final flow = GitHubDeviceFlow(
      client: MockClient((req) async {
        final page = req.url.queryParameters['page']!;
        pages.add(page);
        if (page == '1') {
          return json(<Map<String, dynamic>>[for (var i = 0; i < 100; i++) repo(i, push: i != 3)]);
        }
        return json(<Map<String, dynamic>>[repo(100)]);
      }),
    );
    final repos = await flow.repositories('gho_x');
    expect(pages, <String>['1', '2']);
    expect(repos, hasLength(100));
    expect(repos.map((r) => r.fullName), isNot(contains('u/r3')));
    expect(repos.last.cloneUrl, 'https://github.com/u/r100.git');
  });

  test('membuat repo privat ber-README; nama yang sudah ada dijelaskan', () async {
    late Map<String, dynamic> sent;
    final ok = GitHubDeviceFlow(
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return json(<String, dynamic>{
          'full_name': 'u/zotero-library',
          'name': 'zotero-library',
          'private': true,
          'default_branch': 'main',
          'clone_url': 'https://github.com/u/zotero-library.git',
        }, 201);
      }),
    );
    final created = await ok.createRepository('gho_x', name: 'zotero-library');
    expect(sent['private'], isTrue);
    expect(sent['auto_init'], isTrue);
    expect(created.cloneUrl, 'https://github.com/u/zotero-library.git');

    final taken = GitHubDeviceFlow(
      client: MockClient(
        (req) async => json(<String, dynamic>{'message': 'name already exists'}, 422),
      ),
    );
    await expectLater(
      taken.createRepository('gho_x', name: 'zotero-library'),
      throwsA(
        isA<GitHubLoginFailure>().having((e) => e.message, 'message', contains('zotero-library')),
      ),
    );
  });
}
