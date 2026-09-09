import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/pair_screen.dart';
import 'theme.dart';
import 'wear_pair_prefs.dart';
import 'wear_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hold Wear's existing native launch screen (launch_background.xml) open
  // past Flutter's normal "first frame drawn" auto-dismiss point, until the
  // same Supabase-data-ready signal the phone app's Windows splash screen
  // awaits has settled — see WearStartup. No new splash UI on Wear, just a
  // later handoff. Paired with allowFirstFrame() once startup.ready settles.
  WidgetsBinding.instance.deferFirstFrame();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await SharedPreferences.getInstance();
  final startup = WearStartup();
  unawaited(startup.ready.then((_) => WidgetsBinding.instance.allowFirstFrame()));
  runApp(const ProviderScope(child: SlstWearApp()));
}

class SlstWearApp extends ConsumerWidget {
  const SlstWearApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Swift Staging & Shipping Log',
      theme: WearTheme.dark,
      darkTheme: WearTheme.dark,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool? _floorPaired;

  @override
  void initState() {
    super.initState();
    _loadPaired();
  }

  Future<void> _loadPaired() async {
    final paired = await WearPairPrefs.isPaired();
    if (!mounted) return;
    setState(() => _floorPaired = paired);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        final floorPaired = _floorPaired;
        if (floorPaired == null && session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (session != null || floorPaired == true) {
          return HomeScreen(onUnpaired: _loadPaired);
        }
        return PairScreen(onPaired: _loadPaired);
      },
    );
  }
}
