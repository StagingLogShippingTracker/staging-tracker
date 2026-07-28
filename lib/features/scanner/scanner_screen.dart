import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../platform/photo_picker.dart';
import 'models/scan_models.dart';
import 'scanner_controller.dart';

Future<List<PhotoBytes>?> showDocumentScanner(
  BuildContext context, {
  List<PhotoBytes> initialPages = const [],
}) {
  return showDialog<List<PhotoBytes>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog.fullscreen(
      child: DocumentScannerScreen(initialPages: initialPages),
    ),
  );
}

class ScanDocumentButton extends StatelessWidget {
  const ScanDocumentButton({
    super.key,
    required this.onScanned,
    this.label = 'Scan document',
  });

  final ValueChanged<List<PhotoBytes>> onScanned;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('scan-document-button'),
      onPressed: () async {
        final pages = await showDocumentScanner(context);
        if (pages != null && pages.isNotEmpty) onScanned(pages);
      },
      icon: const Icon(Icons.document_scanner_outlined),
      label: Text(label),
    );
  }
}

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key, this.initialPages = const []});
  final List<PhotoBytes> initialPages;

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  late final ScannerController _controller;
  final _picker = PhotoPickerService();
  bool _showOriginal = false;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _controller = ScannerController();
    if (widget.initialPages.isNotEmpty) {
      _controller.addPhotos(widget.initialPages);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final photos = defaultTargetPlatform == TargetPlatform.android
        ? await _picker.pickFromGallery()
        : await _picker.pickFiles();
    if (photos.isNotEmpty) await _controller.addPhotos(photos);
  }

  Future<void> _camera({int? replace}) async {
    final photo = await _picker.captureCamera();
    if (photo != null) await _controller.addPhoto(photo, replaceIndex: replace);
  }

  Future<void> _replace() async {
    final index = _controller.selectedIndex;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      await _camera(replace: index);
      return;
    }
    final files = await _picker.pickFiles(max: 1);
    if (files.isNotEmpty) {
      await _controller.addPhoto(files.first, replaceIndex: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final page = _controller.selected;
        return Scaffold(
          appBar: AppBar(
            leading: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.document_scanner, color: SlstColors.brand),
            ),
            title: const Text('SST Document Scanner'),
            actions: [
              const Tooltip(
                message:
                    'Images and OCR stay on this device until you attach them.',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.offline_bolt_outlined,
                    color: SlstColors.green,
                  ),
                ),
              ),
              IconButton(
                key: const Key('scanner-close'),
                tooltip: 'Close scanner',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (page == null) return _emptyWorkspace();
                final narrow = constraints.maxWidth < 760;
                final preview = _preview(page);
                final tools = _tools(page);
                return Column(
                  children: [
                    _pageStrip(),
                    if (page.work != ScanWork.idle)
                      LinearProgressIndicator(
                        key: const Key('scanner-progress'),
                        color: page.work == ScanWork.failed
                            ? SlstColors.danger
                            : SlstColors.brand,
                      ),
                    Expanded(
                      child: narrow
                          ? ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                SizedBox(height: 390, child: preview),
                                const SizedBox(height: 12),
                                tools,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: preview,
                                  ),
                                ),
                                SizedBox(
                                  width: 360,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      0,
                                      16,
                                      16,
                                      16,
                                    ),
                                    child: tools,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          bottomNavigationBar: _bottomBar(),
        );
      },
    );
  }

  Widget _emptyWorkspace() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 72,
                color: SlstColors.brand,
              ),
              const SizedBox(height: 16),
              Text(
                'Scan freight documents',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Perspective correction, document cleanup, and OCR run entirely on this device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (Platform.isAndroid)
                    FilledButton.icon(
                      onPressed: _camera,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Camera'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _addFiles,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      Platform.isAndroid ? 'Gallery' : 'Choose files',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageStrip() {
    return SizedBox(
      height: 92,
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              key: const Key('scanner-page-strip'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: _controller.pages.length,
              onReorderItem: _controller.move,
              itemBuilder: (context, index) {
                final page = _controller.pages[index];
                return Padding(
                  key: ValueKey(page.id),
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _controller.select(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 82,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == _controller.selectedIndex
                              ? SlstColors.brand
                              : Theme.of(context).dividerColor,
                          width: index == _controller.selectedIndex ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(page.processedBytes, fit: BoxFit.cover),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: ColoredBox(
                              color: Colors.black54,
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  'Page ${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Add page',
            onPressed: _addFiles,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
    );
  }

  Widget _preview(ScanPage page) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Colors.black87,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_manual)
            ManualCornerEditor(
              imageBytes: page.originalBytes,
              corners: page.corners,
              onChanged: (corners) {
                setState(() {});
                _pendingCorners = corners;
              },
            )
          else
            InteractiveViewer(
              minScale: .8,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  _showOriginal ? page.originalBytes : page.processedBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  semanticLabel: _showOriginal
                      ? 'Original document'
                      : 'Processed document',
                ),
              ),
            ),
          Positioned(
            left: 10,
            top: 10,
            child: Chip(
              avatar: Icon(
                page.detectionConfidence >= .5
                    ? Icons.check_circle
                    : Icons.warning_amber,
                size: 18,
              ),
              label: Text(
                'Edge confidence ${(page.detectionConfidence * 100).round()}%',
              ),
            ),
          ),
        ],
      ),
    );
  }

  DocumentCorners? _pendingCorners;

  Widget _tools(ScanPage page) {
    final status = switch (page.work) {
      ScanWork.detecting => 'Detecting page edges…',
      ScanWork.processing => 'Processing full-resolution page…',
      ScanWork.recognizing => 'Recognizing text offline…',
      ScanWork.failed => page.error ?? 'Processing failed',
      ScanWork.idle => 'Ready',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(status, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(page.diagnostics, style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 24),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Before')),
            ButtonSegment(value: false, label: Text('After')),
          ],
          selected: {_showOriginal},
          onSelectionChanged: (v) => setState(() => _showOriginal = v.first),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ScanEnhancement>(
          initialValue: page.enhancement,
          decoration: const InputDecoration(labelText: 'Enhancement'),
          items: [
            for (final mode in ScanEnhancement.values)
              DropdownMenuItem(value: mode, child: Text(mode.label)),
          ],
          onChanged: page.work == ScanWork.idle
              ? (mode) {
                  if (mode != null) _controller.setEnhancement(mode);
                }
              : null,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: page.work == ScanWork.idle ? _controller.rotate : null,
              icon: const Icon(Icons.rotate_90_degrees_cw),
              label: const Text('Rotate'),
            ),
            OutlinedButton.icon(
              key: const Key('manual-corners'),
              onPressed: page.work == ScanWork.idle
                  ? () async {
                      if (_manual && _pendingCorners != null) {
                        final corners = _pendingCorners!;
                        setState(() {
                          _manual = false;
                          _pendingCorners = null;
                        });
                        await _controller.setCorners(corners);
                      } else {
                        setState(() {
                          _manual = true;
                          _pendingCorners = page.corners;
                        });
                      }
                    }
                  : null,
              icon: Icon(_manual ? Icons.check : Icons.crop_free),
              label: Text(_manual ? 'Apply corners' : 'Adjust corners'),
            ),
            OutlinedButton.icon(
              onPressed: page.work == ScanWork.idle ? _replace : null,
              icon: const Icon(Icons.replay),
              label: const Text('Replace'),
            ),
            IconButton(
              tooltip: 'Delete page',
              onPressed: page.work == ScanWork.idle
                  ? () => _controller.remove(_controller.selectedIndex)
                  : null,
              icon: const Icon(Icons.delete_outline, color: SlstColors.danger),
            ),
          ],
        ),
        const Divider(height: 24),
        FilledButton.icon(
          key: const Key('run-ocr'),
          onPressed: page.work == ScanWork.idle ? _controller.runOcr : null,
          icon: const Icon(Icons.text_snippet_outlined),
          label: Text(
            page.ocr == null ? 'Run offline OCR' : 'Re-run offline OCR',
          ),
        ),
        if (page.ocr != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  page.ocr!.confidence == null
                      ? '${page.ocr!.lineCount} text lines'
                      : '${page.ocr!.lineCount} lines • ${(page.ocr!.confidence! * 100).round()}% confidence',
                ),
              ),
              IconButton(
                tooltip: 'Copy recognized text',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: page.ocr!.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recognized text copied')),
                  );
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                page.ocr!.text.isEmpty ? 'No text recognized.' : page.ocr!.text,
              ),
            ),
          ),
        ],
        if (page.error != null) ...[
          const SizedBox(height: 10),
          Text(page.error!, style: const TextStyle(color: SlstColors.danger)),
        ],
      ],
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Private by design: scanning and OCR stay on this device.',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('scanner-use-pages'),
              onPressed: _controller.pages.isEmpty || _controller.isBusy
                  ? null
                  : () => Navigator.pop(context, _controller.exportPhotos()),
              icon: const Icon(Icons.check),
              label: Text(
                'Use ${_controller.pages.length} page${_controller.pages.length == 1 ? '' : 's'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManualCornerEditor extends StatefulWidget {
  const ManualCornerEditor({
    super.key,
    required this.imageBytes,
    required this.corners,
    required this.onChanged,
  });

  final Uint8List imageBytes;
  final DocumentCorners corners;
  final ValueChanged<DocumentCorners> onChanged;

  @override
  State<ManualCornerEditor> createState() => _ManualCornerEditorState();
}

class _ManualCornerEditorState extends State<ManualCornerEditor> {
  late DocumentCorners corners = widget.corners;
  int? active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        int nearest(Offset position) {
          var result = 0;
          var distance = double.infinity;
          for (var i = 0; i < corners.points.length; i++) {
            final p = Offset(
              corners.points[i].dx * size.width,
              corners.points[i].dy * size.height,
            );
            final d = (p - position).distanceSquared;
            if (d < distance) {
              result = i;
              distance = d;
            }
          }
          return result;
        }

        return GestureDetector(
          key: const Key('corner-editor'),
          onPanStart: (details) => active = nearest(details.localPosition),
          onPanUpdate: (details) {
            if (active == null) return;
            final next = corners.replace(
              active!,
              Offset(
                details.localPosition.dx / size.width,
                details.localPosition.dy / size.height,
              ),
            );
            if (!next.isValid) return;
            setState(() => corners = next);
            widget.onChanged(next);
          },
          onPanEnd: (_) => active = null,
          child: CustomPaint(
            foregroundPainter: _CornerPainter(corners),
            child: SizedBox.expand(
              child: Image.memory(widget.imageBytes, fit: BoxFit.fill),
            ),
          ),
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.corners);
  final DocumentCorners corners;

  @override
  void paint(Canvas canvas, Size size) {
    final points = corners.points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = SlstColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (final point in points) {
      canvas.drawCircle(point, 13, Paint()..color = Colors.white);
      canvas.drawCircle(point, 9, Paint()..color = SlstColors.brand);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.corners != corners;
}
