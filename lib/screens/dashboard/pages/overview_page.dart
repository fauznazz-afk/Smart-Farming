import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../../../services/energy_forecast_service.dart';
import '../../../utils/alarm_rules.dart';
import '../../../utils/battery_sign.dart';
import '../../../utils/date_summary_stats.dart';
import '../../../utils/production_buckets.dart';
import '../../../utils/solar_irradiance.dart';
import '../utils/date_helpers.dart';
import '../utils/history_range.dart';
import '../utils/telemetry_helpers.dart';
import '../widgets/cost_summary_panel.dart';
import '../widgets/date_strip.dart';
import '../widgets/date_summary_panel.dart';
import '../widgets/glass_hero_card.dart';
import '../widgets/glass_sheet.dart';
import '../widgets/metric_grid.dart';
import '../widgets/metric_specs.dart';
import '../widgets/terminal_panel.dart' show slotNumber;

/// Everything the hero card, the 7-day sheet and the two panels below it read.
///
/// One object rather than a dozen parameters because the three blocks share
/// most of them, and a caller that passes the wrong reading to the wrong block
/// is exactly the class of bug the Overview cannot show: every figure still
/// renders.
class OverviewInputs {
  const OverviewInputs({
    required this.displayName,
    required this.battery,
    required this.pzem,
    required this.sensor,
    required this.history,
    required this.energyHistory,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.stripDays,
    required this.activeAlerts,
    required this.exportingCsv,
    required this.solarKwh,
    required this.loadKwh,
    required this.energyLoading,
    required this.energyError,
    required this.weeklyEnergySummary,
    required this.dailyProductionTargetKwh,
    required this.electricityTariffPerKwh,
    required this.pvInstalledWp,
    required this.thresholds,
    required this.bindRevision,
    required this.liveRevision,
    required this.energyRevision,
    required this.chartRevision,
    required this.onPickDate,
    required this.onOpenAlarmHistory,
    required this.onExportCsv,
    required this.onOpenSettings,
    required this.onOpenBattery,
    required this.onOpenEnergyReport,
    required this.onSelectDate,
    required this.onTogglePeriod,
    required this.loadSummaryHistory,
    required this.summarySettled,
  });

  final String displayName;
  final DeviceTelemetry? battery;
  final DeviceTelemetry? pzem;
  final DeviceTelemetry? sensor;
  final Map<String, List<TelemetryPoint>> history;
  final Map<String, List<TelemetryPoint>> energyHistory;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final List<DateTime> stripDays;
  final Set<String> activeAlerts;
  final bool exportingCsv;
  final double solarKwh;
  final double loadKwh;
  final bool energyLoading;
  final String? energyError;
  final bool weeklyEnergySummary;
  final double? dailyProductionTargetKwh;
  final double? electricityTariffPerKwh;
  final double? pvInstalledWp;
  final AlarmThresholds thresholds;

  final Widget Function(Listenable listenable, Widget Function() builder)
  bindRevision;
  final Listenable liveRevision;
  final Listenable energyRevision;
  final Listenable chartRevision;

  final VoidCallback onPickDate;
  final VoidCallback onOpenAlarmHistory;
  final VoidCallback onExportCsv;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenBattery;
  final VoidCallback onOpenEnergyReport;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<bool> onTogglePeriod;

  /// Fetches the greenhouse and fish history the period summary reads. Called
  /// only when the selected window is not today.
  final VoidCallback loadSummaryHistory;

  /// Whether the greenhouse or fish history has settled (loaded or failed).
  /// Until it has, the period summary renders nothing rather than flashing its
  /// "nothing recorded" state on the way to having rows.
  final bool summarySettled;
}

/// The Overview page, in the order the eye reads it: the hero, the 7-day sheet,
/// the cost card, then the period summary.
///
/// **The instrument panel is gone from here, deliberately.** `OverviewPanel`
/// was a 25-row terminal readout — PV_OUT, POWER, SKY, ENERGY, SYSTEM — stacked
/// *underneath* the glass hero and the 7-day sheet. Every headline figure on it
/// was already on the page above: the hero carries PV output, peak, AC load,
/// battery state and SOC; the sheet carries the 7-day totals. What it added was
/// a second, taller way of reading the same numbers, which is why the Overview
/// needed two scrolls to reach the nav bar.
///
/// Nothing became unreachable. AC load, battery flow and both voltages are rows
/// on the Power tab's own panel; lux, temperature and humidity are rows on
/// Hydroponics and Fish. The nav bar reaches each in one tap, so the removed
/// shortcut cost one tap on a route that still exists.
List<Widget Function()> overviewPage(OverviewInputs inputs) {
  return [
    () => inputs.bindRevision(inputs.liveRevision, () => _glassHero(inputs)),
    // **The date strip is inside the hero card now** (`GlassHeroCard.footer`),
    // with its range trigger among the card's actions, so the two rows are one
    // surface instead of two unrelated ones with an empty header strip above
    // the chips.
    //
    // **The CSV export row is gone from this page**, and the capability moved
    // to the app bar rather than disappearing with it. It was a line of text
    // right under the date strip, which is the most valuable real estate on the
    // screen for the app's least-used feature.
    () => const SizedBox(height: 18),
    () => inputs.bindRevision(
      inputs.energyRevision,
      () => _forecastSheet(inputs),
    ),
    // **Cost and array performance, below the panel that reports the kWh it is
    // derived from.**
    //
    // `energyRevision`, not `liveRevision` or `chartRevision`: `solarKwh` and
    // `loadKwh` are memoised by `_updateMemoizedEnergy`, which only the
    // energy-history fetch and the 24h/7d toggle write, and both bump that
    // counter. Binding it to the ten-second poll would rebuild a panel whose
    // numbers cannot change ten times a second.
    //
    // The period label comes from the same switch the ENERGY section uses, so
    // the two blocks cannot disagree about which window they are describing.
    () => inputs.bindRevision(inputs.energyRevision, () {
      final panel = _costSummaryPanel(inputs);
      return panel == null
          ? const SizedBox.shrink()
          : Column(children: [const SizedBox(height: 8), panel]);
    }),
    // **The period summary, bound to `chartRevision` and not `liveRevision`.**
    //
    // It reads the history, which only the history fetch writes, and it reads
    // nothing live — a day does not change because the meter ticked. Binding
    // it to the live revision would rebuild it every ten seconds to produce
    // identical numbers.
    //
    // The panel renders null for today's selection, which keeps it off the
    // page entirely rather than showing an empty frame.
    () => inputs.bindRevision(
      inputs.chartRevision,
      () {
        final panel = _dateSummaryPanel(inputs);
        return panel == null
            ? const SizedBox.shrink()
            : Column(children: [const SizedBox(height: 8), panel]);
      },
    ),
  ];
}

/// The glass hero: the site's name, today's date, the sun glyph, the array's
/// live output, and the three figures that qualify it.
///
/// **The hero is PV output**, with the trade-off recorded on `OverviewPanel`:
/// at midnight it reads zero, and the array's own status is on the Power tab.
/// What changed is the presentation — this is the reference's hero card with
/// telemetry in it, so the biggest number on the page is the one the panels
/// exist to produce.
///
/// The stat row is battery power, battery state and state of charge: the three
/// numbers that answer "where is the power going", which is the question the
/// hero's own figure cannot. AC load is the hero's `Load` pill directly above,
/// so printing it a second time in the row spent a third of it on a number
/// already on screen.
Widget _glassHero(OverviewInputs inputs) {
  final pzem = inputs.pzem;
  final battery = inputs.battery;
  final lux = inputs.sensor?.latestValues['lux'];
  final pvPower = pzem?.latestValues['power_dc'];
  final acPower = pzem?.latestValues['power_ac'];
  final batteryPower = battery?.latestValues['power'];
  final soc = battery?.latestValues['soc'];
  final peak = pvPeakWatts(
    inputs.history['power_dc'] ?? const <TelemetryPoint>[],
    livePower: pvPower,
  );

  // A device that has never reported prints `--`, never `0`. `slotNumber` owns
  // that decision and every figure below goes through it, so the page cannot
  // claim the panels produced nothing.
  return GlassHeroCard(
    title: inputs.displayName.trim().isEmpty
        ? 'EnerGrow'
        : inputs.displayName.trim(),
    subtitle: _heroSubtitle(),
    icon: _heroSkyIcon(lux),
    figure: slotNumber(pvPower, decimals: 0),
    unit: 'W',
    conditionLabel: lux == null ? 'No sky sensor' : skyConditionFor(lux).label,
    highLabel: 'Peak',
    highValue: peak == null ? '--' : '${slotNumber(peak, decimals: 0)} W',
    lowLabel: 'Load',
    lowValue: '${slotNumber(acPower, decimals: 0)} W',
    stats: [
      // **Battery power in watts, not AC load.** See `lib/utils/battery_sign.dart`:
      // a negative reading while the SOC falls means discharging, and the sign is
      // never flipped at the call site, so this cell and the Battery page agree.
      GlassHeroStat(
        label: 'Battery Power',
        value: '${slotNumber(batteryPower, decimals: 0)} W',
        onTap: inputs.onOpenBattery,
      ),
      GlassHeroStat(
        label: 'Battery',
        value: batteryPower == null
            ? '--'
            : batteryChargeState(batteryPower).label,
      ),
      GlassHeroStat(
        label: 'SOC',
        value: '${slotNumber(soc, decimals: 0)}%',
        onTap: inputs.onOpenBattery,
      ),
    ],
    trailingActions: [
      // First, because it is the only action that changes what the whole page
      // below is describing.
      GlassCircleButton(
        icon: Icons.calendar_month_rounded,
        tooltip: dateSelectionLabel(
          selectedDate: inputs.selectedDate,
          rangeStart: inputs.rangeStart,
          rangeEnd: inputs.rangeEnd,
        ),
        onPressed: inputs.onPickDate,
      ),
      GlassCircleButton(
        icon: Icons.notifications_none_rounded,
        badge: inputs.activeAlerts.isNotEmpty,
        tooltip: 'Alarm history',
        onPressed: inputs.onOpenAlarmHistory,
      ),
      GlassCircleButton(
        icon: Icons.download_outlined,
        tooltip: 'Export CSV',
        onPressed: inputs.exportingCsv ? null : inputs.onExportCsv,
      ),
      GlassCircleButton(
        icon: Icons.menu_rounded,
        tooltip: 'Settings',
        onPressed: inputs.onOpenSettings,
      ),
    ],
    // **The dates are the weather card's footer.** They describe the same
    // "now" the card's own reading does, and as a separate block they needed a
    // header row of their own that held nothing but their trigger.
    footer: DateStrip(
      days: inputs.stripDays,
      selectedDate: inputs.selectedDate,
      rangeStart: inputs.rangeStart,
      rangeEnd: inputs.rangeEnd,
      onSelectDate: inputs.onSelectDate,
    ),
  );
}

/// "Senin, 15 Oktober 2026" — the reference's "Monday, June 23" line.
String _heroSubtitle() {
  final now = DateTime.now();
  return '${dayNameFull(now.weekday)}, ${now.day} ${monthName(now.month)} '
      '${now.year}';
}

/// The sun glyph beside the hero figure.
///
/// **Driven by lux, so the icon is a measurement rather than decoration** — the
/// reference's icon is a picture of the weather and this one is the sky the
/// greenhouse is actually under. Below the threshold it drops to a moon, which
/// is the one case where a solar dashboard genuinely has nothing to show.
IconData _heroSkyIcon(double? lux) {
  if (lux == null) return Icons.cloud_queue_rounded;
  return switch (skyConditionFor(lux)) {
    SkyCondition.clear => Icons.wb_sunny_rounded,
    SkyCondition.partlyCloudy => Icons.wb_cloudy_rounded,
    SkyCondition.overcast => Icons.cloud_rounded,
    SkyCondition.night => Icons.nightlight_round,
  };
}

/// The white sheet: today's own row first, then the six previous days, oldest
/// first — today is deliberately not repeated inside the day loop.
///
/// **Yesterday-to-today rather than today-forward.** The reference is a weather
/// forecast, so its rows are days that have not happened. This app has no
/// forecast — `EnergyForecastService` extrapolates the current day's power
/// curve, which is a projection of *today*, not of seven days. Showing a row
/// per upcoming day would mean printing a number the app cannot know, so the
/// sheet reports the seven days it actually has samples for.
Widget _forecastSheet(OverviewInputs inputs) {
  final totals = dailyTotals(
    inputs.energyHistory['power_dc'] ?? const <TelemetryPoint>[],
    DateTime.now(),
  );
  final today = startOfLocalDay(DateTime.now());
  // **The target and the runtime come from the service, and they are here
  // because the instrument panel used to carry them.** `dailyProductionTargetKwh`
  // is a number the user types into Settings, so dropping the panel without
  // carrying the target forward would have silently retired a setting they can
  // still configure. `batteryDepletionHours` is the *measured* runtime rather
  // than the service's 24-hour extrapolation, which is why it is the one on
  // screen.
  final forecast = const EnergyForecastService().calculate(
    history: inputs.energyHistory,
    latest: {...?inputs.battery?.latestValues, ...?inputs.pzem?.latestValues},
    dailyProductionTargetKwh: inputs.dailyProductionTargetKwh,
    referenceDate: DateTime.now(),
  );
  final target = inputs.dailyProductionTargetKwh;
  return GlassSheet(
    title: '7-Day Production',
    onTitleTap: inputs.onOpenEnergyReport,
    // **No page dots.** The reference carries three of them and they implied a
    // swipeable pager; this sheet has no second page, so they were a promise
    // the widget could not keep. A dead affordance is worse than no affordance.
    trailing: const SizedBox.shrink(),
    children: [
      // **The unit is the trailing slot, never the number a second time.**
      // These rows printed `1.37` and then `produksi 1.37 kWh` — the same figure
      // twice with a word attached, which is what made the row too narrow for
      // either half of it and the sentence ellipsised. The label already says
      // which quantity it is; the trailing slot only needs to say the unit.
      GlassSheetRow(
        label: 'Today',
        icon: Icons.bolt_rounded,
        value: inputs.energyLoading
            ? '...'
            : slotNumber(inputs.solarKwh, decimals: 2),
        trailing: inputs.energyLoading ? 'Loading' : 'kWh',
        highlight: true,
      ),
      if (target != null && target > 0)
        GlassSheetRow(
          label: 'Target',
          icon: Icons.flag_rounded,
          value: slotNumber(target, decimals: 1),
          trailing:
              '${((forecast.targetProgress ?? 0) * 100).clamp(0, 999).toStringAsFixed(0)}% tercapai',
        ),
      if (forecast.batteryDepletionHours != null)
        GlassSheetRow(
          label: 'Runtime',
          icon: Icons.battery_charging_full_rounded,
          value: slotNumber(forecast.batteryDepletionHours, decimals: 1),
          trailing: 'h battery',
        ),
      if (inputs.energyError != null)
        GlassSheetRow(
          label: 'Error',
          icon: Icons.error_outline_rounded,
          value: '--',
          trailing: 'Riwayat daya gagal dimuat',
        ),
      for (final day in totals)
        // Today is already the highlighted 'Today' row above; the loop lists
        // only the six previous days.
        if (day.date != today)
          GlassSheetRow(
            label: dayNameShort(day.date.weekday),
            icon: Icons.wb_sunny_rounded,
            value: day.isEmpty ? '--' : slotNumber(day.kwh, decimals: 2),
            // The unit, never the figure again — see the note on `Today`.
            trailing: day.isEmpty ? 'No data' : 'kWh',
          ),
    ],
  );
}

/// The cost and performance card, or null when the user has supplied neither
/// a tariff nor a nameplate.
///
/// **It reads `solarKwh` and `loadKwh`, the same two numbers the energy card
/// above prints.** It could compute its own from the energy history, and that
/// is the version that would be wrong: the comparison is anchored on
/// `DateTime.now()` and ignores the selected date, so a card bound to the date
/// strip and integrals of its own would show last-today's window while the row
/// above it showed something else.
Widget? _costSummaryPanel(OverviewInputs inputs) {
  if (inputs.electricityTariffPerKwh == null && inputs.pvInstalledWp == null) {
    return null;
  }
  return CostSummaryPanel(
    solarKwh: inputs.solarKwh,
    loadKwh: inputs.loadKwh,
    periodLabel: inputs.weeklyEnergySummary
        ? 'Last 7 days'
        : 'Last 24 hours',
    onTogglePeriod: () => inputs.onTogglePeriod(!inputs.weeklyEnergySummary),
    // **The window's real length, not a flat 24.** The comparison ends at "now"
    // and starts at midnight, so at 09:00 the window is nine hours. Dividing by
    // 24 there would report the array as a quarter of as productive as it is,
    // every morning, until noon.
    hours: inputs.weeklyEnergySummary
        ? 7 * 24
        : DateTime.now()
                  .difference(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  )
                  .inMinutes /
              60,
    tariffPerKwh: inputs.electricityTariffPerKwh,
    installedWp: inputs.pvInstalledWp,
  );
}

/// Whether the selected day or range is anything other than today.
///
/// Compares calendar days, not instants. The strip's chips are days and the
/// selected date arrives from `DateTime.now()` when nothing has been picked, so
/// any comparison at second resolution would be false for the whole morning.
bool _isSummaryPeriod(OverviewInputs inputs) =>
    inputs.rangeStart != null ||
    startOfDay(inputs.selectedDate) != startOfDay(DateTime.now());

/// The period summary panel, or nothing when today is selected.
///
/// What the Overview shows for a day other than today: what came IN, what went
/// OUT, and what the greenhouse and the fish tank did over the same window.
/// Today is excluded on purpose — the energy card above already carries
/// generation, load and the previous period, and restating it in a second panel
/// would be the same numbers twice.
///
/// Empty while the request is outstanding, so the panel does not flash its
/// "nothing recorded" state on the way to having rows. A failed load is
/// accepted as settled too, or a device ThingsBoard rejects would leave the
/// panel blank forever instead of saying it has no data.
Widget? _dateSummaryPanel(OverviewInputs inputs) {
  if (!_isSummaryPeriod(inputs)) return null;
  inputs.loadSummaryHistory();
  if (!inputs.summarySettled) return null;

  final window = historyTimeWindow(
    rangeStart: inputs.rangeStart ?? startOfDay(inputs.selectedDate),
    rangeEnd: inputs.rangeEnd,
    now: DateTime.now(),
  );
  return DateSummaryPanel(
    periodLabel: describeHistoryRange(
      selectedDate: inputs.selectedDate,
      rangeStart: inputs.rangeStart,
      rangeEnd: inputs.rangeEnd,
    ),
    // **The same `energyForPeriod` integral the energy card uses, over the same
    // energy history.** A second aggregation rule here would give the page two
    // totals for one day and no way to tell which is right.
    // `energyForCoveredPeriod` adds one thing `energyForPeriod` cannot do:
    // return null rather than `0.0` when the window is not covered, because
    // this history is a rolling fortnight and the picker reaches back ninety
    // days.
    solarKwh: energyForCoveredPeriod(
      points: inputs.energyHistory['power_dc'],
      start: window.start,
      end: window.end,
    ),
    loadKwh: energyForCoveredPeriod(
      points: inputs.energyHistory['power_ac'],
      start: window.start,
      end: window.end,
    ),
    environment: _summaryStats(inputs, kEnvironmentSpecs),
    fish: _summaryStats(inputs, kFishSpecs),
  );
}

/// Min/avg/max rows for one page's specs, from the history already in hand.
///
/// **The rows are derived from `kEnvironmentSpecs` / `kFishSpecs` rather than
/// from a list written here.** Those are the declarations the metric grids
/// read, so a renamed label or a new sensor reaches this panel with no second
/// edit — and, the failure this repo has paid for twice, no way for the two to
/// drift apart silently.
///
/// A spec with no history entry is skipped entirely rather than rendered as
/// `--`. `water_level_percent` is the case that matters: it is displayed on the
/// Fish grid and has no chart, so it is never requested, and a row of dashes
/// for it every time would read as a broken sensor rather than as a choice not
/// to chart a level.
List<DateSummaryStat> _summaryStats(
  OverviewInputs inputs,
  List<MetricSpec> specs,
) {
  return [
    for (final spec in specs)
      if (inputs.history.containsKey(spec.key)) _summaryStat(inputs, spec),
  ];
}

DateSummaryStat _summaryStat(OverviewInputs inputs, MetricSpec spec) {
  // Reduced once. The reduction is a full pass over the day's points and this
  // runs for every spec on two pages on every chart revision.
  final stats = periodStatsForPoints(inputs.history[spec.key]);
  final metric = spec.metric;
  return DateSummaryStat(
    label: spec.label,
    stats: stats,
    unit: spec.unit,
    decimals: spec.decimals,
    // The band comes from the same caption builder the grids use, so the
    // summary grades against the thresholds in Settings and not against a
    // default copied here.
    limitLabel: environmentLimitLabel(spec, inputs.thresholds),
    // **Extrema, not the average.** A day that dipped to 12 °C for ten minutes
    // has an average well inside the band, and the average is the one number
    // that cannot say a limit was crossed.
    //
    // An unmonitored spec — `lux`, `PV_TEMP`, `water_level_percent` all carry
    // no `metric` — cannot have breached, and reporting null is the only honest
    // answer; guessing a bound here would invent an alarm the rules do not have.
    breached:
        metric != null &&
        stats.breached(
          min: inputs.thresholds.minFor(metric),
          max: inputs.thresholds.maxFor(metric),
        ),
  );
}
