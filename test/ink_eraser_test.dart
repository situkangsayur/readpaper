import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/library/domain/entities/zotero_annotation.dart';
import 'package:readpaper/src/features/reader/domain/ink_eraser.dart';

void main() {
  const horizontal = InkPath(<double>[100, 500, 200, 500]);
  const vertical = InkPath(<double>[300, 400, 300, 600]);
  const dot = InkPath(<double>[400, 400]);

  test('goresan yang disapu dibuang utuh, yang lain tetap', () {
    const sweep = InkPath(<double>[150, 520, 150, 480]);
    expect(InkEraser.keep(<InkPath>[horizontal, vertical, dot], sweep, 6), <InkPath>[
      vertical,
      dot,
    ]);
  });

  test('sapuan cepat dengan titik berjauhan tetap mengenai goresan tipis di antaranya', () {
    // Dua titik sapuan 80 titik di kiri dan kanan garis tegak: tidak ada yang
    // dekat garisnya, tetapi lintasan di antaranya memotongnya.
    const sweep = InkPath(<double>[260, 500, 340, 500]);
    expect(InkEraser.touches(vertical, sweep, 6), isTrue);
  });

  test('sapuan yang lewat di dekat tetapi tidak menyentuh tidak menghapus', () {
    const sweep = InkPath(<double>[100, 530, 200, 530]);
    expect(InkEraser.touches(horizontal, sweep, 6), isFalse);
  });

  test('titik tunggal bisa dihapus', () {
    const sweep = InkPath(<double>[398, 403]);
    expect(InkEraser.keep(<InkPath>[dot], sweep, 6), isEmpty);
  });
}
