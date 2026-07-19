import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as im;

import '../models/scan_models.dart';

class ProcessedDocument {
  const ProcessedDocument(this.bytes, this.detection);
  final Uint8List bytes;
  final EdgeDetection detection;
}

class DocumentProcessingService {
  Future<EdgeDetection> detect(Uint8List bytes) =>
      Isolate.run(() => detectDocument(bytes));

  Future<Uint8List> process({
    required Uint8List bytes,
    required DocumentCorners corners,
    required ScanEnhancement enhancement,
    required int rotation,
  }) => Isolate.run(
    () => processDocument(
      bytes: bytes,
      corners: corners,
      enhancement: enhancement,
      rotation: rotation,
    ),
  );
}

EdgeDetection detectDocument(Uint8List bytes) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('The selected file is not a supported image.');
  }
  final source = im.bakeOrientation(decoded);
  final scale = math.min(1.0, 640 / math.max(source.width, source.height));
  final image = scale < 1
      ? im.copyResize(
          source,
          width: math.max(1, (source.width * scale).round()),
          height: math.max(1, (source.height * scale).round()),
          interpolation: im.Interpolation.average,
        )
      : source;
  final w = image.width;
  final h = image.height;
  final gray = Uint8List(w * h);
  var mean = 0.0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final value = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
      gray[y * w + x] = value;
      mean += value;
    }
  }
  mean /= w * h;

  final col = List<double>.filled(w, 0);
  final row = List<double>.filled(h, 0);
  var edgeMean = 0.0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final gx =
          (gray[(y - 1) * w + x + 1] +
                  2 * gray[y * w + x + 1] +
                  gray[(y + 1) * w + x + 1] -
                  gray[(y - 1) * w + x - 1] -
                  2 * gray[y * w + x - 1] -
                  gray[(y + 1) * w + x - 1])
              .abs();
      final gy =
          (gray[(y + 1) * w + x - 1] +
                  2 * gray[(y + 1) * w + x] +
                  gray[(y + 1) * w + x + 1] -
                  gray[(y - 1) * w + x - 1] -
                  2 * gray[(y - 1) * w + x] -
                  gray[(y - 1) * w + x + 1])
              .abs();
      final strength = (gx + gy).toDouble();
      col[x] += strength;
      row[y] += strength;
      edgeMean += strength;
    }
  }
  edgeMean /= math.max(1, (w - 2) * (h - 2));

  int strongest(List<double> values, int start, int end) {
    var best = start;
    var score = -1.0;
    for (
      var i = math.max(1, start);
      i < math.min(values.length - 1, end);
      i++
    ) {
      final smoothed = values[i - 1] + 2 * values[i] + values[i + 1];
      if (smoothed > score) {
        score = smoothed;
        best = i;
      }
    }
    return best;
  }

  final left = strongest(col, (w * .02).round(), (w * .38).round());
  final right = strongest(col, (w * .62).round(), (w * .98).round());
  final top = strongest(row, (h * .02).round(), (h * .38).round());
  final bottom = strongest(row, (h * .62).round(), (h * .98).round());

  ({double slope, double intercept, double fit}) fitVertical(int center) {
    final samples = <Offset>[];
    final radius = math.max(6, (w * .12).round());
    for (var y = top; y <= bottom; y += math.max(3, h ~/ 80)) {
      var bestX = center;
      var best = -1;
      for (
        var x = math.max(2, center - radius);
        x < math.min(w - 2, center + radius);
        x++
      ) {
        final strength = (gray[y * w + x + 1] - gray[y * w + x - 1]).abs();
        if (strength > best) {
          best = strength;
          bestX = x;
        }
      }
      samples.add(Offset(y.toDouble(), bestX.toDouble()));
    }
    return _linearFit(samples);
  }

  ({double slope, double intercept, double fit}) fitHorizontal(int center) {
    final samples = <Offset>[];
    final radius = math.max(6, (h * .12).round());
    for (var x = left; x <= right; x += math.max(3, w ~/ 80)) {
      var bestY = center;
      var best = -1;
      for (
        var y = math.max(2, center - radius);
        y < math.min(h - 2, center + radius);
        y++
      ) {
        final strength = (gray[(y + 1) * w + x] - gray[(y - 1) * w + x]).abs();
        if (strength > best) {
          best = strength;
          bestY = y;
        }
      }
      samples.add(Offset(x.toDouble(), bestY.toDouble()));
    }
    return _linearFit(samples);
  }

  Offset intersect(
    ({double slope, double intercept, double fit}) vertical,
    ({double slope, double intercept, double fit}) horizontal,
  ) {
    final denominator = 1 - vertical.slope * horizontal.slope;
    if (denominator.abs() < .01) {
      return Offset(vertical.intercept, horizontal.intercept);
    }
    final x =
        (vertical.slope * horizontal.intercept + vertical.intercept) /
        denominator;
    return Offset(x, horizontal.slope * x + horizontal.intercept);
  }

  final leftLine = fitVertical(left);
  final rightLine = fitVertical(right);
  final topLine = fitHorizontal(top);
  final bottomLine = fitHorizontal(bottom);
  final area = ((right - left) * (bottom - top)) / (w * h);
  final boundaryStrength =
      (col[left] + col[right]) / (2 * math.max(1, h)) +
      (row[top] + row[bottom]) / (2 * math.max(1, w));
  final contrastScore = (boundaryStrength / math.max(1, edgeMean * 3)).clamp(
    0.0,
    1.0,
  );
  final areaScore = ((area - .18) / .55).clamp(0.0, 1.0);
  final confidence = (.65 * contrastScore + .35 * areaScore).clamp(0.0, 1.0);
  final safe =
      confidence < .18 || right - left < w * .25 || bottom - top < h * .25;
  final detectedCorners = DocumentCorners(
    _normalize(intersect(leftLine, topLine), w, h),
    _normalize(intersect(rightLine, topLine), w, h),
    _normalize(intersect(rightLine, bottomLine), w, h),
    _normalize(intersect(leftLine, bottomLine), w, h),
  );
  final linesFit =
      (leftLine.fit + rightLine.fit + topLine.fit + bottomLine.fit) / 4;
  final corners = safe || !detectedCorners.isValid || linesFit < .08
      ? const DocumentCorners(
          Offset(.04, .04),
          Offset(.96, .04),
          Offset(.96, .96),
          Offset(.04, .96),
        )
      : detectedCorners;
  return EdgeDetection(
    corners: corners,
    confidence: confidence,
    diagnostics:
        'edge=${edgeMean.toStringAsFixed(1)}, boundary=${boundaryStrength.toStringAsFixed(1)}, '
        'coverage=${(area * 100).toStringAsFixed(0)}%, luminance=${mean.toStringAsFixed(0)}'
        ', line-fit=${(linesFit * 100).toStringAsFixed(0)}%'
        '${safe || corners != detectedCorners ? ', fallback=inset' : ''}',
  );
}

({double slope, double intercept, double fit}) _linearFit(
  List<Offset> samples,
) {
  if (samples.length < 2) return (slope: 0, intercept: 0, fit: 0);
  final meanX = samples.fold(0.0, (sum, p) => sum + p.dx) / samples.length;
  final meanY = samples.fold(0.0, (sum, p) => sum + p.dy) / samples.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (final p in samples) {
    covariance += (p.dx - meanX) * (p.dy - meanY);
    variance += math.pow(p.dx - meanX, 2);
  }
  final slope = variance == 0 ? 0.0 : covariance / variance;
  final intercept = meanY - slope * meanX;
  final error =
      samples.fold(
        0.0,
        (sum, p) => sum + (p.dy - (slope * p.dx + intercept)).abs(),
      ) /
      samples.length;
  final fit = (1 - error / 40).clamp(0.0, 1.0);
  return (slope: slope, intercept: intercept, fit: fit);
}

Offset _normalize(Offset point, int width, int height) => Offset(
  (point.dx / width).clamp(0.0, 1.0),
  (point.dy / height).clamp(0.0, 1.0),
);

Uint8List processDocument({
  required Uint8List bytes,
  required DocumentCorners corners,
  required ScanEnhancement enhancement,
  required int rotation,
}) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unable to decode image.');
  var source = im.bakeOrientation(decoded);
  final points = corners.points
      .map((p) => Offset(p.dx * (source.width - 1), p.dy * (source.height - 1)))
      .toList();
  final topWidth = (points[1] - points[0]).distance;
  final bottomWidth = (points[2] - points[3]).distance;
  final leftHeight = (points[3] - points[0]).distance;
  final rightHeight = (points[2] - points[1]).distance;
  final outW = math.max(64, math.max(topWidth, bottomWidth).round());
  final outH = math.max(64, math.max(leftHeight, rightHeight).round());
  source = _perspectiveWarp(source, points, outW, outH);

  final turns = ((rotation ~/ 90) % 4 + 4) % 4;
  for (var i = 0; i < turns; i++) {
    source = im.copyRotate(source, angle: 90);
  }
  final enhanced = _enhance(source, enhancement);
  return Uint8List.fromList(im.encodeJpg(enhanced, quality: 92));
}

im.Image _perspectiveWarp(
  im.Image source,
  List<Offset> src,
  int width,
  int height,
) {
  final dst = <Offset>[
    Offset.zero,
    Offset((width - 1).toDouble(), 0),
    Offset((width - 1).toDouble(), (height - 1).toDouble()),
    Offset(0, (height - 1).toDouble()),
  ];
  final h = _homography(dst, src);
  final output = im.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final d = h[6] * x + h[7] * y + 1;
      final sx = (h[0] * x + h[1] * y + h[2]) / d;
      final sy = (h[3] * x + h[4] * y + h[5]) / d;
      final ix = sx.round().clamp(0, source.width - 1);
      final iy = sy.round().clamp(0, source.height - 1);
      final p = source.getPixel(ix, iy);
      output.setPixelRgb(x, y, p.r, p.g, p.b);
    }
  }
  return output;
}

List<double> _homography(List<Offset> from, List<Offset> to) {
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final x = from[i].dx;
    final y = from[i].dy;
    final u = to[i].dx;
    final v = to[i].dy;
    a[i * 2] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
    a[i * 2 + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
  }
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var row = col + 1; row < 8; row++) {
      if (a[row][col].abs() > a[pivot][col].abs()) pivot = row;
    }
    final swap = a[col];
    a[col] = a[pivot];
    a[pivot] = swap;
    final divisor = a[col][col];
    if (divisor.abs() < 1e-9) return [1, 0, 0, 0, 1, 0, 0, 0];
    for (var j = col; j < 9; j++) {
      a[col][j] /= divisor;
    }
    for (var row = 0; row < 8; row++) {
      if (row == col) continue;
      final factor = a[row][col];
      for (var j = col; j < 9; j++) {
        a[row][j] -= factor * a[col][j];
      }
    }
  }
  return List.generate(8, (i) => a[i][8]);
}

im.Image _enhance(im.Image source, ScanEnhancement mode) {
  if (mode == ScanEnhancement.original) return source;
  final output = im.Image.from(source);
  final w = output.width;
  final h = output.height;
  final gray = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = output.getPixel(x, y);
      gray[y * w + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
    }
  }
  final integral = List<int>.filled((w + 1) * (h + 1), 0);
  for (var y = 1; y <= h; y++) {
    var sum = 0;
    for (var x = 1; x <= w; x++) {
      sum += gray[(y - 1) * w + x - 1];
      integral[y * (w + 1) + x] = integral[(y - 1) * (w + 1) + x] + sum;
    }
  }
  int localMean(int x, int y, int radius) {
    final x0 = math.max(0, x - radius);
    final y0 = math.max(0, y - radius);
    final x1 = math.min(w - 1, x + radius);
    final y1 = math.min(h - 1, y + radius);
    final stride = w + 1;
    final total =
        integral[(y1 + 1) * stride + x1 + 1] -
        integral[y0 * stride + x1 + 1] -
        integral[(y1 + 1) * stride + x0] +
        integral[y0 * stride + x0];
    return total ~/ ((x1 - x0 + 1) * (y1 - y0 + 1));
  }

  final radius = math.max(8, math.min(w, h) ~/ 40);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = source.getPixel(x, y);
      final g = gray[y * w + x];
      final local = localMean(x, y, radius);
      if (mode == ScanEnhancement.blackAndWhite) {
        final v = g < local - 10 ? 0 : 255;
        output.setPixelRgb(x, y, v, v, v);
      } else if (mode == ScanEnhancement.grayscale) {
        final v = ((g - local) * 1.15 + 224).round().clamp(0, 255);
        output.setPixelRgb(x, y, v, v, v);
      } else {
        final correction = 225 - local;
        final contrast = mode == ScanEnhancement.document ? 1.12 : 1.05;
        int clean(num value) =>
            ((value + correction) * contrast - (contrast - 1) * 128)
                .round()
                .clamp(0, 255);
        output.setPixelRgb(x, y, clean(p.r), clean(p.g), clean(p.b));
      }
    }
  }
  return mode == ScanEnhancement.document ||
          mode == ScanEnhancement.blackAndWhite
      ? im.convolution(
          output,
          filter: [-1, -1, -1, -1, 9, -1, -1, -1, -1],
          div: 1,
        )
      : output;
}
