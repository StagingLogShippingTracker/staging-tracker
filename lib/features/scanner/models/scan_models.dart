import 'dart:typed_data';
import 'dart:ui';

enum ScanEnhancement {
  original('Original'),
  color('Color / Photo'),
  document('Document'),
  grayscale('Grayscale'),
  blackAndWhite('B&W');

  const ScanEnhancement(this.label);
  final String label;
}

enum ScanWork { idle, detecting, processing, recognizing, failed }

class DocumentCorners {
  const DocumentCorners(
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  );

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  static const full = DocumentCorners(
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  );

  List<Offset> get points => [topLeft, topRight, bottomRight, bottomLeft];

  DocumentCorners replace(int index, Offset value) {
    final p = [...points];
    p[index] = Offset(value.dx.clamp(0.0, 1.0), value.dy.clamp(0.0, 1.0));
    return DocumentCorners(p[0], p[1], p[2], p[3]);
  }

  bool get isValid {
    final p = points;
    double cross(Offset a, Offset b, Offset c) =>
        (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    final signs = <double>[
      cross(p[0], p[1], p[2]),
      cross(p[1], p[2], p[3]),
      cross(p[2], p[3], p[0]),
      cross(p[3], p[0], p[1]),
    ];
    return signs.every((v) => v.abs() > 0.0001) &&
        (signs.every((v) => v > 0) || signs.every((v) => v < 0));
  }
}

class EdgeDetection {
  const EdgeDetection({
    required this.corners,
    required this.confidence,
    required this.diagnostics,
  });

  final DocumentCorners corners;
  final double confidence;
  final String diagnostics;
}

class ScanOcrResult {
  const ScanOcrResult({
    required this.text,
    this.confidence,
    this.lineCount = 0,
  });
  final String text;
  final double? confidence;
  final int lineCount;
}

class ScanPage {
  const ScanPage({
    required this.id,
    required this.name,
    required this.originalBytes,
    required this.processedBytes,
    required this.corners,
    required this.detectionConfidence,
    required this.diagnostics,
    this.enhancement = ScanEnhancement.original,
    this.rotation = 0,
    this.work = ScanWork.idle,
    this.ocr,
    this.error,
  });

  final String id;
  final String name;
  final Uint8List originalBytes;
  final Uint8List processedBytes;
  final DocumentCorners corners;
  final double detectionConfidence;
  final String diagnostics;
  final ScanEnhancement enhancement;
  final int rotation;
  final ScanWork work;
  final ScanOcrResult? ocr;
  final String? error;

  ScanPage copyWith({
    Uint8List? originalBytes,
    Uint8List? processedBytes,
    DocumentCorners? corners,
    double? detectionConfidence,
    String? diagnostics,
    ScanEnhancement? enhancement,
    int? rotation,
    ScanWork? work,
    ScanOcrResult? ocr,
    bool clearOcr = false,
    String? error,
    bool clearError = false,
  }) {
    return ScanPage(
      id: id,
      name: name,
      originalBytes: originalBytes ?? this.originalBytes,
      processedBytes: processedBytes ?? this.processedBytes,
      corners: corners ?? this.corners,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
      diagnostics: diagnostics ?? this.diagnostics,
      enhancement: enhancement ?? this.enhancement,
      rotation: rotation ?? this.rotation,
      work: work ?? this.work,
      ocr: clearOcr ? null : (ocr ?? this.ocr),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
