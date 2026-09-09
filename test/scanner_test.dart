import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import 'package:swift_staging_log/core/theme.dart';
import 'package:swift_staging_log/data/app_state.dart';
import 'package:swift_staging_log/features/scanner/models/scan_models.dart';
import 'package:swift_staging_log/features/scanner/scanner_controller.dart';
import 'package:swift_staging_log/features/scanner/scanner_screen.dart';
import 'package:swift_staging_log/features/scanner/services/document_processing_service.dart';

Uint8List _fixture({int width = 480, int height = 640}) {
  final image = im.Image(width: width, height: height);
  im.fill(image, color: im.ColorRgb8(45, 55, 65));
  im.fillRect(
    image,
    x1: 55,
    y1: 45,
    x2: width - 45,
    y2: height - 55,
    color: im.ColorRgb8(238, 235, 220),
  );
  for (var y = 100; y < height - 80; y += 32) {
    im.drawLine(
      image,
      x1: 90,
      y1: y,
      x2: width - 90,
      y2: y,
      color: im.ColorRgb8(45, 45, 45),
      thickness: 3,
    );
  }
  return Uint8List.fromList(im.encodeJpg(image, quality: 95));
}

void main() {
  test('corner replacement clamps and rejects crossed quadrilaterals', () {
    final adjusted = DocumentCorners.full.replace(0, const Offset(-1, .2));
    expect(adjusted.topLeft, const Offset(0, .2));
    expect(adjusted.isValid, isTrue);
    const crossed = DocumentCorners(
      Offset(0, 0),
      Offset(1, 1),
      Offset(1, 0),
      Offset(0, 1),
    );
    expect(crossed.isValid, isFalse);
  });

  test('synthetic warehouse form detects and processes deterministically', () {
    final bytes = _fixture();
    final detection = detectDocument(bytes);
    expect(detection.confidence, greaterThan(.15));
    expect(detection.corners.isValid, isTrue);
    // A clean, high-contrast, frame-filling fixture should be a genuine
    // detection, not the hardcoded inset fallback — `isValid` alone is true
    // for both, so it can't tell them apart.
    expect(detection.diagnostics, isNot(contains('fallback=inset')));

    final first = processDocument(
      bytes: bytes,
      corners: detection.corners,
      enhancement: ScanEnhancement.document,
      rotation: 0,
    );
    final second = processDocument(
      bytes: bytes,
      corners: detection.corners,
      enhancement: ScanEnhancement.document,
      rotation: 0,
    );
    expect(first, orderedEquals(second));
    expect(im.decodeImage(first), isNotNull);
  });

  test('detects a smaller, off-center document without falling back', () {
    // Document occupies roughly the left-hand 45% x 55% of the frame,
    // clear of the frame edges on all sides — the kind of casually framed
    // photo that a fixed >=62%-frame-coverage search would miss entirely.
    const width = 480;
    const height = 640;
    final image = im.Image(width: width, height: height);
    im.fill(image, color: im.ColorRgb8(60, 70, 80));
    im.fillRect(
      image,
      x1: 40,
      y1: 60,
      x2: 220,
      y2: 410,
      color: im.ColorRgb8(238, 235, 220),
    );
    for (var y = 110; y < 380; y += 24) {
      im.drawLine(
        image,
        x1: 60,
        y1: y,
        x2: 200,
        y2: y,
        color: im.ColorRgb8(45, 45, 45),
        thickness: 2,
      );
    }
    final bytes = Uint8List.fromList(im.encodeJpg(image, quality: 95));

    final detection = detectDocument(bytes);
    expect(detection.diagnostics, isNot(contains('fallback=inset')));
    expect(detection.confidence, greaterThan(.15));

    final corners = detection.corners.points;
    final maxX = corners.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final minY = corners.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = corners.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    // Detected box should track the actual ~0.08-0.46 x / 0.09-0.64 y
    // document, not the frame-filling 0.04-0.96 fallback rectangle.
    expect(maxX, lessThan(.6));
    expect(minY, lessThan(.2));
    expect(maxY, greaterThan(.35));
    expect(maxY, lessThan(.85));
  });

  test('adaptive threshold preserves a valid high resolution page', () {
    final result = processDocument(
      bytes: _fixture(),
      corners: const DocumentCorners(
        Offset(.1, .08),
        Offset(.92, .08),
        Offset(.9, .92),
        Offset(.12, .92),
      ),
      enhancement: ScanEnhancement.blackAndWhite,
      rotation: 90,
    );
    final decoded = im.decodeImage(result)!;
    expect(decoded.width, greaterThan(300));
    expect(decoded.height, greaterThan(200));
  });

  test('page state supports reorder, delete, and stable exports', () async {
    final controller = ScannerController();
    addTearDown(controller.dispose);
    final bytes = _fixture(width: 160, height: 220);
    await controller.addPhotos([
      (bytes: bytes, name: 'first form.png'),
      (bytes: bytes, name: 'second form.png'),
    ]);
    expect(controller.pages, hasLength(2));
    controller.move(0, 1);
    expect(controller.pages.first.name, 'second form.png');
    expect(
      controller.exportPhotos().first.name,
      startsWith('scan_1_second_form'),
    );
    controller.remove(1);
    expect(controller.pages, hasLength(1));
  });

  testWidgets('manual corner editor is draggable at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var changed = DocumentCorners.full;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSlstTheme(dark: false),
        home: Scaffold(
          body: ManualCornerEditor(
            imageBytes: _fixture(width: 160, height: 220),
            corners: DocumentCorners.full,
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    await tester.dragFrom(const Offset(2, 2), const Offset(35, 45));
    expect(changed.topLeft.dx, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scanner workspace fits phone and exposes explicit close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final photo = (bytes: _fixture(width: 160, height: 220), name: 'form.jpg');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSlstTheme(dark: false),
        home: DocumentScannerScreen(initialPages: <PhotoBytes>[photo]),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('scanner-close')), findsOneWidget);
    expect(find.byKey(const Key('scanner-page-strip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
