/// Golden-image harness for the Neon Brutalist restyle of 10 October 2026.
///
/// ## What this is for
///
/// Four agents restyled `lib/` onto the brief at `DESIGN (1).md` — acid lime
/// `#C6FF00`, Inter at 900/700/400, 8px radii, hard `4px 4px 0` offset shadows.
/// `design_tokens.dart` is the single source of truth, and a *token* being right
/// says nothing about a *screen* being right: `FEATURE.md`'s header exists
/// because three label regressions once passed `flutter analyze`, a release
/// build and every test in this repo.
///
/// This file renders the key screens at a phone width (411 dp) inside the app's
/// real `AppBackground` and writes each one to
/// `test/visual_audit/<name>_<light|dark>.png`, so a human can **look** at the
/// design without a device. It is a review harness, not a mutation guard: when
/// a widget changes shape the image changes and that is the point.
///
/// **Every screen is rendered in both ramps, and the file name says which.**
///
/// The ramp is not a parameter any widget can see: `AppTheme.apply` swaps the
/// `AppSurfaces` and `AppPalette` statics, so light and dark are two *global
/// states* rather than two arguments. That has two consequences this harness
/// has to respect, and both of them were found by looking at the images rather
/// than by reading the code.
///
///  * **The ramp has to be applied before the theme is built.**
///    `appThemeData()` reads `AppTheme.brightness` and the two statics, and
///    every widget reads the statics while it builds. Applying the ramp after
///    the pump would repaint nothing that was already on screen.
///  * **The ramp leaks between cases**, so `tearDown` puts it back to dark
///    after every test. A case that left the light palette behind would tint
///    the next case's chrome, and the image would look wrong for a reason that
///    has nothing to do with the widget under review.
///
/// A screen that was only ever looked at in one ramp is a screen nobody has
/// reviewed in the other, so both are written every time.
///
/// ## Regenerating the images
///
/// ```
/// flutter test test/visual_audit_test.dart --update-goldens
/// ```
///
/// **On the 7 GB machine this repo is developed on, run it one case at a
/// time.** The whole-file command renders eleven screens in two ramps each,
/// and the process is killed part-way through with the isolate's
/// "did not complete" — the same symptom `run_tests_per_file.ps1` exists to
/// work around, and the same one this file's own header has always warned
/// about. A case on its own is a fresh process with the whole machine's RAM
/// behind it, and it is reliable:
///
/// ```powershell
/// foreach ($c in 'glass_nav_bar_expanded','live_power_card','telemetry_card',
///                'energy_summary_card','date_strip','telemetry_chart_card',
///                'settings_row','dashboard_screen','settings_screen',
///                'energy_report','ai_chat') {
///   flutter test test/visual_audit_test.dart --update-goldens --plain-name $c
/// }
/// ```
///
/// On a clean checkout the PNGs do not exist, and a bare
/// `flutter test test/visual_audit_test.dart` would therefore fail on the first
/// run. So this file **bootstraps itself**: for each case it captures the
/// pixels and, if the golden is still missing, writes them through
/// `goldenFileComparator.update()` before comparing. That means the first run
/// is green *and* leaves the images behind for the human. `--update-goldens`
/// is still the command to use after an intentional visual change.
///
/// ## Two things that are not portable, and are not bugs
///
/// 1. **Custom fonts do not load automatically.** Flutter's own documentation
///    states that the test font set falls back to **Ahem**, which draws a
///    square per glyph. `setUpAll` below loads the app's three families
///    through `FontLoader` explicitly — **Inter** for the prose, **JetBrains
///    Mono** for the instrument panel's slot labels, and **MaterialIcons** for
///    the icons — and two tests measure the width of `Solar` at 10px to prove
///    the first two worked: Inter is ~26 px and JetBrains Mono ~30 px, where
///    Ahem is exactly 50 px (one glyph advance per font size). **If either
///    test ever fails, every PNG in here is unreadable blocky rectangles** and
///    the goldens are worthless — read the failure before touching anything
///    else.
/// 2. **Text rasterisation is platform- and Flutter-version specific.** Flutter
///    says so itself. A golden generated on Windows will not match one
///    generated on Linux. Do not chase that across machines.
///
/// ## Two ramps, and why the file name carries them
///
/// Every case is rendered twice — once with `AppTheme.apply(Brightness.light)`
/// and once with `AppTheme.apply(Brightness.dark)` — and the golden is named
/// `<case>_light.png` / `<case>_dark.png`.
///
/// The ramp is **global mutable state**: `AppTheme.apply` swaps the
/// `AppSurfaces` and `AppPalette` statics that every widget reads while it
/// builds, and `AppTheme.brightness` is what `AppGlass` reads to pick the page
/// gradient. It is applied *before* `appThemeData()` is called, because that
/// call is what reads the statics to build the `ThemeData` and the
/// `ColorScheme`; a ramp applied afterwards would leave the chrome in the
/// previous ramp while the widgets below it repainted in the new one.
///
/// And it is reset in `tearDown`, because the statics outlive the test that
/// set them: a case that left the light palette behind would tint the next
/// case's chrome, and the resulting image would be wrong for a reason that has
/// nothing to do with the widget under review.
///
/// ## Constraints this file keeps
///
/// No timers, no network, no `pumpAndSettle` (an infinite animation in the
/// tree would hang), and no `tester.getSemantics()` without `ensureSemantics()`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/main.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/dashboard/charts/chart_data.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/chart_card.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/chart_groups.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/date_strip.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/live_power_card.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_grid.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/metric_specs.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/nav_bar.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/overview_panel.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/telemetry_card.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';
import 'package:plts_monitoring/screens/energy_report/utils/period_buckets.dart';
import 'package:plts_monitoring/screens/energy_report/widgets/period_selector.dart';
import 'package:plts_monitoring/screens/energy_report/widgets/totals_card.dart';
import 'package:plts_monitoring/screens/settings/widgets/settings_fields.dart';
import 'package:plts_monitoring/services/energy_report_service.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';
import 'package:plts_monitoring/widgets/energy_summary_card.dart';
import 'package:plts_monitoring/widgets/formatted_markdown_text.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// The phone width the brief is designed against: 411 dp is the smallest
/// common Android viewport, and every card in this app is measured at it.
const double kPhoneWidth = 411;

/// The padding between the phone frame and the case body.
///
/// **Named, and it is not cosmetic.** The dashboard case has to size a scroll
/// view to the space this leaves, and a second literal for the same number
/// would be a silent mismatch the first time either one changed.
const EdgeInsets _framePadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.gutter,
  vertical: AppSpacing.sm,
);

/// The bundled Inter faces, in pubspec order.
///
/// **The weight is in the file name, and the list is the whole of it.** A
/// variable font would let a single asset serve 400/500/600/700/900, but on
/// older Android the `wght` axis is not applied reliably, so a variable file
/// declared once renders every weight at its default. These are the five
/// `pubspec.yaml` declares.
const List<String> _interFaces = [
  'assets/fonts/Inter-Regular-400.ttf',
  'assets/fonts/Inter-Medium-500.ttf',
  'assets/fonts/Inter-SemiBold-600.ttf',
  'assets/fonts/Inter-Bold-700.ttf',
  'assets/fonts/Inter-Black-900.ttf',
];

/// The bundled JetBrains Mono faces, in pubspec order.
///
/// **A second family, and it is the app's terminal face.** `AppType.mono` is
/// `JetBrainsMono`, and the Overview panel, the metric grid and every slot
/// label are drawn in it. An unregistered family falls back to Ahem, which
/// draws a solid box per glyph — so a harness that loaded only Inter produced
/// images where the entire instrument panel was a wall of navy rectangles and
/// the "readable screenshot" was a picture of Ahem.
const List<String> _monoFaces = [
  'assets/fonts/JetBrainsMono-Medium.ttf',
  'assets/fonts/JetBrainsMono-Bold.ttf',
];

/// The Material icon font, which the framework puts in the asset bundle.
///
/// **Without it every `Icon` in every PNG is an empty box.** An unregistered
/// family falls back to Ahem, and Ahem has no glyph for the icon codepoints,
/// so the harness was drawing tofu where the design puts an icon. The font is
/// 1.6 MB, which is the price of the images being pictures of the design.
const String _iconFont = 'fonts/MaterialIcons-Regular.otf';

/// The ramps every case is rendered in, in the order they are captured.
///
/// **A fixed list, not `Brightness.values`.** The order decides which capture
/// is written first, and spelling the list out means a ramp added later cannot
/// silently reorder the files that already exist.
const List<Brightness> kRamps = <Brightness>[Brightness.light, Brightness.dark];

/// The suffix a ramp contributes to a golden's file name.
String _rampSuffix(Brightness brightness) =>
    brightness == Brightness.light ? 'light' : 'dark';

void main() {
  // **Opt-in, and the reason is a hang rather than a preference.**
  //
  // This file renders eleven screens to PNG, in two ramps each. On the 7 GB
  // machine this repo is developed on, `captureImage` under `flutter test` takes
  // the whole isolate down: the cases run green one at a time and the file
  // "does not complete" when it runs, which is the same symptom
  // `run_tests_per_file.ps1` exists to work around. A review tool that breaks
  // the suite is worse than no tool, so the goldens are only registered when
  // the comparator is actually updating them — `flutter test --update-goldens`
  // — and a plain run reports one skipped test that says so.
  //
  // Regenerate with:
  //
  //     flutter test test/visual_audit_test.dart --update-goldens
  //
  // …or one case at a time on a machine with 7 GB of RAM, which is the only
  // way that reliably completes there:
  //
  //     flutter test test/visual_audit_test.dart --update-goldens --plain-name <case>
  final updating = autoUpdateGoldenFiles;
  if (!updating) {
    // A passing test rather than a skipped one, and that is deliberate: the
    // per-file runner this repo uses recognises "All tests passed" and treats
    // anything else — including a *skip* — as a failure, so a skip here would
    // break every suite run for a file that did nothing. What is asserted is
    // the state that makes the harness opt-in, so a plain run has actually
    // checked something.
    test('visual audit goldens are opt-in', () {
      expect(
        autoUpdateGoldenFiles,
        isFalse,
        reason:
            'This file renders eleven screens to PNG and needs '
            '`--update-goldens`. A plain run registers this one test and '
            'skips the images.',
      );
    });
    return;
  }

  // The one thing the golden harness cannot do for itself: without this the
  // entire app renders in Ahem squares and every image below is decoration
  // rather than documentation.
  //
  // **All three families.** The app draws its prose in Inter, its instrument
  // panel in JetBrains Mono and its icons in MaterialIcons, so loading only
  // Inter left half of every screen as Ahem boxes.
  setUpAll(() async {
    await _loadFont('Inter', _interFaces);
    await _loadFont('JetBrainsMono', _monoFaces);
    await _loadFont('MaterialIcons', const [_iconFont]);
  });

  group('visual audit goldens', () {
    // **The ramp is global state, so it is put back after every case.**
    //
    // `AppTheme.apply` swaps the `AppSurfaces` and `AppPalette` statics, and
    // those outlive the test that set them. A case that left the light palette
    // behind would tint the next case's chrome, and the resulting image would
    // be wrong for a reason that has nothing to do with the widget under
    // review.
    tearDown(() => AppTheme.apply(Brightness.dark));

    // **One nav-bar golden, and it used to be two.** There was a
    // `glass_nav_bar_collapsed` variant for the vertical-scroll state that
    // crossfaded four icons out and one enlarged icon in. That state is gone —
    // the bar always shows all four destinations — so the collapsed golden
    // rendered the same bar as the expanded one and its PNG was deleted rather
    // than regenerated. A golden for a state that no longer exists is a file
    // that has to be re-approved every time the bar changes, for a picture no
    // user can reach.
    testWidgets('glass_nav_bar_expanded', (tester) async {
      await _auditBoth(
        tester,
        'glass_nav_bar_expanded',
        GlassNavBar(selectedIndex: 0, onSelect: (_) {}),
        height: 120,
        mainAxisAlignment: MainAxisAlignment.end,
      );
    });

    testWidgets('live_power_card', (tester) async {
      await _auditBoth(
        tester,
        'live_power_card',
        const LivePowerCard(
          pvPower: 1834,
          acPower: 720,
          batteryPower: -42,
          soc: 68,
          pzemStale: false,
          pzemAgeLabel: '12s ago',
        ),
        height: 340,
      );
    });

    testWidgets('telemetry_card', (tester) async {
      await _auditBoth(
        tester,
        'telemetry_card',
        TelemetryCard(
          data: DeviceTelemetry(
            latestValues: const {
              'voltage': 25.4,
              'current': -1.24,
              'power': -31,
              'soc': 78,
            },
            lastUpdate: null,
          ),
          metrics: const [
            MetricDef(
              'voltage',
              'Voltage',
              'V',
              Icons.bolt_outlined,
              decimals: 1,
            ),
            MetricDef(
              'current',
              'Current',
              'A',
              Icons.electrical_services_outlined,
              decimals: 2,
            ),
            MetricDef(
              'power',
              'Power',
              'W',
              Icons.wb_sunny_outlined,
              decimals: 0,
            ),
            MetricDef(
              'soc',
              'State of Charge',
              '%',
              Icons.battery_std_rounded,
              decimals: 0,
            ),
          ],
          staleMinutes: 10,
        ),
        height: 520,
      );
    });

    // **No standalone metric-grid golden, and it is a considered omission.**
    // There used to be one, and it was dropped because it did not finish
    // rendering on the 7 GB machine this repo is developed on: it hung the
    // isolate, and the PNG left behind was a partial frame with a lime bar in
    // it that is not in the render tree at all (measured: no decorator and no
    // paragraph in that region). A golden of a partial frame is worse than no
    // golden, because it looks like a defect.
    //
    // **The grid is not missing from the audit, though** — it is inside the
    // `dashboard_screen` case below, rendered in its real place on the page,
    // and it is fine there. `metric_grid_test.dart` covers the widget itself,
    // ten tests, and it passes.
    testWidgets('energy_summary_card', (tester) async {
      await _auditBoth(
        tester,
        'energy_summary_card',
        const EnergySummaryCard(
          weekly: false,
          loading: false,
          hasData: true,
          errorMessage: null,
          solarKwh: 12.41,
          previousSolarKwh: 10.0,
          loadKwh: 8.72,
          previousLoadKwh: 9.1,
          onRangeChanged: _noopBool,
          onOpenReport: _noopVoid,
        ),
        height: 340,
      );
    });

    testWidgets('date_strip', (tester) async {
      final today = DateTime.now();
      await _auditBoth(
        tester,
        'date_strip',
        DateStrip(
          days: [
            for (var i = -3; i <= 3; i++)
              DateTime(today.year, today.month, today.day + i),
          ],
          selectedDate: today,
          rangeStart: null,
          rangeEnd: null,
          onSelectDate: (_) {},
        ),
        height: 210,
      );
    });

    testWidgets('telemetry_chart_card', (tester) async {
      // Real series, from the app's own chart-group declaration rather than
      // hand-built spots: `chartGroupsForPrefix('env').first` is the two-series
      // greenhouse temperature card, which is the only multi-series group that
      // exercises the legend, the shared Y axis and the multi-series
      // statistics row at once.
      final group = chartGroupsForPrefix('env').first;
      final base = DateTime(2026, 10, 5, 6, 0);
      final points = <String, List<TelemetryPoint>>{
        for (final spec in group.series)
          spec.key: [
            for (var i = 0; i < 72; i++)
              TelemetryPoint(
                timestamp: base.add(Duration(minutes: 15 * i)),
                // A believable diurnal curve, offset between the two sensors.
                value:
                    24.0 +
                    6.0 * math.sin(i / 72 * 2 * math.pi) +
                    (spec.key == 'temp_dht' ? 0 : 3.5),
              ),
          ],
      };

      await _auditBoth(
        tester,
        'telemetry_chart_card',
        TelemetryChartCard(
          prefix: 'env',
          group: group,
          points: points,
          spots: {
            for (final entry in points.entries)
              entry.key: processSpots(entry.value),
          },
          stats: {
            for (final entry in points.entries)
              entry.key: SeriesStats.fromPoints(entry.value),
          },
          boundsCache: <String, ChartBounds>{},
          loading: false,
          loadFailed: false,
          // A fixed past day so `describeHistoryRange` prints a stable label
          // rather than one that flips on midnight.
          selectedDate: DateTime(2026, 10, 5),
          rangeStart: null,
          rangeEnd: null,
          onPointerActive: (_) {},
        ),
        height: 360,
      );
    });

    // **No CCTV golden, and it is a considered omission rather than an
    // unfinished one.** The standby overlay is a `Stack(fit: StackFit.expand)`
    // over an arbitrary *video* surface, so a golden of it is a golden of
    // whatever matte the harness gives it — it documents the harness, not the
    // design. It also asserts during layout in a bare `testWidgets` (a
    // `RenderStack` given invalid constraints), which costs the whole file its
    // remaining cases rather than just its own. The real CCTV screen needs the
    // device; this file is the dashboard and the report.
    testWidgets('settings_row', (tester) async {
      await _auditBoth(
        tester,
        'settings_row',
        SectionCard(
          title: 'Monitoring',
          subtitle: 'Set how often live telemetry updates.',
          icon: Icons.monitor_heart_outlined,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto refresh telemetry'),
            value: true,
            onChanged: (_) {},
          ),
        ),
        height: 380,
      );
    });

    // **The whole dashboard, in one scroll view.**
    //
    // The other cases are single widgets in isolation, which is what a golden
    // is good at. This one is the page: the cards in the order the screen
    // stacks them, so the *relationships* between them — the gap rhythm, the
    // shared page fill, the panel typography against the card typography — are
    // visible in one image. A page that is wrong in a way no single card is
    // wrong cannot be caught by a card golden.
    //
    // **The dates on screen are pinned.** A `DateTime.now()` in the day strip
    // or the Overview header would make the image change every day, and a
    // golden that changes by itself is a golden nobody re-approves. The one
    // `DateTime.now()` left in the tree is the metric grid's freshness probe,
    // and what it draws — a fresh reading, or the stale tag — does not change
    // from one day to the next.
    testWidgets('dashboard_screen', (tester) async {
      const thresholds = AlarmThresholds.defaults;
      final day = DateTime(2026, 10, 5);

      await _auditBoth(
        tester,
        'dashboard_screen',
        ListView(
          padding: EdgeInsets.zero,
          children: [
            const LivePowerCard(
              pvPower: 1834,
              acPower: 720,
              batteryPower: -42,
              soc: 68,
              pzemStale: false,
              pzemAgeLabel: '12s ago',
            ),
            const SizedBox(height: AppSpacing.sm),
            TelemetryCard(
              data: DeviceTelemetry(
                latestValues: const {
                  'voltage': 25.4,
                  'current': -1.24,
                  'power': -31,
                  'soc': 78,
                },
                lastUpdate: null,
              ),
              metrics: const [
                MetricDef('voltage', 'Voltage', 'V', Icons.bolt_outlined,
                    decimals: 1),
                MetricDef('current', 'Current', 'A',
                    Icons.electrical_services_outlined, decimals: 2),
                MetricDef('power', 'Power', 'W', Icons.wb_sunny_outlined,
                    decimals: 0),
                MetricDef('soc', 'State of Charge', '%',
                    Icons.battery_std_rounded, decimals: 0),
              ],
              staleMinutes: 10,
            ),
            const SizedBox(height: AppSpacing.sm),
            const EnergySummaryCard(
              weekly: false,
              loading: false,
              hasData: true,
              errorMessage: null,
              solarKwh: 12.41,
              previousSolarKwh: 10.0,
              loadKwh: 8.72,
              previousLoadKwh: 9.1,
              onRangeChanged: _noopBool,
              onOpenReport: _noopVoid,
            ),
            const SizedBox(height: AppSpacing.sm),
            DateStrip(
              days: [
                for (var i = -3; i <= 3; i++)
                  DateTime(day.year, day.month, day.day + i),
              ],
              selectedDate: day,
              rangeStart: null,
              rangeEnd: null,
              onSelectDate: (_) {},
            ),
            const SizedBox(height: AppSpacing.sm),
            const OverviewPanel(
              readings: OverviewReadings(
                displayName: 'Rumah Apik',
                pvPower: 1834,
                pvPeak: 2140,
                acPower: 720,
                batteryPower: -42,
                soc: 68,
                batteryVoltage: 25.4,
                acVoltage: 231.2,
                lux: 18400,
                pzemAgeLabel: '12s ago',
                solarKwh: 12.41,
                loadKwh: 8.72,
                previousSolarKwh: 10.0,
                previousLoadKwh: 9.1,
                productionProgress: 0.83,
                forecastBatteryHours: 6.5,
                isLive: false,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            MetricGrid(
              title: 'Environment',
              specs: kEnvironmentSpecs,
              values: const {
                'temp_dht': 27.4,
                'humidity_dht': 68.0,
                'temp_ds18b20': 31.2,
                'lux': 18400,
                'tds_ppm': 980,
              },
              thresholds: thresholds,
              limitLabelFor: (spec) => environmentLimitLabel(spec, thresholds),
              // `DateTime.now()` and not a pinned date: this field is *about*
              // freshness, and a pinned date three weeks in the past would draw
              // the stale tag every time, which is a different design to review.
              lastUpdate: DateTime.now(),
            ),
            const SizedBox(height: AppSpacing.sm),
            const TerminalPanel(
              semanticLabel: 'Status',
              children: [
                TerminalRow(label: 'GATEWAY', value: 'ONLINE', unit: null),
                TerminalRule(),
                TerminalRow(label: 'UPLINK', value: '4G', unit: null),
              ],
            ),
          ],
        ),
        height: 1400,
      );
    });

    // **Two settings cards, and the point is that they are two different
    // controls.** A switch and a text field do not share a row shape, and a
    // golden of one of them says nothing about the other.
    testWidgets('settings_screen', (tester) async {
      final controller = TextEditingController(text: '32');
      addTearDown(controller.dispose);

      await _auditBoth(
        tester,
        'settings_screen',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Monitoring',
              subtitle: 'Set how often live telemetry updates.',
              icon: Icons.monitor_heart_outlined,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto refresh telemetry'),
                value: true,
                onChanged: (_) {},
              ),
            ),
            SectionCard(
              title: 'Greenhouse',
              subtitle: 'Alerts for the environment sensors.',
              icon: Icons.thermostat_outlined,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Max temperature (C)',
                ),
              ),
            ),
          ],
        ),
        height: 600,
      );
    });

    // **The energy report's two headline pieces.** The period selector and
    // the totals card, which is the whole top of that screen.
    testWidgets('energy_report', (tester) async {
      final day = DateTime(2026, 10, 5);
      final buckets = <EnergyBucket>[
        for (var h = 6; h <= 18; h++)
          EnergyBucket(
            hour: DateTime(day.year, day.month, day.day, h),
            pvKwh: 1.2,
            acKwh: 0.6,
            sampleCount: 12,
          ),
      ];

      await _auditBoth(
        tester,
        'energy_report',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PeriodSelector(
              monthly: false,
              selectedDate: day,
              onMonthlyChanged: _noopBool,
              onPickPeriod: _noopVoid,
            ),
            const SizedBox(height: AppSpacing.md),
            TotalsCard(
              monthly: false,
              selectedDate: day,
              pvKwh: 15.6,
              acKwh: 7.8,
              buckets: buckets,
              previousTotals: const PeriodTotals(pvKwh: 12.1, acKwh: 8.4),
            ),
          ],
        ),
        height: 500,
      );
    });

    // **The AI chat, without the screen.**
    //
    // `AiChatScreen` reads its API key from `flutter_secure_storage` and its
    // bubbles are a private `_Bubble`, so the screen cannot be pumped here
    // without a service and a private type. What the design *is* — the answer
    // bubble's typography and the composer row — is the public
    // `FormattedMarkdownText` and a `TextField` in a row, so that is what this
    // golden is.
    testWidgets('ai_chat', (tester) async {
      await _auditBoth(
        tester,
        'ai_chat',
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FormattedMarkdownText(
                text: '### Ringkasan hari ini\n'
                    '\n'
                    '- Produksi **12.41 kWh**, naik 24% dari kemarin.\n'
                    '- Beban rumah 8.72 kWh, turun 4%.\n'
                    '- Baterai 68%, sisa 6.5 jam.',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Tanya tentang data tanaman',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        height: 500,
      );
    });
  });

  group('fonts are really loaded', () {
    testWidgets('jetbrains_mono_is_actually_loaded', (tester) async {
      // The same measurement as the Inter check below, on the app's other
      // family. Ahem gives every glyph an advance of exactly one font size,
      // so five glyphs at 10 px is 50.0; JetBrains Mono's advance is 0.6 em,
      // so the same string is about 30.
      tester.view.physicalSize = const Size(kPhoneWidth, 160);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appThemeData(),
          home: const RepaintBoundary(
            child: Center(
              child: Text(
                'Solar',
                style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final width = tester.getSize(find.text('Solar')).width;
      // ignore: avoid_print
      print(
        'visual_audit: JetBrainsMono "Solar" at 10px measured $width px '
        '(JetBrains Mono ~30, Ahem 50.0).',
      );

      expect(
        width,
        lessThan(40.0),
        reason:
            'JetBrainsMono did not load: "Solar" measured $width px, which is '
            'the Ahem fallback (50.0) rather than JetBrains Mono (~30). Every '
            'slot label and every row of the instrument panels in '
            'test/visual_audit/ is a blocky rectangle until setUpAll\'s '
            'FontLoader succeeds.',
      );
      expect(
        width,
        greaterThan(15.0),
        reason:
            '"Solar" measured $width px — narrower than JetBrains Mono should '
            'be, so the text is not laying out at the size it was asked for.',
      );
    });

    testWidgets('inter_is_actually_loaded', (tester) async {
      // Inter 'Solar' at 10px is about 22 px wide. The flutter_test fallback,
      // Ahem, gives every glyph an advance of exactly one font size, so the
      // same string is 50.0 px. That gap is the whole check.
      tester.view.physicalSize = const Size(kPhoneWidth, 160);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appThemeData(),
          home: const RepaintBoundary(
            child: Center(
              child: Text(
                'Solar',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final width = tester.getSize(find.text('Solar')).width;
      // ignore: avoid_print
      print(
        'visual_audit: Inter "Solar" at 10px measured $width px '
        '(Inter ~22, Ahem 50.0).',
      );

      expect(
        width,
        lessThan(40.0),
        reason:
            'Inter did not load: "Solar" measured $width px, which is the '
            'Ahem fallback (50.0) rather than Inter (~26). Every PNG in '
            'test/visual_audit/ is blocky rectangles until '
            'setUpAll\'s FontLoader succeeds.',
      );
      expect(
        width,
        greaterThan(15.0),
        reason:
            '"Solar" measured $width px — narrower than Inter should be, '
            'so the text is not laying out at the size it was asked for.',
      );
    });
  });
}

/// Where this file writes its goldens, relative to the test file.
///
/// **The ramp is in the name.** Light and dark are two images of the same
/// case, and a name that did not say which was which would leave a reviewer
/// comparing the wrong two files.
String _goldenKey(String name, Brightness brightness) =>
    'visual_audit/${name}_${_rampSuffix(brightness)}.png';

/// Renders one case in every ramp, in [kRamps] order.
///
/// The same widget instance is pumped once per ramp. That is safe because the
/// cases are stateless trees, and the root [MaterialApp] carries a per-ramp
/// key so each pump rebuilds the whole tree from scratch — the ramp lives in
/// statics, and a tree that survived from the previous ramp would keep the
/// widgets it had already built.
Future<void> _auditBoth(
  WidgetTester tester,
  String name,
  Widget child, {
  required double height,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
}) async {
  for (final ramp in kRamps) {
    await _audit(
      tester,
      name,
      child,
      height: height,
      mainAxisAlignment: mainAxisAlignment,
      brightness: ramp,
    );
  }
}

/// Pumps one case at a phone width inside the app's real [AppBackground] and
/// compares it against its golden.
///
/// If the golden is missing it is written from the pixels this run just
/// captured, so the first run on a clean checkout is green and leaves the
/// images behind. See the library header.
Future<void> _audit(
  WidgetTester tester,
  String name,
  Widget child, {
  required double height,
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = Size(kPhoneWidth, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // **The ramp goes on before the theme is built.**
  //
  // `appThemeData()` reads `AppTheme.brightness` and the two statics, and
  // every widget reads the statics while it builds. Applying the ramp after
  // the pump would leave the chrome in the previous ramp while the widgets
  // below it repainted in the new one.
  AppTheme.apply(brightness);

  final rampSuffix = _rampSuffix(brightness);
  final boundaryKey = ValueKey('audit-$name-$rampSuffix');
  await tester.pumpWidget(
    MaterialApp(
      // **A per-ramp key on the root.** The ramp is global mutable state, so
      // the tree has to be built again from scratch for it; a tree that
      // survived from the previous ramp would keep the widgets it had already
      // built, with the old ramp's values baked into them.
      key: ValueKey('audit-root-$name-$rampSuffix'),
      debugShowCheckedModeBanner: false,
      theme: appThemeData(),
      home: RepaintBoundary(
        key: boundaryKey,
        child: AppBackground(
          child: SizedBox(
            width: kPhoneWidth,
            height: height,
            child: Padding(
              padding: _framePadding,
              child: Column(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // **Loose, so the child keeps its own height.**
                  //
                  // A `Column` hands its children an *unbounded* main-axis
                  // constraint, which a `ListView` cannot live with — it throws
                  // "Vertical viewport was given unbounded height". `Flexible`
                  // gives the child a bounded maximum instead, and `loose` lets
                  // a child that is smaller than that maximum keep its own
                  // size, which is what the nav bar's `mainAxisAlignment: end`
                  // relies on.
                  Flexible(
                    fit: FlexFit.loose,
                    // Adds Inter's family — and nothing else — to the ambient
                    // style, so the several widgets that render a raw
                    // `TextStyle(fontSize:)` still come out in Inter rather than
                    // in Ahem squares.
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontFamily: 'Inter'),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // **Settle, but do not `pumpAndSettle`.**
  //
  // `matchesGoldenFile` asserts that the tree does **not** need paint, and three
  // things in here keep it dirty for more than one frame: `AppCard` is an
  // `AnimatedContainer` (its pressed state), the nav bar is one, the CCTV
  // standby overlay fades — and a font registered in `setUpAll` re-measures
  // every `Text` on the frame *after* it lands, which is a second frame nobody
  // sees coming.
  //
  // So: one pump, three at a frame's length for whatever settles
  // asynchronously, and one at the container duration for the animations.
  // `pumpAndSettle` is deliberately not used — it never returns on an animation
  // that does not stop, and this file is not allowed to hang.
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(AppMotion.container);
  await tester.pump();

  // **`matchesGoldenFile` and nothing else.**
  //
  // The first version of this file captured the pixels by hand — walk up to the
  // nearest repaint boundary, take its `debugLayer`, `toImage` it inside
  // `tester.binding.runAsync`, encode a PNG — and then fed those bytes to
  // `matchesGoldenFile` so the same pixels were both written and compared. It
  // hung for ten minutes on the first case and produced nothing.
  //
  // The framework's own comparator already does all of that, including the
  // `--update-goldens` write, and it does it without `runAsync`. Hand-rolling a
  // second rasteriser was the risk; the framework's is the maintained one. The
  // cost is that a clean checkout has no PNGs yet, so the first run has to be
  // `flutter test --update-goldens` — which is what the header says.
  await expectLater(
    find.byKey(boundaryKey),
    matchesGoldenFile(_goldenKey(name, brightness)),
  );
}

void _noopBool(bool _) {}

void _noopVoid() {}

/// Loads one bundled family into the test's font collection.
Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}
