// First widget test for EnergySummaryCard.
//
// This repo had three separate label regressions pass `flutter analyze`, pass a
// release build and pass every existing test, because nothing ever looked at
// this screen. Every string asserted below is copied from
// `lib/widgets/energy_summary_card.dart` at the line noted beside it, so a
// rename in the widget shows up here as a failure rather than as a wrong label
// nobody noticed until a device was in hand.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/services/energy_forecast_service.dart';
import 'package:plts_monitoring/widgets/energy_summary_card.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

import 'widget_text_helpers.dart';

void main() {
  const seedColor = Color(0xFF35A968);

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  /// A card with sensible defaults so each test only states what it is about.
  Widget card({
    Color seed = seedColor,
    bool isDark = false,
    AppTheme? theme,
    bool weekly = false,
    bool loading = false,
    bool hasData = true,
    String? errorMessage,
    double solarKwh = 4.2,
    double previousSolarKwh = 3.5,
    double loadKwh = 1,
    double previousLoadKwh = 2.5,
    ValueChanged<bool>? onRangeChanged,
    VoidCallback? onOpenReport,
    EnergyForecastResult? forecast,
  }) {
    return EnergySummaryCard(
      theme: theme ?? (isDark ? AppTheme.dark : AppTheme.light),
      weekly: weekly,
      loading: loading,
      hasData: hasData,
      errorMessage: errorMessage,
      solarKwh: solarKwh,
      previousSolarKwh: previousSolarKwh,
      loadKwh: loadKwh,
      previousLoadKwh: previousLoadKwh,
      onRangeChanged: onRangeChanged ?? (_) {},
      onOpenReport: onOpenReport ?? () {},
      seedColor: seed,
      forecast: forecast,
    );
  }

  /// A tall surface keeps the whole card on one screen so no assertion has to
  /// scroll first. The test device is 1220x2712 at density 520, but a plain
  /// 800x600 logical surface would push the tiles below the fold.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('EnergySummaryCard chrome', () {
    testWidgets('shows the title and the method note', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card()));

      // 'Energy analytics' — line 163.
      expect(find.text('Energy analytics'), findsOneWidget);
      // 'Estimated from average telemetry power' — line 187. This is the line
      // that says the figure is derived from mean power, not metered energy,
      // so it must not be dropped when the layout is under pressure.
      expect(
        find.text('Estimated from average telemetry power'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the title and method note while loading', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card(loading: true)));

      expect(find.text('Energy analytics'), findsOneWidget);
      expect(
        find.text('Estimated from average telemetry power'),
        findsOneWidget,
      );
      // The spinner replaces only the body — line 194.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('PV production'), findsNothing);
    });

    testWidgets('shows both period options and reports the selection',
        (tester) async {
      useTallSurface(tester);
      final reported = <bool>[];

      // The selection is applied back into the widget, exactly as
      // DashboardScreen does at lines 1450-1472. Without that a
      // `SegmentedButton` never changes what it thinks is selected, and
      // tapping the segment that is already selected is correctly a no-op —
      // so the second tap would silently record nothing and the test would be
      // asserting a behaviour the real caller never has.
      await tester.pumpWidget(
        wrap(StatefulBuilder(
          builder: (context, setState) => card(
            weekly: reported.isNotEmpty && reported.last,
            onRangeChanged: (value) {
              reported.add(value);
              setState(() {});
            },
          ),
        )),
      );

      // 'Day' and '7 days' — lines 170 and 171. The selector is a
      // SegmentedButton<bool>, so the segment label is the user-visible text.
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);

      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(reported, [true]);

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(reported, [true, false]);
    });

    testWidgets('marks the selected period in the segmented button',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card(weekly: true)));

      // `selected: {weekly}` — line 173. The selected segment is the one whose
      // icon slot is filled, and showSelectedIcon is off, so the check has to
      // come from the button's own state rather than from a visible tick.
      final button = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(button.selected, {true});
    });

    testWidgets('opens the report from the toolbar button', (tester) async {
      useTallSurface(tester);
      var opened = 0;
      await tester.pumpWidget(wrap(card(onOpenReport: () => opened++)));

      // 'Open the energy report' — line 178, the IconButton tooltip.
      expect(find.byTooltip('Open the energy report'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.insert_chart_outlined_rounded));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('EnergySummaryCard tiles', () {
    testWidgets('shows PV production and AC usage with their comparisons',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card()));

      // Titles — lines 217 and 225.
      expect(find.text('PV production'), findsOneWidget);
      expect(find.text('AC usage'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.byIcon(Icons.electrical_services_outlined), findsOneWidget);

      // Values are formatted by _formatEnergy (line 41) to two decimals and
      // suffixed at line 105.
      expect(find.text('4.20 kWh'), findsOneWidget);
      expect(find.text('1.00 kWh'), findsOneWidget);

      // (4.20 - 3.50) / 3.50 = +20% — line 73.
      expect(find.text('+20% vs previous'), findsOneWidget);
      // (1.00 - 2.50) / 2.50 = -60%, and a negative change gets no '+'.
      expect(find.text('-60% vs previous'), findsOneWidget);
    });

    testWidgets('says nothing comparable when the previous period was empty',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(card(previousSolarKwh: 0, previousLoadKwh: 0)),
      );

      // Line 58. The reading is still shown; only the ratio is withheld.
      expect(find.text('4.20 kWh'), findsOneWidget);
      expect(find.text('Nothing to compare yet'), findsNWidgets(2));
    });

    testWidgets('does not report a ratio between two rounding-noise periods',
        (tester) async {
      useTallSurface(tester);
      // previous = 0.05 is below _meaningfulPrevious (0.1, line 77) and current
      // is zero, so the tile says 'No production' rather than '-100% vs
      // previous' (lines 60-63).
      await tester.pumpWidget(
        wrap(
          card(
            solarKwh: 0,
            previousSolarKwh: 0.05,
            loadKwh: 0,
            previousLoadKwh: 0.05,
          ),
        ),
      );

      expect(find.text('No production'), findsNWidgets(2));
      expect(find.text('-100% vs previous'), findsNothing);
    });

    testWidgets('does not claim an absence for a small non-zero previous period',
        (tester) async {
      useTallSurface(tester);
      // **This test used to assert the wrong sentence.** Both periods are below
      // the 0.1 kWh threshold and the current one is not zero, so the tile
      // spelled the figure out — and it said "none last period" about a previous
      // period of 0.02 kWh. The 0.02 was on screen one line above. The *decision*
      // is unchanged and still right: no ratio is claimed between two periods
      // that are both rounding noise. Only the wording moved, because
      // `classifyEnergyChange` now names the case instead of each surface
      // inventing a sentence for it — and the energy report had the identical
      // sentence, so fixing one and not the other would have left the pair
      // contradicting each other again, which is the failure this repo has
      // already paid for once.
      await tester.pumpWidget(
        wrap(
          card(
            solarKwh: 0.04,
            previousSolarKwh: 0.02,
            loadKwh: 0.03,
            previousLoadKwh: 0.02,
          ),
        ),
      );

      expect(find.text('Both periods under 0.1 kWh'), findsNWidgets(2));
      expect(find.textContaining('none last period'), findsNothing);
    });

    testWidgets('says "Same as before" when the change rounds to zero',
        (tester) async {
      useTallSurface(tester);
      // The PV period is identical. The AC one differs by 0.004 out of 1.004,
      // i.e. -0.4%, which rounds to 0 — so line 68 suppresses a "-0%".
      await tester.pumpWidget(
        wrap(
          card(
            previousSolarKwh: 4.2,
            previousLoadKwh: 1.004,
            solarKwh: 4.2,
            loadKwh: 1,
          ),
        ),
      );

      expect(find.text('Same as before'), findsNWidgets(2));
      expect(find.text('-0% vs previous'), findsNothing);
    });

    testWidgets('labels each tile for a screen reader', (tester) async {
      useTallSurface(tester);
      // Disposed at the end of the body, not through addTearDown.
      // `TestWidgetsFlutterBinding._runTestBody` calls `_endOfTestVerifications`
      // — and therefore `_verifySemanticsHandlesWereDisposed` — before any
      // addTearDown callback runs, so a tearDown-disposed handle is still live
      // at the moment it is checked and the test fails for a reason that has
      // nothing to do with the card. AGENT_PLAYBOOK.md §7 records the same trap
      // from the other end: enabling semantics and then not disposing them
      // contaminates every later test in the file.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(card()));

      // Built at line 90 as '$title: <value> kilowatt-hours. <comparison>'.
      // Matched by label rather than through getSemantics, so no Semantics
      // node outside the card is picked up — the widget is a StatelessWidget
      // with no key, so find.descendant would need a parent to narrow from.
      //
      // Matched as a RegExp, not a String: _metric wraps the Semantics in
      // MergeSemantics (line 88), so the surviving node's label is this
      // sentence concatenated with the text of the tile beneath it. An exact
      // string would only pass if the merge ever stopped merging.
      expect(
        find.bySemanticsLabel(
          RegExp(r'PV production: 4\.20 kilowatt-hours\. \+20% vs previous'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'AC usage: 1\.00 kilowatt-hours\. -60% vs previous'),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('EnergySummaryCard empty state', () {
    testWidgets('shows the default message when there is no data',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(card(hasData: false, errorMessage: null)),
      );

      // Line 204: the fallback when the caller has no error to report.
      expect(
        find.text('No power data available to calculate from.'),
        findsOneWidget,
      );
      expect(find.text('PV production'), findsNothing);
      expect(find.text('AC usage'), findsNothing);
    });

    testWidgets('shows the caller error message in place of the default',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          card(
            hasData: false,
            errorMessage: 'Could not reach ThingsBoard for the last hour',
          ),
        ),
      );

      // errorMessage ?? ... — line 204.
      expect(
        find.text('Could not reach ThingsBoard for the last hour'),
        findsOneWidget,
      );
      expect(
        find.text('No power data available to calculate from.'),
        findsNothing,
      );
    });
  });

  group('EnergySummaryCard forecast', () {
    EnergyForecastResult result({
      double observed = 1.25,
      double daily = 6.4,
      double? target = 8,
      double? progress = 0.5,
      double? peakWatts = 1800,
      double? runwayHours = 3.5,
    }) {
      return EnergyForecastResult(
        observedProductionKwh: observed,
        dailyProductionEstimateKwh: daily,
        productionTargetKwh: target,
        targetProgress: progress,
        peakUsageWatts: peakWatts,
        peakUsageAt: DateTime(2026, 9, 29, 13),
        batteryDepletionHours: runwayHours,
        sampleStart: DateTime(2026, 9, 29),
        sampleEnd: DateTime(2026, 9, 29, 23, 59),
      );
    }

    testWidgets('summarises a forecast with a target and a runway',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card(forecast: result())));
      // pump, not pumpAndSettle: the summary ends in a LinearProgressIndicator.
      await tester.pump();

      // 'Forecast' — line 261. Metrics at lines 274 and 283.
      expect(find.text('Forecast'), findsOneWidget);
      expect(find.text('Daily estimate'), findsOneWidget);
      expect(find.text('6.40 kWh'), findsOneWidget);
      expect(find.text('Peak usage'), findsOneWidget);
      expect(find.text('1800 W'), findsOneWidget);

      // Footer at line 301 joins the two labels with a middle dot.
      expect(
        find.text('50% of 8.0 kWh · 3.5 h of estimated battery'),
        findsOneWidget,
      );
      // Only rendered while something was actually observed (line 307).
      expect(find.text('Actual today: 1.25 kWh'), findsOneWidget);
    });

    testWidgets('says the target and runway are unavailable when they are null',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrap(
          card(
            forecast: result(
              target: null,
              progress: null,
              peakWatts: null,
              runwayHours: null,
              observed: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      // 'Unavailable' for a null peak is its own Text — line 284.
      expect(find.text('Unavailable'), findsOneWidget);

      // The other two are not standalone Texts: 'No production target set'
      // (line 247) and 'No battery runway available' (line 250) are joined by
      // the footer at line 301 into one string, so the footer is what is
      // asserted on.
      expect(
        find.text(
          'No production target set · No battery runway available',
        ),
        findsOneWidget,
      );

      // progress is null, so no bar is drawn (line 293) — a progress bar
      // showing 0% would read as "you have produced nothing", which is the
      // opposite of "no target is set".
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // hasProduction is false at zero observed — energy_forecast_service.dart
      // line 29 — so the actuals line is suppressed (line 307).
      expect(find.textContaining('Actual today:'), findsNothing);
    });

    testWidgets('omits the forecast entirely when none is supplied',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card()));

      expect(find.text('Forecast'), findsNothing);
      // The two tiles must still be there.
      expect(find.text('PV production'), findsOneWidget);
      expect(find.text('AC usage'), findsOneWidget);
    });
  });

  group('EnergySummaryCard theming', () {
    // The tiles pass an `accent`, and it does not reach the screen.
    //
    // `AppTile` delivers the wash as a `ColoredBox` *parent* of the tile's own
    // `Container`, and that `Container`'s `BoxDecoration` carries an opaque
    // `color` — so the fill paints straight over the wash. `ClipRRect` clips the
    // wash to the tile radius and the Container fills that same radius, so no
    // sliver survives either. Both tiles have therefore rendered with no wash
    // since the widget was extracted from two call sites.
    //
    // It is left that way on purpose: `AppTile` records that reviving it costs
    // two AA failures on the delta caption, or the fill-contrast bug the widget
    // was just fixed for. So this asserts the **current, invisible** behaviour
    // instead of leaving it unstated. If the wash is ever revived this test is
    // expected to fail, and that failure is the point: it also moves the
    // surfaces in `color_helpers_test.dart`, so it is not a one-line edit here.
    testWidgets('the tile accent wash is not painted, over an opaque fill', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card(seed: Color(0xFF00838F))));

      final tiles = find.byType(AppTile);
      expect(tiles, findsNWidgets(2));

      for (final tile in tiles.evaluate()) {
        // The wash is a `ColoredBox` *above* the tile's own `Container` — which
        // is why `find.descendant` finds it here and not below.
        final washes = find.descendant(
          of: find.byWidget(tile.widget),
          matching: find.byType(ColoredBox),
        );
        expect(washes, findsOneWidget);

        // What paints over it. **Two Containers now, and both have to be
        // opaque.** The skeuomorphic tile is a chamfered rim (`AppSkeuo.rim`)
        // with the fill inset inside it by one pixel, so the rim covers the
        // tile's outer pixel and the fill covers the rest. Either one going
        // translucent would let the wash show through it.
        final containers = find.descendant(
          of: find.byWidget(tile.widget),
          matching: find.byType(Container),
        );
        expect(containers, findsNWidgets(2));
        final layers = tester
            .widgetList<Container>(containers)
            .map((c) => c.decoration! as BoxDecoration)
            .toList();

        // Opaque, every stop of both gradients. This is what makes the wash
        // invisible. `a` is the 0..1 double, so 255 is 1.0.
        for (final layer in layers) {
          for (final stop in (layer.gradient! as LinearGradient).colors) {
            expect(
              stop.a,
              1.0,
              reason: 'the tile must stay opaque, or the accent wash behind '
                  'it becomes visible and the delta caption needs remeasuring',
            );
          }
        }
        // The inner layer is the fill, and the token is one of its stops — the
        // stop nearest the caption, by `AppSkeuo.fill`'s direction rule.
        expect(
          (layers.last.gradient! as LinearGradient).colors,
          contains(AppSurfaces.input(AppTheme.light)),
          reason: 'the rendered tile surface is the input fill - the same one '
              'color_helpers_test.dart measures faintColor against',
        );

        // And the wash really is behind rather than in front, so the opacity
        // above is the reason and not a coincidence of tree shape.
        expect(
          find.descendant(
            of: containers.first,
            matching: find.byType(ColoredBox),
          ),
          findsNothing,
          reason: 'if the wash became a child of the filled Container it would '
              'be visible, and this test would be asserting the wrong thing',
        );
      }
    });

    testWidgets('keeps both tile colours inside the chosen accent hue',
        (tester) async {
      useTallSurface(tester);
      // An accent that is neither amber nor blue, so a hard-coded tile colour
      // cannot accidentally match it.
      const seed = Color(0xFF00838F);
      await tester.pumpWidget(wrap(card(seed: seed)));

      // Both tiles are derived from seedColor (lines 142-150), differing only
      // in lightness. The sun icon paints with the PV colour and the plug icon
      // with the AC colour, so their hues must agree and their lightnesses
      // must not. Hard-coded amber/blue here is the regression this guards.
      final solarIcon = tester.widget<Icon>(
        find.byIcon(Icons.wb_sunny_outlined),
      );
      final loadIcon = tester.widget<Icon>(
        find.byIcon(Icons.electrical_services_outlined),
      );

      expect(solarIcon.color, isNotNull);
      expect(loadIcon.color, isNotNull);

      final seedHsl = HSLColor.fromColor(seed);
      final solarHsl = HSLColor.fromColor(solarIcon.color!);
      final loadHsl = HSLColor.fromColor(loadIcon.color!);

      // The hue is the one thing themeColor cannot perturb — it only touches
      // saturation and lightness (color_helpers.dart lines 10-13) — so this is
      // really only absorbing the 8-bit quantisation of the round trip. Amber
      // (~40) and the usual blues (~210 to 240) are all far outside it.
      expect((solarHsl.hue - seedHsl.hue).abs(), lessThan(5));
      expect((loadHsl.hue - seedHsl.hue).abs(), lessThan(5));
      expect(solarHsl.lightness, isNot(closeTo(loadHsl.lightness, 0.01)));
    });

    testWidgets('renders in dark mode', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(card(isDark: true)));

      expect(find.text('Energy analytics'), findsOneWidget);
      expect(find.text('4.20 kWh'), findsOneWidget);
    });
  });

  // The two groups below are the ones written on 2 October 2026 after the card
  // was measured at widths and text scales it had never been measured at. They
  // are not a rewrite of the file above — that file was already here and its
  // chrome, theming and accent-wash coverage is kept as it was.
  group('EnergySummaryCard never amputates a figure', () {
    /// Resizes the surface to [widthDp] logical pixels.
    ///
    /// `physicalSize` is in physical pixels and `devicePixelRatio` is 1, so the
    /// two are the same number here. Setting only one of them is the mistake
    /// that makes a "narrow screen" test quietly run at the default 800x600,
    /// which is wide enough that nothing truncates and the assertion passes for
    /// the wrong reason — which is what this group exists to rule out.
    void useWidth(WidgetTester tester, double widthDp) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(widthDp, 1600);
      addTearDown(tester.view.reset);
    }

    /// Resizes and sets a system font scale together, because neither is the
    /// interesting case on its own.
    Future<void> pumpScaled(
      WidgetTester tester, {
      required double widthDp,
      required double scale,
    }) async {
      useWidth(tester, widthDp);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: wrap(
            card(solarKwh: 1234.56, previousSolarKwh: 1400, loadKwh: 987.65, previousLoadKwh: 1200),
          ),
        ),
      );
      await tester.pump();
    }

    // The `109....` regression, reproduced with a different number.
    //
    // The two tiles share a row and each gets an `Expanded`, so at 320 dp a
    // column is about 115 dp wide — and `1.53 kWh` at 17 sp w800 needs a little
    // more than that. With `overflow: ellipsis` the engine drew `1.53 k…` and
    // `0.27 k…`: **the unit amputated off an entirely ordinary reading**, on a
    // phone narrower than any this had ever been checked on.
    //
    // `didExceedMaxLines` rather than `find.text`, because the widget tree still
    // reports the full string after the engine has clipped it. An assertion built
    // on `find.text` passes with the truncation present — which is why this one
    // passed for three label regressions in a row on 27 September 2026.
    for (final width in kNarrowWidthsDp) {
      testWidgets('nothing is truncated at ${width.toInt()} dp, scale 1.0', (
        tester,
      ) async {
        await pumpScaled(tester, widthDp: width, scale: 1.0);

        expectNothingClipped(tester, ignore: _controlLabels);
      });
    }

    // 2.0 is not hypothetical: `DateStripChip` laid its label out at 20 sp and
    // scaled it back to 13 dp, and nothing in the suite could see it.
    for (final width in kNarrowWidthsDp) {
      for (final scale in kTextScales) {
        testWidgets('nothing is truncated at ${width.toInt()} dp, scale $scale', (
          tester,
        ) async {
          await pumpScaled(tester, widthDp: width, scale: scale);

          expectNothingClipped(tester, ignore: _controlLabels);
        });
      }
    }

    // A `RenderFlex` overflow is not a warning, it is an exception on every
    // frame, and it paints the black-and-yellow stripe. This asserts none is
    // thrown rather than reading the tree, because a `Row` that overflows still
    // renders — it just renders broken.
    testWidgets('the card lays out without overflowing at any scale', (
      tester,
    ) async {
      for (final width in kNarrowWidthsDp) {
        for (final scale in kTextScales) {
          await pumpScaled(tester, widthDp: width, scale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: 'a RenderFlex overflowed at ${width.toInt()} dp, scale '
                '$scale. The header held the title in an Expanded and the '
                'SegmentedButton at its intrinsic width, and a SegmentedButton '
                'cannot be squeezed -- so a user with a large system font got a '
                'broken card on a 411 dp phone, not only on a small one.',
          );
        }
      }
    });
  });

  group('EnergySummaryCard states each label once', () {
    // The `PV Output` regression: one card, three copies of one phrase. A count
    // is the only assertion that catches a reintroduction, because each copy on
    // its own is perfectly correct.
    testWidgets('the kWh figure and its unit are one string', (tester) async {
      useWidth900(tester);
      await tester.pumpWidget(wrap(card()));

      // If the unit were ever lifted out of the value into its own row it would
      // appear twice and the tile would grow a line for no information.
      expect(find.textContaining('kWh'), findsNWidgets(2));
    });
  });
}

/// The range selector's own label, and only it.
///
/// At a 2.0 system font on a 320 dp phone `7 days` does not fit beside the
/// report button, and the alternative measured was a row that overflowed by
/// 111 px and painted the stripe on every frame. A control that reads `7 da…` is
/// still operable; a layout that throws is not. The kWh figures have no such
/// exemption, which is the whole reason this list names two strings instead of
/// loosening the assertion.
const Set<String> _controlLabels = {'Day', '7 days'};

/// 900 dp, the width [EnergySummaryCard]'s other group uses so the whole card
/// sits on one screen.
void useWidth900(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
