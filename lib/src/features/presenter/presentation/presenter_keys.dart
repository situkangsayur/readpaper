import 'package:flutter/services.dart';

import '../data/audience_link.dart';

/// Tombol presenter clicker dan keyboard saat menyajikan.
///
/// Clicker Bluetooth/USB tampil sebagai keyboard dan mengirim salah satu
/// tombol ini — panah, Page Up/Down, atau spasi, tergantung mereknya — jadi
/// semuanya diterima. Di Android clicker Bluetooth juga berupa keyboard.
PresenterKey? presenterKeyFor(LogicalKeyboardKey key) {
  if (_next.contains(key)) return PresenterKey.next;
  if (_previous.contains(key)) return PresenterKey.previous;
  if (key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.period) {
    return PresenterKey.blank;
  }
  if (key == LogicalKeyboardKey.escape) return PresenterKey.exit;
  return null;
}

final Set<LogicalKeyboardKey> _next = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.keyN,
  LogicalKeyboardKey.mediaTrackNext,
};

final Set<LogicalKeyboardKey> _previous = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.mediaTrackPrevious,
};
