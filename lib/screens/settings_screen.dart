import 'package:flutter/material.dart';

import '../utils/app_log.dart';
import '../widgets/liquid_glass.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_section.dart';
import 'settings/widgets/settings_fields.dart';

/// Settings browser: a category list that drills into one section at a time.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _settings;
  late final List<SettingsSection> _sections;

  /// Null while browsing the list, otherwise the open section index.
  int? _selectedSection;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController();
    _sections = buildSettingsSections(onLogout: _confirmLogout);
    _settings
      ..load()
      ..loadAppVersion();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? error;
    try {
      error = await _settings.save();
    } catch (exception) {
      appLog(() => 'Saving settings failed: $exception');
      error = 'Saving the settings failed. Please try again.';
    }
    if (error != null) {
      if (mounted) _showError(error);
      return;
    }
    if (mounted) Navigator.pop(context, true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
          'Your saved session will be cleared from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.onLogout();
  }

  void _openSection(int index) => setState(() => _selectedSection = index);

  void _closeSection() => setState(() => _selectedSection = null);

  @override
  Widget build(BuildContext context) {
    // `AppBar` and `bottomNavigationBar` sit outside the listening scope on
    // purpose.
    //
    // The builder used to wrap the whole `Scaffold`, so every toggle, dropdown
    // and colour chip rebuilt the app bar and the save button with it — and
    // `_settings.saving` is only ever true between the press and the write
    // completing, so those two rebuilds were pure cost.
    //
    // The save button is the one thing that genuinely has to listen, because it
    // reads `_settings.saving` and nothing else: `SettingsController.save`
    // sets `saving = true` and calls `notifyListeners()`
    // (settings_controller.dart:248), so moving the button out of the scope
    // without giving it its own listener would have left the label reading
    // "Save settings" for the whole write. It gets a `ListenableBuilder` of its
    // own, below, which narrows the rebuild to that one button.
    final detail = _selectedSection;
    final openSection = detail == null ? null : _sections[detail];
    return PopScope(
      canPop: detail == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && detail != null) _closeSection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: detail == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _closeSection,
                ),
          title: Text(openSection?.title ?? 'Settings'),
        ),
        bottomNavigationBar: detail != null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                child: ListenableBuilder(
                  listenable: _settings,
                  builder: (context, _) => SaveSettingsButton(
                    saving: _settings.saving,
                    onPressed: _save,
                  ),
                ),
              ),
        // The section body is the part that has to follow every setting change.
        body: ListenableBuilder(
          listenable: _settings,
          builder: (context, _) => AnimatedSwitcher(
            // 200ms, unchanged. Named rather than literal because
            // AppMotion.state is that value; this is a value changing, not a
            // container.
            duration: AppMotion.state,
            // The library default centres the incoming and outgoing children on
            // top of each other, so a section arrived as a cross-fade in the
            // middle of the screen rather than from the edge it was drilled into
            // from. Aligning to the top keeps the header where the user's eye
            // already is.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previousChildren, ?currentChild],
            ),
            child: switch (openSection) {
              final section? => _buildDetailPage(context, section),
              _ => _buildCategoryList(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('settings-list'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          // **`AppSurface`, not `AppCard`, and the difference is the shadow.**
          // The brief's `list-row` is `surface` + a 1px hairline + 8px radius +
          // 16 padding + `boxShadow: none` — list rows are explicitly the *flat*
          // tier, alongside the app bar and the chips. `AppCard` carries
          // `AppShadows.stamped` by construction and has no way to decline it,
          // so using it here would have stamped nine rows and contradicted the
          // one tier the brief cares most about separating.
          //
          // The padding is passed in rather than left to the child so the
          // layout is byte-identical to the card it replaced: `AppSurface` has
          // no default, and `ListTile` brings its own insets on top.
          //
          // `RepaintBoundary`, because `AppCard` carries one and `AppSurface`
          // does not: eight rows inside a `ListView.builder` would otherwise
          // re-rasterise with every scroll frame.
          child: RepaintBoundary(
            child: AppSurface(
              radius: AppRadius.card,
              fill: AppSurfaces.surface,
              border: AppBorders.hairlineBorder,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              // The transparent `Material` is the same arrangement `AppCard`
              // makes and for the same reason: a `Container`'s opaque fill
              // paints over the ink layer of any `Material` placed outside it,
              // and a `ListTile`'s splash and hover live on exactly that layer.
              // `settings_screen_test.dart` asserts the paint order for the
              // drill-in page; this row is the same hazard with no test.
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: SettingsIconBadge(icon: section.icon),
                  title: Text(section.title, style: AppType.headlineMd),
                  // No `maxLines` and no ellipsis here, deliberately.
                  //
                  // This was `maxLines: 1, overflow: TextOverflow.ellipsis`, and on
                  // a 375dp phone it truncated eight of the nine category
                  // subtitles -- every one except "Application information.",
                  // which is the only string short enough to survive one line. The
                  // `SectionCard` on the drill-in page renders the same string with
                  // no clamp at all (settings_fields.dart), so the copy was written
                  // to wrap; only this list clamped it.
                  //
                  // The subtitle is the only prose on this screen explaining what a
                  // category does, so an ellipsis leaves the reader with a list of
                  // unexplained labels.
                  //
                  // Letting it wrap costs no height here, which was the thing worth
                  // checking before committing to it. `ListTile` with a subtitle and
                  // `isThreeLine: false` targets 72dp, and its `_computeSizes`
                  // (list_tile.dart) falls into "compact" mode when the content
                  // will not fit the ideal baseline positions, giving
                  // `2 * minVerticalPadding + titleHeight + subtitleHeight` = 8*2 +
                  // ~20 + ~32 = ~68dp for a two-line bodySmall subtitle. So a tile
                  // that wraps is not taller than the 72dp one that truncates --
                  // the vertical slack was already reserved. The list extent does
                  // not grow, and the Save button is in `bottomNavigationBar`, so it
                  // is pinned and cannot be pushed off screen regardless.
                  //
                  // Unbounded rather than `maxLines: 2` on purpose: at a 2.0
                  // accessibility text scale these strings need three or four
                  // lines, and a clamp would reintroduce exactly the truncation
                  // this removes, for the users least able to tolerate it.
                  subtitle: Text(
                    section.subtitle,
                    style: AppType.bodySm.copyWith(color: faintColor),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                  onTap: () => _openSection(index),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailPage(BuildContext context, SettingsSection section) {
    return ListView(
      key: ValueKey('settings-${section.title}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        SectionCard(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
          child: section.builder(context, _settings),
        ),
      ],
    );
  }
}
