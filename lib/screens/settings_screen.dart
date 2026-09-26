import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';
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
    final error = await _settings.save();
    if (error != null) {
      _showError(error);
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
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
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
                    child: SaveSettingsButton(
                      saving: _settings.saving,
                      onPressed: _save,
                    ),
                  ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (openSection) {
                final section? => _buildDetailPage(context, section),
                _ => _buildCategoryList(context),
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      key: const ValueKey('settings-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final section = _sections[index];
        return ListTile(
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
