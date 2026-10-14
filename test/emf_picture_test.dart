import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/files/domain/table_data.dart';
import 'package:readpaper/src/features/office/data/emf_picture.dart';
import 'package:readpaper/src/features/office/data/office_pdf.dart';
import 'package:readpaper/src/features/office/domain/office_document.dart';

/// EMF kecil seperti keluaran MathType: kuas, jalur bezier yang diisi,
/// pemetaan window → viewport, lalu pena EXTCREATEPEN untuk garis pecahan.
Uint8List _emf() {
  final out = BytesBuilder();
  void rec(int type, List<int> ints) {
    final b = ByteData(8 + ints.length * 4)
      ..setUint32(0, type, Endian.little)
      ..setUint32(4, 8 + ints.length * 4, Endian.little);
    for (var i = 0; i < ints.length; i++) {
      b.setInt32(8 + i * 4, ints[i], Endian.little);
    }
    out.add(b.buffer.asUint8List());
  }

  final header = ByteData(108)
    ..setUint32(0, 1, Endian.little)
    ..setUint32(4, 108, Endian.little)
    ..setInt32(16, 99, Endian.little)
    ..setInt32(20, 49, Endian.little)
    ..setInt32(32, 2540, Endian.little) // 25,4 mm
    ..setInt32(36, 1270, Endian.little)
    ..setUint32(40, 0x464D4520, Endian.little)
    ..setInt32(72, 10, Endian.little) // 10 px = 1 mm → bingkai 254 × 127 px
    ..setInt32(76, 10, Endian.little)
    ..setInt32(80, 1, Endian.little)
    ..setInt32(84, 1, Endian.little);
  out.add(header.buffer.asUint8List());
  rec(17, <int>[8]); // MM_ANISOTROPIC
  rec(9, <int>[1000, 500]); // window
  rec(11, <int>[100, 50]); // viewport
  rec(39, <int>[1, 0, 0x000000FF, 0]); // kuas merah
  rec(37, <int>[1]);
  rec(59, <int>[]);
  rec(27, <int>[0, 0]);
  rec(54, <int>[1000, 0]);
  rec(54, <int>[1000, 500]);
  rec(61, <int>[]);
  rec(60, <int>[]);
  rec(62, <int>[0, 0, 100, 50]);
  // EXTCREATEPEN: ihPen 2, tanpa bitmap, gaya geometris, tebal 10, biru.
  rec(95, <int>[2, 52, 0, 52, 0, 0x00010000, 10, 0, 0x00FF0000, 0, 0]);
  rec(37, <int>[2]);
  rec(14, <int>[0, 0, 0]);
  return out.toBytes();
}

void main() {
  test('EMF: jalur diisi dan pena dari EXTCREATEPEN terbaca benar', () {
    final picture = EmfPicture.of(_emf());
    expect(picture, isNotNull);
    expect(picture!.bounds.width, closeTo(254, 0.5));
    expect(picture.ops, hasLength(1));
    final op = picture.ops.single as EmfPathOp;
    expect(op.paint_.color, const Color(0xFFFF0000));
    // Koordinat logis 1000 → 100 piksel perangkat.
    expect(op.path.getBounds().right, closeTo(100, 0.01));
  });

  test('bukan EMF dikenali', () {
    expect(EmfPicture.of(Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47])), isNull);
  });

  test('Word dan Excel jadi PDF', () async {
    final doc = OfficeDocument(
      blocks: <OfficeBlock>[
        OfficeParagraph(runs: const <OfficeRun>[OfficeRun('Judul')], heading: 1),
        OfficeParagraph(runs: const <OfficeRun>[OfficeRun('Isi — dengan β')], bullet: '•'),
        OfficeImage(_emf(), width: 100),
      ],
    );
    final word = await OfficePdf.document(doc);
    expect(String.fromCharCodes(word.take(5)), '%PDF-');
    final excel = await OfficePdf.sheets(const <TableSheet>[
      TableSheet(
        name: 'Lembar 1',
        rows: <List<String>>[
          <String>['a', 'b'],
          <String>['1', '2'],
        ],
      ),
    ]);
    expect(String.fromCharCodes(excel.take(5)), '%PDF-');
  });
}
