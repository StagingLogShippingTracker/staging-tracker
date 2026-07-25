import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/log_tables.dart';
import '../shared/widgets.dart';

class StagingScreen extends ConsumerStatefulWidget {
  const StagingScreen({super.key});

  @override
  ConsumerState<StagingScreen> createState() => _StagingScreenState();
}

class _StagingScreenState extends ConsumerState<StagingScreen> {
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
    final entries = data.staging.where((e) {
      if (_q.isEmpty) return true;
      final hay =
          '${e.so} ${e.customer} ${e.location} ${e.status} ${e.comments ?? ''} ${e.stagedBy ?? ''} ${e.id}'
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
              hint: 'Search staging — SO, customer, location, status, UUID…',
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 14),
            if (data.loading && data.staging.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              StagingLogCard(entries: entries, expanded: true),
            const BrandFooter(),
          ],
        ),
      ),
    );
  }
}
