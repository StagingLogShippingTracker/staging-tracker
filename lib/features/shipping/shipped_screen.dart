import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/log_tables.dart';
import '../shared/widgets.dart';
import 'quick_ship_sheet.dart';

class ShippedScreen extends ConsumerStatefulWidget {
  const ShippedScreen({super.key});

  @override
  ConsumerState<ShippedScreen> createState() => _ShippedScreenState();
}

class _ShippedScreenState extends ConsumerState<ShippedScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final entries = data.shipped.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.carrier} ${e.location} ${e.comments ?? ''} ${e.shippedBy ?? ''} ${e.id}'
              .toLowerCase();
      return hay.contains(_q);
    }).toList();

    return ColoredBox(
      color: IndustrialTheme.darkBase,
      child: RefreshIndicator(
        onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: slstPagePadding(context),
          children: [
            SearchField(
              controller: _search,
              hint: 'Search shipped — SO, customer, carrier, location, UUID…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 14),
            if (data.loading && data.shipped.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ShippedLogCard(
                entries: entries,
                expanded: true,
                onQuickShip: () => showQuickShipSheet(context, ref),
              ),
            const BrandFooter(),
          ],
        ),
      ),
    );
  }
}
