import 'package:flutter/material.dart';

/// Kotak yang bisa diseret di atas anotasi yang sedang dipilih.
///
/// Tanda tangan yang mendarat dua sentimeter dari kotak isian dulu berarti
/// menghapusnya lalu menggambar ulang. Yang kurang hanyalah cara memegangnya:
/// begitu sebuah anotasi terpilih, kotak inilah yang menerima seretan, dan
/// hanya di dalam batas anotasinya — sisa halaman tetap bisa digulir.
class AnnotationMoveLayer extends StatefulWidget {
  const AnnotationMoveLayer({
    required this.bounds,
    required this.onMoved,
    required this.onDelete,
    this.limit,
    this.onTransformed,
    this.onDragStart,
    super.key,
  });

  /// Batas anotasinya pada kanvas halaman, bukan koordinat PDF.
  final Rect bounds;

  /// Ukuran ruang yang tersedia — biasanya sebesar halamannya.
  ///
  /// Dipakai untuk menahan kotak sentuh tetap **di dalam** ruang itu: anotasi
  /// yang menempel di tepi halaman punya pegangan yang jatuh di luar induknya,
  /// dan yang di luar induk tidak pernah menerima sentuhan. Terlihat, tidak
  /// bisa dipencet — itu keluhan yang sama yang dulu membuat tombol hapus
  /// tampak rusak.
  final Size? limit;

  /// Dipanggil sekali saat seretan selesai, dengan perpindahan pada kanvas.
  final ValueChanged<Offset> onMoved;

  final VoidCallback onDelete;

  /// Bila diisi, seretannya diserahkan ke pemanggil sejak awal, dengan posisi
  /// global tempat jari menekan. Lapisan ini terkurung di halamannya sendiri
  /// — tidak bisa menggambar, apalagi menjatuhkan, sesuatu di halaman lain —
  /// jadi memindah ke halaman lain hanya bisa diurus dari atas penampil.
  /// [onMoved] tidak dipanggil dalam hal ini.
  final ValueChanged<Offset>? onDragStart;

  /// Dipanggil sekali saat gerakan mengubah ukuran atau memutar selesai.
  ///
  /// Null berarti anotasi ini memang tidak bisa diubah begitu — stabilo dan
  /// garis bawah disimpan sebagai kotak sejajar sumbu, dan memutarnya
  /// menghasilkan sesuatu yang tidak bisa dibaca Zotero lagi.
  final void Function({double scale, double rotation})? onTransformed;

  @override
  State<AnnotationMoveLayer> createState() => _AnnotationMoveLayerState();
}

class _AnnotationMoveLayerState extends State<AnnotationMoveLayer> {
  Offset _drag = Offset.zero;
  bool _dragging = false;

  /// Perubahan yang sedang berlangsung, ditampilkan sebagai pratinjau
  /// bingkainya saja. Diterapkan sekali saat jarinya diangkat: menerapkannya
  /// sedikit demi sedikit berarti titik tintanya ditulis ulang berkali-kali,
  /// dan ketelitiannya habis.
  double _scale = 1;
  double _rotation = 0;
  bool _transforming = false;

  void _applyTransform() {
    final scale = _scale;
    final rotation = _rotation;
    setState(() {
      _transforming = false;
      _scale = 1;
      _rotation = 0;
    });
    if (scale == 1 && rotation == 0) return;
    widget.onTransformed?.call(scale: scale, rotation: rotation);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Kotak sentuhnya jauh lebih lebar dari gambarnya, dan itu bukan sekadar
    // kenyamanan: pegangan yang digambar di luar kotak induknya terlihat
    // tetapi tidak pernah menerima sentuhan — Flutter tidak mengirim
    // pointer ke anak yang berada di luar batas induknya. Semua pegangan
    // karena itu duduk di dalam kotak ini.
    const grip = 26.0;
    var box = widget.bounds.shift(_drag).inflate(grip);

    // Digeser masuk kalau kotaknya keluar dari ruang yang ada; pergeserannya
    // dibayar balik oleh jarak dalamnya, supaya bingkainya tetap pas di
    // anotasinya dan yang bergeser hanya pegangannya.
    var shiftX = 0.0;
    var shiftY = 0.0;
    final limit = widget.limit;
    if (limit != null) {
      if (box.left < 0) shiftX = -box.left;
      if (box.top < 0) shiftY = -box.top;
      if (box.right + shiftX > limit.width) shiftX = limit.width - box.right;
      if (box.bottom + shiftY > limit.height) shiftY = limit.height - box.bottom;
      box = box.shift(Offset(shiftX, shiftY));
    }

    final canTransform = widget.onTransformed != null;

    return Positioned(
      left: box.left,
      top: box.top,
      width: box.width,
      height: box.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          setState(() => _dragging = true);
          widget.onDragStart?.call(d.globalPosition);
        },
        onPanUpdate: (d) {
          if (widget.onDragStart != null) return;
          setState(() => _drag += d.delta);
        },
        onPanEnd: (_) {
          final moved = _drag;
          setState(() {
            _dragging = false;
            _drag = Offset.zero;
          });
          if (widget.onDragStart == null && moved != Offset.zero) widget.onMoved(moved);
        },
        onPanCancel: () => setState(() {
          _dragging = false;
          _drag = Offset.zero;
        }),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // Pratinjau: bingkainya saja yang ikut membesar dan berputar,
            // karena anotasinya sendiri digambar lapisan lain.
            // Bingkainya sendiri tetap sebesar anotasinya; ruang di sekeliling
            // adalah tempat pegangan.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  grip - shiftX,
                  grip - shiftY,
                  grip + shiftX,
                  grip + shiftY,
                ),
                child: Transform.rotate(
                  angle: _rotation,
                  child: Transform.scale(
                    scale: _scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _dragging ? scheme.primary : scheme.primary.withValues(alpha: 0.6),
                          width: _dragging ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        color: scheme.primary.withValues(
                          alpha: (_dragging || _transforming) ? 0.10 : 0.04,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Empat pegangan: geser, hapus, ubah ukuran, putar. Di sudut yang
            // berbeda supaya jari tidak pernah harus memilih dua hal yang
            // bertumpuk.
            const Positioned(
              left: 0,
              top: 0,
              child: _Chip(
                icon: Icons.open_with,
                color: null,
                onTap: null,
                tooltip: 'Seret untuk memindahkan',
              ),
            ),
            if (canTransform) ...<Widget>[
              Positioned(
                right: 0,
                bottom: 0,
                child: _Handle(
                  icon: Icons.open_in_full,
                  color: scheme.primary,
                  tooltip: 'Seret untuk mengubah ukuran',
                  onStart: () => setState(() => _transforming = true),
                  onUpdate: (delta) {
                    // Jarak dari titik tengah menentukan skalanya: menyeret
                    // menjauh membesarkan, mendekat mengecilkan.
                    final half = widget.bounds.longestSide / 2;
                    if (half <= 1) return;
                    setState(() {
                      _scale = (_scale + (delta.dx + delta.dy) / (half * 2)).clamp(0.15, 12.0);
                    });
                  },
                  onEnd: _applyTransform,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: _Handle(
                  icon: Icons.rotate_right,
                  color: scheme.primary,
                  tooltip: 'Seret untuk memutar',
                  onStart: () => setState(() => _transforming = true),
                  onUpdate: (delta) => setState(() {
                    // Satu layar penuh ke samping memutar setengah lingkaran:
                    // cukup halus untuk meluruskan tanda tangan yang miring.
                    _rotation += delta.dx * 0.01;
                  }),
                  onEnd: _applyTransform,
                ),
              ),
            ],
            Positioned(
              right: 0,
              top: 0,
              child: _Chip(
                icon: Icons.delete_outline,
                color: scheme.error,
                onTap: widget.onDelete,
                tooltip: 'Hapus',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.tooltip, this.color, this.onTap});

  final IconData icon;

  /// Null memakai warna utama tema — dipakai chip yang hanya penanda.
  final Color? color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color ?? Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    ),
  );
}

/// Pegangan kecil yang menerima seretan sendiri, terpisah dari kotaknya.
class _Handle extends StatelessWidget {
  const _Handle({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanStart: (_) => onStart(),
    onPanUpdate: (d) => onUpdate(d.delta),
    onPanEnd: (_) => onEnd(),
    onPanCancel: onEnd,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    ),
  );
}
