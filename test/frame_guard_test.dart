import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/utils/frame_guard.dart';

void main() {
  testWidgets('jendela yang dianggap tersembunyi tetap mendapat bingkai', (tester) async {
    await tester.pumpWidget(const SizedBox());
    // Keadaan yang ditinggalkan dialog pemilih berkas di GNOME + Forge.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    expect(SchedulerBinding.instance.framesEnabled, isFalse);

    SchedulerBinding.instance.scheduleFrame();
    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse, reason: 'bingkai biasa ditolak');

    FrameGuard.kick();
    expect(SchedulerBinding.instance.hasScheduledFrame, isTrue);
  });
}
