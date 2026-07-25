import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/location_intelligence.dart';
import 'widgets.dart';

typedef LocationSelection = ({String value, LocationCategory category});

enum LocationAdvisoryDecision { cancel, proceed, consolidate }

class LocationSelectorField extends ConsumerWidget {
  const LocationSelectorField({
    super.key,
    required this.controller,
    required this.soController,
    this.label = 'Location',
    this.ignoreEntryId,
    this.onCategoryChanged,
  });

  final TextEditingController controller;
  final TextEditingController soController;
  final String label;
  final String? ignoreEntryId;
  final ValueChanged<LocationCategory>? onCategoryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final result = await showLocationSelector(
          context,
          ref,
          initialValue: controller.text,
          so: soController.text,
          ignoreEntryId: ignoreEntryId,
        );
        if (result == null) return;
        controller.text = result.value;
        onCategoryChanged?.call(result.category);
      },
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Choose a category, remembered location, or type a new one',
        suffixIcon: const Icon(Icons.chevron_right),
      ),
    );
  }
}

Future<LocationSelection?> showLocationSelector(
  BuildContext context,
  WidgetRef ref, {
  String initialValue = '',
  String so = '',
  String? ignoreEntryId,
}) {
  return showAdaptivePopup<LocationSelection>(
    context,
    maxWidth: 720,
    builder: (_) => LocationSelectorDialog(
      initialValue: initialValue,
      so: so,
      ignoreEntryId: ignoreEntryId,
    ),
  );
}

class LocationSelectorDialog extends ConsumerStatefulWidget {
  const LocationSelectorDialog({
    super.key,
    this.initialValue = '',
    this.so = '',
    this.ignoreEntryId,
  });

  final String initialValue;
  final String so;
  final String? ignoreEntryId;

  @override
  ConsumerState<LocationSelectorDialog> createState() =>
      _LocationSelectorDialogState();
}

class _LocationSelectorDialogState
    extends ConsumerState<LocationSelectorDialog> {
  LocationCategory? _category;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _select(String value) {
    final category = _category;
    final clean = value.trim();
    if (category == null || clean.isEmpty) return;
    Navigator.pop(context, (value: clean, category: category));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_category != null)
                    IconButton(
                      key: const Key('location-selector-back'),
                      tooltip: 'Back to location categories',
                      onPressed: () => setState(() {
                        _category = null;
                        _query.clear();
                      }),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const Icon(Icons.place_outlined, color: SlstColors.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _category?.label ?? 'SELECT LOCATION',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('location-selector-close'),
                    tooltip: 'Close location selector',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _category == null
                    ? _buildCategories()
                    : _buildLocations(_category!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    const icons = {
      LocationCategory.aisle: Icons.view_column_outlined,
      LocationCategory.floor: Icons.warehouse_outlined,
      LocationCategory.shipping: Icons.local_shipping_outlined,
      LocationCategory.outside: Icons.landscape_outlined,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in LocationCategory.values)
                SizedBox(
                  width: width,
                  height: columns == 1 ? 82 : 108,
                  child: OutlinedButton(
                    key: Key('location-category-${category.name}'),
                    onPressed: () => setState(() {
                      _category = category;
                      _query.text =
                          category == classifyLocation(widget.initialValue)
                          ? widget.initialValue
                          : '';
                    }),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Row(
                      children: [
                        Icon(icons[category], size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            category.label,
                            style: const TextStyle(
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocations(LocationCategory category) {
    final data = ref.watch(appDataProvider);
    final movements =
        ref.watch(recentBinMovementsProvider).valueOrNull ?? const [];
    final remembered =
        ref.watch(locationSuggestionsProvider(category)).valueOrNull ??
        const <String>[];
    final query = _query.text.trim().toLowerCase();
    final visible = remembered
        .where((value) => query.isEmpty || value.toLowerCase().contains(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('location-selector-input'),
          controller: _query,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Search or type a new ${category.label.toLowerCase()}',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () => setState(_query.clear),
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _select,
        ),
        const SizedBox(height: 10),
        if (_query.text.trim().isNotEmpty &&
            !remembered.any(
              (value) => locationKey(value) == locationKey(_query.text),
            ))
          FilledButton.icon(
            key: const Key('location-selector-add-new'),
            onPressed: () => _select(_query.text),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text('Use new location "${_query.text.trim()}"'),
          ),
        if (_query.text.trim().isNotEmpty) const SizedBox(height: 8),
        Flexible(
          child: visible.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No remembered locations in this category.'),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final value = visible[index];
                    final assessment = assessLocation(
                      location: value,
                      so: widget.so,
                      active: data.staging,
                      shipped: data.shipped,
                      ignoreEntryId: widget.ignoreEntryId,
                    );
                    final occupied = !assessment.vacant;
                    final occupantText = assessment.occupants
                        .map(
                          (entry) =>
                              'SO ${entry.so} · ${entry.customer} · ${entry.type}',
                        )
                        .join('\n');
                    final history = assessment.recentHistory.isEmpty
                        ? ''
                        : '\nRecent: ${assessment.recentHistory.map((entry) => 'SO ${entry.so}').join(', ')}';
                    final movement = movements
                        .where(
                          (entry) => entry.action.toUpperCase().contains(
                            locationKey(value),
                          ),
                        )
                        .take(1)
                        .map(
                          (entry) => entry.action.replaceFirst(
                            RegExp(r'^Bin Movement:\s*', caseSensitive: false),
                            '',
                          ),
                        )
                        .join();
                    final movementText = movement.isEmpty
                        ? ''
                        : '\nMovement: $movement';
                    return ListTile(
                      leading: Icon(
                        occupied
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: occupied
                            ? SlstColors.warning
                            : SlstColors.success,
                      ),
                      title: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        occupied
                            ? 'Occupied: $occupantText$history$movementText'
                            : 'Vacant$history$movementText',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _select(value),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<LocationAdvisoryDecision> confirmLocationAdvisory(
  BuildContext context,
  WidgetRef ref, {
  required String location,
  required String so,
  String? ignoreEntryId,
}) async {
  // Loose floor / shipping / outside areas are freeflow — skip conflict UI.
  if (classifyLocation(location) != LocationCategory.aisle) {
    return LocationAdvisoryDecision.proceed;
  }
  // Refresh immediately before confirmation where practical. A failure leaves
  // the existing realtime snapshot available; this remains advisory, not a lock.
  await ref.read(appDataProvider.notifier).refresh();
  if (!context.mounted) return LocationAdvisoryDecision.cancel;
  final data = ref.read(appDataProvider);
  final assessment = assessLocation(
    location: location,
    so: so,
    active: data.staging,
    shipped: data.shipped,
    ignoreEntryId: ignoreEntryId,
  );
  final sameHere = assessment.occupants
      .where((entry) => orderKey(entry.so) == orderKey(so))
      .toList();
  final differentHere = assessment.occupants
      .where((entry) => orderKey(entry.so) != orderKey(so))
      .toList();
  if (assessment.sameOrderElsewhere.isEmpty &&
      sameHere.isEmpty &&
      differentHere.isEmpty) {
    return LocationAdvisoryDecision.proceed;
  }

  final signedIn = ref.read(currentUserProvider) != null;
  final lines = <String>[
    if (differentHere.isNotEmpty)
      '${differentHere.length} active ${differentHere.length == 1 ? 'entry uses' : 'entries use'} this location for a different SO.',
    if (sameHere.isNotEmpty)
      'SO $so already has ${sameHere.length} active ${sameHere.length == 1 ? 'entry' : 'entries'} here.',
    if (assessment.sameOrderElsewhere.isNotEmpty)
      'SO $so is also active at ${assessment.sameOrderElsewhere.map((entry) => entry.location).toSet().join(', ')}.',
    'This warning is advisory; another user can change staging before save.',
  ];
  final showConsolidate =
      signedIn && assessment.hasConsolidationOpportunity;
  final result = await showDialog<LocationAdvisoryDecision>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Location assignment warning'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.join('\n\n')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              LocationAdvisoryDecision.proceed,
            ),
            child: const Text('Proceed anyway'),
          ),
          if (showConsolidate) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                LocationAdvisoryDecision.consolidate,
              ),
              child: const Text('Save & consolidate'),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              LocationAdvisoryDecision.cancel,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
  return result ?? LocationAdvisoryDecision.cancel;
}
