import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/office_document.dart';
import 'compound_file.dart';
import 'ooxml_package.dart';
import 'doc_reader.dart';
import 'docx_reader.dart';
import 'odf_reader.dart';
import 'ppt_reader.dart';
import 'pptx_reader.dart';
import 'text_formats.dart';

/// Akhiran berkas Word dan PowerPoint (juga Writer dan Impress) yang dibaca
/// sendiri oleh ReadPaper.
const Set<String> officeExtensions = <String>{
  '.docx', '.docm', '.dotx', '.doc', '.dot', //
  '.pptx', '.pptm', '.ppsx', '.potx', '.ppt', '.pps', '.pot', '.rtf',
  '.odt', '.ott', '.odp', '.otp',
};

/// Akhiran lembar kerja OpenDocument (Calc), dibuka di penampil tabel.
const Set<String> odfSheetExtensions = <String>{'.ods', '.ots'};

/// Membaca dokumen Word atau PowerPoint. Isi berkas yang menentukan, bukan
/// akhirannya: `.doc` yang sebenarnya `.docx` (hasil ganti nama), RTF, atau
/// HTML (ekspor banyak aplikasi web) tetap terbaca.
OfficeDocument readOffice(String fileName, Uint8List bytes) {
  final ext = p.extension(fileName).toLowerCase();
  if (CompoundFile.looksLike(bytes)) {
    final cfb = CompoundFile(bytes);
    // .docx/.pptx berkata sandi dibungkus OLE2, isinya terenkripsi.
    if (cfb.has('EncryptedPackage')) {
      throw const FormatException('Dokumen dilindungi kata sandi');
    }
    if (cfb.has('PowerPoint Document')) return PptReader.read(bytes);
    if (cfb.has('WordDocument')) return DocReader.read(bytes);
    throw const FormatException('Bukan dokumen Word atau PowerPoint');
  }
  if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    switch (OdfReader.kindOf(bytes)) {
      case OdfKind.text || OdfKind.presentation:
        return OdfReader.read(bytes);
      case OdfKind.spreadsheet:
        throw const FormatException('Lembar kerja dibuka di penampil tabel');
      case OdfKind.other:
        break;
    }
    final pkg = OoxmlPackage(bytes);
    if (pkg.bytes('ppt/presentation.xml') != null) return PptxReader.read(bytes);
    if (pkg.bytes('word/document.xml') != null) return DocxReader.read(bytes);
    throw const FormatException('Bukan dokumen Word atau PowerPoint');
  }
  if (TextFormats.isRtf(bytes)) return TextFormats.rtf(bytes);
  if (TextFormats.isHtml(bytes)) return TextFormats.htmlDocument(bytes);
  if (ext != '.ppt' && ext != '.pptx' && TextFormats.isPlainText(bytes)) {
    return TextFormats.plain(bytes);
  }
  throw const FormatException('Format berkas tidak dikenal');
}
