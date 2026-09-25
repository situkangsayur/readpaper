import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/features/reader/domain/page_image_export.dart';

void main() {
  group('PageImageFormat', () {
    test('carries the extension and media type a save dialog needs', () {
      expect(PageImageFormat.png.extension, 'png');
      expect(PageImageFormat.png.mimeType, 'image/png');
      expect(PageImageFormat.jpg.extension, 'jpg');
      expect(PageImageFormat.jpg.mimeType, 'image/jpeg');
    });
  });
}
