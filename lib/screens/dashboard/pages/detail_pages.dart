import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../utils/alarm_rules.dart';
import '../../cctv_screen.dart';
import '../charts/chart_data.dart';
import '../utils/bound.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import '../widgets/metric_grid.dart';
import '../widgets/metric_specs.dart';
import '../widgets/power_sub_tabs.dart';
import '../widgets/telemetry_card.dart';

/// The gap between the header and the card under it, and between a card and
/// the block after it.
const double kDetailCardGap = AppSpacing.md;

/// Icon + title header, the gap under it, and nothing else.
///
/// Every detail page opens with this row; the page then appends its own cards.
Widget detailHeader(String title, IconData icon, MetricCategory category) {
  return Padding(
    padding: const EdgeInsets.only(bottom: kDetailCardGap),
    child: GlassPageHeader(
      title: title,
      icon: icon,
      accent: categoryColor(category),
    ),
  );
}

/// One telemetry reading card, with the staleness tag its devices' age earns.
Widget detailTelemetryCard(
  DeviceTelemetry? data,
  List<MetricDef> metrics,
  int staleMinutes,
) {
  return TelemetryCard(
    data: data,
    metrics: metrics,
    staleMinutes: staleMinutes,
  );
}

/// The segmented PV / AC / Battery selector.
Widget powerSelector(int selected, ValueChanged<int> onSelect) {
  return SizedBox(
    width: double.infinity,
    child: SegmentedButton<int>(
      segments: [
        for (final tab in kPowerSubTabs)
          ButtonSegment<int>(
            value: kPowerSubTabs.indexOf(tab),
            icon: Icon(tab.icon, size: 16),
            label: Text(tab.label),
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      // **The design system's own style, not Material's default.** The default
      // is a 14 sp w500 label on a 40 dp pill; every other control in the app
      // speaks `buttonLabel` (13 sp, w900, tracked). Left at the default this
      // selector was the one control on the Power page that looked borrowed.
      style: SegmentedButton.styleFrom(
        textStyle: AppType.buttonLabel,
        selectedBackgroundColor: AppPalette.accent,
        selectedForegroundColor: AppPalette.onHue,
        foregroundColor: AppSurfaces.onSurfaceVariant,
        side: BorderSide(color: AppSurfaces.border),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      onSelectionChanged: (selection) => onSelect(selection.first),
    ),
  );
}

/// The greenhouse readings as a grid of metric tiles.
Widget environmentGrid({
  required DeviceTelemetry? sensor,
  required AlarmThresholds thresholds,
  required int staleMinutes,
}) {
  return MetricGrid(
    title: 'Environment',
    specs: kEnvironmentSpecs,
    values: sensor?.latestValues,
    thresholds: thresholds,
    limitLabelFor: (spec) => environmentLimitLabel(spec, thresholds),
    staleMinutes: staleMinutes,
    lastUpdate: sensor?.lastUpdate,
    // The alerts toggle governs the grid's warning colours too, not just the
    // background rules — a limit the user switched off must stop colouring the
    // page, or Settings and the dashboard contradict each other.
    showGridColors: thresholds.environmentAlerts,
  );
}

/// Water quality tiles for the fish tank.
Widget fishGrid({
  required DeviceTelemetry? fish,
  required AlarmThresholds thresholds,
  required int staleMinutes,
}) {
  return MetricGrid(
    title: 'Water Quality',
    specs: kFishSpecs,
    values: fish?.latestValues,
    thresholds: thresholds,
    limitLabelFor: (spec) => environmentLimitLabel(spec, thresholds),
    showGridColors: thresholds.fishAlerts,
    // The readings still get the stale tag, so a dead sensor cannot present a
    // page of plausible numbers as current.
    staleMinutes: staleMinutes,
    lastUpdate: fish?.lastUpdate,
    // Two columns, so four readings land as 2 + 2. Three would leave the fourth
    // stranded beside a gap.
    columns: 2,
  );
}

/// A camera panel that stays alive while the page is mounted.
Widget cameraPanel({
  required Listenable keepAlive,
  required String streamUrl,
  required int selectedIndex,
  required int pageIndex,
}) {
  return Bound(
    listenable: keepAlive,
    // **`AppTheme.brightness` is in this token for the same reason it is in
    // the dashboard's `_visualToken`.** `CctvScreen`'s standby overlay is drawn
    // from `AppPalette`/`AppSurfaces`, and without the brightness a light/dark
    // switch left the play glyph and its ring painted in the other theme's
    // accent until the next poll.
    token: '$streamUrl|$selectedIndex|${AppTheme.brightness}',
    builder: () => CctvScreen(
      streamUrl: streamUrl,
      // The page index has to be known, because this panel is inside a pager
      // and is therefore mounted on every tab; see `isVisible`.
      isVisible: selectedIndex == pageIndex,
    ),
  );
}
