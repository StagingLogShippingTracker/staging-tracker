import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:integration_test/integration_test.dart';

import 'package:slst/features/scanner/services/offline_ocr_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native OCR recognizes a bundled synthetic freight form', (
    tester,
  ) async {
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
