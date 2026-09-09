import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_log/data/app_state.dart';
import 'package:swift_staging_log/features/shell/windows_splash_screen.dart';

Future<void> _loadFont(String family, String assetPath) async {
  final data = await File(assetPath).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(data.buffer)));
  await loader.load();
}

/// Renders the Windows-only splash/loading screen and writes a PNG for
/// visual review — mirrors Swift Document Generator's
/// generate_windows_splash_preview_test.dart pattern so both apps' splash
/// screens can be sanity-checked the same way. Not a regression test (the
/// widget has no asserted behavior beyond "it builds"); run manually when
/// the splash design changes.
///
/// Every real dart:io / async-decode step (font loading, the SVG
/// wordmark's decode, and the final PNG write) is wrapped in
/// `tester.runAsync()` — outside of it, `flutter_test`'s fake clock never
/// lets real I/O futures resolve and the test hangs forever.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generate Windows splash screen preview', (tester) async {
    final key = GlobalKey();
    await tester.runAsync(() async {
      await _loadFont('Oswald', 'assets/fonts/Oswald-SemiBold.ttf');
      await _loadFont('Montserrat', 'assets/fonts/Montserrat-Bold.ttf');
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Never a real Supabase round-trip for a screenshot test — the
          // splash's real progress ticks (see AppDataNotifier) stay at 0,
          // which renders as the same indeterminate bar as before.
          appDataProvider.overrideWith(
            (ref) => AppDataNotifier(ref, initialize: false),
          ),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const WindowsSplashScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    // Let the SVG wordmark's async decode settle for real. The progress
    // bar is intentionally indeterminate/continuously animating, so
    // pumpAndSettle() would hang forever here — plain timed pumps only.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    // Land mid-cycle in the indeterminate bar's ~1.8s animation so the
    // preview frame shows a representative wide segment instead of the
    // sliver present at frame 0.
    await tester.pump(const Duration(milliseconds: 600));

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    late File outFile;
    await tester.runAsync(() async {
      final outDir = Directory('qa_windows_splash_preview');
      await outDir.create(recursive: true);
      outFile = File(
        '${outDir.path}${Platform.pathSeparator}windows_splash_preview_latest.png',
      );
      await outFile.writeAsBytes(bytes!.buffer.asUint8List());
    });

    // ignore: avoid_print
    print('Wrote Windows splash preview:\n  ${outFile.absolute.path}');
    expect(outFile.existsSync(), isTrue);

    // Swap away the splash screen's perpetually-repeating indeterminate
    // progress animation before the test ends — otherwise flutter_test's
    // teardown spends a long real-world time settling a Ticker that never
    // naturally stops, slowing down every future full-suite run.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
