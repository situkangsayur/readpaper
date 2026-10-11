import '../../library/domain/entities/library_index.dart';
import '../../../core/l10n.dart';

/// Ke mana sebuah catatan boleh disimpan.
///
/// Aturannya satu kalimat: catatan hanya masuk ke akar berjenis catatan.
/// Menolaknya di sini, sekali, lebih baik daripada membiarkan setiap layar
/// menebak sendiri — dan penolakannya harus menjelaskan sebabnya, bukan
/// sekadar berkata tidak bisa.
class NoteTarget {
  const NoteTarget._({this.collectionKey, this.refusal});

  /// Memeriksa pilihan di pohon koleksi.
  factory NoteTarget.of(LibrarySelection selection) {
    if (selection.isNotes) {
      return NoteTarget._(collectionKey: selection.noteCollectionKey);
    }
    return NoteTarget._(refusal: refusalMessage);
  }

  static String get refusalMessage => l10n.notesTargetRefusal;

  /// Koleksi catatan tujuannya; null berarti akar catatan (tanpa koleksi).
  final String? collectionKey;

  /// Alasan penolakan, kalau yang dipilih bukan akar catatan.
  final String? refusal;

  bool get isAllowed => refusal == null;
}
