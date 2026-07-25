import 'package:flutter/material.dart';
import 'package:slst_shared/slst_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import 'ship_confirm_screen.dart';
import 'verify_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ShipOperations _ops =
      ShipOperations(Supabase.instance.client);
  List<StagingEntry>? _entries;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _ops.fetchStaging();
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
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
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _refresh,
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
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WearTheme.danger, fontSize: 11),
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
        return InkWell(
          onTap: () async {
            final shipped = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ShipConfirmScreen(entry: e, ops: _ops),
              ),
            );
            if (shipped == true) _refresh();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SO ${e.so}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${e.location} · ${e.type} ×${e.qty}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
