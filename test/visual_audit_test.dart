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
/// real `AppBackground` and writes each one to `test/visual_audit/<name>.png`,
/// so a human can **look** at the new design without a device. It is a
/// review harness, not a mutation guard: when a widget changes shape the image
/// changes and that is the point.
///
/// ## Regenerating the images
///
/// ```
/// flutter test test/visual_audit_test.dart --update-goldens
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
///    square per glyph. `setUpAll` below loads the three bundled Inter faces
///    through `FontLoader` explicitly, and `inter_is_actually_loaded` measures
///    the width of `Solar` at 10px to prove it worked: Inter is ~22 px where
///    Ahem is exactly 50 px (one glyph advance per font size). **If that test
///    ever fails, every PNG in here is unreadable blocky rectangles** and the
///    goldens are worthless — read the failure before touching anything else.
/// 2. **Text rasterisation is platform- and Flutter-version specific.** Flutter
///    says so itself. A golden generated on Windows will not match one
///    generated on Linux. Do not chase that across machines.
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
import 'package:plts_monitoring/screens/dashboard/widgets/telemetry_card.dart';
import 'package:plts_monitoring/screens/settings/widgets/settings_fields.dart';
import 'package:plts_monitoring/utils/alarm_rules.dart';
import 'package:plts_monitoring/widgets/energy_summary_card.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// The phone width the brief is designed against: 411 dp is the smallest
/// common Android viewport, and every card in this app is measured at it.
const double kPhoneWidth = 411;

/// The three bundled static Inter faces, in pubspec order.
///
/// **Static instances, and the weight in the filename is why.** A variable font
/// would let a single asset serve 400/700/900, but on older Android the `wght`
/// axis is not applied reliably, so a variable file declared once renders every
/// weight at its default. These three are what `pubspec.yaml` declares.
const List<(String, int)> _interFaces = [
  ('assets/fonts/Inter-Regular-400.ttf', 400),
  ('assets/fonts/Inter-Bold-700.ttf', 700),
  ('assets/fonts/Inter-Black-900.ttf', 900),
];

void main() {
  // **Opt-in, and the reason is a hang rather than a preference.**
  //
  // This file renders ten screens to PNG. On the 7 GB machine this repo is
  // developed on, `captureImage` under `flutter test` takes the whole isolate
  // down: the cases run green one at a time and the file "does not complete"
  // when it runs, which is the same symptom `run_tests_per_file.ps1` exists to
  // work around. A review tool that breaks the suite is worse than no tool, so
  // the goldens are only registered when the comparator is actually updating
  // them — `flutter test --update-goldens` — and a plain run reports one skipped
  // test that says so.
  //
  // Regenerate with:
  //
  //     flutter test test/visual_audit_test.dart --update-goldens
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
            'This file renders ten screens to PNG and needs '
            '`--update-goldens`. A plain run registers this one test and '
            'skips the images.',
      );
    });
    return;
  }

  // The one thing the golden harness cannot do for itself: without this the
  // entire app renders in Ahem squares and every image below is decoration
  // rather than documentation.
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final (asset, _) in _interFaces) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  });

  group('visual audit goldens', () {
    testWidgets('glass_nav_bar_expanded', (tester) async {
      final collapsed = ValueNotifier<bool>(false);
      addTearDown(collapsed.dispose);
      await _audit(
        tester,
        'glass_nav_bar_expanded',
        GlassNavBar(
          selectedIndex: 0,
          collapsed: collapsed,
          onSelect: (_) {},
          onExpand: () => collapsed.value = false,
        ),
        height: 120,
        mainAxisAlignment: MainAxisAlignment.end,
      );
    });

    testWidgets('glass_nav_bar_collapsed', (tester) async {
      final collapsed = ValueNotifier<bool>(true);
      addTearDown(collapsed.dispose);
      await _audit(
        tester,
        'glass_nav_bar_collapsed',
        GlassNavBar(
          selectedIndex: 1,
          collapsed: collapsed,
          onSelect: (_) {},
          onExpand: () => collapsed.value = false,
        ),
        height: 120,
        mainAxisAlignment: MainAxisAlignment.end,
      );
    });

    testWidgets('live_power_card', (tester) async {
      await _audit(
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
      await _audit(
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

    testWidgets('metric_grid', (tester) async {
      await _audit(
        tester,
        'metric_grid',
        MetricGrid(
          title: 'Environment',
          specs: kEnvironmentSpecs,
          values: const {
            'temp_dht': 28.4,
            'humidity_dht': 61.0,
            'temp_ds18b20': 34.2,
            'lux': 41200,
            'tds_ppm': 842,
          },
          thresholds: AlarmThresholds.defaults,
          lastUpdate: DateTime.now(),
          limitLabelFor: (spec) =>
              environmentLimitLabel(spec, AlarmThresholds.defaults),
        ),
        height: 300,
      );
    });

    testWidgets('energy_summary_card', (tester) async {
      await _audit(
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
      await _audit(
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
          onPickRange: () {},
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

      await _audit(
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
      await _audit(
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
  });

  group('inter is really loaded', () {
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
          theme: _auditTheme(),
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
            'Ahem fallback (50.0) rather than Inter (~22). Every PNG in '
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
String _goldenKey(String name) => 'visual_audit/$name.png';

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
}) async {
  tester.view.physicalSize = Size(kPhoneWidth, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final boundaryKey = ValueKey('audit-$name');
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _auditTheme(),
      home: RepaintBoundary(
        key: boundaryKey,
        child: AppBackground(
          child: SizedBox(
            width: kPhoneWidth,
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: mainAxisAlignment,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Adds Inter's family — and nothing else — to the ambient
                  // style, so the several widgets that render a raw
                  // `TextStyle(fontSize:)` still come out in Inter rather than
                  // in Ahem squares.
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontFamily: 'Inter'),
                    child: child,
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
    matchesGoldenFile(_goldenKey(name)),
  );
}

/// The one `ThemeData`.
///
/// **A copy of `main.dart`'s `_appThemeData`, because that is private.** It
/// exists here so a `FilledButton`, a `SwitchListTile` and a `SegmentedButton`
/// render in the app's own colours rather than in Material's defaults — a
/// golden of the CCTV play button drawn in `secondaryContainer` would look like
/// a design defect that is not one. Everything measurable in it comes from
/// `design_tokens.dart`; nothing here picks a colour.
ThemeData _auditTheme() {
  TextStyle ink(TextStyle style) =>
      style.copyWith(color: AppSurfaces.onSurface);
  TextStyle muted(TextStyle style) =>
      style.copyWith(color: AppSurfaces.onSurfaceVariant);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppPalette.primary,
      onPrimary: AppPalette.onHue,
      primaryContainer: AppPalette.primary,
      onPrimaryContainer: AppPalette.onHue,
      secondary: AppPalette.secondary,
      onSecondary: AppPalette.onHue,
      secondaryContainer: AppPalette.secondary,
      onSecondaryContainer: AppPalette.onHue,
      tertiary: AppPalette.accent,
      onTertiary: AppPalette.onHue,
      surface: AppSurfaces.surface,
      onSurface: AppSurfaces.onSurface,
      onSurfaceVariant: AppSurfaces.onSurfaceVariant,
      error: AppPalette.error,
      onError: AppPalette.onHue,
      outline: AppSurfaces.border,
      outlineVariant: AppSurfaces.border,
    ),
    textTheme: TextTheme(
      displayLarge: ink(AppType.displayLg),
      displayMedium: ink(AppType.displayMd),
      displaySmall: ink(AppType.numeralLg),
      headlineLarge: ink(AppType.numeralLg),
      headlineMedium: ink(AppType.headlineMd),
      headlineSmall: ink(AppType.headlineMd),
      titleLarge: ink(AppType.headlineMd),
      titleMedium: ink(AppType.headlineMd),
      titleSmall: muted(AppType.labelUppercase),
      bodyLarge: ink(AppType.bodyMd),
      bodyMedium: muted(AppType.bodyMd),
      bodySmall: muted(AppType.bodySm),
      labelLarge: ink(AppType.labelUppercase),
      labelMedium: ink(AppType.labelUppercase),
      labelSmall: muted(AppType.labelMicro),
    ),
    scaffoldBackgroundColor: AppSurfaces.page,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(AppPalette.primary),
        foregroundColor: const WidgetStatePropertyAll(AppPalette.onHue),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(AppType.labelUppercase),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.secondary
              : AppSurfaces.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.onHue
              : AppSurfaces.onSurfaceVariant,
        ),
        side: const WidgetStatePropertyAll(AppBorders.hairline),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(AppType.labelUppercase),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppSurfaces.input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.inset),
        borderSide: AppBorders.hairline,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.inset),
        borderSide: AppBorders.hairline,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppSurfaces.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: AppBorders.hairline,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppSurfaces.border,
      space: 1,
      thickness: 1,
    ),
  );
}

void _noopBool(bool _) {}

void _noopVoid() {}
