import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import '../../../core/constants/app_constants.dart';
import '../../library/domain/entities/zotero_annotation.dart';
import 'pdf_page_editor.dart';

/// Anotasi yang tertanam di dalam PDF itu sendiri — dibuat Acrobat, Okular,
/// Xodo, skrip, atau "Simpan sebagai PDF" ReadPaper.
///
/// Zotero membacanya dan menampilkannya di panel anotasi, terkunci. ReadPaper
/// dulu hanya mengenal anotasinya sendiri (data item Zotero atau
/// `anotasi.json`), jadi stabilo dan catatan tempel dari aplikasi lain memang
/// tergambar di halaman oleh pdfium, tetapi isi komentarnya tidak bisa dibaca
/// dan panelnya kosong.
///
/// Gambarnya tetap urusan pdfium — ia menggambar tampilan aslinya, termasuk
/// jenis yang tidak dikenal ReadPaper. Yang dibaca di sini adalah isinya:
/// letak, warna, komentar, penulis, dan teks yang distabilo.
class PdfEmbeddedAnnotations {
  const PdfEmbeddedAnnotations._();

  /// Awalan kunci anotasi tertanam; kunci Zotero tidak pernah memakai `:`.
  static const String keyPrefix = 'pdf:';

  static bool isEmbedded(ZoteroAnnotation annotation) => annotation.key.startsWith(keyPrefix);

  static const int _text = 1;
  static const int _freeText = 3;
  static const int _highlight = 9;
  static const int _underline = 10;
  static const int _squiggly = 11;
  static const int _strikeOut = 12;
  static const int _inkType = 15;

  /// Semua anotasi yang dikenal dari [document], urut per halaman.
  ///
  /// Lewat `useNativeDocumentHandle`: pdfrx menjeda pekerja pdfium-nya selama
  /// fungsi ini berjalan. pdfium tidak aman dipanggil dari dua utas
  /// sekaligus, dan dokumennya sedang dipakai penampil.
  static Future<List<ZoteroAnnotation>> read(PdfDocument document) =>
      document.useNativeDocumentHandle(
        (handle) => readDocument(
          pdfium.getPdfium(modulePath: PdfPageEditor.modulePath),
          pdfium.FPDF_DOCUMENT.fromAddress(handle),
        ),
      );

  /// Isi [read] untuk dokumen pdfium yang sudah terbuka.
  static List<ZoteroAnnotation> readDocument(pdfium.PDFium lib, pdfium.FPDF_DOCUMENT doc) {
    final result = <ZoteroAnnotation>[];
    final count = lib.FPDF_GetPageCount(doc);
    for (var i = 0; i < count; i++) {
      final page = lib.FPDF_LoadPage(doc, i);
      if (page == nullptr) continue;
      try {
        result.addAll(_readPage(lib, page, i, lib.FPDF_GetPageHeightF(page)));
      } finally {
        lib.FPDF_ClosePage(page);
      }
    }
    return result;
  }

  static List<ZoteroAnnotation> _readPage(
    pdfium.PDFium lib,
    pdfium.FPDF_PAGE page,
    int pageIndex,
    double pageHeight,
  ) {
    final count = lib.FPDFPage_GetAnnotCount(page);
    if (count <= 0) return const <ZoteroAnnotation>[];
    final out = <ZoteroAnnotation>[];
    pdfium.FPDF_TEXTPAGE? text;
    try {
      for (var i = 0; i < count; i++) {
        final annot = lib.FPDFPage_GetAnnot(page, i);
        if (annot == nullptr) continue;
        try {
          final subtype = lib.FPDFAnnot_GetSubtype(annot);
          final type = switch (subtype) {
            _highlight => AnnotationType.highlight,
            _underline || _squiggly || _strikeOut => AnnotationType.underline,
            _text => AnnotationType.note,
            _freeText => AnnotationType.text,
            _inkType => AnnotationType.ink,
            _ => null,
          };
          if (type == null) continue;

          final comment = _string(lib, annot, 'Contents');
          final rect = _rect(lib, annot);
          var rects = <AnnotationRect>[];
          if (type == AnnotationType.highlight || type == AnnotationType.underline) {
            rects = _quads(lib, annot);
            if (rects.isEmpty && rect != null) rects = <AnnotationRect>[rect];
          } else if (rect != null) {
            rects = <AnnotationRect>[rect];
          }
          final paths = type == AnnotationType.ink ? _ink(lib, annot) : const <InkPath>[];
          if (rects.isEmpty && paths.isEmpty) continue;

          var quoted = '';
          if (type == AnnotationType.highlight || type == AnnotationType.underline) {
            text ??= lib.FPDFText_LoadPage(page);
            if (text != nullptr) quoted = _boundedText(lib, text, rects);
          }

          final top = rects.isEmpty ? pageHeight : rects.map((r) => r.top).reduce(math.max);
          final left = rects.isEmpty ? 0.0 : rects.map((r) => r.left).reduce(math.min);
          out.add(
            ZoteroAnnotation(
              key: '$keyPrefix$pageIndex:$i',
              parentItemKey: '',
              type: type,
              color: _color(lib, annot) ?? AnnotationPalette.yellow,
              pageIndex: pageIndex,
              rects: rects,
              paths: paths,
              inkWidth: _borderWidth(lib, annot) ?? 1,
              text: quoted,
              comment: comment,
              pageLabel: '${pageIndex + 1}',
              sortIndex: ZoteroAnnotation.buildSortIndex(
                pageIndex: pageIndex,
                textOffset: 0,
                topFromPageTop: math.max(0, pageHeight - top),
              ),
              authorName: _string(lib, annot, 'T'),
              rawPosition: <String, dynamic>{'pageIndex': pageIndex, 'left': left},
            ),
          );
        } finally {
          lib.FPDFPage_CloseAnnot(annot);
        }
      }
    } finally {
      if (text != null && text != nullptr) lib.FPDFText_ClosePage(text);
    }
    return out;
  }

  static AnnotationRect? _rect(pdfium.PDFium lib, pdfium.FPDF_ANNOTATION annot) {
    final rect = calloc<pdfium.FS_RECTF>();
    try {
      if (lib.FPDFAnnot_GetRect(annot, rect) == 0) return null;
      final r = rect.ref;
      return AnnotationRect(
        math.min(r.left, r.right),
        math.min(r.bottom, r.top),
        math.max(r.left, r.right),
        math.max(r.bottom, r.top),
      );
    } finally {
      calloc.free(rect);
    }
  }

  /// Kotak per baris dari QuadPoints: stabilo yang melintasi tiga baris adalah
  /// tiga kotak, bukan satu kotak besar yang menutupi margin.
  static List<AnnotationRect> _quads(pdfium.PDFium lib, pdfium.FPDF_ANNOTATION annot) {
    final count = lib.FPDFAnnot_CountAttachmentPoints(annot);
    if (count <= 0) return const <AnnotationRect>[];
    final quad = calloc<pdfium.FS_QUADPOINTSF>();
    final out = <AnnotationRect>[];
    try {
      for (var i = 0; i < count; i++) {
        if (lib.FPDFAnnot_GetAttachmentPoints(annot, i, quad) == 0) continue;
        final q = quad.ref;
        final xs = <double>[q.x1, q.x2, q.x3, q.x4];
        final ys = <double>[q.y1, q.y2, q.y3, q.y4];
        out.add(
          AnnotationRect(
            xs.reduce(math.min),
            ys.reduce(math.min),
            xs.reduce(math.max),
            ys.reduce(math.max),
          ),
        );
      }
    } finally {
      calloc.free(quad);
    }
    return out;
  }

  static List<InkPath> _ink(pdfium.PDFium lib, pdfium.FPDF_ANNOTATION annot) {
    final count = lib.FPDFAnnot_GetInkListCount(annot);
    final out = <InkPath>[];
    for (var i = 0; i < count; i++) {
      final length = lib.FPDFAnnot_GetInkListPath(annot, i, nullptr, 0);
      if (length <= 0) continue;
      final points = calloc<pdfium.FS_POINTF>(length);
      try {
        lib.FPDFAnnot_GetInkListPath(annot, i, points, length);
        out.add(
          InkPath.fromList(<double>[
            for (var j = 0; j < length; j++) ...<double>[points[j].x, points[j].y],
          ]),
        );
      } finally {
        calloc.free(points);
      }
    }
    return out;
  }

  static String? _color(pdfium.PDFium lib, pdfium.FPDF_ANNOTATION annot) {
    final r = calloc<UnsignedInt>(4);
    try {
      if (lib.FPDFAnnot_GetColor(
            annot,
            pdfium.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
            r,
            r + 1,
            r + 2,
            r + 3,
          ) ==
          0)
        return null;
      String hex(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${hex(r[0])}${hex(r[1])}${hex(r[2])}';
    } finally {
      calloc.free(r);
    }
  }

  static double? _borderWidth(pdfium.PDFium lib, pdfium.FPDF_ANNOTATION annot) {
    final values = calloc<Float>(3);
    try {
      if (lib.FPDFAnnot_GetBorder(annot, values, values + 1, values + 2) == 0) return null;
      final width = values[2];
      return width > 0 ? width : null;
    } finally {
      calloc.free(values);
    }
  }

  /// Nilai string anotasi (`Contents`, `T`), dari UTF-16LE milik pdfium.
  static String _string(pdfium.PDFium lib, pdfium.FPDF_ANNOTATION annot, String key) {
    final k = key.toNativeUtf8();
    try {
      final bytes = lib.FPDFAnnot_GetStringValue(annot, k.cast(), nullptr, 0);
      if (bytes <= 2) return '';
      final buffer = calloc<UnsignedShort>(bytes ~/ 2);
      try {
        lib.FPDFAnnot_GetStringValue(annot, k.cast(), buffer, bytes);
        final units = buffer.cast<Uint16>().asTypedList(bytes ~/ 2 - 1);
        return String.fromCharCodes(units).replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
      } finally {
        calloc.free(buffer);
      }
    } finally {
      malloc.free(k);
    }
  }

  /// Teks halaman di bawah kotak-kotak stabilo, baris demi baris.
  static String _boundedText(
    pdfium.PDFium lib,
    pdfium.FPDF_TEXTPAGE text,
    List<AnnotationRect> rects,
  ) {
    final parts = <String>[];
    for (final r in rects) {
      final count = lib.FPDFText_GetBoundedText(text, r.left, r.top, r.right, r.bottom, nullptr, 0);
      if (count <= 1) continue;
      final buffer = calloc<UnsignedShort>(count + 1);
      try {
        final written = lib.FPDFText_GetBoundedText(
          text,
          r.left,
          r.top,
          r.right,
          r.bottom,
          buffer,
          count,
        );
        final units = buffer.cast<Uint16>().asTypedList(math.max(0, written));
        parts.add(String.fromCharCodes(units).replaceAll('\u0000', '').trim());
      } finally {
        calloc.free(buffer);
      }
    }
    return parts.where((s) => s.isNotEmpty).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
