/// The WCAG 1.4.11 check for `EnergySummaryCard`'s two metric icons.
///
/// **Why this file exists.** Those icons were derived with a bare
/// `themeColor(lightness: 0.52, saturation: 0.5)`, a value chosen when there were
/// two brightnesses and checked on those two. Adding a third theme applied it to
/// a surface it had never been measured against, and on Dracula's preset purple
/// it produces `#7A47C2` at **1.97:1** — the AC usage icon was effectively
/// invisible. The old code's own comment predicted this ("would need measuring
/// before Dracula is a supported appearance") and the prediction was correct.
///
/// It is the third instance of the same shape in this repo: a colour rule
/// written for one set of conditions and extended to a new one without a
/// measurement. The other two were the `AppTile` contrast exclusion and the
/// `themeColor` lightness that cannot serve two hues.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/energy_summary_card.dart';

double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

void main() {
  const oceanCyan = Color(0xFF2AA7A1);

  /// The two icon colours **as the card actually paints them**.
  ///
  /// Read out of the rendered widget tree rather than re-derived here, and that
  /// is the whole point of the file.
  ///
  /// The first version called `metricColor` and `strongMetricColor` itself and
  /// compared the results. Mutation-checked, it **passed with
  /// `energy_summary_card.dart` reverted to the broken derivation** — it was
  /// asserting on its own copy of the rule while the card did something else
  /// entirely. A guard that cannot fail is worse than no guard, because it
  /// reports confidence it has not earned. This reads the painted tree instead,
  /// so changing the card changes what is measured.
  Future<List<Color>> painted(WidgetTester tester, AppTheme theme) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnergySummaryCard(
            theme: theme,
            seedColor: theme == AppTheme.dracula ? draculaAccent : oceanCyan,
            weekly: false,
            loading: false,
            hasData: true,
            errorMessage: null,
            solarKwh: 4.2,
            previousSolarKwh: 3.5,
            loadKwh: 1.0,
            previousLoadKwh: 2.5,
            onRangeChanged: (_) {},
            onOpenReport: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widgetList<Icon>(find.byType(Icon))
        .where((i) => i.size == 18)
        .map((i) => i.color ?? Colors.black)
        .toList();
  }

  group('EnergySummaryCard metric icons, read from the painted card', () {
    testWidgets('clear WCAG 1.4.11 3:1 on dark and on Dracula', (tester) async {
      // 1.4.11 is non-text contrast: 3:1 for a graphical object. These are 18dp
      // glyphs, not lettering, so the 4.5:1 `faintColor` is held to does not
      // apply here and demanding it would be a different, wrong test.
      for (final theme in [AppTheme.dark, AppTheme.dracula]) {
        final colours = await painted(tester, theme);
        expect(colours.length, 2, reason: 'expected the PV and AC icons');

        for (final entry in {0: 'PV', 1: 'AC'}.entries) {
          final worst = [
            _contrast(colours[entry.key], AppSurfaces.card(theme)),
            _contrast(colours[entry.key], AppSurfaces.input(theme)),
          ].reduce(math.min);

          expect(
            worst,
            greaterThanOrEqualTo(3.0),
            reason: '$theme ${entry.value} icon #${_hex(colours[entry.key])} is '
                '$worst:1 on its worst surface; the old fixed HSL step measured '
                '1.97:1 on Dracula and the icon was invisible',
          );
        }
      }
    });

    testWidgets('stay two different colours, labelling two quantities', (tester) async {
      // `metricColor` takes an `index` and deliberately ignores it -- a
      // documented rule in this repo, and `color_helpers_test.dart` fails if it
      // ever starts honouring it. So the first attempt at fixing the contrast,
      // routing both icons through `metricColor`, collapsed the two tiles onto
      // one value and lost the distinction. That was caught by the widget's own
      // existing test; this is the guard that keeps it caught.
      for (final theme in AppTheme.values) {
        final colours = await painted(tester, theme);
        expect(
          colours.first,
          isNot(colours.last),
          reason: '$theme paints both metric icons as #${_hex(colours.first)}; '
              'they label different quantities',
        );
      }
    });

    testWidgets('keep their hue, so they still read as the user\'s accent', (tester) async {
      // The distinction above must not be bought with an unrelated colour.
      for (final theme in AppTheme.values) {
        final seed = theme == AppTheme.dracula ? draculaAccent : oceanCyan;
        final seedHue = HSLColor.fromColor(seed).hue;
        for (final c in await painted(tester, theme)) {
          expect(
            (HSLColor.fromColor(c).hue - seedHue).abs(),
            lessThan(6.0),
            reason: '#${_hex(c)} on $theme has drifted from its seed hue',
          );
        }
      }
    });

    testWidgets('light mode clears 3:1 too, which it did not for a long time', (tester) async {
      // **This was a recorded shortfall and now is not.** The icon measured
      // 2.16:1 here, against 2.17:1 before the Dracula work -- the same to within
      // a hundredth -- and this test used to assert a floor at 2.1 plus a
      // reminder to retire itself once light mode was fixed.
      //
      // It is fixed, by `metricGraphic`, which is the point of that function: 3:1
      // is what 1.4.11 asks of a graphical object and 4.5:1 is what it asks of
      // text, `metricColor` was built for the second, and the fix belongs on the
      // graphical uses rather than on every metric value in the app.
      //
      // The earlier draft of this file also claimed 2.78:1 with a 2.7 floor, which
      // was a number measured against *Dracula's* cyan rather than the Ocean cyan
      // the user actually selects. The assertion is what caught that, and it is
      // why the value is read off the painted card rather than computed here.
      final colours = await painted(tester, AppTheme.light);
      for (final entry in {0: 'PV', 1: 'AC'}.entries) {
        final measured = _contrast(
          colours[entry.key],
          AppSurfaces.card(AppTheme.light),
        );
        expect(
          measured,
          greaterThanOrEqualTo(3.0),
          reason: 'light-mode ${entry.value} icon #${_hex(colours[entry.key])} '
              'fell to $measured:1; it was 2.17:1 before any of this work',
        );
      }
    });
  });
}