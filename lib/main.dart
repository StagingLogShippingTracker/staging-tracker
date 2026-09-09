import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/branding.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/log_view_mode.dart';
import 'data/contact_memory_host.dart';
import 'data/theme_preference.dart';
import 'features/settings/scheduled_update_host.dart';
import 'features/shell/windows_splash_screen.dart';

SystemUiOverlayStyle _overlayFor({required bool dark}) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor:
        dark ? SwiftBrandColors.bgDark : SwiftBrandColors.bgLight,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    // Hold Android's existing native launch screen (launch_background.xml —
    // the dark screen the OS shows while the process starts) open past
    // Flutter's normal "first frame drawn" auto-dismiss point, until the
    // same Supabase-data-ready signal the Windows splash screen below
    // awaits has settled. This adds no new splash UI on Android — it just
    // gates *when* the existing one goes away. Paired with the matching
    // allowFirstFrame() call once appDataReadyProvider resolves.
    WidgetsBinding.instance.deferFirstFrame();
  }
  final prefs = await SharedPreferences.getInstance();
  final dark = loadDarkMode(prefs);
  SystemChrome.setSystemUIOverlayStyle(_overlayFor(dark: dark));
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final logView = await loadLogViewMode(prefs);

  // One shared container so main() can kick off (and, on Android, await)
  // the same initial Supabase load the Windows splash screen's readiness
  // check and the widget tree both watch — never a second round-trip.
  final container = ProviderContainer(
    overrides: [
      darkModeProvider.overrideWith((ref) => DarkModeNotifier(prefs, dark)),
      logViewModeProvider.overrideWith(
        (ref) => LogViewModeNotifier(prefs, logView),
      ),
    ],
  );
  // Start the staging+shipped load immediately (don't wait for the first
  // widget build to trigger it) so both the Windows splash and Android's
  // held launch screen see progress from the earliest possible moment.
  final ready = container.read(appDataReadyProvider.future);
  if (Platform.isAndroid) {
    unawaited(ready.then((_) => WidgetsBinding.instance.allowFirstFrame()));
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SlstApp()),
  );
}

class SlstApp extends ConsumerWidget {
  const SlstApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    // Windows only: hold on the load screen until the initial Supabase
    // staging+shipped fetch settles, then a brief cosmetic settle so the
    // progress bar lands at 100% (Document Generator pattern). Android/Wear
    // hold their existing native launch screen instead (see
    // main()/deferFirstFrame above) and release on appDataReady alone.
    if (Platform.isWindows && !ref.watch(windowsSplashGateProvider).hasValue) {
      return MaterialApp(
        title: kProductName,
        theme: IndustrialTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const WindowsSplashScreen(),
      );
    }
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: kProductName,
      theme: IndustrialTheme.lightTheme,
      darkTheme: IndustrialTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ScheduledUpdateHost(
          child: ContactMemoryHost(
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: _overlayFor(dark: dark),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
