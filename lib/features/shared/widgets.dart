import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../../platform/photo_picker.dart';
import '../scanner/scanner_screen.dart';
import 'industrial_widgets.dart';

bool usesDesktopPopupChrome(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux ||
      platform == TargetPlatform.macOS;
}

/// Uses a conventional dialog on desktop and a bottom sheet on touch-first
/// mobile platforms. Popup content is expected to render its own explicit X
/// close control on every platform (sheets remain swipe-dismissible too).
Future<T?> showAdaptivePopup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 680,
}) {
  if (usesDesktopPopupChrome(context)) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
          ),
          child: builder(dialogContext),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Resolves the [StatusStyle] for a raw DB status string.
StatusStyle statusStyleOf(BuildContext context, String dbStatus) {
  return statusStyleFor(
    uiLabel: StatusRules.formatUi(dbStatus),
    isDateStatus: StatusRules.isYmd(dbStatus),
    overdue: StatusRules.isOverdue(dbStatus),
    brightness: Theme.of(context).brightness,
  );
}

/// Shared page insets: 16 on narrow widths, 24 on wide.
///
/// [includeCompactChrome] adds scroll clearance for the phone NavigationBar
/// (and optional action strip) so trailing controls are not clipped.
EdgeInsets slstPagePadding(
  BuildContext context, {
  double top = 20,
  double bottom = 8,
  bool includeCompactChrome = false,
}) {
  final size = MediaQuery.sizeOf(context);
  final narrow = size.width < 600;
  final h = narrow ? 16.0 : 24.0;
  var b = bottom;
  if (includeCompactChrome &&
      size.width < IndustrialTheme.tokens.compactBreakpoint) {
    // NavigationBar height 68 + action strip ~60 + breathing room.
    b = bottom + 68 + 72;
  }
  return EdgeInsets.fromLTRB(h, top, h, b);
}

/// SST wordmark ("SST — Swift Staging Tracker") for compact brand placements.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: height),
        SizedBox(width: height * 0.28),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SST',
                style: TextStyle(
                  fontSize: height * 0.52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: IndustrialTheme.textPrimary,
                  height: 1.05,
                ),
              ),
              Text(
                'Swift Staging Tracker',
                style: TextStyle(
                  fontSize: height * 0.28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: IndustrialTheme.textMuted,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full SST logo for login and large brand placements.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    final iconSize = (height * 0.72).clamp(56.0, 96.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: iconSize),
        SizedBox(height: height * 0.12),
        Text(
          'SST',
          style: TextStyle(
            fontSize: height * 0.28,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: IndustrialTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Swift Staging Tracker',
          style: TextStyle(
            fontSize: height * 0.145,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: IndustrialTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Compact square SST app icon for app bars / nav.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/sst-app-icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Icon(
        Icons.inventory_2_outlined,
        color: SlstColors.brand,
        size: size * 0.95,
      ),
    );
  }
}

/// Legacy KPI wrapper — prefers [IndustrialKpiCard].
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IndustrialKpiCard(
      label: label,
      value: '$value',
      subtext: '',
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Pill action buttons (web .btn-purple / .btn-notify / success / danger)
// ---------------------------------------------------------------------------

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: IndustrialTheme.textPrimary,
      disabledBackgroundColor: color.withValues(alpha: 0.4),
      disabledForegroundColor: IndustrialTheme.textMuted,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: compact ? const Size(0, 34) : const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        fontSize: compact ? 12 : 13,
        color: IndustrialTheme.textPrimary,
      ),
    );
    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: compact ? 15 : 18),
      label: Text(label),
    );
  }
}

/// Small status pill — muted pastel industrial badge language.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.dbStatus, this.compact = false});

  final String dbStatus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = statusStyleOf(context, dbStatus);
    return IndustrialStatusBadge(status: style.label);
  }
}

// ---------------------------------------------------------------------------
// Section card with header controls (Staging Entries / Shipped Log panels)
// ---------------------------------------------------------------------------

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.headerActions = const [],
    this.subHeader,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.expandChild = false,
  });

  final String title;
  final List<Widget> headerActions;
  final Widget? subHeader;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When true, [child] expands to fill leftover height (parent must be bounded).
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: IndustrialTheme.darkSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialTheme.borderStroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.9,
                    color: IndustrialTheme.textPrimary,
                  ),
                ),
                if (headerActions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: headerActions,
                  ),
              ],
            ),
          ),
          if (subHeader != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: subHeader!,
            ),
          const Divider(height: 1, color: IndustrialTheme.borderStroke),
          if (expandChild) Expanded(child: body) else body,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status legend (Partial / Ship Today / Ship Tomorrow / Future / Corp Pick /
// Customer Pick-Up / Awaiting Instructions)
// ---------------------------------------------------------------------------

const List<({String label, Color accent})> _legend = [
  (label: 'Partial', accent: IndustrialTheme.amber),
  (label: 'Ship Today', accent: IndustrialTheme.mintGreen),
  (label: 'Ship Tomorrow', accent: IndustrialTheme.skyBlue),
  (label: 'Ship On Future Date', accent: IndustrialTheme.purple),
  (label: 'Corp Pick', accent: IndustrialTheme.mintGreen),
  (label: 'Customer Pick-Up', accent: IndustrialTheme.purple),
  (label: 'Awaiting Instructions', accent: IndustrialTheme.slateMuted),
];

/// Desktop swatch legend (muted pastel chips + Inter labels).
class StagingStatusLegend extends StatelessWidget {
  const StagingStatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final item in _legend)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: item.accent.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: IndustrialTheme.textMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Soft row wash for a staging status (industrial dark only).
Color? statusRowColor(BuildContext context, String dbStatus) {
  final ui = StatusRules.formatUi(dbStatus).toLowerCase();
  if (ui == 'ship today' || StatusRules.isOverdue(dbStatus)) {
    return SlstColors.statusToday;
  }
  if (ui == 'ship tomorrow') return SlstColors.statusTomorrow;
  if (StatusRules.isYmd(dbStatus)) return SlstColors.statusFuture;
  if (ui == 'partial') return SlstColors.statusPartial;
  if (ui.contains('corp pick')) return SlstColors.statusCorpPick;
  if (ui.contains('customer pick')) return SlstColors.statusCustomerPick;
  return null;
}

// ---------------------------------------------------------------------------
// Quick search field
// ---------------------------------------------------------------------------

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: 13.5,
        color: IndustrialTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: IndustrialTheme.textMuted,
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: IndustrialTheme.textMuted,
        ),
        isDense: true,
        filled: true,
        fillColor: IndustrialTheme.darkHeader,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: IndustrialTheme.borderStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: IndustrialTheme.borderStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: IndustrialTheme.skyBlue,
            width: 1.5,
          ),
        ),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              icon: const Icon(
                Icons.close,
                size: 18,
                color: IndustrialTheme.textMuted,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coming soon card (web parity)
// ---------------------------------------------------------------------------

class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: IndustrialTheme.darkHeader,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialTheme.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: IndustrialTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: IndustrialTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Container count entry (staging / quick ship forms)
// ---------------------------------------------------------------------------

class ContainerInputs extends StatelessWidget {
  const ContainerInputs({
    super.key,
    required this.skids,
    required this.boxes,
    required this.crates,
    required this.pipe,
    required this.other,
    required this.onChanged,
  });

  final TextEditingController skids;
  final TextEditingController boxes;
  final TextEditingController crates;
  final TextEditingController pipe;
  final TextEditingController other;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c) {
      return Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: (_) => onChanged(),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            field('Skids', skids),
            const SizedBox(width: 8),
            field('Boxes', boxes),
            const SizedBox(width: 8),
            field('Crates', crates),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            field('Pipe/Rod', pipe),
            const SizedBox(width: 8),
            field('Other', other),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

ContainerCounts countsFromControllers({
  required TextEditingController skids,
  required TextEditingController boxes,
  required TextEditingController crates,
  required TextEditingController pipe,
  required TextEditingController other,
}) {
  int p(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  return ContainerCounts(
    skids: p(skids),
    boxes: p(boxes),
    crates: p(crates),
    pipe: p(pipe),
    other: p(other),
  );
}

// ---------------------------------------------------------------------------
// Photos
// ---------------------------------------------------------------------------

/// Photos + Camera + Scan — always show all three capture options.
class PhotoAttachButtons extends StatelessWidget {
  const PhotoAttachButtons({
    super.key,
    required this.picker,
    required this.photos,
    required this.onChanged,
    this.attachLabel,
    this.scanLabel = 'Scan document',
  });

  final PhotoPickerService picker;
  final List<PhotoBytes> photos;
  final ValueChanged<List<PhotoBytes>> onChanged;
  final String? attachLabel;
  final String scanLabel;

  Future<void> _attachPhotos() async {
    final files = await picker.pickPreferred();
    if (files.isNotEmpty) onChanged([...photos, ...files]);
  }

  Future<void> _captureCamera() async {
    final shot = await picker.captureCamera();
    if (shot != null) onChanged([...photos, shot]);
  }

  @override
  Widget build(BuildContext context) {
    final count = photos.length;
    final label = attachLabel ?? 'Photos ($count)';
    final btnStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          style: btnStyle,
          onPressed: _attachPhotos,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(label.contains('(') ? label : '$label ($count)'),
        ),
        OutlinedButton.icon(
          style: btnStyle,
          onPressed: _captureCamera,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Camera'),
        ),
        ScanDocumentButton(
          label: scanLabel,
          onScanned: (pages) {
            if (pages.isNotEmpty) onChanged([...photos, ...pages]);
          },
        ),
      ],
    );
  }
}

class PhotoThumbRow extends StatelessWidget {
  const PhotoThumbRow({super.key, required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final url = AppConfig.publicPhotoUrl(paths[i]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: Colors.black12,
                child: const Icon(Icons.broken_image),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> showPhotosDialog(
  BuildContext context, {
  required String title,
  required List<String> paths,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: paths.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No photos attached.'),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemCount: paths.length,
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            AppConfig.publicPhotoUrl(paths[i]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.black12,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Card for one staging/shipped entry. Supports both a Windows-style row tint
/// ([color]) and the touch-first status accent bar + chip ([dbStatus]).
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    this.dbStatus,
    this.color,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<String> details;
  final String? dbStatus;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = dbStatus == null ? null : statusStyleOf(context, dbStatus!);
    return Card(
      color: color ?? IndustrialTheme.darkSurface,
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: style?.accent ?? IndustrialTheme.borderStroke,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: IndustrialTheme.mono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: IndustrialTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (style != null)
                            IndustrialStatusBadge(status: style.label),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: IndustrialTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in details)
                            if (d.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: IndustrialTheme.darkHeader,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: IndustrialTheme.borderStroke,
                                  ),
                                ),
                                child: Text(
                                  d,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(child: trailing),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer credit carried over from the legacy web app.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            'SST — SWIFT STAGING TRACKER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Designed & developed by Brice Johnson',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Future<void> showError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString()), backgroundColor: scheme.error),
  );
}

Future<void> showOk(BuildContext context, String message) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: SlstColors.green),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = SlstColors.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
