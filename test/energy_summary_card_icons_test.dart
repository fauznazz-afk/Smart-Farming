/// The WCAG 1.4.11 check for `EnergySummaryCard`'s two category colours.
///
/// **Why this file exists.** Those two colours were once derived from a bare
/// `themeColor(lightness: 0.52, saturation: 0.5)`, a value chosen when there were
/// two brightnesses and checked on those two. Adding a third appearance applied
/// it to a surface it had never been measured against, and on Dracula's preset
/// purple it produced `#7A47C2` at **1.97:1** — the AC usage figure was
/// effectively invisible. The old code's own comment predicted this ("would
/// need measuring before Dracula is a supported appearance") and the prediction
/// was correct.
///
/// It is the third instance of the same shape in this repo: a colour rule
/// written for one set of conditions and extended to a new one without a
/// measurement.
///
/// **What survived the migration.** There is one appearance now and the hue is
/// no longer derived from a seed at all — each tile reads its own category's
/// fixed hue, so the class of bug above cannot recur. What is left worth
/// guarding is the two properties the old file cared about: the two tiles are
/// *different* colours, and both clear 3:1 against the surface they are
/// actually painted on.
///
/// The hue is read off the tile's **icon**, because that is where the card puts
/// it. The figure text itself is drawn in ordinary ink, so a version of this
/// file that read the figures' text colour would assert that two labels are the
/// same grey and pass while both tiles were painted the same hue.
///
/// The value is read out of the **painted widget tree**, not re-derived here.
/// The first version of this file called `metricColor` itself and compared the
/// results; mutation-checked, it **passed with the card reverted to the broken
/// derivation** — it was asserting on its own copy of the rule while the card
/// did something else. A guard that cannot fail reports confidence it has not
/// earned.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/widgets/energy_summary_card.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
///
/// The same arithmetic `color_helpers_test.dart` uses, kept local rather than
/// imported so this file has no dependency on another test's internals. What it
/// must never become is a hardcoded ratio: the point of the assertion is that
/// the check is *recomputed*, so a token that moves is caught by a new number
/// rather than accepted by an old one.
double _contrast(Color a, Color b) {
  final x = _luminance(a), y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

/// The `BoxDecoration` `AppTile` built for tile [index].
///
/// `AppTile` renders a bare `Container` with no key, so the first `Container`
/// descending from it *is* the tile — nothing inside a tile can precede it.
BoxDecoration _tileDecoration(WidgetTester tester, int index) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(AppTile).at(index),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

/// The surface each icon is painted on, read out of the rendered tile.
///
/// **Not written down.** `AppTile`'s fill is a step on the app's tonal ramp, and
/// the two tiles sit inside the card, which sits inside the page — so
/// `AppSurfaces.surfaceAlt` is the right token today and would be the wrong one
/// the day somebody nests a tile somewhere deeper. Reading it off the
/// `BoxDecoration` the tile actually built is the only version of this that
/// cannot drift; see the header of `color_helpers_test.dart` for what a
/// hand-written surface list cost this repo twice.
Color _tileFill(WidgetTester tester, int index) =>
    _tileDecoration(tester, index).color!;

void main() {
  /// The two figure colours, as the card actually paints them.
  Future<List<Color>> painted(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnergySummaryCard(
            weekly: false,
            loading: false,
            hasData: true,
            errorMessage: null,
            solarKwh: 12.4,
            previousSolarKwh: 10,
            loadKwh: 8.7,
            previousLoadKwh: 9,
            onRangeChanged: _noop,
            onOpenReport: _noopVoid,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The category hue is on the tile's **icon**, not on its figure text: the
    // figure is drawn in ordinary ink and the tile's frame carries the hue. So
    // this is read off the two icons by icon type, which is unambiguous — the
    // previous version of this file read "every coloured Text in the tree" and
    // got a list whose length depended on how many captions happened to be
    // tinted that day.
    Color iconColour(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color!;
    return [
      iconColour(Icons.wb_sunny_outlined),
      iconColour(Icons.electrical_services_outlined),
    ];
  }

  group('EnergySummaryCard category colours, read from the painted card', () {
    testWidgets('clear WCAG 1.4.11 3:1 on the fill they are painted on', (
      tester,
    ) async {
      // 1.4.11 is non-text contrast: 3:1 for a graphical object. These are
      // icons on a tile, not body text, so the 4.5:1 floor that `faintColor` is
      // held to does not apply here and demanding it would be a different,
      // wrong test. `color_helpers_test.dart` holds the *same* hues to the
      // stricter 4.5:1 as captions, so this is the floor and not the claim.
      //
      // Measured against the tile's own fill rather than against a list of
      // surfaces: the icon is never painted on anything else, and a measurement
      // against `page` would pass no matter how dark the tile got.
      final colours = await painted(tester);

      for (final entry in {0: 'PV', 1: 'AC'}.entries) {
        final fill = _tileFill(tester, entry.key);
        final measured = _contrast(colours[entry.key], fill);
        expect(
          measured,
          greaterThanOrEqualTo(3.0),
          reason:
              'the ${entry.value} icon #${_hex(colours[entry.key])} is '
              '$measured:1 on its own tile fill #${_hex(fill)}; the old fixed '
              'HSL step measured 1.97:1 on Dracula and the icon was invisible',
        );
      }
    });

    testWidgets('stay two different colours, labelling two quantities', (
      tester,
    ) async {
      // The hue rule in this repo is fixed per category and deliberately does
      // not vary by index — `color_helpers_test.dart` fails if `categoryColor`
      // ever starts deriving from one. So the two tiles can only collapse onto
      // one value if both categories are mapped to the same hue, which is
      // exactly the regression this is here for. This is the shape of bug the
      // old `metricColor`-based version missed by asserting on its own copy of
      // the rule.
      final colours = await painted(tester);
      expect(
        colours.first,
        isNot(colours.last),
        reason:
            'the card paints both tiles in #${_hex(colours.first)}; '
            'they label different quantities',
      );
    });

    testWidgets('are the two category hues, not something derived per render', (
      tester,
    ) async {
      // Each category owns a fixed hue, reused everywhere that category
      // appears. If either tile were re-derived at paint time it would drift
      // from the one shown on the dashboard, and the two screens would stop
      // agreeing about what "PV" looks like.
      final colours = await painted(tester);
      expect(colours, [
        categoryColor(MetricCategory.pv),
        categoryColor(MetricCategory.ac),
      ]);
    });

    testWidgets('each tile bottom border carries its own category', (
      tester,
    ) async {
      // The same claim as above, on the second surface the hue appears on.
      //
      // **The edge is a 2px BOTTOM border at full strength, and it used to be a
      // 1px frame on all four sides at 20% alpha.** The old value was the tint
      // chip recipe applied to a stat tile; the brief's stat tile colour-codes
      // itself with `border-b-2` in the category hue. Full strength, because a
      // 2px line is a shape rather than text — WCAG's 3:1 for a non-text
      // boundary is what it is measured against, and 20% of the hue is nowhere
      // near it. Reading `.top` here now returns transparent, which is exactly
      // how this test caught the change.
      await painted(tester);
      final borders = <Color>[];
      for (var i = 0; i < 2; i++) {
        borders.add(
          (_tileDecoration(tester, i).border! as Border).bottom.color,
        );
      }
      expect(
        borders,
        [categoryColor(MetricCategory.pv), categoryColor(MetricCategory.ac)],
        reason:
            'the tile bottom borders are #${borders.map(_hex).join(' and ')}; '
            'an edge in the wrong category is a card claiming data it does not '
            'contain',
      );

      // And it is the bottom edge only: a frame on all four sides at low alpha
      // was the component this replaced, and the brief's stat tile has one
      // coloured edge and three clean ones. `BorderSide.none` keeps an opaque
      // black *colour* with width 0 and `BorderStyle.none`, so the honest
      // assertion is that the other three edges are not drawn — not that they
      // are transparent, which they are not.
      for (var i = 0; i < 2; i++) {
        final border = _tileDecoration(tester, i).border! as Border;
        for (final side in [border.top, border.left, border.right]) {
          expect(
            side.style,
            BorderStyle.none,
            reason:
                'the tile still draws a frame; the brief gives it one '
                'coloured bottom edge',
          );
          expect(side.width, 0);
        }
      }
    });
  });
}

void _noop(bool _) {}

void _noopVoid() {}
