import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/presenter/data/audience_link.dart';
import 'package:readpaper/src/features/presenter/data/presenter_notes_store.dart';
import 'package:readpaper/src/features/presenter/domain/audience_state.dart';
import 'package:readpaper/src/features/presenter/presentation/laser_pointer.dart';
import 'package:readpaper/src/features/presenter/presentation/presenter_keys.dart';

ZoteroAnnotation _ink(int pageIndex) => ZoteroAnnotation(
  key: 'ABCD1234',
  parentItemKey: 'ATTACH01',
  type: AnnotationType.ink,
  color: '#ff0000',
  pageIndex: pageIndex,
  paths: const <InkPath>[
    InkPath(<double>[10, 20, 30, 40]),
  ],
  inkWidth: 3,
  pageLabel: '${pageIndex + 1}',
  sortIndex: ZoteroAnnotation.buildSortIndex(
    pageIndex: pageIndex,
    textOffset: 0,
    topFromPageTop: 0,
  ),
  authorName: '',
  dateAdded: DateTime.utc(2026, 10, 12),
  dateModified: DateTime.utc(2026, 10, 12),
);

/// Pesan melewati kanal sebagai JSON, jadi ujinya juga.
Map<String, dynamic> _wire(Map<String, dynamic> message) =>
    (jsonDecode(jsonEncode(message)) as Map).cast<String, dynamic>();

void main() {
  group('AudienceMessage', () {
    test('scene sampai utuh di layar audiens', () {
      final sent = AudienceState(
        path: '/tmp/slide.pdf',
        page: 3,
        annotations: <ZoteroAnnotation>[_ink(2)],
        pending: const <InkPath>[
          InkPath(<double>[1, 2, 3, 4]),
        ],
        pendingColor: '#00ff00',
        pendingWidth: 4,
        tint: 'sepia',
        blank: true,
      );
      final got = AudienceMessage.apply(const AudienceState(), _wire(AudienceMessage.scene(sent)));
      expect(got.path, '/tmp/slide.pdf');
      expect(got.page, 3);
      expect(got.annotations.single.key, 'ABCD1234');
      expect(got.annotations.single.paths.single.points, <double>[10, 20, 30, 40]);
      expect(got.pending.single.points, <double>[1, 2, 3, 4]);
      expect(got.pendingColor, '#00ff00');
      expect(got.pendingWidth, 4);
      expect(got.tint, 'sepia');
      expect(got.blank, isTrue);
    });

    test('goresan yang sedang ditarik tampil, dan hilang saat halaman berganti', () {
      var state = AudienceMessage.apply(
        const AudienceState(path: '/a.pdf'),
        _wire(AudienceMessage.live(points: <double>[1, 2, 3, 4], color: '#123456', width: 5)),
      );
      expect(state.live, <double>[1, 2, 3, 4]);
      expect(state.liveColor, '#123456');
      expect(state.liveWidth, 5);

      // Scene halaman yang sama tidak membuang goresan yang sedang berjalan.
      state = AudienceMessage.apply(
        state,
        _wire(AudienceMessage.scene(const AudienceState(path: '/a.pdf'))),
      );
      expect(state.live, isNotEmpty);

      state = AudienceMessage.apply(
        state,
        _wire(AudienceMessage.scene(const AudienceState(path: '/a.pdf', page: 2))),
      );
      expect(state.page, 2);
      expect(state.live, isEmpty);
    });

    test('gambar tempelan dikirim sebagai base64 dan kembali sama', () {
      final bytes = Uint8List.fromList(<int>[137, 80, 78, 71, 0, 1, 2]);
      final got = AudienceMessage.picturesOf(
        _wire(AudienceMessage.pictures(<String, Uint8List>{'a.png': bytes})),
      );
      expect(got['a.png'], bytes);
    });

    test('pesan close memanggil onClose', () async {
      final controller = AudienceController();
      var closed = false;
      controller.onClose = () => closed = true;
      await controller.handle(_wire(AudienceMessage.close));
      expect(closed, isTrue);
    });
  });

  group('PresenterNotesStore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('presenter-notes'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('menyimpan dan membaca catatan per slide, yang kosong dibuang', () async {
      final store = PresenterNotesStore.forLibrary(repoRoot: dir.path, attachmentKey: 'ATTACH01');
      expect(store.path, p.join(dir.path, 'presenter', 'ATTACH01.json'));
      expect(store.synced, isTrue);
      expect(await store.load(), isEmpty);

      await store.save(<int, String>{1: 'Sapa hadirin', 2: '  ', 10: 'Tanya jawab'});
      expect(await store.load(), <int, String>{1: 'Sapa hadirin', 10: 'Tanya jawab'});
      final json = jsonDecode(File(store.path).readAsStringSync()) as Map;
      expect(json['schema'], 1);
      expect((json['notes'] as Map).keys, <String>['1', '10']);

      await store.save(<int, String>{1: ''});
      expect(File(store.path).existsSync(), isFalse);
    });

    test('PDF catatan menyimpan di folder catatannya', () {
      final store = PresenterNotesStore.forNote(p.join(dir.path, 'catatan', 'anotasi.json'));
      expect(store.path, p.join(dir.path, 'catatan', 'presenter.json'));
    });

    test('PDF lepas disimpan di perangkat, tidak tersinkron', () {
      AppPaths.debugOverride(dir);
      final a = PresenterNotesStore.forLooseFile('/home/x/slide.pdf');
      final b = PresenterNotesStore.forLooseFile('/home/x/../x/slide.pdf');
      expect(a.synced, isFalse);
      expect(a.path, b.path);
      expect(p.isWithin(dir.path, a.path), isTrue);
    });

    test('berkas rusak dibaca sebagai kosong', () async {
      final store = PresenterNotesStore(p.join(dir.path, 'rusak.json'));
      File(store.path).writeAsStringSync('{bukan json');
      expect(await store.load(), isEmpty);
    });
  });

  test('tombol clicker dan keyboard', () {
    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.enter,
    ]) {
      expect(presenterKeyFor(key), PresenterKey.next, reason: key.debugName);
    }
    for (final key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.pageUp,
      LogicalKeyboardKey.backspace,
    ]) {
      expect(presenterKeyFor(key), PresenterKey.previous, reason: key.debugName);
    }
    expect(presenterKeyFor(LogicalKeyboardKey.keyB), PresenterKey.blank);
    expect(presenterKeyFor(LogicalKeyboardKey.period), PresenterKey.blank);
    expect(presenterKeyFor(LogicalKeyboardKey.escape), PresenterKey.exit);
    expect(presenterKeyFor(LogicalKeyboardKey.keyQ), isNull);
  });

  group('LaserPointer', () {
    test('menunjuk, dan pesannya menggerakkan penunjuk di layar audiens', () {
      final presenter = LaserPointer(trail: const Duration(milliseconds: 800))
        ..moveTo(2, const Offset(0.25, 0.5));
      final audience = LaserPointer()..apply(_wire(presenter.toMessage()));
      expect(audience.page, 2);
      expect(audience.head, const Offset(0.25, 0.5));
      expect(audience.trail, const Duration(milliseconds: 800));

      presenter.hide();
      audience.apply(_wire(presenter.toMessage()));
      expect(audience.head, isNull);
    });

    test('buntutnya menua lalu hilang; titik yang diam tetap terlihat', () {
      final pointer = LaserPointer(trail: const Duration(milliseconds: 500))
        ..moveTo(1, const Offset(0.1, 0.1))
        ..moveTo(1, const Offset(0.2, 0.2));
      final now = pointer.now;
      expect(pointer.trailAt(now), hasLength(2));
      final later = pointer.trailAt(now + const Duration(seconds: 2));
      expect(later, hasLength(1), reason: 'titik terakhir tetap menunjuk');
      expect(later.single.at, const Offset(0.2, 0.2));

      pointer.hide();
      expect(pointer.trailAt(now + const Duration(seconds: 3)), isEmpty);
      expect(pointer.isActive, isFalse);
    });

    test('tanpa buntut hanya titiknya', () {
      final pointer = LaserPointer(trail: Duration.zero)
        ..moveTo(1, const Offset(0.1, 0.1))
        ..moveTo(1, const Offset(0.3, 0.3));
      expect(pointer.trailAt(pointer.now + const Duration(milliseconds: 1)), hasLength(1));
    });

    test('pindah halaman membuang buntut halaman lama', () {
      final pointer = LaserPointer()
        ..moveTo(1, const Offset(0.1, 0.1))
        ..moveTo(1, const Offset(0.2, 0.2))
        ..moveTo(2, const Offset(0.5, 0.5));
      expect(pointer.trailAt(pointer.now), hasLength(1));
      expect(pointer.page, 2);
    });
  });
}
