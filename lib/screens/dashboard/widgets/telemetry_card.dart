import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../theme/app_theme_of.dart';
import '../../../widgets/liquid_glass.dart';
import '../charts/chart_data.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';

/// Icon + title row used at the top of each detail page.
class GlassPageHeader extends StatelessWidget {
  const GlassPageHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final String title;
  final IconData icon;
  final Color accent;

  /// Still a `bool`, and deliberately.
  ///
  /// This header is a glyph and a heading: it paints one icon in the raw accent
  /// at 0.15 alpha and one run of ordinary text, with no surface, no shadow pair
  /// and no border of its own. Nothing here is per-theme, and `appPrimaryText`
  /// is the one text colour the two dark presets share, so the correct
  /// migration is to pass `theme.isDark` rather than to widen the parameter.
  /// A Dracula call site therefore supplies `theme.isDark` at the boundary.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // The shipped 0.15 accent wash, made opaque so it can be lit from
            // above, and lit away from the icon — which *is* the accent. The
            // first skeuomorphic pass put a near-opaque accent at the top of
            // this circle, so the icon all but vanished into it.
            gradient: AppSkeuo.fillGradient(
              Color.alphaBlend(
                accent.withValues(alpha: 0.15),
                AppSurfaces.card(appThemeOf(context)),
              ),
              foreground: accent,
            ),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: appPrimaryText(isDark),
          ),
        ),
      ],
    );
  }
}

/// Vertical list of key/value metrics for a single device, with a stale
/// telemetry notice when the device has not reported recently.
class TelemetryCard extends StatelessWidget {
  const TelemetryCard({
    super.key,
    required this.data,
    required this.metrics,
    required this.theme,
    required this.seedColor,
    required this.staleMinutes,
  });

  final DeviceTelemetry? data;
  final List<MetricDef> metrics;

  /// The appearance to paint, as an `AppTheme`.
  ///
  /// This one **must** be the enum rather than a bool, and the card itself is the
  /// reason: `AppCard` draws the `raised` pair and a hairline, and both have
  /// their own Dracula derivation. It also owns the per-row accent, and
  /// `metricColor` needs a theme because Dracula's purple wants a different HSL
  /// lightness than the dark theme's green does for any hue.
  ///
  /// The captions below still take `theme.isDark`, because a text colour is
  /// shared by both dark presets.
  final AppTheme theme;

  final Color seedColor;
  final int staleMinutes;

  @override
  Widget build(BuildContext context) {
    final stale = data?.isStale(minutes: staleMinutes) ?? true;
    return AppCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          if (stale) _StaleNotice(ageLabel: data?.ageLabel, isDark: theme.isDark),
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricRow(
              metric: metrics[index],
              value: data?.latestValues[metrics[index].key],
              accent: metricColor(
                seedColor: seedColor,
                index: index,
                theme: theme,
              ),
              isDark: theme.isDark,
            ),
            // The rule between two rows of one card. `AppDivider`'s default
            // opacity is the one this was already asking for, so it is passed
            // through as the theme rather than as a brightness.
            if (index < metrics.length - 1) AppDivider(theme: theme),
          ],
        ],
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.ageLabel, required this.isDark});

  final String? ageLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 15,
            color: faintColor(isDark),
          ),
          const SizedBox(width: 6),
          Text(
            ageLabel ?? 'No update received',
            style: TextStyle(
              fontSize: 12,
              color: faintColor(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.value,
    required this.accent,
    required this.isDark,
  });

  final MetricDef metric;
  final double? value;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final unit = metric.unit;
    final decimals = metric.decimals;
    final displayValue = value == null
        ? (unit.isEmpty ? '--' : '-- $unit')
        : (unit.isEmpty
              ? value!.toStringAsFixed(decimals)
              : '${value!.toStringAsFixed(decimals)} $unit');
    return MergeSemantics(
      child: Semantics(
        // `metric.label`, not `$metric`. MetricDef has no toString(), so
        // interpolating the object announced "Instance of 'MetricDef': 45 %" to a
        // screen reader instead of "State of Charge: 45 %". It compiles and passes
        // every lint, which is why it survived.
        label: '${metric.label}: $displayValue',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(metric.icon, size: 19, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.label,
                  style: TextStyle(color: appPrimaryText(isDark)),
                ),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: appPrimaryText(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


