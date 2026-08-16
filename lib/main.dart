import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/branding.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/log_view_mode.dart';
import 'data/contact_memory_host.dart';
import 'data/theme_preference.dart';
import 'features/settings/scheduled_update_host.dart';

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
  runApp(
    ProviderScope(
      overrides: [
        darkModeProvider.overrideWith(
          (ref) => DarkModeNotifier(prefs, dark),
        ),
        logViewModeProvider.overrideWith(
          (ref) => LogViewModeNotifier(prefs, logView),
        ),
      ],
      child: const SlstApp(),
    ),
  );
}

class SlstApp extends ConsumerWidget {
  const SlstApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final dark = ref.watch(darkModeProvider);
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
