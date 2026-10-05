import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/citation/presentation/controllers/citation_server_controller.dart';
import 'package:readpaper/src/features/settings/domain/entities/repo_profile.dart';
import 'package:readpaper/src/features/sync/domain/entities/git_entities.dart';
import 'package:readpaper/src/features/settings/presentation/screens/profiles_screen.dart';
import 'package:readpaper/src/features/workspace/domain/entities/workspace_state.dart';
import 'package:readpaper/src/features/workspace/presentation/controllers/workspace_controller.dart';

class _FakeWorkspace extends WorkspaceController {
  _FakeWorkspace(this._state);

  final WorkspaceState _state;

  @override
  WorkspaceState build() => _state;
}

class _FakeCitationServer extends CitationServerController {
  @override
  CitationServerStatus build() => const CitationServerStatus(
    available: true,
    enabled: true,
    running: true,
    token: 'tokenrahasiauntukwordyangpanjangsekali',
  );
}

/// Layar Repositori pernah tampak kosong di semua platform: footer versinya
/// mengambil seluruh tinggi layar, sehingga daftar profil dan tombol tambah
/// tertutup — dan repositori tidak bisa disunting maupun ditambah.
void main() {
  testWidgets('profil dan tombol tambah terlihat dan bisa diketuk', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const profile = RepoProfile(
      id: 'p1',
      name: 'zotero-hendri',
      remoteUrl: 'https://github.com/situkangsayur/zotero-hendri.git',
      localPath: '/tmp/uji/zotero-hendri',
      transport: GitTransport.https,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceControllerProvider.overrideWith(
            () => _FakeWorkspace(
              const WorkspaceState(
                settings: AppSettings(profiles: <RepoProfile>[profile], activeProfileId: 'p1'),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfilesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('zotero-hendri').hitTestable(), findsOneWidget);
    expect(find.text('Tambah repositori').hitTestable(), findsOneWidget);
    final footer = tester.getRect(find.textContaining('lisensi AGPL'));
    expect(footer.top, greaterThan(600), reason: 'footer versi di bawah, bukan memenuhi layar');
  });

  testWidgets('kartu sitasi menyamarkan token sampai diminta', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceControllerProvider.overrideWith(() => _FakeWorkspace(const WorkspaceState())),
          citationServerProvider.overrideWith(_FakeCitationServer.new),
        ],
        child: const MaterialApp(home: ProfilesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sitasi di Word & OnlyOffice'), findsOneWidget);
    expect(find.text('Berjalan di http://127.0.0.1:23121'), findsOneWidget);
    expect(find.textContaining('tokenrahasia'), findsNothing);
    await tester.tap(find.byTooltip('Tampilkan token'));
    await tester.pump();
    expect(find.text('tokenrahasiauntukwordyangpanjangsekali'), findsOneWidget);
  });
}
