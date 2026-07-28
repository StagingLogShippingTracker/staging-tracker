import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slst_shared/slst_shared.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';

/// Creates a short-lived Wear pairing code via the `watch-pair` Edge Function.
class PairWatchCard extends ConsumerStatefulWidget {
  const PairWatchCard({super.key});

  @override
  ConsumerState<PairWatchCard> createState() => _PairWatchCardState();
}

class _PairWatchCardState extends ConsumerState<PairWatchCard> {
  bool _busy = false;
  String? _error;
  WatchPairCreateResult? _result;

  Future<void> _createCode() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final client = WatchPairingClient(ref.read(supabaseClientProvider));
      final result = await client.createCode();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final fmt = DateFormat('h:mm a');

    return Semantics(
      container: true,
      label: 'Pair Watch',
      child: Card(
        key: const ValueKey('pair-watch-card'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.watch,
                    size: 20,
                    color: IndustrialTheme.skyBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pair Watch',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: IndustrialTheme.textPrimary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'PAIR WATCH',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a 6-digit code on this device, then enter it on the '
                'Wear OS app to sign in with your account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (user == null) ...[
                Text(
                  'Sign in to create a pairing code.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IndustrialTheme.amber,
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Sign in'),
                ),
              ] else ...[
                Semantics(
                  button: true,
                  label: 'Pair Watch',
                  child: FilledButton.icon(
                    key: const ValueKey('pair-watch-generate'),
                    onPressed: _busy ? null : _createCode,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.watch, size: 18),
                    label: Text(_busy ? 'Creating…' : 'Pair Watch'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    label: _error,
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    label: 'Pairing code ${_result!.code}',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: IndustrialTheme.darkHeader,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: IndustrialTheme.borderStroke),
                      ),
                      child: Column(
                        children: [
                          SelectableText(
                            _result!.code,
                            key: const ValueKey('pair-watch-code'),
                            style: IndustrialTheme.mono(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: IndustrialTheme.mintGreen,
                            ).copyWith(letterSpacing: 6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expires ${fmt.format(_result!.expiresAt.toLocal())}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _result!.code),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy code'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
