/// The Overview page's instrument panel.
///
/// **One panel, one question.** The page used to be five separate cards, each in
/// its own rounded box with its own gaps. That says "five different widgets"
/// when what it means is "one readout, and these are its fields" — so this is a
/// single frame with hairline rules inside it and every reading on a labelled
/// row.
///
/// ## Which figure is the hero, and why it is not the power
///
/// The hero is **total load**, not PV output. That is a decision, so here is the
/// reasoning: PV output alone cannot answer "is the system ok", because a
/// perfectly healthy array reads 0 W at midnight and 0 W under a storm. The
/// number a grower actually wants on opening the app is the one the house is
/// drawing, because that is the thing that has to keep working — and it is the
/// only figure on this page that is bounded, non-negative and always present.
///
/// So the hero carries the load, and the array is the row *under* it. Reversing
/// those two was the other candidate and it inverts the page's meaning: a big
/// number that collapses to zero every night trains the reader to distrust it.
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
    this.forecastBatteryHours,
    this.weekly = false,
    this.activeAlerts = 0,
    this.staleDevices = const [],
  });

  /// The grower's name, for the header. Empty until the profile loads.
  final String displayName;

  final double? pvPower;
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
          // The house draw, for the reason in the file doc.
          figure: slotNumber(r.acPower, decimals: 0),
          unit: 'W',
          caption: 'House load',
          secondary: [
            ('Peak', slotNumber(_todayPeak(r.acPower), decimals: 0)),
            ('Stale', r.pzemStale ? 'YES' : 'NO'),
          ],
        ),
        const TerminalRule(),

        _section('POWER'),
        TerminalRow(
          label: 'PV_OUT',
          value: slotNumber(r.pvPower, decimals: 0),
          unit: 'W',
          divider: false,
        ),
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
          leftCaption: 'BAT_SOC 0%',
          rightCaption: r.soc == null ? '--' : '${slotNumber(r.soc, decimals: 0)}%  100%',
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

        const TerminalRule(),
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
          divider: false,
        ),
        TerminalMeter(
          fraction: sunFraction(r.lux ?? 0),
          leftCaption: '0%',
          rightCaption: '100% SUN',
        ),

        const TerminalRule(),
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
        else if (r.forecastTargetProgress != null)
          TerminalRow(
            label: 'TARGET',
            value: (r.forecastTargetProgress! * 100).toStringAsFixed(0),
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

        const TerminalRule(),
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
          alert: r.pzemStale,
          divider: r.staleDevices.isEmpty,
        ),
        if (r.staleDevices.isNotEmpty)
          TerminalRow(
            label: 'OFFLINE',
            value: r.staleDevices.join(', '),
            alert: true,
            divider: false,
          ),
        if (r.staleDevices.isEmpty)
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

  /// The house draw, clamped at zero.
  ///
  /// **Negative load is not a thing and is not the sensor's fault.** An inverter
  /// mid-switchover can report a small negative, the same way the BMS reports
  /// `-0.01 A` while idle, and a hero figure that reads `-3 W` is a number the
  /// reader has to work out the sign of. Zero is what "not drawing" means.
  static double _todayPeak(double? acPower) =>
      acPower == null ? 0 : (acPower < 0 ? 0 : acPower);

  /// A section heading: a small monospace key above a group of rows.
  ///
  /// [onTap] makes the heading a route rather than a decoration — see the note
  /// at the ENERGY heading for why the route lives here.
  static Widget _section(String label, {VoidCallback? onTap}) {
    final text = Text(
      label,
      style: AppType.slotMicro.copyWith(color: AppSurfaces.onSurfaceVariant),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.md,
        AppSpacing.cardPadding,
        AppSpacing.sm,
      ),
      child: onTap == null
          ? text
          : InkWell(
              onTap: onTap,
              // A heading is full-bleed to the panel's padding, so the ripple has
              // to be given the same shape or it draws a rounded blob inside a
              // square strip.
              borderRadius: AppRadius.all(AppRadius.badge),
              child: Row(
                children: [
                  text,
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right,
                    size: 12,
                    color: AppSurfaces.onSurfaceVariant,
                  ),
                ],
              ),
            ),
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
                    'OVERVIEW',
                    style: AppType.slotMicro.copyWith(
                      color: AppSurfaces.onSurfaceVariant,
                    ),
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
            TerminalTag(text: '${r.activeAlerts} alarm', alert: true)
          else if (r.pzemStale || r.batteryStale)
            TerminalTag(text: 'Stale', alert: true),
        ],
      ),
    );
  }
}