import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../shared/widgets.dart';

Future<void> showSplitDialog(
  BuildContext context,
  WidgetRef ref, {
  required StagingEntry entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => SplitDialog(entry: entry),
  );
}

class SplitDialog extends ConsumerStatefulWidget {
  const SplitDialog({super.key, required this.entry});
  final StagingEntry entry;

  @override
  ConsumerState<SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends ConsumerState<SplitDialog> {
  final _aSkids = TextEditingController();
  final _aBoxes = TextEditingController();
  final _aCrates = TextEditingController();
  final _aPipe = TextEditingController();
  final _aOther = TextEditingController();
  final _bSkids = TextEditingController();
  final _bBoxes = TextEditingController();
  final _bCrates = TextEditingController();
  final _bPipe = TextEditingController();
  final _bOther = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _aSkids.dispose();
    _aBoxes.dispose();
    _aCrates.dispose();
    _aPipe.dispose();
    _aOther.dispose();
    _bSkids.dispose();
    _bBoxes.dispose();
    _bCrates.dispose();
    _bPipe.dispose();
    _bOther.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(operationsProvider)
          .splitStaging(
            entry: widget.entry,
            first: countsFromControllers(
              skids: _aSkids,
              boxes: _aBoxes,
              crates: _aCrates,
              pipe: _aPipe,
              other: _aOther,
            ),
            second: countsFromControllers(
              skids: _bSkids,
              boxes: _bBoxes,
              crates: _bCrates,
              pipe: _bPipe,
              other: _bOther,
            ),
          );
      if (mounted) {
        Navigator.pop(context);
        showOk(context, 'Split SO ${widget.entry.so}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: IndustrialTheme.chromeOf(context).surface,
      title: Text(
        'Split SO ${widget.entry.so}',
        style: IndustrialTheme.mono(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Part A', style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Original: ${widget.entry.type.isEmpty ? '${widget.entry.qty} total' : widget.entry.type}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ContainerInputs(
                skids: _aSkids,
                boxes: _aBoxes,
                crates: _aCrates,
                pipe: _aPipe,
                other: _aOther,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text('Part B', style: Theme.of(context).textTheme.titleMedium),
              ContainerInputs(
                skids: _bSkids,
                boxes: _bBoxes,
                crates: _bCrates,
                pipe: _bPipe,
                other: _bOther,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Splitting…' : 'Split'),
        ),
      ],
    );
  }
}
