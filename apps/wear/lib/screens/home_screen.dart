import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../launch_prompts.dart';
import '../theme.dart';
import '../wear_layout.dart';
import 'ship_confirm_screen.dart';
import 'update_screen.dart';
import 'verify_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ShipOperations _ops = ShipOperations(Supabase.instance.client);
  List<StagingEntry>? _entries;
  String? _error;
  bool _loading = true;
  RealtimeChannel? _channel;
  Timer? _realtimeDebounce;
  int _channelEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _bindRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(maybeShowWearLaunchPrompts(context));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeDebounce?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bindRealtime();
      _refresh(quiet: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _unbindRealtime();
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _refresh(quiet: true),
    );
  }

  void _unbindRealtime() {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      unawaited(Supabase.instance.client.removeChannel(ch));
    }
  }

  void _bindRealtime() {
    _unbindRealtime();
    final epoch = ++_channelEpoch;
    final client = Supabase.instance.client;
    final channel = client.channel('wear-staging-$epoch');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'staging',
      callback: (_) {
        if (!mounted || epoch != _channelEpoch) return;
        _scheduleRealtimeRefresh();
      },
    );
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (!quiet || _entries == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (_error != null) {
      setState(() => _error = null);
    }
    try {
      final rows = await _ops.fetchStaging();
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = wearSafeError(e);
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    _unbindRealtime();
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final insets = WearLayout.contentInsets(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WearIconAction(
                      tooltip: 'Verify',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const VerifyScreen(),
                          ),
                        );
                        _refresh();
                      },
                      icon: Icons.checklist,
                      color: WearTheme.accent,
                    ),
                    WearIconAction(
                      tooltip: 'Update',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WearUpdateScreen(),
                          ),
                        );
                      },
                      icon: Icons.system_update_alt,
                      color: WearTheme.muted,
                    ),
                    WearIconAction(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : () => _refresh(),
                      icon: Icons.refresh,
                      color: WearTheme.muted,
                    ),
                    WearIconAction(
                      tooltip: 'Sign out',
                      onPressed: _signOut,
                      icon: Icons.logout,
                      color: WearTheme.muted,
                    ),
                  ],
                ),
                Text(
                  'STAGING',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: WearTheme.border),
          Expanded(child: _body(insets)),
        ],
      ),
    );
  }

  Widget _body(EdgeInsets insets) {
    if (_loading && _entries == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null && (_entries == null || _entries!.isEmpty)) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(insets.left, 8, insets.right, insets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: WearTheme.danger, fontSize: 11),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _refresh(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final entries = _entries ?? const <StagingEntry>[];
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: insets.left),
          child: Text(
            'No active staging',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        insets.left,
        6,
        insets.right,
        insets.bottom + 8,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: WearTheme.border),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: InkWell(
            onTap: () async {
              final shipped = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => ShipConfirmScreen(entry: e, ops: _ops),
                ),
              );
              if (shipped == true) _refresh();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    e.so,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    e.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.location} · ${e.type}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
