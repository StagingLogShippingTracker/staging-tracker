import 'dart:typed_data';

import 'package:flutter_ocr_native/flutter_ocr_native.dart';

import '../models/scan_models.dart';

/// A single cached native session. Android uses the bundled ML Kit Latin model;
/// Windows uses Windows.Media.Ocr. Neither path sends document data off-device.
class OfflineOcrService {
  final OcrReader _reader = OcrReader();
  bool _disposed = false;

  Future<ScanOcrResult> recognize(Uint8List imageBytes) async {
    if (_disposed) throw StateError('OCR service has been disposed.');
    final result = await _reader.readFromBytes(imageBytes);
    final confidences = <double>[
      for (final block in result.blocks)
        for (final line in block.lines)
          if (line.confidence != null) line.confidence!,
    ];
    return ScanOcrResult(
      text: result.text.trim(),
      confidence: confidences.isEmpty
          ? null
          : confidences.reduce((a, b) => a + b) / confidences.length,
      lineCount: result.blocks.fold(
        0,
        (count, block) => count + block.lines.length,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _reader.dispose();
    } catch (_) {
      // Some engines hold no session and older platform implementations omit
      // the optional dispose channel. Teardown must never lose scanned pages.
    }
  }
}
