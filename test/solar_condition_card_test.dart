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
/// ## The unit changed, and the reason is worth recording
///
/// This card used to convert the lux reading to irradiance and show `443 W/m²`
/// with a `% of a clear noon` caption under the bar. The conversion is sound
/// arithmetic and it took one look at the device to see it was the wrong number
/// to show: a W/m² figure is a quantity the PV card is the authority on, and a
/// user who wants to know what the sky is doing should not have to interpret a
/// photometric-to-radiometric conversion to find out.
///
/// The card now shows what the sensor measured — lux — plus the condition that
/// number lands in, and the question "is it bright enough" is answered in words
/// rather than in a derived unit. `luxToIrradiance` is still used, but only to
/// drive the bar: a fraction of one sun is a bounded thing to fill a track with,
/// and it does not need to be spelled out.
///
/// The states worth a test are the ones that are not the happy path, because the
/// happy path is the only one that gets looked at. A greenhouse lux sensor goes
/// to zero at night, reads a small negative value when it is dark, and stops
/// reporting entirely when the gateway drops.
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
/// from `tester.ensureSemantics()` and disposes it at the end of the test body.
///
/// **Matched with `find.bySemanticsLabel`, not `tester.getSemantics`.** The
/// obvious spelling fails twice over here, and both failures are silent: the
/// un-narrowed `find.byType(Semantics).first` returns the `Scaffold`'s node
/// rather than the card's, and once narrowed the label is still empty because
/// the card's own `Semantics` sits above descendants whose nodes are separate
/// rather than merged. `bySemanticsLabel` asks the question the reader's
/// software actually asks.
Finder announced(Pattern pattern) => find.bySemanticsLabel(pattern);

void main() {
  group('states', () {
    testWidgets('a missing reading says so, and draws no figure', (
      tester,
    ) async {
      await pumpCard(tester, lux: null);
      expect(tester.takeException(), isNull);
      expect(find.text('No reading'), findsOneWidget);
      // The dangerous case is a card that renders "0 lx" and a full-width bar for
      // a sensor that has said nothing at all. Zero light and no light are
      // different facts and the card must not conflate them.
      expect(find.text('lx'), findsNothing);
      expect(find.textContaining('% of a clear noon'), findsNothing);
    });

    testWidgets('a dark reading reads as heavily overcast, not as clear', (
      tester,
    ) async {
      await pumpCard(tester, lux: 0);
      expect(find.text('Heavily overcast'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a small negative reading does not become negative light', (
      tester,
    ) async {
      // The sensor really does report a small negative value in the dark, the
      // same way the BMS reports `-0.01 A`. `luxToIrradiance` clamps at zero;
      // this asserts the clamp reaches the screen, because a card that rendered
      // "-0 lx" would be a visible, inexplicable minus sign.
      await pumpCard(tester, lux: -0.4);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('-0'), findsNothing);
    });

    testWidgets('a noon reading is clear', (tester) async {
      await pumpCard(tester, lux: 100000);
      expect(find.text('Clear sky'), findsOneWidget);
      // **The lux reading itself, not a conversion.** 100 000 lx is 1075 W/m²,
      // which is over one sun — but the card no longer shows that, because the
      // number the user can verify against the environment grid is the one the
      // sensor actually reported.
      expect(find.text('100000'), findsOneWidget);
      expect(find.textContaining('W/m²'), findsNothing);
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
      // If the bar were pinned full everywhere it would stop being information.
      // The conversion is still what drives it -- 50 000 lx is about 0.54 of a
      // sun -- and that is verified here as a *rendered* width rather than
      // restated as the maths, which `solar_irradiance_test.dart` covers.
      await pumpCard(tester, lux: 50000);
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
      expect(fill.width / track.width, closeTo(0.54, 0.03));
    });
  });

  group('the announcement', () {
    // **`handle.dispose()` at the end of the body, not in an `addTearDown`.**
    //
    // The framework verifies that every `SemanticsHandle` was disposed *before*
    // tearDowns run, so a teardown-registered dispose fails the test with "A
    // SemanticsHandle was active at the end of the test" — a message about
    // bookkeeping that has nothing to do with the card, and one that appears only
    // once the label assertions themselves have already passed.
    testWidgets('reads the reading and the condition in one sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, lux: 41200);
      // 41 200 lx lands in the 28 000–55 000 band, so the whole point of the
      // card -- a bare lux number turned into a sentence about the sky -- is in
      // this one string. The lux figure is what a screen reader is told, and it
      // is the number the sensor reported rather than a derived one.
      expect(announced(RegExp(r'41200 lux')), findsOneWidget);
      expect(announced(RegExp('Mostly clear')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('says "no reading" rather than reading out a zero', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, lux: null);
      // A missing sensor and a dark one are different facts. Announcing "0 lx"
      // for a device that has never reported would tell a grower the greenhouse
      // is in darkness when in fact nothing is known.
      expect(announced(RegExp('no reading')), findsOneWidget);
      expect(announced(RegExp(r'0 lx')), findsNothing);
      handle.dispose();
    });
  });

  group('tokens', () {
    testWidgets('the fill is lime, and only lime', (tester) async {
      // The app's rule is that a status colour means a condition rather than an
      // identity, and the one place a hue could drift is here. A clear-sky card
      // that borrowed the chart triad's red would say "something is wrong" about
      // a cloudless noon.
      await pumpCard(tester, lux: 100000);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(FractionallySizedBox),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, AppPalette.primary);
    });
  });
}
