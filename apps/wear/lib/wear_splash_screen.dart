import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Wear's load/splash screen — shown by [SlstWearApp] while [WearStartup.ready]
/// is unresolved, then swapped for [_AuthGate]. Same idea as the phone app's
/// `WindowsSplashScreen`/`AndroidSplashScreen` (icon, real progress, held
/// until Supabase data is ready) but stripped down for a small round/square
/// face: no wordmark, no briysce-apps signature, no product-name text —
/// just the icon and a thin progress bar, kept well inside the safe circular
/// area so nothing clips on a round watch.
class WearSplashScreen extends StatelessWidget {
  const WearSplashScreen({super.key, this.progress});

  /// 0–1, or null for an indeterminate bar (no reliable progress signal yet).
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WearTheme.base,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(56 * 0.222),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/swift-staging-log-app-icon.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 120,
                child: progress == null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Color(0x1FFFFFFF),
                          color: WearTheme.accent,
                        ),
                      )
                    : ValueListenableBuilder<double>(
                        valueListenable: progress!,
                        builder: (context, value, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: value <= 0 ? null : value,
                              minHeight: 3,
                              backgroundColor: const Color(0x1FFFFFFF),
                              color: WearTheme.accent,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
