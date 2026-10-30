/// The Overview page's instrument panel.
///
/// **One panel, one question.** The page used to be five separate cards, each in
/// its own rounded box with its own gaps. That says "five different widgets"
/// when what it means is "one readout, and these are its fields" — so this is a
/// single frame with hairline rules inside it and every reading on a labelled
/// row.
///
/// ## Which figure is the hero, and why it changed once
///
/// The hero is **PV output**. It was the house load, on the argument that a
/// healthy array reads 0 W at midnight and 0 W under a storm, so a large figure
/// that collapses to zero every night trains the reader to distrust it. The
/// user reversed that call: what they want at a glance is what the panels are
/// producing, which is the number the whole system exists to make. Their call,
/// and the trade-off is now recorded rather than argued.
///
/// **The cost is real and is not papered over.** At 22:00 the hero reads 0, and
/// a user who opens the app to check whether the system is ok sees a zero. The
/// array's own status is on the panel anyway — `SKY_STATE` and `LUX` under SKY,
/// `ALARMS` and `METER_AGE` under SYSTEM — so the answer is two scrolls down
/// rather than one glance up. If it is ever argued back, this is the paragraph
/// to read first.
///
/// So the hero carries the array and the house draw is the row *under* it.
///
/// ## Absent values
///
/// A device that has never reported prints `--`, not `0`. The panel's claim is
/// that it reports what the sensors said, and a zero is a claim about the
/// world. `slotNumber` owns the formatting and `TerminalRow` owns the
/// placeholder, and they are separate because a figure can be absent while the
/// *row* is still meaningful — "no battery reporting" is information.
library;

import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../utils/solar_irradiance.dart';
import '../utils/design_tokens.dart';
import 'terminal_panel.dart';

/// Returns a simple icon for the sky condition.
Widget _skyIcon(SkyCondition condition, {double size = 24, Color? color}) {
  final icon = switch (condition) {
    SkyCondition.clear => Icons.wb_sunny_rounded,
    SkyCondition.partlyCloudy => Icons.wb_cloudy_rounded,
    SkyCondition.overcast => Icons.cloud_rounded,
    SkyCondition.night => Icons.nightlight_round,
  };
  return Icon(icon, size: size, color: color ?? AppSurfaces.onSurfaceVariant);
}

/// The panel's inputs, resolved once by the screen.
///
/// **A single record rather than eleven constructor parameters.** The screen owns
/// the device state and this widget owns the layout; passing the devices would
/// put ThingsBoard shapes into a presentation file and make it untestable
/// without a server. Resolving to plain doubles and strings at the boundary is
/// what lets this be pumped in a widget test at all.
///
/// Every field is nullable for the same reason: a device that has never reported
/// is a state the panel has to draw, not an error it has to avoid.
class OverviewReadings {
  const OverviewReadings({
    this.displayName = '',
    this.pvPower,
    this.pvPeak,
    this.acPower,
    this.batteryPower,
    this.soc,
    this.batteryVoltage,
    this.acVoltage,
    this.lux,
    this.pzemAgeLabel,
    this.pzemStale = false,
    this.batteryStale = false,
    this.solarKwh,
    this.loadKwh,
    this.previousSolarKwh,
    this.previousLoadKwh,
    this.energyLoading = false,
    this.energyError,
    this.forecastTargetProgress,
    this.productionProgress,
    this.forecastBatteryHours,
    this.weekly = false,
    this.activeAlerts = 0,
    this.staleDevices = const [],
    this.isLive = false,
  });

  /// The grower's name, for the header. Empty until the profile loads.
  final String displayName;

  final double? pvPower;

  /// The highest PV output reached so far in the window on screen.
  ///
  /// **A separate field because `Peak` used to be `pvPower` with a clamp on it.**
  /// That made the hero's own secondary figure report the present as if it were
  /// the best the day has done, which is not a rounding difference: at 11:00 on a
  /// rising curve they are equal, and every other minute they are not. The user
  /// read it as "the peak just follows the PV number".
  ///
  /// `null` when no history is in hand, in which case the row says so rather than
  /// quietly falling back to the current figure - a fallback that looks identical
  /// to the bug is not worth having.
  final double? pvPeak;

  final double? acPower;
  final double? batteryPower;
  final double? soc;
  final double? batteryVoltage;
  final double? acVoltage;

  /// The greenhouse lux reading, for the sky row.
  final double? lux;

  final String? pzemAgeLabel;
  final bool pzemStale;
  final bool batteryStale;

  /// Energy for the period, from `energyComparison`.
  ///
  /// **These arrive already aggregated — daily or weekly depending on
  /// [weekly] — and the panel does not recompute them.** The comparison used to
  /// run inside `EnergySummaryCard`, which meant the rule lived in a widget; it
  /// now runs in `_updateMemoizedEnergy` and the panel reads the result. Two
  /// screens reporting different totals for one period is exactly what
  /// `energy_comparison_test.dart` exists to prevent, and a second copy of the
  /// rule in the panel would put it back.
  final double? solarKwh;
  final double? loadKwh;
  final double? previousSolarKwh;
  final double? previousLoadKwh;

  /// Whether the energy history fetch is in flight.
  final bool energyLoading;

  /// Set when the history could not be fetched. Shown rather than swallowed —
  /// a panel that silently stops reporting energy is worse than one that says so.
  final String? energyError;

  /// How far today's generation is toward the user's daily target, as 0–1+.
  ///
  /// Null when no target is set in Settings. The row disappears rather than
  /// showing `0%`, because "no target configured" and "produced nothing" are
  /// different facts and only one of them is a failure.
  final double? forecastTargetProgress;

  /// Today's *actual* production against the daily target, as a fraction.
  ///
  /// **This is what the Overview's `TARGET` row shows, and it is deliberately
  /// not [forecastTargetProgress].** That one divides a 24-hour extrapolation of
  /// the day's production by the daily target, which is a forecast of a forecast:
  /// at 13:00 on a good day it reads well past 100% because it has already
  /// assumed the afternoon it is halfway through. The row is labelled `TARGET`
  /// next to a production figure, so the reader takes it as progress made, and
  /// the user read 176% at midday as the number being wrong.
  ///
  /// The forecast's own estimate is still correct for what it is, and
  /// `EnergySummaryCard` labels it as an estimate; this is the measurement.
  final double? productionProgress;

  /// Hours of runtime the forecast projects, or null when it cannot say.
  ///
  /// **Negative is meaningful and is not clamped here.** The service returns a
  /// negative figure when the array cannot cover the house load, and that is the
  /// most useful number it produces — "minus three hours" means *right now*.
  final double? forecastBatteryHours;

  /// True when the figures cover seven days rather than one.
  final bool weekly;

  /// How many alarm rules are currently firing.
  final int activeAlerts;

  /// Names of devices that stopped reporting.
  final List<String> staleDevices;

  /// Whether the data source is live (realtime websocket connected).
  /// Drives the subtle pulse on the hero figure.
  final bool isLive;
}

/// The whole Overview readout.
class OverviewPanel extends StatelessWidget {
  const OverviewPanel({
    super.key,
    required this.readings,
    this.onOpenBattery,
    this.onOpenEnergyReport,
    this.onToggleEnergyPeriod,
  });

  final OverviewReadings readings;

  /// Tapping `BAT_SOC` jumps to the Battery view in the Power tab.
  final VoidCallback? onOpenBattery;

  /// Tapping the ENERGY heading opens the full energy report.
  final VoidCallback? onOpenEnergyReport;

  /// Tapping the energy rows toggles the period between today and this week.
  ///
  /// **The toggle moved onto the rows themselves rather than into a separate
  /// control.** `EnergySummaryCard` owned it as a segmented pair of buttons; the
  /// panel has no room for that, and the rows are what the toggle changes, so the
  /// rows are what carries it. `_weeklyEnergySummary` is still the screen's
  /// state, so the aggregation rule is unchanged.
  final VoidCallback? onToggleEnergyPeriod;

  @override
  Widget build(BuildContext context) {
    final r = readings;
    final batteryState = r.batteryPower == null
        ? null
        : batteryChargeState(r.batteryPower!);

    return TerminalPanel(
      header: _Header(readings: r),
      children: [
        TerminalHero(
          // **The array, not the house draw.** It was the house draw, on the
          // argument that a healthy array reads 0 W at midnight and 0 W under a
          // storm, so a large PV figure trains the reader to distrust it. The
          // user reversed that call, which is theirs to make — see the file doc
          // for the trade-off now recorded.
          figure: slotNumber(r.pvPower, decimals: 0),
          unit: 'W',
          // **The slot name, not a sentence.** A caption in prose above an 88 dp
          // figure is the loudest quiet thing on the page; `PV_OUT` is in the
          // panel's own voice, sits on the header row beside the stats, and
          // labels the block instead of competing with it.
          slot: 'PV_OUT',
          secondary: [
            ('Peak', slotNumber(r.pvPeak ?? r.pvPower ?? 0, decimals: 0)),
            ('Stale', r.pzemStale ? 'YES' : 'NO'),
          ],
          isLive: r.isLive,
        ),
        const TerminalRule(),

        _section('POWER'),
        TerminalRow(
          label: 'AC_LOAD',
          value: slotNumber(r.acPower, decimals: 0),
          unit: 'W',
          alert: r.pzemStale,
          divider: false,
        ),
        TerminalRow(
          label: 'BAT_FLOW',
          value: slotNumber(r.batteryPower, decimals: 0),
          unit: 'W',
          divider: false,
        ),
        // **The meter is the shortcut to the Battery view, and that is not a
        // detail.**
        //
        // This row is the *only* place on the Overview that opened the battery
        // readings — `SystemStatusStrip.onOpenBattery` was its sole caller, and
        // replacing that strip with this panel would have silently deleted the
        // route. The meter is the right target for it because "how full is the
        // pack" is the question the tap answers, so the affordance is the thing
        // being asked about rather than a separate chevron nobody notices.
        TerminalMeter(
          fraction: _socFraction(r.soc),
          alert: r.batteryStale,
          // **Both captions carry the real figure.** The left one used to be
          // the literal `'BAT_SOC 0%'`, which was invisible while the meter drew
          // a continuous fill and became a flat contradiction the moment the bar
          // was segmented: 0% over eight lit blocks. The right caption had it
          // right all along, so the two now read from one expression.
          leftCaption:
              'BAT_SOC ${r.soc == null ? '--' : slotNumber(r.soc, decimals: 0)}%',
          // **The right caption is the scale, not the value again.** It read
          // `'58%  100%'` while the left one already said `BAT_SOC 58%`, so the
          // same two characters were printed twice on one 8 dp line with nothing
          // between them — the one place on the panel where the eye had to stop
          // and work out which was the reading. The widget's own doc says the
          // two ends of the bar are the caption's job; the value belongs on the
          // left, next to its slot name, and the scale on the right.
          rightCaption: '0%   100%',
          onTap: onOpenBattery,
        ),
        TerminalRow(
          label: 'BAT_STATE',
          value: batteryState?.label ?? '--',
          alert: r.batteryStale,
          divider: false,
        ),
        TerminalRow(
          label: 'DC_V',
          value: slotNumber(r.batteryVoltage, decimals: 1),
          unit: 'V',
          divider: false,
        ),
        TerminalRow(
          label: 'AC_V',
          value: slotNumber(r.acVoltage, decimals: 1),
          unit: 'V',
          divider: false,
        ),

        // **This one stays.** The hero is the only block on the panel that is
        // not a list of labelled rows, so the full-width rule under it carries a
        // distinction the other three do not — they only ever followed a row,
        // and a row followed by a row is a table.
        // **No full-width rule here any more.** The heading now runs into its own
        // leader rule, so the old one drew a second line 12 dp above it and every
        // section boundary acquired a pair of rules.
        _section('SKY'),
        TerminalRow(
          label: 'LUX',
          value: slotNumber(r.lux, decimals: 0),
          unit: 'lx',
          divider: false,
        ),
        TerminalRow(
          label: 'SKY_STATE',
          value: r.lux == null ? '--' : skyConditionFor(r.lux!).label,
          // **On the right edge, at the end of the row, and not in a block of
          // its own.**
          //
          // A centred block between two table rows was tried and reverted: the
          // panel is one instrument read as columns, and a figure with its name
          // stacked under it in the middle of a column reads as a section
          // heading that lost its heading. `trailing` puts it on the far right
          // where the eye already lands for the value, and the slot name keeps
          // the left edge to itself.
          //
          // 44 dp, not the 22 it started at and not the 72 the block used.
          // 72 made the row 86 dp tall in a column of 43 dp rows; 22 put the
          // lamps at 0.84 dp, smaller than the gaps between them, which is a
          // texture rather than a picture. 44 is the house tap-size floor and
          // puts a lamp at 2.3 dp - visible, and a row that still belongs to its
          // neighbours.
          trailing: r.lux == null
              ? null
              : _skyIcon(
                  skyConditionFor(r.lux!),
                  size: 28,
                  color: AppSurfaces.onSurfaceVariant,
                ),
          divider: false,
        ),
        // **No bar under the sky rows.** There are two meters in this panel and
        // only one of them is actionable — `BAT_SOC` opens the Battery view.
        // A second bar under `SKY_STATE` read as a second shortcut and drew the
        // eye to the one figure on the page that has no route behind it.
        // `LUX` and the condition together already say whether the sky is doing
        // anything.
        const SizedBox(height: AppSpacing.xs),

        // **No full-width rule here either.** This one was left in and it is the
        // asymmetry the whole change is about: POWER, SKY and SYSTEM lost the
        // rule because their heading draws one, and ENERGY — the only heading
        // with a route on it, so the only one wrapped in a `Row` — kept it and
        // ended up with the exact pair of lines 12 dp apart that the others were
        // cleaned of.
        //
        // **The heading carries the report's route.** `EnergySummaryCard`'s
        // `onOpenReport` was the only other caller of `_openEnergyReport`, so
        // dropping that card would have left the full report unreachable from
        // anywhere. A tappable section heading is quieter than a button and
        // costs no vertical space, which matters on a panel that is already the
        // densest thing in the app.
        _section(
          'ENERGY ${r.weekly ? '(7D)' : '(24H)'}',
          onTap: onOpenEnergyReport,
        ),
        TerminalRow(
          label: r.weekly ? 'SOLAR_GEN_7D' : 'SOLAR_GEN_24H',
          value: slotNumber(r.solarKwh, decimals: 2),
          unit: 'kWh',
          onTap: onToggleEnergyPeriod,
          divider: false,
        ),
        TerminalRow(
          label: 'LOAD_USED',
          value: slotNumber(r.loadKwh, decimals: 2),
          unit: 'kWh',
          divider: false,
        ),
        TerminalRow(
          label: 'PREV_SOLAR',
          value: slotNumber(r.previousSolarKwh, decimals: 2),
          unit: 'kWh',
          divider: false,
        ),
        TerminalRow(
          label: 'PREV_LOAD',
          value: slotNumber(r.previousLoadKwh, decimals: 2),
          unit: 'kWh',
          divider: false,
        ),
        if (r.energyError != null)
          TerminalRow(
            label: 'ENERGY_ERR',
            value: r.energyError!,
            alert: true,
            divider: false,
          )
        else if (r.productionProgress != null)
          TerminalRow(
            label: 'TARGET',
            value: (r.productionProgress! * 100).toStringAsFixed(0),
            unit: '%',
            divider: false,
          ),
        if (r.forecastBatteryHours != null)
          TerminalRow(
            label: 'BAT_RUNTIME',
            value: r.forecastBatteryHours!.toStringAsFixed(1),
            unit: 'h',
            // **An alert below zero hours is not a fault.** The forecast returns
            // a negative figure when the array cannot cover the load, which is
            // the single most useful thing it says — "you run out in minus three
            // hours" means *now*. Painting it as a breach would be exactly as
            // useless as painting it as fine.
            divider: false,
          ),

        // **No full-width rule here any more.** The heading now runs into its own
        // leader rule, so the old one drew a second line 12 dp above it and every
        // section boundary acquired a pair of rules.
        _section('SYSTEM'),
        TerminalRow(
          label: 'ALARMS',
          value: r.activeAlerts == 0 ? 'NONE' : '${r.activeAlerts}',
          alert: r.activeAlerts > 0,
          divider: false,
        ),
        TerminalRow(
          label: 'METER_AGE',
          value: r.pzemAgeLabel ?? '--',
          // **The small size, and it is the reason `valueStyle` exists.** Every
          // other value on this panel is a figure, so `slotValue`'s 24 px was
          // correct by default — and this one is a sentence. `Updated 3 minutes
          // ago` at 24 px w700 was the longest run of text on the panel and it
          // reached nearly to the slot name, so the row's eye stopped there
          // instead of on `ALARMS` and `OFFLINE` directly above and below it.
          // Freshness is metadata about the feed, and the meter caption above
          // already reports the one number that matters.
          valueStyle: AppType.slotValueSmall,
          alert: r.pzemStale,
          // **Always false.** This was `divider: r.staleDevices.isEmpty`, which
          // is the same condition as the closing rule below — so in the
          // no-stale-device case `METER_AGE`'s own `Divider` and that rule were
          // both drawn, one directly under the other with nothing between them.
          // Two 1 px lines with zero gap between them read as one 2 px line.
          // And in the stale case the rule was suppressed, leaving `OFFLINE`
          // as the last thing in the card with nothing closing it.
          // One closing rule, unconditional; no row draws one here.
          divider: false,
        ),
        if (r.staleDevices.isNotEmpty)
          TerminalRow(
            label: 'OFFLINE',
            value: r.staleDevices.join(', '),
            alert: true,
            divider: false,
          ),
        const TerminalRule(),
      ],
    );
  }

  /// SOC as a 0–1 fraction, with a null guarded.
  ///
  /// **A null is 0 here, and that is correct rather than convenient.** The meter
  /// is a bar; a bar with nothing in it is "nothing known", which is the honest
  /// reading. What would be wrong is showing a *full* bar, and `TerminalMeter`
  /// clamps so a bad sensor value cannot draw past the track either.
  static double _socFraction(double? soc) =>
      soc == null ? 0 : (soc / 100).clamp(0.0, 1.0);

  /// **Deleted: it was never a peak.**
  ///
  /// It read `acPower` - clamped at zero - and was called from the *PV* hero, so
  /// "Peak" was the current PV figure whenever the caller passed `pvPower` in.
  /// The name said one thing, the argument said another, and the panel rendered
  /// the present as though it were the best the day has managed. It is now
  /// [OverviewReadings.pvPeak], which the dashboard computes from the history it
  /// already holds.

  /// A section heading: a small monospace key that introduces a group of rows.
  ///
  /// **The heading runs into a leader rule, and that is what gives it weight.**
  /// At 10 px it was the smallest text on the panel, and nothing around it said
  /// "this starts a group" — so `POWER` and `SKY` read as two more row labels
  /// in a list of eighteen, and the panel was one long undifferentiated column
  /// with four hairlines in it. The rule carries the heading to the right edge,
  /// which turns a floating word into the head of a ruled block.
  ///
  /// **Its weight stays the token's `w500`.** `design_tokens_test.dart` states
  /// the invariant as "the panel scale is exactly two weights, and the split is
  /// keys vs values" — and that test reads the tokens, so a `copyWith` at a call
  /// site drifts past it silently. A third weight would have been the third
  /// thing standing in for structure, and the rule is structure.
  ///
  /// The rule is the theme's own `Divider` — the same one [TerminalRule] draws,
  /// and un-tinted. A coloured rule here would be a drawn edge on the card,
  /// which is the one thing this app's surface system exists to avoid.
  ///
  /// [onTap] makes the heading a route rather than a decoration — see the note
  /// at the ENERGY heading for why the route lives here.
  static Widget _section(String label, {VoidCallback? onTap}) {
    final text = Text(
      label,
      style: AppType.slotMicro.copyWith(color: AppPalette.accent),
    );
    return Padding(
      // **Top `md`, bottom `xs`.** The first of these was `sm`/`xs` on the
      // argument that "a heading belongs to what is under it", which is true and
      // was half the problem: with 8 dp of air above and only the rows' own 9 dp
      // below, the heading sat in the middle of its own whitespace. Top 12
      // against bottom 4 puts it against the rows and lets the rule above it
      // supply the separation.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.md,
        AppSpacing.cardPadding,
        AppSpacing.xs,
      ),
      child: onTap == null
          ? _ruled(text)
          : InkWell(
              onTap: onTap,
              // A heading is full-bleed to the panel's padding, so the ripple has
              // to be given the same shape or it draws a rounded blob inside a
              // square strip.
              borderRadius: AppRadius.all(AppRadius.badge),
              child: _ruled(text, chevron: true),
            ),
    );
  }

  /// The heading text, an optional route chevron, then a hairline out to the
  /// panel's right padding.
  static Widget _ruled(Widget text, {bool chevron = false}) {
    return Row(
      children: [
        text,
        if (chevron) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right,
            size: 12,
            color: AppSurfaces.onSurfaceVariant,
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        // `CrossAxisAlignment.center` hands this loose vertical constraints, so
        // `Divider`'s own 1 dp height holds and the rule sits on the text's
        // optical centre rather than underlining it.
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// The panel header: who is logged in, and the one tag worth showing.
class _Header extends StatelessWidget {
  const _Header({required this.readings});

  final OverviewReadings readings;

  @override
  Widget build(BuildContext context) {
    final r = readings;
    final name = r.displayName.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.md,
        AppSpacing.cardPadding,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? 'ENerGROW' : name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.slotKey.copyWith(
                    color: AppSurfaces.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (name.isNotEmpty)
                  Text(
                    // Red, like the reference's station label. The name above
                    // stays white so the two lines are not one red block.
                    'OVERVIEW',
                    style: AppType.slotMicro.copyWith(color: AppPalette.accent),
                  ),
              ],
            ),
          ),
          // **One tag, and it is the alarms.** The alternative was also showing
          // a stale-device tag here, which is how this header ends up with three
          // competing statuses. The row list below already says `METER_AGE` and
          // `OFFLINE` in full; repeating them as chips at the top means the
          // reader sees the same fact twice in two different vocabularies.
          if (r.activeAlerts > 0)
            // **Pluralised.** `TerminalTag` uppercases what it is given, so a bare
            // `'alarm'` printed as `3 ALARM` — and it is a tag on a panel whose
            // whole argument is that its labels are precise. One alarm and many
            // alarms are also two different states of the system, not two ways
            // of writing the same one.
            TerminalTag(
              text: r.activeAlerts == 1
                  ? '1 alarm'
                  : '${r.activeAlerts} alarms',
              alert: true,
            )
          else if (r.pzemStale || r.batteryStale)
            TerminalTag(text: 'Stale', alert: true),
        ],
      ),
    );
  }
}
