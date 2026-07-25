import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/log_view_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  final prefs = await SharedPreferences.getInstance();
  final logView = await loadLogViewMode(prefs);
  runApp(
    ProviderScope(
      overrides: [
        // Industrial Command Center is dark-operations only.
        darkModeProvider.overrideWith((ref) => true),
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
    return MaterialApp.router(
      title: 'Swift Staging Tracker',
      theme: IndustrialTheme.darkTheme,
      darkTheme: IndustrialTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
