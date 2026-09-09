import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_ocr_native/flutter_ocr_native.dart';
import 'package:image/image.dart' as im;

import '../models/scan_models.dart';

const _maxOcrDimension = 2000;

Uint8List _prepareForOcr(Uint8List bytes) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longEdge = math.max(decoded.width, decoded.height);
  // processedBytes already came from this app's own JPEG-encoding pipeline
  // (document_processing_service.dart caps at the same 2000px limit), so the
  // common case needs no further resize — skip the extra lossy re-encode
  // pass entirely rather than compounding JPEG generations on every scan.
  if (longEdge <= _maxOcrDimension) return bytes;
  final image = im.bakeOrientation(decoded);
  final scale = _maxOcrDimension / longEdge;
  final resized = im.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
    interpolation: im.Interpolation.linear,
  );
  return Uint8List.fromList(im.encodeJpg(resized, quality: 92));
}

/// A single cached native session. Android uses the bundled ML Kit Latin model;
/// Windows uses Windows.Media.Ocr. Neither path sends document data off-device.
class OfflineOcrService {
  final OcrReader _reader = OcrReader();
  bool _disposed = false;

  Future<ScanOcrResult> recognize(Uint8List imageBytes) async {
    if (_disposed) throw StateError('OCR service has been disposed.');
    if (imageBytes.isEmpty) {
      throw ArgumentError('Cannot run OCR on an empty image.');
    }
    try {
      final prepared = await Isolate.run(() => _prepareForOcr(imageBytes));
      final result = await _reader.readFromBytes(prepared);
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
    } on PlatformException catch (e) {
      final code = e.code;
      if (code == 'NOT_INITIALIZED') {
        throw StateError(
          'Offline OCR is unavailable. On Windows, install an English OCR '
          'language pack (Settings → Time & language → Language).',
        );
      }
      throw StateError(
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'OCR failed ($code).',
      );
    }
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
