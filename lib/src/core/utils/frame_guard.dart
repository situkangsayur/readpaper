import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

/// Menjaga jendela desktop tetap digambar ulang.
///
/// Mesin Flutter di Linux menurunkan status aplikasi ke `hidden` begitu GTK
/// melaporkan jendelanya ICONIFIED atau WITHDRAWN, dan sejak itu tidak ada
/// bingkai baru yang digambar sampai GTK melaporkan jendelanya terlihat lagi.
/// Di GNOME dengan pengelola jendela tiling (Forge), membuka dan menutup
/// dialog pemilih berkas bisa meninggalkan status itu: berkas atau folder
/// yang baru ditambahkan sudah masuk library, tetapi daftarnya baru berubah
/// setelah jendela diminimalkan lalu dibuka lagi.
///
/// Jendela yang menerima gerakan tetikus atau ketukan jelas terlihat, jadi
/// selama bingkai dimatikan setiap masukan dan setiap perubahan data memaksa
/// satu bingkai.
class FrameGuard {
  const FrameGuard._();

  static bool _installed = false;

  static bool get _desktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  static void install() {
    if (_installed || !_desktop) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((_) => kick());
  }

  /// Satu bingkai, juga ketika mesinnya menganggap jendela tersembunyi.
  static void kick() {
    if (!_desktop) return;
    final scheduler = SchedulerBinding.instance;
    if (!scheduler.framesEnabled) scheduler.scheduleForcedFrame();
  }
}
