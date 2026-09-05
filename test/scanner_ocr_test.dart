import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import 'package:swift_staging_log/features/scanner/services/offline_ocr_service.dart';

/// Host-side OCR smoke test (no integration_test plugin — that package
/// registers into Android release builds and breaks APK packaging).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native OCR recognizes a bundled synthetic freight form', () async {
    final image = im.Image(width: 1200, height: 500);
    im.fill(image, color: im.ColorRgb8(255, 255, 255));
    im.drawString(
      image,
      'PURCHASE ORDER 12345',
      font: im.arial48,
      x: 80,
      y: 90,
      color: im.ColorRgb8(0, 0, 0),
    );
    im.drawString(
      image,
      'WAREHOUSE RECEIPT',
      font: im.arial48,
      x: 80,
      y: 210,
      color: im.ColorRgb8(0, 0, 0),
    );
    final service = OfflineOcrService();
    addTearDown(service.dispose);

    final result = await service.recognize(
      Uint8List.fromList(im.encodePng(image)),
    );

    expect(result.text.toUpperCase(), contains('12345'));
    expect(result.lineCount, greaterThan(0));
  });
}
