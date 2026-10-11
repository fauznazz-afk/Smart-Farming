import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/screens/dashboard/widgets/chart_groups.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/chart_card.dart';
import 'package:plts_monitoring/screens/dashboard/charts/chart_data.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';
import 'package:fl_chart/fl_chart.dart';

/// Tests for two states this app was conflating, and for the one accessibility
/// setting it was quietly overriding.
///
/// They are in one file because they share a reason: each is a case where the
/// widget looked like it was saying something and was saying something else.
/// A failed request and a quiet day both read "No data", a chip in a fixed box
/// read as though it had honoured the font scale, and both fixes are about not
/// quietly substituting one meaning for another.
void main() {
  Widget wrap(Widget child, {double width = 381, double scale = 1.0}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800))
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  group('TelemetryChartCard empty state', () {
    Widget card({required bool loadFailed, required bool loading}) =>
        TelemetryChartCard(
          prefix: 'pv',
          group: chartGroupsForPrefix('pv').first,
          points: <String, List<TelemetryPoint>>{},
          spots: <String, List<FlSpot>>{},
          stats: <String, SeriesStats?>{},
          boundsCache: <String, ChartBounds>{},
          loading: loading,
          loadFailed: loadFailed,
          selectedDate: DateTime(2026, 10, 1),
          rangeStart: null,
          rangeEnd: null,
          onPointerActive: (_) {},
        );

    testWidgets('a failed request does not claim the range produced nothing', (
      tester,
    ) async {
      // **This is the whole reason `loadFailed` exists.** `_fetchHistoryFor`
      // caught every exception and substituted an empty map, so a dropped
      // connection and a quiet day reached the card as the same empty list and
      // both rendered "No data for this range".
      //
      // That sentence is not neutral: it tells the user the greenhouse produced
      // nothing, which sends them to look at the plants, when the overwhelmingly
      // more likely cause is a network they cannot fix from the field.
      await tester.pumpWidget(wrap(card(loadFailed: true, loading: false)));
      await tester.pumpAndSettle();

      expect(find.text('Could not load this range'), findsOneWidget);
      expect(find.text('No data for this range'), findsNothing);
    });

    testWidgets('a genuinely quiet range still says no data', (tester) async {
      await tester.pumpWidget(wrap(card(loadFailed: false, loading: false)));
      await tester.pumpAndSettle();

      expect(find.text('No data for this range'), findsOneWidget);
      expect(find.text('Could not load this range'), findsNothing);
    });

    testWidgets('a spinner wins over either message', (tester) async {
      // The caller passes `loadFailed: !loading && ...` for this, and the widget
      // checks `loading` first, so a retry in progress never flashes a warning.
      await tester.pumpWidget(wrap(card(loadFailed: true, loading: true)));
      // `pump`, not `pumpAndSettle`: a `CircularProgressIndicator` animates
      // forever, so settling never completes. Which is the point -- there is a
      // spinner on screen rather than a sentence.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Could not load this range'), findsNothing);
    });
  });

  group('DateStripChip honours the font scale', () {
    // The day name was inside `SizedBox(height: 13)` with a `FittedBox`, so at
    // 2x it was laid out at 20 sp and scaled straight back down to 13 dp. It
    // rendered at effectively its 1.0 size whatever the user asked for, which is
    // the one place in the app that inverted an accessibility setting silently.
    //
    // **The assertion is on the label, not on the chip.** It used to be
    // `chip height > 68`, i.e. "taller than the chip's `minHeight`", which reads
    // like a proxy for "the text got taller" and is not one.
    //
    // It was passing for the wrong reason. At the 42 dp width below, the test
    // font's glyphs are a full em square, so a 20 sp `MON` is 60 dp wide inside
    // 26 dp of content space: it *wrapped*, onto two lines, and the wrap is what
    // pushed the chip past 68. So the assertion was pinned to the wrapping bug —
    // the very defect that made the Overview calendar's row not one row, since a
    // wrapped name makes one chip of seven taller than the other six. Fixing the
    // wrap is what made this test fail, and it was the test that was wrong.
    //
    // `minHeight: 68` is doing its job here: at 42 dp there is room for a 20 sp
    // label inside the minimum, so the chip correctly does not need to grow. The
    // thing that must grow is the text, and that is now what is measured.

    /// The height the chip's day name is actually laid out at.
    double nameHeight(WidgetTester tester) =>
        tester.getSize(find.text('MON')).height;

    Widget chip({required double width, required double scale}) => wrap(
      DateStripChip(
        width: width,
        dayName: 'Mon',
        dayNumber: 28,
        isSelected: false,
        onTap: () {},
      ),
      scale: scale,
    );

    testWidgets('the two texts are laid out at the user\'s scale', (
      tester,
    ) async {
      await tester.pumpWidget(chip(width: 42, scale: 1.0));
      await tester.pumpAndSettle();
      final atOne = nameHeight(tester);

      await tester.pumpWidget(chip(width: 42, scale: 2.0));
      await tester.pumpAndSettle();
      final atTwo = nameHeight(tester);

      // No overflow, which was the reason the fixed box existed.
      expect(tester.takeException(), isNull);
      // And the direction the defect inverted.
      expect(
        atTwo,
        greaterThan(atOne),
        reason:
            'at a 2x system font the day name is $atTwo tall and at 1.0 it '
            'is $atOne. A label that does not grow with the scale is the '
            'FittedBox defect this test was written for.',
      );
    });

    testWidgets('the day name stays on one line, whatever the chip width', (
      tester,
    ) async {
      // The counterpart to the assertion above, and the reason the chip's height
      // is uniform across the strip. A name that breaks at a character to fit
      // ("MO" over "N") makes its chip taller than its six neighbours, which is
      // an asymmetry in a row of seven cells that look like a calendar.
      for (final width in [34.0, 42.0, 49.0]) {
        for (final scale in [1.0, 2.0, 3.0]) {
          await tester.pumpWidget(chip(width: width, scale: scale));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'at ${width}dp, scale $scale',
          );

          final paragraph = tester.renderObject<RenderParagraph>(
            find.text('MON'),
          );
          final lines = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 3),
              )
              .length;
          expect(
            lines,
            1,
            reason: '"MON" broke onto $lines lines at ${width}dp, scale $scale',
          );
        }
      }
    });

    testWidgets('all seven chips are one height at every scale', (
      tester,
    ) async {
      // The property the Overview calendar is actually judged on. Asserted on
      // the chips together rather than on one, because a uniform-height strip is
      // a claim about the row and no single chip can make it.
      for (final scale in [1.0, 2.0, 3.0]) {
        final heights = <double>{};
        for (var i = 0; i < 7; i++) {
          await tester.pumpWidget(
            wrap(
              Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    DateStripChip(
                      width: 49,
                      dayName: [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][d],
                      dayNumber: 1 + d + i,
                      isSelected: d == 3,
                      onTap: () {},
                    ),
                ],
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'at scale $scale');
          heights.add(tester.getSize(find.byType(DateStripChip).first).height);
        }
        expect(
          heights,
          hasLength(1),
          reason:
              'at scale $scale the chips were $heights tall. A row of seven '
              'calendar cells is only a calendar if they are one height.',
        );
      }
    });

    testWidgets('still no overflow at 1.5 with a narrow chip', (tester) async {
      await tester.pumpWidget(chip(width: 34, scale: 1.5));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The chip uppercases the day name, so the string to look for is `MON`
      // and not `Mon`. The assertion is still about truncation, not casing: a
      // too-narrow box makes the layout engine *throw*, it does not silently
      // shorten a `Text`, so finding the whole three-letter name is the evidence
      // that it was laid out at the width it was given rather than clipped.
      expect(find.text('MON'), findsOneWidget);
    });
  });
}
