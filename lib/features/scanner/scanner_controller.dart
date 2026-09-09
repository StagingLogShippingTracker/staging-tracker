import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_state.dart';
import 'models/scan_models.dart';
import 'services/document_processing_service.dart';
import 'services/offline_ocr_service.dart';

/// Ceiling on each pipeline stage so a stalled native call or pathological
/// image leaves a page in "failed" (retryable) rather than stuck spinning.
const _detectTimeout = Duration(seconds: 20);
const _processTimeout = Duration(seconds: 30);
const _recognizeTimeout = Duration(seconds: 30);

class ScannerController extends ChangeNotifier {
  ScannerController({
    DocumentProcessingService? processing,
    OfflineOcrService? ocr,
  }) : _processing = processing ?? DocumentProcessingService(),
       _ocr = ocr ?? OfflineOcrService();

  final DocumentProcessingService _processing;
  final OfflineOcrService _ocr;
  final Set<Timer> _timers = {};

  /// Like [Future.timeout], but the underlying [Timer] is tracked and
  /// force-cancelled on [dispose] instead of lingering (harmlessly, but
  /// noisily in tests) until it would have fired.
  Future<T> _withTimeout<T>(Future<T> future, Duration duration) {
    final completer = Completer<T>();
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Timed out after $duration'),
        );
      }
    });
    _timers.add(timer);
    future.then(
      (value) {
        timer.cancel();
        _timers.remove(timer);
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        timer.cancel();
        _timers.remove(timer);
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    return completer.future;
  }
  final List<ScanPage> _pages = [];
  bool _disposed = false;
  int selectedIndex = 0;

  List<ScanPage> get pages => List.unmodifiable(_pages);
  ScanPage? get selected =>
      _pages.isEmpty ? null : _pages[selectedIndex.clamp(0, _pages.length - 1)];
  bool get isBusy => _pages.any(
    (p) =>
        p.work == ScanWork.detecting ||
        p.work == ScanWork.processing ||
        p.work == ScanWork.recognizing,
  );

  Future<void> addPhotos(List<PhotoBytes> photos) async {
    // Detect edges in parallel; process each page after its detection finishes.
    await Future.wait(photos.map(addPhoto));
  }

  Future<void> addPhoto(PhotoBytes photo, {int? replaceIndex}) async {
    final page = ScanPage(
      id: const Uuid().v4(),
      name: photo.name,
      originalBytes: photo.bytes,
      processedBytes: photo.bytes,
      corners: DocumentCorners.full,
      detectionConfidence: 0,
      diagnostics: 'Detection pending',
      work: ScanWork.detecting,
    );
    final index = replaceIndex ?? _pages.length;
    if (replaceIndex == null) {
      _pages.add(page);
    } else {
      _pages[index] = page;
    }
    selectedIndex = index;
    _notify();
    try {
      final detection =
          await _withTimeout(_processing.detect(photo.bytes), _detectTimeout);
      _pages[index] = _pages[index].copyWith(
        corners: detection.corners,
        detectionConfidence: detection.confidence,
        diagnostics: detection.diagnostics,
        work: ScanWork.processing,
        clearError: true,
        clearFailedFrom: true,
      );
      _notify();
      await _reprocess(index);
    } catch (error) {
      if (index >= _pages.length || _pages[index].id != page.id) return;
      _pages[index] = _pages[index].copyWith(
        work: ScanWork.failed,
        failedFrom: ScanWork.detecting,
        error: _friendlyError(error, ScanWork.detecting),
      );
      _notify();
    }
  }

  /// Re-runs whichever stage failed, without redoing already-successful work.
  Future<void> retry() async {
    final page = selected;
    if (page == null) return;
    switch (page.failedFrom) {
      case ScanWork.detecting:
        await addPhoto(
          (bytes: page.originalBytes, name: page.name),
          replaceIndex: selectedIndex,
        );
      case ScanWork.recognizing:
        await runOcr();
      case ScanWork.processing:
      default:
        await _reprocess(selectedIndex);
    }
  }

  void select(int index) {
    selectedIndex = _pages.isEmpty ? 0 : index.clamp(0, _pages.length - 1);
    _notify();
  }

  Future<void> setCorners(DocumentCorners corners) async {
    if (!corners.isValid || selected == null) return;
    final index = selectedIndex;
    _pages[index] = _pages[index].copyWith(
      corners: corners,
      work: ScanWork.processing,
      clearOcr: true,
      clearError: true,
      clearFailedFrom: true,
    );
    _notify();
    await _reprocess(index);
  }

  Future<void> setEnhancement(ScanEnhancement enhancement) async {
    if (selected == null || selected!.enhancement == enhancement) return;
    final index = selectedIndex;
    _pages[index] = _pages[index].copyWith(
      enhancement: enhancement,
      work: ScanWork.processing,
      clearOcr: true,
      clearError: true,
      clearFailedFrom: true,
    );
    _notify();
    await _reprocess(index);
  }

  Future<void> rotate() async {
    if (selected == null) return;
    final index = selectedIndex;
    _pages[index] = _pages[index].copyWith(
      rotation: (selected!.rotation + 90) % 360,
      work: ScanWork.processing,
      clearOcr: true,
      clearError: true,
      clearFailedFrom: true,
    );
    _notify();
    await _reprocess(index);
  }

  Future<void> _reprocess(int index) async {
    final page = _pages[index];
    _pages[index] = page.copyWith(
      work: ScanWork.processing,
      clearError: true,
      clearFailedFrom: true,
    );
    _notify();
    try {
      // Fast path: original framing with no rotation skips heavy warp/enhance.
      final skipWarp = page.enhancement == ScanEnhancement.original &&
          page.rotation == 0 &&
          page.corners == DocumentCorners.full;
      final bytes = skipWarp
          ? page.originalBytes
          : await _withTimeout(
              _processing.process(
                bytes: page.originalBytes,
                corners: page.corners,
                enhancement: page.enhancement,
                rotation: page.rotation,
              ),
              _processTimeout,
            );
      if (index >= _pages.length || _pages[index].id != page.id) return;
      _pages[index] = _pages[index].copyWith(
        processedBytes: bytes,
        work: ScanWork.idle,
        clearError: true,
      );
    } catch (error) {
      if (index < _pages.length && _pages[index].id == page.id) {
        _pages[index] = _pages[index].copyWith(
          work: ScanWork.failed,
          failedFrom: ScanWork.processing,
          error: _friendlyError(error, ScanWork.processing),
        );
      }
    }
    _notify();
  }

  Future<void> runOcr() async {
    final page = selected;
    if (page == null) return;
    final index = selectedIndex;
    _pages[index] = page.copyWith(
      work: ScanWork.recognizing,
      clearError: true,
      clearFailedFrom: true,
    );
    _notify();
    try {
      final result = await _withTimeout(
        _ocr.recognize(page.processedBytes),
        _recognizeTimeout,
      );
      if (index >= _pages.length || _pages[index].id != page.id) return;
      _pages[index] = _pages[index].copyWith(
        ocr: result,
        work: ScanWork.idle,
        clearError: true,
      );
    } catch (error) {
      if (index < _pages.length && _pages[index].id == page.id) {
        _pages[index] = _pages[index].copyWith(
          work: ScanWork.failed,
          failedFrom: ScanWork.recognizing,
          error: _friendlyError(error, ScanWork.recognizing),
        );
      }
    }
    _notify();
  }

  void remove(int index) {
    _pages.removeAt(index);
    selectedIndex = selectedIndex.clamp(
      0,
      _pages.isEmpty ? 0 : _pages.length - 1,
    );
    _notify();
  }

  void move(int oldIndex, int newIndex) {
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
    selectedIndex = _pages.indexOf(page);
    _notify();
  }

  List<PhotoBytes> exportPhotos() => [
    for (var i = 0; i < _pages.length; i++)
      (
        bytes: Uint8List.fromList(_pages[i].processedBytes),
        name: 'scan_${i + 1}_${_safeName(_pages[i].name)}.jpg',
      ),
  ];

  static String _safeName(String name) {
    final stem = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return stem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _ocr.dispose();
    super.dispose();
  }
}

/// Readable error text for a failed pipeline stage, including a timeout hint
/// and the existing "OCR language not installed" guidance for Windows.
String _friendlyError(Object error, ScanWork stage) {
  if (error is TimeoutException) {
    final what = switch (stage) {
      ScanWork.detecting => 'Detecting the document edges',
      ScanWork.processing => 'Processing the image',
      ScanWork.recognizing => 'Recognizing text',
      _ => 'This step',
    };
    return '$what took too long and was cancelled. Tap Retry to try again.';
  }
  final message = error.toString();
  if (stage == ScanWork.recognizing &&
      (message.contains('NOT_INITIALIZED') ||
          message.contains('Windows OCR language is not installed'))) {
    return 'Offline OCR is unavailable. Install English OCR: '
        'Settings → Time & language → Language & region → '
        'Add English (United States) → Options → Optical character recognition.';
  }
  final what = switch (stage) {
    ScanWork.detecting => 'Detection failed',
    ScanWork.processing => 'Processing failed',
    ScanWork.recognizing => 'OCR failed',
    _ => 'Failed',
  };
  return '$what: $message';
}
