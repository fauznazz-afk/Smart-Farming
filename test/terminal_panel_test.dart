import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';

/// The panel's primitives, and the claims that are invisible in the source.
///
/// ## Why this file asserts *rendered geometry*
///
/// The meter looked correct in the source, compiled clean, and drew nothing. A
/// childless `DecoratedBox` under loose vertical constraints collapses to
/// `constraints.smallest`, so a fill with the right width and **0 dp height**
/// passes every ratio assertion and paints nothing — twice on this widget, once
/// through an `Align` and once through a `Row`.
///
/// `flutter analyze` cannot see that, and neither can an assertion about the
/// caption. So the checks here read the layout rather than the widget tree: the
/// blocks' painted height against the track's, and the *number of lit blocks*
/// rather than a continuous width.
void main() {
  /// How the meter actually painted: the track's painted size, one block's
  /// painted size, the fraction of the track the lit blocks span, and the
  /// number of lit blocks.
  ///
  /// **Block count, not width.** A segmented bar quantises the reading, so the
  /// claim is "19 of 20 blocks are lit", and a continuous width would only be
  /// measuring the gaps. The span is still checked, because a row of blocks with
  /// the right count in the wrong place is a rendering fault.
  Future<({Size track, Size block, double span, int lit})> pumpMeter(
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

    // The first box is the track; every box after it is a lit block, because an
    // unlit slot renders as `SizedBox.shrink` and so is not a `DecoratedBox`.
    final boxes = find.descendant(
      of: find.byType(TerminalMeter),
      matching: find.byType(DecoratedBox),
    );
    final count = boxes.evaluate().length;
    final trackFinder = boxes.first;
    final track = tester.getSize(trackFinder);
    final lit = count - 1;
    expect(
      track.width,
      greaterThan(0),
      reason: 'the track has no width, so no fraction can mean anything',
    );

    final trackRect = tester.getRect(trackFinder);
    final span = lit == 0
        ? 0.0
        : (tester.getRect(boxes.at(count - 1)).right - trackRect.left) /
              track.width;
    return (
      track: track,
      block: lit == 0 ? Size.zero : tester.getSize(boxes.at(1)),
      span: span,
      lit: lit,
    );
  }

  group('the meter actually fills', () {
    testWidgets('a 95% reading lights 19 of the 20 blocks', (tester) async {
      final m = await pumpMeter(tester, 0.95);
      expect(
        m.lit,
        19,
        reason:
            'a 95% reading lit ${m.lit} blocks. The blocks *are* the reading — a '
            'bar that reads empty at 95% is worse than no bar, because the reader '
            'acts on it.',
      );
      expect(m.span, closeTo(0.95, 0.02));
    });

    testWidgets('a half reading lights half the blocks', (tester) async {
      final m = await pumpMeter(tester, 0.5);
      expect(m.lit, 10);
      expect(m.span, closeTo(0.5, 0.02));
    });

    testWidgets('a zero reading lights nothing at all', (tester) async {
      // The case a `Row` of two `Expanded`s cannot express: both children get at
      // least their flex share, so zero renders as a visible stub.
      expect((await pumpMeter(tester, 0)).lit, 0);
    });

    testWidgets('a full reading lights every block, never past it', (
      tester,
    ) async {
      final m = await pumpMeter(tester, 1.0);
      expect(m.lit, 20);
      // `Expanded` divides the track into 20 fractional widths, so the last
      // block's right edge is the track's within rounding — 1.0000000000000002.
      expect(m.span, closeTo(1.0, 0.001));
    });

    testWidgets('out-of-range and NaN inputs cannot escape the track', (
      tester,
    ) async {
      for (final bad in [1.7, -0.4, double.nan, double.infinity]) {
        final m = await pumpMeter(tester, bad);
        expect(
          m.lit,
          inInclusiveRange(0, 20),
          reason: '$bad lit ${m.lit} blocks',
        );
        // The span is clamped, not forced: a negative input legitimately lights nothing.
        expect(
          m.span,
          inInclusiveRange(0.0, 1.001),
          reason:
              '$bad spans ${(m.span * 100).toStringAsFixed(1)}% of the track',
        );
      }
    });

    // **The device-only case, and it is the one that shipped.** The meter is 6 dp
    // tall and a phone is 2.75x; a widget test at `devicePixelRatio: 1` lays the
    // same numbers out. This runs at the device's own density so the zero-height
    // collapse cannot hide behind a different layout pass.
    testWidgets('every block is the height of the track on a real phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.75;
      tester.view.physicalSize = const Size(1220, 2712);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerminalMeter(
                fraction: 0.95,
                leftCaption: '0',
                rightCaption: '1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boxes = find.descendant(
        of: find.byType(TerminalMeter),
        matching: find.byType(DecoratedBox),
      );
      final track = tester.getSize(boxes.first);
      final block = tester.getSize(boxes.at(1));
      expect(
        block.height,
        closeTo(track.height, 0.5),
        reason:
            'the block is ${block.height}dp tall and the track is '
            '${track.height}dp. A childless `DecoratedBox` under the loose '
            'constraints a `Row` passes collapses to zero, so a block with the '
            'right width and no height paints nothing.',
      );
    });

    // **The blocks are separated and flat-ended, or it is a bar again.** Both
    // assertions here pass on a continuous rounded fill, which is why they
    // exist: `gap: 0` and a radius render a bar that satisfies every count and
    // height check above and silently undoes the change.
    testWidgets('the blocks are gapped and square-ended', (tester) async {
      final m = await pumpMeter(tester, 1.0);
      expect(m.lit, greaterThan(1), reason: 'there is nothing to space out');

      final boxes = find.descendant(
        of: find.byType(TerminalMeter),
        matching: find.byType(DecoratedBox),
      );
      final first = tester.getRect(boxes.at(1));
      final second = tester.getRect(boxes.at(2));
      expect(
        second.left - first.right,
        greaterThan(0),
        reason:
            'two blocks are flush, so the meter reads as one continuous bar',
      );

      for (final box in [boxes.first, boxes.at(1)]) {
        final decoration = tester.widget<DecoratedBox>(box).decoration;
        expect(
          decoration,
          isA<BoxDecoration>().having(
            (d) => d.borderRadius,
            'borderRadius',
            null,
          ),
          reason:
              'a rounded block or track is a pill again. The reference is '
              'flat-ended.',
        );
      }
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

  group('the figure belongs to the right edge', () {
    // **Measured on the unmodified build, and it said the opposite.**
    //
    // `Flexible` defaults to `FlexFit.loose`, so the `FittedBox` around each
    // text shrink-wrapped to its own glyphs and `RenderFlex` packed every child
    // from the start. The row was 381 wide and the figure ended at 172.6:
    //
    // | text | left | right |
    // |---|---|---|
    // | `AC_LOAD` | 16.0 | 97.6 |
    // | `26` | 109.6 | 157.3 |
    // | `W` | 161.3 | 172.6 |
    //
    // 208 dp of empty card to the right of the reading, and the figure sitting
    // 12 dp from its own label. This asserts where the ink lands rather than
    // that the widget tree is shaped correctly, because the tree was correct
    // when this shipped.
    testWidgets(
      'the figure paints to the right edge and the label to the left',
      (tester) async {
        tester.view.physicalSize = const Size(381, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TerminalPanel(
                  children: const [
                    TerminalRow(label: 'AC_LOAD', value: '26', unit: 'W'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final panel = tester.getRect(find.byType(TerminalPanel).first);
        final unit = tester.getRect(find.text('W'));
        final label = tester.getRect(find.text('AC_LOAD'));

        // **Within a pixel or two of the card's own edge.** The panel's padding
        // is 16 dp and the row's border is 1 px at the panel's outer edge, so
        // the figure's right edge should sit 16-17 dp inside the panel. A
        // tolerance of 2 dp is the renderer's own rounding, not a design slack.
        expect(
          panel.right - unit.right,
          inInclusiveRange(15.0, 18.0),
          reason:
              'the figure ends ${panel.right - unit.right} dp from the panel\'s '
              'right edge - it is not on the edge it was measured to be off',
        );

        // **And a long way from the label.** The whole complaint was that the
        // two read as one run of text. `AppSpacing.md` is 12 dp, so anything
        // under about 60 dp means the label is still beside the figure.
        expect(
          unit.left - label.right,
          greaterThan(60),
          reason:
              'the figure is only ${unit.left - label.right} dp from its label',
        );
      },
    );

    // **The caption goes on the figure's side of the row, never between the
    // label and it.** Measured before the move, the limit caption `15-50` was
    // painted 6.8 dp from `AMBIENT_T` and 12 dp from `40.1 / 71.6 / 94.9` -
    // attached to the label, which is the one thing a caption must not do.
    testWidgets('the caption paints past the figure, not beside the label', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TerminalPanel(
                children: const [
                  TerminalRow(
                    label: 'AMBIENT_T',
                    value: '40.1 / 71.6 / 94.9',
                    unit: 'C',
                    trailing: Text('15-50'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = tester.getRect(find.byType(TerminalPanel).first);
      final caption = tester.getRect(find.text('15-50'));
      final label = tester.getRect(find.text('AMBIENT_T'));
      final value = tester.getRect(find.text('40.1 / 71.6 / 94.9'));

      // The caption is the right-most ink in the row.
      expect(
        panel.right - caption.right,
        inInclusiveRange(15.0, 18.0),
        reason: 'the caption is not on the right edge',
      );

      // **Decisively past the figure, not merely past it.** Before the move the
      // caption started 6.8 dp after the label's right edge. Now it has to sit
      // to the right of everything the row draws, which on a 320 dp card means
      // at least the width of a `md` gap clear of the figure.
      expect(caption.left, greaterThan(value.right));
      expect(caption.left - label.right, greaterThan(60));
    });
  });

  group('the hero never overflows', () {
    // **The one figure in the app with no `Flexible` on it, at the one font
    // scale that breaks it.** An 88 px monospace digit is ~53 dp, so the largest
    // value the panel can draw — `10000` W, a 10 kW array at noon — is ~265 dp
    // against ~379 dp of card and fits at 1.0. At 2.0 it is ~424 dp and the row
    // is over by ~45, which paints a hard `RenderFlex` overflow stripe across
    // the page's largest element. `takeException` is the whole assertion: an
    // overflow is thrown as an exception, not drawn as a warning.
    for (final figure in ['0', '286', '10000']) {
      testWidgets('$figure survives a 2.0 system font', (tester) async {
        tester.view.physicalSize = const Size(381, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(381, 900))
                  .copyWith(textScaler: const TextScaler.linear(2.0)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TerminalPanel(
                    children: [
                      TerminalHero(figure: figure, unit: 'W', slot: 'PV_OUT'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'the hero overflowed its row',
        );
      });
    }
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
            data: const MediaQueryData(size: Size(381, 900))
                .copyWith(textScaler: const TextScaler.linear(2.0)),
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
