import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_state.dart';
import 'models/scan_models.dart';
import 'services/document_processing_service.dart';
import 'services/offline_ocr_service.dart';

class ScannerController extends ChangeNotifier {
  ScannerController({
    DocumentProcessingService? processing,
    OfflineOcrService? ocr,
  }) : _processing = processing ?? DocumentProcessingService(),
       _ocr = ocr ?? OfflineOcrService();

  final DocumentProcessingService _processing;
  final OfflineOcrService _ocr;
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
      final detection = await _processing.detect(photo.bytes);
      _pages[index] = _pages[index].copyWith(
        corners: detection.corners,
        detectionConfidence: detection.confidence,
        diagnostics: detection.diagnostics,
        work: ScanWork.processing,
        clearError: true,
      );
      _notify();
      await _reprocess(index);
    } catch (error) {
      _pages[index] = _pages[index].copyWith(
        work: ScanWork.failed,
        error: error.toString(),
      );
      _notify();
    }
  }

  void select(int index) {
    selectedIndex = index.clamp(0, _pages.length - 1);
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
    );
    _notify();
    await _reprocess(index);
  }

  Future<void> _reprocess(int index) async {
    final page = _pages[index];
    try {
      // Fast path: original framing with no rotation skips heavy warp/enhance.
      final skipWarp = page.enhancement == ScanEnhancement.original &&
          page.rotation == 0 &&
          page.corners == DocumentCorners.full;
      final bytes = skipWarp
          ? page.originalBytes
          : await _processing.process(
              bytes: page.originalBytes,
              corners: page.corners,
              enhancement: page.enhancement,
              rotation: page.rotation,
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
          error: error.toString(),
        );
      }
    }
    _notify();
  }

  Future<void> runOcr() async {
    final page = selected;
    if (page == null) return;
    final index = selectedIndex;
    _pages[index] = page.copyWith(work: ScanWork.recognizing, clearError: true);
    _notify();
    try {
      final result = await _ocr.recognize(page.processedBytes);
      if (index >= _pages.length || _pages[index].id != page.id) return;
      _pages[index] = _pages[index].copyWith(
        ocr: result,
        work: ScanWork.idle,
        clearError: true,
      );
    } catch (error) {
      if (index < _pages.length && _pages[index].id == page.id) {
        final message = error.toString();
        final friendly = message.contains('NOT_INITIALIZED') ||
                message.contains('Windows OCR language is not installed')
            ? 'Offline OCR is unavailable. Install English OCR: '
                'Settings → Time & language → Language & region → '
                'Add English (United States) → Options → Optical character recognition.'
            : 'OCR failed: $message';
        _pages[index] = _pages[index].copyWith(
          work: ScanWork.failed,
          error: friendly,
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
    _ocr.dispose();
    super.dispose();
  }
}
