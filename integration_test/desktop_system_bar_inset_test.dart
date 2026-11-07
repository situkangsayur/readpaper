import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:readpaper/main.dart' as app;

import 'support.dart';

/// Bilah navigasi tiga tombol Android (kembali, beranda, aplikasi terakhir)
/// tidak boleh menutupi baris paling bawah: jumlah item, pemilih repositori,
/// koleksi atau berkas terakhir.
///
///   flutter test integration_test/desktop_system_bar_inset_test.dart -d linux
///
/// Di Android aplikasinya digambar di bawah bilah sistem; bilah tiga tombol
/// ~48 dp, sedangkan bilah gestur hanya garis tipis — itulah sebabnya hanya
/// mode tiga tombol yang tertutup. Bilahnya ditiru di sini lewat jarak
/// tampilan, persis yang dilaporkan Android ke Flutter.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => Fixture.create());

  testWidgets('baris paling bawah tetap di atas bilah tiga tombol', (tester) async {
    final view = tester.view;
    const bar = 48.0;
    final dpr = view.devicePixelRatio;
    view.padding = FakeViewPadding(bottom: bar * dpr);
    view.viewPadding = FakeViewPadding(bottom: bar * dpr);
    addTearDown(view.resetPadding);
    addTearDown(view.resetViewPadding);

    app.main(const <String>[]);
    await pumpUntil(tester, find.text('Migrasi kriptografi pascakuantum'));
    await pumpFor(tester, const Duration(seconds: 1));

    final height = view.physicalSize.height / dpr;
    for (final label in <String>['2 item', 'readpaper']) {
      final rect = tester.getRect(find.text(label).last);
      diag('"$label" berakhir di y=${rect.bottom} dari $height');
      expect(rect.bottom, lessThanOrEqualTo(height - bar + 0.5), reason: '"$label" tertutup bilah');
    }
  });
}
