import 'note_document.dart';

/// Riwayat perubahan sebuah catatan, untuk urungkan dan ulangi.
///
/// Semuanya bisa diurungkan — menggambar, menghapus, menggeser, mengubah
/// ukuran, memutar, mengganti warna dan kepekatan, menambah dan membuang
/// halaman — karena yang disimpan bukan daftar tindakan melainkan keadaan
/// dokumennya. Tindakan yang lupa didaftarkan adalah cara paling mudah
/// membuat urungkan bohong, dan cara ini menutup kemungkinan itu.
///
/// Yang disalin hanyalah daftar rujukan komponen: komponennya sendiri tidak
/// pernah berubah isi, selalu diganti dengan salinan baru.
class NoteHistory {
  NoteHistory(NoteDocument initial, {this.limit = 60}) : _states = <NoteDocument>[initial];

  final List<NoteDocument> _states;
  int _at = 0;

  /// Berapa langkah ke belakang yang disimpan.
  final int limit;

  NoteDocument get current => _states[_at];

  bool get canUndo => _at > 0;
  bool get canRedo => _at < _states.length - 1;

  /// Mencatat keadaan baru. Apa pun yang sudah diurungkan dan belum diulangi
  /// dibuang — itu yang diharapkan orang setelah menulis sesuatu yang baru.
  void push(NoteDocument document) {
    if (identical(document, current)) return;
    _states
      ..removeRange(_at + 1, _states.length)
      ..add(document);
    if (_states.length > limit) _states.removeAt(0);
    _at = _states.length - 1;
  }

  NoteDocument undo() {
    if (canUndo) _at--;
    return current;
  }

  NoteDocument redo() {
    if (canRedo) _at++;
    return current;
  }
}
