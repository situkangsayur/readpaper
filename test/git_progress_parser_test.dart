import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/sync/domain/entities/sync_progress.dart';

void main() {
  group('GitProgressParser', () {
    test('reads percentage, counts and transfer rate from a clone', () {
      final progress = GitProgressParser.parse(
        'Receiving objects:  45% (1234/2700), 120.50 MiB | 3.20 MiB/s',
      );

      expect(progress.isMeasurable, isTrue);
      expect(progress.percent, 45);
      expect(progress.current, 1234);
      expect(progress.total, 2700);
      expect(progress.detail, '120.50 MiB | 3.20 MiB/s');
      expect(progress.message, 'Mengunduh objek');
      expect(progress.label, 'Mengunduh objek 45% (1234/2700) · 120.50 MiB | 3.20 MiB/s');
    });

    test('handles the phases git reports during a clone', () {
      expect(
        GitProgressParser.parse('remote: Counting objects: 100% (500/500), done.').message,
        'Menghitung objek',
      );
      expect(GitProgressParser.parse('Resolving deltas:  12% (100/800)').message, 'Menyusun delta');
      expect(GitProgressParser.parse('Updating files:  90% (3300/3684)').message, 'Menulis berkas');
      expect(GitProgressParser.parse('Writing objects:  50% (3/6)').message, 'Mengirim objek');
    });

    test('drops the trailing "done" so the label stays clean', () {
      final progress = GitProgressParser.parse('Resolving deltas: 100% (800/800), done.');
      expect(progress.detail, isNull);
      expect(progress.label, 'Menyusun delta 100% (800/800)');
    });

    test('keeps an unknown phase name as git wrote it', () {
      expect(GitProgressParser.parse('Sideband stuff:  10% (1/10)').message, 'Sideband stuff');
    });

    test('lines without a percentage stay unmeasurable', () {
      final progress = GitProgressParser.parse("Cloning into 'zotero-hendri'...");
      expect(progress.isMeasurable, isFalse);
      expect(progress.fraction, isNull);
      expect(progress.label, "Cloning into 'zotero-hendri'...");
    });

    test('a percentage without counts is still not mistaken for progress', () {
      // git only reports a fraction together with counts; anything else is log
      // output and must not drive the progress bar.
      expect(GitProgressParser.parse('done. 100%').isMeasurable, isFalse);
    });
  });
}
