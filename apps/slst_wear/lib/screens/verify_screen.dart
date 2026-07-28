import 'package:flutter/material.dart';
import 'package:slst_shared/slst_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../wear_layout.dart';

/// Lean SVR-style walk: staging rows in warehouse location order, Yes / Skip.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  late final ShipOperations _ops = ShipOperations(Supabase.instance.client);
  List<StagingEntry> _queue = const [];
  int _index = 0;
  int _ok = 0;
  int _skipped = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _ops.fetchStaging();
      rows.sort(compareAuditLocations);
      if (!mounted) return;
      setState(() {
        _queue = rows;
        _index = 0;
        _ok = 0;
        _skipped = 0;
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

  void _mark(bool verified) {
    if (_queue.isEmpty || _index >= _queue.length) return;
    setState(() {
      if (verified) {
        _ok++;
      } else {
        _skipped++;
      }
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = WearLayout.contentInsets(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(insets.left, insets.top, insets.right, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WearPageHeader(
              title: 'Local checklist',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(child: _body(insets)),
          ],
        ),
      ),
    );
  }

  Widget _body(EdgeInsets insets) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: WearTheme.danger, fontSize: 11),
        ),
      );
    }
    if (_queue.isEmpty) {
      return Center(
        child: Text(
          'Nothing to verify',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    if (_index >= _queue.length) {
      return ListView(
        padding: EdgeInsets.only(bottom: insets.bottom + 8),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.check_circle, color: WearTheme.ok, size: 28),
          const SizedBox(height: 8),
          Text(
            'Done',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Checked $_ok · Skipped $_skipped',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _load,
              child: const Text('Restart'),
            ),
          ),
        ],
      );
    }

    final e = _queue[_index];
    final progress = '${_index + 1}/${_queue.length}';

    // Single scroll surface: swipe to read full card + reach Skip/Matches.
    return ListView(
      padding: EdgeInsets.only(bottom: insets.bottom + 10),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        Text(
          progress,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Results are not saved.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Text(
          e.location,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: WearTheme.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'SO ${e.so}',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          e.customer,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${e.type} ×${e.qty}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Text(
          'Does this match the staging list?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _mark(false),
                  child: const Text('Skip'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => _mark(true),
                  child: const Text('Matches'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe for more',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
