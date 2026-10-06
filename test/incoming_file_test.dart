import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readpaper/src/features/files/data/incoming_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('masuk'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('PDF dari baris perintah desktop dibuka sekali', () async {
    final pdf = File(p.join(dir.path, 'paper satu.pdf'))..writeAsStringSync('%PDF-1.4');
    IncomingFile.fromArguments(<String>['--verbose', pdf.path]);
    expect(await IncomingFile.takeInitial(), pdf.absolute.path);
    expect(await IncomingFile.takeInitial(), isNull);
  });

  test('URI file:// dari pengelola berkas juga diterima', () async {
    final epub = File(p.join(dir.path, 'buku.epub'))..writeAsStringSync('x');
    IncomingFile.fromArguments(<String>[Uri.file(epub.path).toString()]);
    expect(await IncomingFile.takeInitial(), epub.absolute.path);
  });

  test('berkas yang tidak ada atau bukan PDF/EPUB diabaikan', () async {
    final txt = File(p.join(dir.path, 'catatan.txt'))..writeAsStringSync('x');
    IncomingFile.fromArguments(<String>[txt.path, p.join(dir.path, 'hilang.pdf')]);
    expect(await IncomingFile.takeInitial(), isNull);
  });
}
