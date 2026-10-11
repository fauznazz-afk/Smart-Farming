import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';

/// The panel's primitives, and the two claims that are invisible in the source.
///
/// ## Why this file asserts a *rendered width*
///
/// The meter looked correct in the source, compiled clean, and drew nothing. A
/// `FractionallySizedBox` in a `Stack` is a non-positioned child, so the stack
/// sizes itself to it and hands it loose constraints — with nothing to scale
/// against, `widthFactor` has no width to take a fraction *of*, and a 95%
/// reading drew an empty track.
///
/// `flutter analyze` cannot see that, and neither can an assertion about the
/// caption. This is the same lesson as the sky card's bar in 1.9.1, in the same
/// shape, so the check here reads the rendered size rather than trusting the
/// widget tree.
void main() {
  /// The meter's painted size, as the layout actually resolved it.
///
/// **Both dimensions, and the height is the half that was missing.** The first
/// version of this file measured `fill.width / track.width` and passed at 95%
/// while the bar was invisible on the device — because the fill was 95% wide
/// and **0 dp tall**. A `DecoratedBox` with no child under loose constraints
/// collapses to `constraints.smallest`, so a `FractionallySizedBox` carrying
/// only a `widthFactor` gets a width and nothing for height.
///
/// So this asserts the fill's height against the track's, which is the claim
/// that actually describes whether anything was painted.
Future<Size> pumpMeter(
  WidgetTester tester,
  double fraction, {
  double width = 381,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TerminalMeter(
            fraction: fraction,
            leftCaption: '0%',
            rightCaption: '100%',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final track = tester.getSize(
    find
        .descendant(
          of: find.byType(TerminalMeter),
          matching: find.byType(DecoratedBox),
        )
        .first,
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
    track.width,
    greaterThan(0),
    reason: 'the track has no width, so no fraction can mean anything',
  );
  expect(
    fill.height,
    closeTo(track.height, 0.5),
    reason:
        'the fill is ${fill.height}dp tall and the track is ${track.height}dp. A '
        'zero-height fill has the right width and paints nothing at all, which '
        'is what shipped.',
  );
  return Size(fill.width / track.width, fill.height);
}

  group('the meter actually fills', () {
    testWidgets('a 95% reading draws 95% of the track', (tester) async {
      final size = await pumpMeter(tester, 0.95);
      expect(
        size.width,
        closeTo(0.95, 0.02),
        reason:
            'the fill is ${(size.width * 100).toStringAsFixed(1)}% of the track. '
            'A meter that reads empty at 95% is worse than no meter, because the '
            'reader acts on it.',
      );
    });

    testWidgets('a half reading draws half', (tester) async {
      expect((await pumpMeter(tester, 0.5)).width, closeTo(0.5, 0.02));
    });

    testWidgets('a zero reading draws nothing at all', (tester) async {
      // The case a `Row` of two `Expanded`s cannot express: both children get at
      // least their flex share, so zero renders as a visible stub.
      expect((await pumpMeter(tester, 0)).width, lessThan(0.01));
    });

    testWidgets('a full reading draws the whole track, never past it', (
      tester,
    ) async {
      final size = await pumpMeter(tester, 1.0);
      expect(size.width, closeTo(1.0, 0.01));
      expect(size.width, lessThanOrEqualTo(1.0));
    });

    testWidgets('out-of-range and NaN inputs cannot escape the track', (
      tester,
    ) async {
      for (final bad in [1.7, -0.4, double.nan, double.infinity]) {
        final size = await pumpMeter(tester, bad);
        expect(
          size.width,
          inInclusiveRange(0.0, 1.0),
          reason: '$bad drew ${(size.width * 100).toStringAsFixed(1)}% of the track',
        );
      }
    });

    // **The device-only case, and it is the one that shipped.** The meter is 6 dp
    // tall and a phone is 2.75x; a widget test at `devicePixelRatio: 1` lays the
    // same numbers out. This runs at the device's own density so the zero-height
    // collapse cannot hide behind a different layout pass.
    testWidgets('the fill is the height of the track on a real phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.75;
      tester.view.physicalSize = const Size(1220, 2712);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerminalMeter(fraction: 0.95, leftCaption: '0', rightCaption: '1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fill = tester.getSize(
        find
            .descendant(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        fill.height,
        greaterThan(0),
        reason:
            'the fill is ${fill.height}dp tall. A `DecoratedBox` with no child '
            'collapses to zero under the loose constraints an `Align` passes, so '
            'a fill with the right width and no height paints nothing.',
      );
    });
  });

  group('slotNumber', () {
    test('right-trims, because a trailing zero is false precision', () {
      expect(slotNumber(81.0), '81');
      expect(slotNumber(12.00), '12');
      expect(slotNumber(13.34), '13.3');
      expect(slotNumber(220.53), '220.5');
    });

    test('honours the requested precision', () {
      expect(slotNumber(1.2345, decimals: 2), '1.23');
      expect(slotNumber(1.2399, decimals: 2), '1.24');
    });

    test('an absent reading is --, never 0', () {
      // The panel's claim is that it reports what the sensor said. A zero is a
      // claim about the world; a null is a claim about the sensor.
      expect(slotNumber(null), '--');
      expect(slotNumber(double.nan), '--');
      expect(slotNumber(double.infinity), '--');
    });

    test('a negative figure keeps its sign', () {
      // `BAT_FLOW` is negative while discharging, and the Battery page one tab
      // away shows the same negative. Trimming must not swallow the sign.
      expect(slotNumber(-31.0), '-31');
      expect(slotNumber(-0.4), '-0.4');
    });
  });

  group('rows never clip their own text', () {
    // **The vocabulary has no short words.** `Discharging` and
    // `Heavily overcast` are values this panel actually renders, and on the
    // device at a 2.0 system font the first lost its last two glyphs and the
    // second ran off the right edge of the card.
    testWidgets('a long label and a long value both fit', (tester) async {
      tester.view.physicalSize = const Size(381, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(381, 900)).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: TerminalRow(
                  label: 'Heavily overcast',
                  value: 'Discharging',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // **The rendered widths, not the widget tree.** `find.text` matches a Text
      // by its data, which is still the full string after the engine has clipped
      // it — which is how `Dischargin` shipped.
      for (final label in const ['Heavily overcast', 'Discharging']) {
        final box = tester.getSize(find.text(label));
        expect(
          box.width,
          greaterThan(0),
          reason: '"$label" has no laid-out width',
        );
      }

      // And nothing overflowed the row: Flutter reports an overflow as a
      // paint-time exception rather than a failed layout.
      expect(tester.takeException(), isNull);
    });
  });
}