import 'dart:async';

import 'package:flutter/material.dart';
import 'package:slst_shared/slst_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
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
        _error = '$e';
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
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STAGING',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          email.isEmpty ? 'Signed in' : email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Verify',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VerifyScreen(),
                        ),
                      );
                      _refresh();
                    },
                    icon: const Icon(Icons.checklist, size: 18),
                    color: WearTheme.accent,
                  ),
                  IconButton(
                    tooltip: 'Update',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WearUpdateScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    color: WearTheme.muted,
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : () => _refresh(),
                    icon: const Icon(Icons.refresh, size: 18),
                    color: WearTheme.muted,
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, size: 18),
                    color: WearTheme.muted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: WearTheme.border),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
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
          padding: const EdgeInsets.all(12),
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
        child: Text(
          'No active staging',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: WearTheme.border),
      itemBuilder: (context, i) {
        final e = entries[i];
        return SizedBox(
          height: 64,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(e.so, style: Theme.of(context).textTheme.titleSmall),
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
