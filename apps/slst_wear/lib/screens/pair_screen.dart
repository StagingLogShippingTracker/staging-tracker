import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slst_shared/slst_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../wear_layout.dart';

/// Redeem a 6-digit pairing code from Windows/Android Settings → Pair Watch.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = WatchPairingClient(Supabase.instance.client);
      await client.redeemCode(code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = WearLayout.contentInsets(context);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          insets.left,
          insets.top,
          insets.right,
          insets.bottom + 12,
        ),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          Text(
            'PAIR',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Enter code from phone/PC',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: WearTheme.ok,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••••',
              ),
              onSubmitted: (_) => _redeem(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(color: WearTheme.danger, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _busy ? null : _redeem,
              child: Text(_busy ? 'Pairing…' : 'Pair'),
            ),
          ),
        ],
      ),
    );
  }
}
