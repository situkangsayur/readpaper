import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/app_paths.dart';
import 'package:readpaper/src/features/library/presentation/import_actions.dart';

/// Pemilih berkas palsu yang menahan jawabannya sampai test melepasnya —
/// selama itu "dialog"-nya terbuka.
final class _HeldPicker extends FilePickerPlatform {
  final answer = Completer<List<PlatformFile>>();
  var opened = false;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    opened = true;
    return answer.future;
  }
}

final class _PickedFile extends PlatformFile {
  _PickedFile(String path) : uri = Uri.file(path);

  @override
  final Uri uri;

  @override
  String get name => uri.pathSegments.last;

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => null;

  @override
  Future<Uint8List> readAsBytes() => throw UnimplementedError();

  @override
  Stream<Uint8List> readAsByteStream() => throw UnimplementedError();
}

void main() {
  setUp(() {
    final dir = Directory.systemTemp.createTempSync('rp_import_host_');
    AppPaths.debugOverride(dir);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  // Di desktop, dialog pemilih berkas bisa mengubah ukuran jendela — Forge di
  // GNOME menata dialog sebagai ubin — sehingga tata letaknya berganti dan
  // tombol tambah dibongkar selagi dialog terbuka. Dulu berkas yang dipilih
  // lalu dibuang diam-diam karena `context` tombolnya sudah tidak terpasang.
  testWidgets('tombol tambah dibongkar selagi dialog terbuka: berkasnya tetap diproses', (
    tester,
  ) async {
    final picker = _HeldPicker();
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previous);

    final showButton = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showButton,
              builder: (_, show, _) => show
                  ? const AddFilesButton(
                      notes: false,
                      collectionKey: null,
                      collectionName: 'Library Uji',
                    )
                  : const Text('tata letak sempit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AddFilesButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambahkan berkas…'));
    await tester.pump();
    expect(picker.opened, isTrue);

    // Jendela menyempit selagi dialog terbuka: tombolnya hilang.
    showButton.value = false;
    await tester.pump();
    expect(find.byType(AddFilesButton), findsNothing);

    picker.answer.complete(<PlatformFile>[_PickedFile('/tmp/makalah.pdf')]);
    await tester.pumpAndSettle();

    // Tidak ada library di test ini, jadi yang sampai adalah penolakan dari
    // controller — buktinya alurnya berlanjut sampai sana, bukan berhenti.
    expect(find.text('Tidak ada library aktif untuk menampung berkas ini.'), findsOneWidget);
  });
}
