import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding.dart';
import '../../core/briysce_apps_logo.dart';
import '../../data/app_state.dart';

/// Windows-only load/splash screen — shown by [SlstApp] until
/// `windowsSplashGateProvider` resolves (initial staging+shipped load
/// plus a brief 100% progress settle), then swapped for the routed app.
///
/// Android/Wear do not get this widget: they keep their existing native
/// launch screen, just held open longer by `main()` awaiting the same
/// initial-load signal (see `deferFirstFrame`/`allowFirstFrame` in
/// `lib/main.dart` and `apps/wear/lib/main.dart`).
///
/// Layout, colors, typography, the standalone Swift mark above the app
/// icon, the real (not fake) progress bar, and the briysce-apps signature
/// below all match Swift Document Generator's Windows splash screen
/// exactly — only the app icon/name differ.
class WindowsSplashScreen extends ConsumerWidget {
  const WindowsSplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.read(appDataProvider.notifier).initialLoadProgress;
    return Scaffold(
      backgroundColor: const Color(0xFF14161A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SwiftMark(),
                const SizedBox(height: 22),
                const _AppIcon(),
                const SizedBox(height: 30),
                const Text(
                  kProductName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Oswald',
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 44),
                SizedBox(
                  width: 260,
                  child: ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: value <= 0 ? null : value,
                          minHeight: 4,
                          backgroundColor: const Color(0x1FFFFFFF),
                          color: const Color(0xFFCE4E30),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Loading your workspace…',
                  style: TextStyle(
                    fontFamily: 'Oswald',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 64),
                const BriysceAppsLockup(width: 112),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small standalone Swift Supply brand mark shown above the app icon —
/// same non-overlapping placement as Swift Document Generator's splash
/// (an earlier revision of this screen overlapped it as a badge on the
/// icon's corner; that was superseded).
///
/// Uses the flat solid-orange lockup with no shadow/box (the same asset
/// [SwiftChromeLogo] uses for app chrome), drawn as a plain [Image.asset]
/// with no wrapping decoration — the PNG's own alpha channel is fully
/// transparent outside the ink, so nothing paints behind it except the
/// splash background.
class _SwiftMark extends StatelessWidget {
  const _SwiftMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/swift_supply_logo_orange_solid.png',
      width: 96,
      fit: BoxFit.contain,
    );
  }
}

/// The Swift Staging & Shipping Log app icon — plain rounded square with a
/// drop shadow, no overlapping badge (see [_SwiftMark] above it instead).
class _AppIcon extends StatelessWidget {
  const _AppIcon();

  static const _iconSize = 132.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_iconSize * 0.222),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Image.asset(
        'assets/swift-staging-log-app-icon.png',
        width: _iconSize,
        height: _iconSize,
        fit: BoxFit.contain,
      ),
    );
  }
}
