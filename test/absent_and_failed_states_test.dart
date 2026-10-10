import 'package:flutter/material.dart';
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

    testWidgets('a failed request does not claim the range produced nothing',
        (tester) async {
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
    // The assertion is that the text gets *taller* with the scale. Not a pixel
    // value -- that would pin the chosen font and break the moment anyone
    // adjusted it -- but a direction, which is what the defect inverted.

    testWidgets('the two texts are laid out at the user\'s scale', (tester) async {
      await tester.pumpWidget(
        wrap(
          DateStripChip(
            width: 42,
            dayName: 'Mon',
            dayNumber: 28,
            isSelected: false,
            onTap: () {},
          ),
          scale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      // No overflow, which was the reason the fixed box existed.
      expect(tester.takeException(), isNull);
      // And the chip is genuinely taller than it is at 1.0, rather than the text
      // being scaled back down inside a box that cannot grow.
      final tall = tester.getSize(find.byType(DateStripChip));
      expect(tall.height, greaterThan(68));
    });

    testWidgets('still no overflow at 1.5 with a narrow chip', (tester) async {
      await tester.pumpWidget(
        wrap(
          DateStripChip(
            width: 34,
            dayName: 'Mon',
            dayNumber: 28,
            isSelected: false,
            onTap: () {},
          ),
          scale: 1.5,
        ),
      );
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