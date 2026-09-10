import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding.dart';
import '../../core/briysce_apps_logo.dart';
import '../../data/app_state.dart';

/// Android-only load/splash screen — shown by [SlstApp] until
/// `appSplashGateProvider` resolves (initial staging+shipped load plus a
/// brief 100% progress settle), then swapped for the routed app.
///
/// Same layout, colors, typography, standalone Swift mark, real progress
/// bar, and briysce-apps signature as [WindowsSplashScreen] — sized down for
/// a phone screen instead of a desktop window. Android's native
/// `launch_background.xml` still shows for the brief pre-engine-init flash
/// every Flutter app has; this widget takes over the instant the first
/// Flutter frame paints and holds until data is ready, so there is no gap
/// where the app looks like it has finished loading but hasn't.
class AndroidSplashScreen extends ConsumerWidget {
  const AndroidSplashScreen({super.key});

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
                const SizedBox(height: 18),
                const _AppIcon(),
                const SizedBox(height: 24),
                const Text(
                  kProductName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Oswald',
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 220,
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
                const SizedBox(height: 12),
                Text(
                  'Loading your workspace…',
                  style: TextStyle(
                    fontFamily: 'Oswald',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 48),
                const BriysceAppsLockup(width: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standalone Swift Supply brand mark above the app icon — see
/// [WindowsSplashScreen]'s `_SwiftMark` for why it is drawn plain with no
/// wrapping decoration.
class _SwiftMark extends StatelessWidget {
  const _SwiftMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/swift_supply_logo_orange_solid.png',
      width: 80,
      fit: BoxFit.contain,
    );
  }
}

/// The Swift Staging & Shipping Log app icon, sized for a phone splash.
class _AppIcon extends StatelessWidget {
  const _AppIcon();

  static const _iconSize = 108.0;

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
            blurRadius: 22,
            offset: const Offset(0, 10),
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
