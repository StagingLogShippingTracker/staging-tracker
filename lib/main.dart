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
import 'features/shell/android_splash_screen.dart';
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
  final prefs = await SharedPreferences.getInstance();
  final dark = loadDarkMode(prefs);
  SystemChrome.setSystemUIOverlayStyle(_overlayFor(dark: dark));
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final logView = await loadLogViewMode(prefs);

  // One shared container so main() can kick off the same initial Supabase
  // load the splash screen's readiness check and the widget tree both
  // watch — never a second round-trip.
  final container = ProviderContainer(
    overrides: [
      darkModeProvider.overrideWith((ref) => DarkModeNotifier(prefs, dark)),
      logViewModeProvider.overrideWith(
        (ref) => LogViewModeNotifier(prefs, logView),
      ),
    ],
  );
  // Start the staging+shipped load immediately (don't wait for the first
  // widget build to trigger it) so the Windows/Android splash screen sees
  // progress from the earliest possible moment.
  unawaited(container.read(appDataReadyProvider.future));

  runApp(
    UncontrolledProviderScope(container: container, child: const SlstApp()),
  );
}

class SlstApp extends ConsumerWidget {
  const SlstApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    // Windows and Android: hold on a branded load screen until the initial
    // Supabase staging+shipped fetch settles, then a brief cosmetic settle
    // so the progress bar lands at 100% (Document Generator pattern). Wear
    // is a separate Flutter project with its own equivalent gate
    // (`WearStartup`/`WearSplashScreen`).
    final onSplashPlatform = Platform.isWindows || Platform.isAndroid;
    if (onSplashPlatform && !ref.watch(appSplashGateProvider).hasValue) {
      return MaterialApp(
        title: kProductName,
        theme: IndustrialTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Platform.isWindows
            ? const WindowsSplashScreen()
            : const AndroidSplashScreen(),
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
