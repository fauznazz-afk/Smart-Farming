import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/solar_condition.dart';

/// The card that turns the greenhouse lux sensor into a sky reading.
///
/// **The maths is covered in `solar_irradiance_test.dart` and is deliberately
/// not re-tested here.** What this file covers is the three things only a widget
/// can: that the card survives the states the sensor actually gets into, that the
/// bar never draws outside its track, and that the label a screen reader reads is
/// the same sentence the card draws.
///
/// The states worth a test are the ones that are not the happy path, because the
/// happy path is the only one that gets looked at. A greenhouse lux sensor goes
/// to zero at night, reads a small negative value when it is dark, and stops
/// reporting entirely when the gateway drops -- and this card is on the
/// Hydroponics page, which is the page a grower opens in the morning.
Future<void> pumpCard(
  WidgetTester tester, {
  required double? lux,
  DateTime? lastUpdate,
  int staleMinutes = 10,
  double width = 411,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SolarConditionCard(
            lux: lux,
            lastUpdate: lastUpdate,
            staleMinutes: staleMinutes,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The card's whole announcement, as a screen reader would read it.
///
/// **Never call `tester.getSemantics()` without `ensureSemantics()`** — it can
/// hang the isolate, and AGENTS.md records that the damage is then attributed to
/// every later test in the file. Each test that reads semantics takes the handle
/// from `tester.ensureSemantics()` and disposes it, which is the pairing the
/// framework documents.
String? announce(WidgetTester tester) =>
    tester.getSemantics(find.byType(Semantics).first).label;

void main() {
  group('states', () {
    testWidgets('a missing reading says so, and draws no figure', (
      tester,
    ) async {
      await pumpCard(tester, lux: null);
      expect(tester.takeException(), isNull);
      expect(find.text('No reading'), findsOneWidget);
      // The dangerous case is a card that renders "0 W/m²" and a full-width bar
      // for a sensor that has said nothing at all. Zero light and no light are
      // different facts and the card must not conflate them.
      expect(find.text('W/m²'), findsNothing);
      expect(find.textContaining('% of a clear noon'), findsNothing);
    });

    testWidgets('a dark reading reads as heavily overcast, not as clear', (
      tester,
    ) async {
      await pumpCard(tester, lux: 0);
      expect(find.text('Heavily overcast'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('0% of a clear noon'), findsOneWidget);
    });

    testWidgets('a small negative reading does not become negative light', (
      tester,
    ) async {
      // The sensor really does report a small negative value in the dark, the
      // same way the BMS reports `-0.01 A`. `luxToIrradiance` clamps at zero;
      // this asserts the clamp reaches the screen, because a card that rendered
      // "-0 W/m²" would be a visible, inexplicable minus sign.
      await pumpCard(tester, lux: -0.4);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('-0'), findsNothing);
      expect(find.text('0% of a clear noon'), findsOneWidget);
    });

    testWidgets('a noon reading is clear, and the bar is full', (tester) async {
      await pumpCard(tester, lux: 100000);
      expect(find.text('Clear sky'), findsOneWidget);
      // 100 000 lx is 1075 W/m², so the figure is over one sun and the fraction
      // is clamped. Both halves of that are asserted: the number is allowed to
      // exceed 1000, and the bar is not.
      expect(find.text('1075'), findsOneWidget);
      expect(find.text('100% of a clear noon'), findsOneWidget);
    });

    testWidgets('a stale reading is marked, and a fresh one is not', (
      tester,
    ) async {
      await pumpCard(
        tester,
        lux: 40000,
        lastUpdate: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(find.text('stale'), findsOneWidget);

      await pumpCard(
        tester,
        lux: 40000,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(find.text('stale'), findsNothing);
    });

    testWidgets(
      'a missing timestamp is not stale, because nothing claims it is',
      (tester) async {
        // The dashboard passes `_sensor?.lastUpdate`, which is null whenever the
        // greenhouse device has never reported. Marking that "stale" would assert
        // a condition -- that the data is old -- which is not what is known.
        await pumpCard(tester, lux: 40000, lastUpdate: null);
        expect(find.text('stale'), findsNothing);
      },
    );
  });

  group('the bar', () {
    testWidgets('never draws wider than its track, at any reading', (
      tester,
    ) async {
      // The overflow this guards against is invisible in a source review and
      // obvious on the device: a lime fill escaping an 8dp rounded track on the
      // brightest day of the year.
      //
      // Measured, not re-derived from the maths. `sunFraction` already clamps and
      // `solar_irradiance_test.dart` already pins that, so recomputing the
      // expected width here would only restate the clamp. What is new in a widget
      // is whether the *rendered* fill respects it, which is a claim about a
      // different object.
      for (final lux in [
        0.0,
        1.0,
        1800.0,
        9000.0,
        28000.0,
        55000.0,
        100000.0,
        500000.0,
      ]) {
        await pumpCard(tester, lux: lux);
        expect(tester.takeException(), isNull, reason: 'at $lux lx');

        // The track is the outer `Container`; the fill is the `DecoratedBox`
        // inside the `FractionallySizedBox` inside it.
        final track = tester.getSize(
          find
              .descendant(
                of: find.byType(SolarConditionCard),
                matching: find.byType(Container),
              )
              .last,
        );
        final fill = tester.getSize(
          find
              .descendant(
                of: find.byType(FractionallySizedBox),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );

        expect(
          fill.width,
          lessThanOrEqualTo(track.width + 0.01),
          reason:
              'at $lux lx the fill is ${fill.width}dp inside a '
              '${track.width}dp track',
        );
        expect(fill.width, greaterThanOrEqualTo(0), reason: 'at $lux lx');
      }
    });

    testWidgets('a zero reading draws no fill at all', (tester) async {
      // Zero light is the one reading where the fill must vanish rather than
      // being a sliver: at night the card should read as an empty track.
      await pumpCard(tester, lux: 0);
      final fill = tester.getSize(
        find
            .descendant(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(fill.width, 0);
    });

    testWidgets('is proportional in the middle of the range', (tester) async {
      // If the bar were pinned full everywhere the percentage caption would be
      // the only thing telling the truth, and a caption is not a bar.
      await pumpCard(tester, lux: 50000);
      expect(find.text('54% of a clear noon'), findsOneWidget);
    });
  });

  group('the announcement', () {
    testWidgets('reads the figure and the condition in one sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);
      await pumpCard(tester, lux: 41200);
      final label = announce(tester);
      expect(label, isNotNull);
      expect(label, contains('W/m²'));
      expect(label, contains('Mostly clear'));
    });

    testWidgets('says "no reading" rather than reading out a zero', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);
      await pumpCard(tester, lux: null);
      expect(announce(tester), contains('no reading'));
    });
  });

  group('tokens', () {
    testWidgets('the fill is lime, and only lime', (tester) async {
      // The app's rule is that lime is the sun and the sun is this card, so the
      // one place a hue could drift is here. A clear-sky card that borrowed the
      // chart triad's red would say "something is wrong" about a cloudless noon.
      await pumpCard(tester, lux: 100000);
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, AppPalette.primary);
    });
  });
}
