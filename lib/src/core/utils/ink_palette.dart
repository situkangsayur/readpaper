import 'dart:ui';

/// Warna tinta yang ditawarkan, dengan namanya.
///
/// Satu daftar untuk papan tulis dan buku catatan. Enam warna ternyata tidak
/// cukup: catatan yang dipakai menandai sesuatu butuh warna yang jelas
/// berbeda, dan "biru" saja tidak menolong kalau bagan yang sama sudah memakai
/// biru untuk hal lain. Namanya ikut disebut karena bulatan warna saja sulit
/// dibedakan di layar kecil — apalagi hijau dan hijau muda.
class InkPalette {
  const InkPalette._();

  static const List<({String name, Color color})> all = <({String name, Color color})>[
    (name: 'Hitam', color: Color(0xFF1A1A1A)),
    (name: 'Abu', color: Color(0xFF616161)),
    (name: 'Putih', color: Color(0xFFFAFAFA)),
    (name: 'Merah', color: Color(0xFFC62828)),
    (name: 'Jingga', color: Color(0xFFEF6C00)),
    (name: 'Kuning', color: Color(0xFFF9A825)),
    (name: 'Hijau', color: Color(0xFF2E7D32)),
    (name: 'Hijau muda', color: Color(0xFF7CB342)),
    (name: 'Biru', color: Color(0xFF1565C0)),
    (name: 'Biru langit', color: Color(0xFF039BE5)),
    (name: 'Ungu', color: Color(0xFF6A1B9A)),
    (name: 'Merah muda', color: Color(0xFFD81B60)),
    (name: 'Cokelat', color: Color(0xFF6D4C41)),
    (name: 'Biru malam', color: Color(0xFF283593)),
  ];
}
