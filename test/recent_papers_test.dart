import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/formatting.dart';
import 'package:readpaper/src/features/settings/domain/entities/repo_profile.dart';

RecentPaper paper(String path, {String profile = 'p1', int page = 1, DateTime? at}) => RecentPaper(
  profileId: profile,
  itemKey: 'ITEM',
  itemFilePath: '/repo/items/ITEM.json',
  attachmentKey: 'ATT',
  filePath: path,
  title: 'Judul',
  lastPage: page,
  openedAt: at ?? DateTime(2026, 9, 25, 12),
);

void main() {
  group('history', () {
    test('reopening a paper moves it to the front instead of duplicating it', () {
      var settings = const AppSettings()
          .withRecent(paper('/a.pdf'))
          .withRecent(paper('/b.pdf'))
          .withRecent(paper('/a.pdf', page: 12));

      expect(settings.recents.length, 2);
      expect(settings.recents.first.filePath, '/a.pdf');
      expect(settings.recents.first.lastPage, 12);
      expect(settings.recents.last.filePath, '/b.pdf');

      settings = settings.withRecent(paper('/b.pdf'));
      expect(settings.recents.map((r) => r.filePath), <String>['/b.pdf', '/a.pdf']);
    });

    test('the same path in another library is a different paper', () {
      final settings = const AppSettings()
          .withRecent(paper('/a.pdf'))
          .withRecent(paper('/a.pdf', profile: 'p2'));
      expect(settings.recents.length, 2);
    });

    test('the list is capped so config.json cannot grow without end', () {
      var settings = const AppSettings();
      for (var i = 0; i < AppSettings.maxRecents + 15; i++) {
        settings = settings.withRecent(paper('/paper$i.pdf'));
      }
      expect(settings.recents.length, AppSettings.maxRecents);
      // The newest survives, the oldest is dropped.
      expect(settings.recents.first.filePath, '/paper${AppSettings.maxRecents + 14}.pdf');
      expect(settings.recents.any((r) => r.filePath == '/paper0.pdf'), isFalse);
    });

    test('forgetting a profile removes only its own history', () {
      final settings = const AppSettings()
          .withRecent(paper('/a.pdf'))
          .withRecent(paper('/b.pdf', profile: 'p2'))
          .withoutRecentsOf('p1');
      expect(settings.recents.map((r) => r.filePath), <String>['/b.pdf']);
    });

    test('lookup is by library and path together', () {
      final settings = const AppSettings().withRecent(paper('/a.pdf', page: 9));
      expect(settings.recentFor(profileId: 'p1', filePath: '/a.pdf')?.lastPage, 9);
      expect(settings.recentFor(profileId: 'p2', filePath: '/a.pdf'), isNull);
      expect(settings.recentFor(profileId: 'p1', filePath: '/z.pdf'), isNull);
    });

    test('survives a round trip through JSON', () {
      final settings = const AppSettings().withRecent(paper('/a.pdf', page: 33));
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.recents.length, 1);
      expect(restored.recents.first.filePath, '/a.pdf');
      expect(restored.recents.first.lastPage, 33);
      expect(restored.recents.first.openedAt, DateTime(2026, 9, 25, 12));
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 9, 25, 12);
    String ago(Duration d) => relativeTime(now.subtract(d), now: now);

    test('reads the way someone would say it', () {
      expect(ago(const Duration(seconds: 20)), 'baru saja');
      expect(ago(const Duration(minutes: 5)), '5 menit lalu');
      expect(ago(const Duration(hours: 3)), '3 jam lalu');
      expect(ago(const Duration(days: 1)), 'kemarin');
      expect(ago(const Duration(days: 3)), '3 hari lalu');
      expect(ago(const Duration(days: 10)), '1 pekan lalu');
      expect(ago(const Duration(days: 60)), '2 bulan lalu');
      expect(ago(const Duration(days: 400)), '1 tahun lalu');
    });

    test('a clock that jumped backwards does not print a negative age', () {
      expect(relativeTime(now.add(const Duration(hours: 2)), now: now), 'baru saja');
    });
  });
}
