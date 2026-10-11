import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:readpaper/src/core/l10n.dart';
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:readpaper/src/features/settings/presentation/widgets/github_login_dialog.dart';
import 'package:readpaper/src/features/settings/presentation/widgets/profile_editor_dialog.dart';
import 'package:readpaper/src/features/sync/data/datasources/github_device_flow.dart';

/// GitHub tiruan: kode perangkat, persetujuan seketika, akun, dan dua repo.
GitHubDeviceFlow fakeGitHub(List<String> calls) => GitHubDeviceFlow(
  client: MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);
    switch (req.url.path) {
      case '/login/device/code':
        return json(<String, dynamic>{
          'device_code': 'DEV',
          'user_code': 'WDJB-MJHT',
          'verification_uri': 'https://github.com/login/device',
          'expires_in': 900,
          'interval': 0,
        });
      case '/login/oauth/access_token':
        return json(<String, dynamic>{'access_token': 'gho_uji'});
      case '/user':
        return json(<String, dynamic>{
          'login': 'situkangsayur',
          'id': 7,
          'name': 'Hendri Karisma',
          'email': null,
        });
      case '/user/repos':
        Map<String, dynamic> repo(String name) => <String, dynamic>{
          'full_name': 'situkangsayur/$name',
          'name': name,
          'private': true,
          'default_branch': 'main',
          'clone_url': 'https://github.com/situkangsayur/$name.git',
          'permissions': <String, bool>{'push': true},
        };
        return json(<Map<String, dynamic>>[repo('zotero-hendri'), repo('zotero-lab')]);
    }
    return json(<String, dynamic>{'message': 'tidak dikenal'}, 404);
  }),
);

void main() {
  late Directory data;

  setUp(() {
    data = Directory.systemTemp.createTempSync('rp_github_');
    AppPaths.debugOverride(data);
  });

  tearDown(() => data.deleteSync(recursive: true));

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('id'),
          home: Scaffold(body: ProfileEditorDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Waktu nyata untuk berkas dan HTTP tiruan, lalu beberapa frame. Bukan
  /// pumpAndSettle: indikator putar dialog tidak pernah "tenang".
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String field(WidgetTester tester, String label) =>
      tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

  testWidgets('masuk pertama: kode, pilih repo, profil terisi, akun diingat', (tester) async {
    final calls = <String>[];
    createGitHubDeviceFlow = () => fakeGitHub(calls);
    addTearDown(() => createGitHubDeviceFlow = GitHubDeviceFlow.new);
    await pumpEditor(tester);

    await tester.tap(find.text('Masuk dengan GitHub').first);
    await settle(tester);
    expect(find.text('Masuk sebagai situkangsayur'), findsOneWidget);
    expect(calls, contains('POST /login/device/code'));

    await tester.tap(find.text('situkangsayur/zotero-lab'));
    await settle(tester);

    expect(field(tester, 'URL repositori'), 'https://github.com/situkangsayur/zotero-lab.git');
    expect(field(tester, 'Nama tampilan'), 'zotero-lab');
    expect(field(tester, 'Username GitHub'), 'situkangsayur');
    expect(field(tester, 'Personal access token'), 'gho_uji');
    expect(field(tester, 'Nama'), 'Hendri Karisma');
    expect(field(tester, 'Email'), '7+situkangsayur@users.noreply.github.com');

    final known = await tester.runAsync(() => const SettingsLocalDataSource().githubAccounts());
    expect(known, <String, String>{'situkangsayur': 'gho_uji'});
  });

  testWidgets('profil berikutnya memakai akun yang diingat tanpa kode baru', (tester) async {
    await tester.runAsync(
      () => const SettingsLocalDataSource().saveGitHubAccount(
        login: 'situkangsayur',
        token: 'gho_lama',
      ),
    );
    final calls = <String>[];
    createGitHubDeviceFlow = () => fakeGitHub(calls);
    addTearDown(() => createGitHubDeviceFlow = GitHubDeviceFlow.new);
    await pumpEditor(tester);

    await tester.tap(find.text('Masuk dengan GitHub').first);
    await settle(tester);
    expect(find.text('Pakai akun situkangsayur'), findsOneWidget);
    expect(find.text('Masuk dengan akun lain'), findsOneWidget);

    await tester.tap(find.text('Pakai akun situkangsayur'));
    await settle(tester);
    await tester.tap(find.text('situkangsayur/zotero-hendri'));
    await settle(tester);

    expect(calls, isNot(contains('POST /login/device/code')), reason: 'tidak perlu kode lagi');
    expect(field(tester, 'URL repositori'), 'https://github.com/situkangsayur/zotero-hendri.git');
    expect(field(tester, 'Personal access token'), 'gho_lama');
  });
}
