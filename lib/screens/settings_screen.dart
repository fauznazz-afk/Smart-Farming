import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';
import '../theme/app_theme_of.dart';
import '../utils/app_log.dart';
import '../widgets/liquid_glass.dart';
import 'dashboard/utils/design_tokens.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_section.dart';
import 'settings/widgets/settings_fields.dart';

/// Settings browser: a category list that drills into one section at a time.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.onLogout,
  });

  final AppThemeController themeController;
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
    _settings = SettingsController(themeController: widget.themeController);
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
      // A thrown exception used to escape here as an unhandled async error, so
      // the save failed with no SnackBar and no pop and the button looked
      // dead. Say so instead, and leave the details in the log -- in a debug
      // build. `appLog` compiles the line out in release, so a release user
      // reporting "save does nothing" now needs a debug build to be chased; see
      // `app_log.dart`.
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
    final theme = Theme.of(context);
    final appTheme = appThemeOf(context);
    return ListView.builder(
      key: const ValueKey('settings-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          // Each settings row is a raised plate. Tokens and the app's own
          // shadow pair rather than the hex values and two ad-hoc shadows this
          // replaced, which had no Dracula branch, and `SkeuoSurface` rather
          // than a four-colour `Border`, which crashes with a radius.
          child: SkeuoSurface(
            theme: appTheme,
            base: AppSurfaces.card(appTheme),
            radius: AppRadius.card,
            shadows: AppElevation.raised(appTheme),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: SettingsIconBadge(icon: section.icon),
                title: Text(section.title),
                subtitle: Text(
                  section.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onTap: () => _openSection(index),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
