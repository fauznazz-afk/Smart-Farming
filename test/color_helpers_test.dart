import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// The surfaces these colours are actually rendered on.
///
/// **Derived, not written down.** This list used to be six hand-written hex
/// values in this file. They were copied in when the glass fills were replaced,
/// the fills changed again without touching the test, and because the stale
/// values happened to be *lighter* than the real ones the test measured against
/// a more forgiving surface than the one rendering: three captions sat below AA
/// with the suite green. It survived two commits. A literal in a test whose job
/// is to describe the app's own tokens is a copy, and copies drift.
///
/// It was once a pair — a light list and a dark list — because there were two
/// brightnesses to cover. There is one now, so there is one list, read straight
/// out of `AppSurfaces.captionSurfaces()`.
final List<Color> _surfaces = AppSurfaces.captionSurfaces();

/// The five colours every caption and status reading in the app is drawn in.
///
/// They are `const` today rather than functions of a `bool isDark`, so this list
/// is a plain list of constants and the "does Dracula reuse the dark palette?"
/// question below has become the stronger claim: there is only one palette.
List<Color> _captionPalette() => [
      faintColor,
      statusOk,
      statusWarn,
      statusBad,
      statusAlert,
    ];

/// The fill `AppTile` actually paints, read out of the widget rather than
/// written down here.
///
/// A widget test rather than a constant, deliberately: `AppTile` builds a plain
/// `Container` with no key, so the only honest way to read the fill is to render
/// one and inspect the tree. `find.byType(Container)` would also match containers
/// the tile does not own, so this takes the *first* — which is the tile itself,
/// because nothing inside it can precede it.
Future<BoxDecoration> _tileDecoration(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: AppTile(child: SizedBox.shrink())),
  );
  return tester
      .widgetList<Container>(find.byType(Container))
      .first
      .decoration! as BoxDecoration;
}

/// The progress track (`AppSurfaces.track`) is the **same value** as
/// [AppSurfaces.surfaceAlt], and that is deliberate rather than an accident of
/// the ramp: a track is a 6 to 8dp bar, but nothing else in the app needs a
/// fourth step, so the two share one. `design_tokens_test.dart` asserts the
/// identity (`contains(AppSurfaces.track)`), and the tile that draws text is
/// `surfaceAlt` — which is why `surfaceAlt` is the last entry of
/// [AppSurfaces.captionSurfaces], and why the tile is measured against it.
///
/// A test used to live here asserting the tile fill was *not* the track. It was
/// written for the previous system, in which the track was a lighter step than
/// the tile and no text sat on it, and its numbers (captions at 4.31:1 to
/// 4.39:1 on it) describe that value, not this one. Under the current tokens the
/// assertion could only be satisfied by putting the tile in the card's own fill,
/// which is what it was "fixed" to do — and which made every metric tile in the
/// app invisible against the card behind it, with the suite green. That is the
/// third guard in this repo that encoded a relationship which was itself the
/// thing that had gone stale, so it is recorded here rather than deleted
/// quietly.
void main() {
  /// `HSLColor.hue` is already in degrees, not 0..1, which is worth stating
  /// because getting that wrong scales every tolerance here by 360 and makes a
  /// correct implementation look wrong.
  double hueOf(Color c) => HSLColor.fromColor(c).hue;

  group('the categorical vocabulary', () {
    test('every category owns a distinct colour', () {
      // A category mapped to exactly the same colour as another one is the
      // failure this whole system exists to prevent: two pages, two meanings,
      // one colour. Checked as distinctness rather than as a list of expected
      // hexes, so adding a category cannot pass by accident.
      final byColor = <int, List<String>>{};
      for (final category in MetricCategory.values) {
        byColor
            .putIfAbsent(categoryColor(category).toARGB32(), () => [])
            .add(category.name);
      }
      for (final entry in byColor.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason: '#${_hex(Color(entry.key))} is claimed by '
              '${entry.value.join(" and ")}',
        );
      }
    });

    test('the three Power-tab sub-tabs are far enough apart to tell apart', () {
      // PV, AC and battery are the only three category hues that share a
      // screen, so this is the only place separation is load-bearing. Butter
      // yellow was chosen for solar partly for this: it is the widest
      // separation the palette offers. Asserted as the floor the doc names
      // rather than as the exact angles, so quantisation cannot make it flaky.
      final angles = <String, double>{
        'battery': hueOf(categoryColor(MetricCategory.battery)),
        'ac': hueOf(categoryColor(MetricCategory.ac)),
        'pv': hueOf(categoryColor(MetricCategory.pv)),
      };
      expect((angles['ac']! - angles['pv']!).abs(),
          greaterThan(50.0), reason: 'AC and PV');
      expect((angles['ac']! - angles['battery']!).abs(),
          greaterThan(50.0), reason: 'AC and battery');
    });

    test('the one hue collision the palette cannot avoid is still two roles', () {
      // `primary` and `error` are both 0.0 degrees and `chartCoral` is 6.2 away,
      // so battery and water sit in the same hue family as the breach colour.
      // `color_helpers.dart` argues at length that this is legible because the
      // two never take the same role: a category hue is a fill, `error` is ink.
      // Asserting the facts here so the argument cannot quietly stop holding.
      expect(hueOf(categoryColor(MetricCategory.battery)),
          closeTo(hueOf(AppPalette.error), 1.0));
      expect(
        (hueOf(categoryColor(MetricCategory.water)) -
                hueOf(AppPalette.error))
            .abs(),
        lessThan(10.0),
        reason: 'this is the documented collision; a reassignment that breaks it '
            'should make this test fail so the doc note gets rewritten',
      );
      // And `success` is still refused as a category hue.
      expect(
        MetricCategory.values.map(categoryColor),
        isNot(contains(AppPalette.success)),
      );
    });

    test('a category returns the same colour every time it is asked', () {
      // The old rule was the opposite shape: `metricColor` took an `index` and
      // deliberately ignored it, so that one accent meant one colour. That guard
      // is gone with the function; what replaces it is that a category has no
      // parameter to vary at all.
      for (final category in MetricCategory.values) {
        expect(categoryColor(category), categoryColor(category));
      }
    });

    test('forKey resolves every key it accepts, and null for anything else', () {
      // `MetricCategory.forKey` is the single place a telemetry key becomes a
      // category, and it is built from `keys` rather than from a second written
      // list — two lists of the same strings is the shape that produced the
      // stale-surface bug this file has already paid for. So the check that
      // matters is that the two agree, key by key.
      for (final category in MetricCategory.values) {
        for (final key in category.keys) {
          expect(MetricCategory.forKey(key), category, reason: key);
          expect(categoryColorForKey(key), categoryColor(category),
              reason: key);
        }
      }
    });

    test('no key belongs to two categories', () {
      // Two categories claiming one key means one reading rendered in two
      // colours on two pages. `forKey` returns the *first* match, so the second
      // category would render in a hue the lookup never returns.
      final seen = <String, MetricCategory>{};
      for (final category in MetricCategory.values) {
        for (final key in category.keys) {
          expect(
            seen.putIfAbsent(key, () => category),
            category,
            reason: '$key is claimed by both ${seen[key]?.name} and '
                '${category.name}',
          );
        }
      }
    });

    test('a key that is not a reading resolves to no hue at all', () {
      // A derived value like a forecast has no category. It must come back null
      // so the caller falls back to ordinary text — resolving it to *some* hue
      // would put a value on screen in a colour that claims to mean a sensor.
      for (final key in const ['forecast', 'not_a_sensor', '']) {
        expect(MetricCategory.forKey(key), isNull, reason: key);
        expect(categoryColorForKey(key), isNull, reason: key);
      }
    });
  });

  group('WCAG AA contrast', () {
    // Everything below is used as text between 9 and 15dp, which WCAG counts as
    // normal text, so the requirement is 4.5:1 rather than the 3:1 that large
    // text would get.
    const aa = 4.5;

    void expectClearsAa(String name, Color color, List<Color> surfaces) {
      final ratios = surfaces.map((s) => _contrast(color, s)).toList();
      final worst = ratios.reduce(math.min);
      final worstSurface = surfaces[ratios.indexOf(worst)];
      expect(
        worst,
        greaterThanOrEqualTo(aa),
        reason: '$name measures ${worst.toStringAsFixed(2)}:1 on its worst '
            'surface #${_hex(worstSurface)} '
            '(${surfaces.map((s) => _contrast(color, s).toStringAsFixed(2)).join('/')})',
      );
    }

    test('faintColor, the units and captions', () {
      expectClearsAa('faintColor', faintColor, _surfaces);
    });

    test('status colours, used for out-of-range readings', () {
      expectClearsAa('statusOk', statusOk, _surfaces);
      expectClearsAa('statusWarn', statusWarn, _surfaces);
      expectClearsAa('statusBad', statusBad, _surfaces);
      expectClearsAa('statusAlert', statusAlert, _surfaces);
    });

    test('every caption colour clears AA on every caption surface', () {
      // The five individual assertions above are the ones that print a readable
      // name on failure. This one is the loop that cannot be forgotten when a
      // sixth caption colour is added — a hand-written list is exactly the copy
      // that went stale three times in this file.
      final names = [
        'faintColor',
        'statusOk',
        'statusWarn',
        'statusBad',
        'statusAlert',
      ];
      for (var i = 0; i < names.length; i++) {
        expectClearsAa(names[i], _captionPalette()[i], _surfaces);
      }
    });

    test('every category hue clears AA as a caption too', () {
      // A category hue is not only a figure: it is a chart line, a nav label and
      // a badge foreground, and the badge puts it on a 10%-alpha wash of itself.
      // The bare hue is the strictest of those cases, so it is the one measured.
      for (final category in MetricCategory.values) {
        expectClearsAa(
          '${category.name} hue',
          categoryColor(category),
          _surfaces,
        );
      }
    });

    test('a badge wash leaves its own foreground readable', () {
      // `AppBorders.categoricalWash` is 10% of the hue composited over the page,
      // which is the one surface in the app that is not in `captionSurfaces` —
      // it is derived from a hue, so it cannot be listed there. Composited here
      // from the token rather than written down, for the same reason.
      for (final category in MetricCategory.values) {
        final hue = categoryColor(category);
        final wash = Color.alphaBlend(AppBorders.categoricalWash(hue), AppSurfaces.page);
        expectClearsAa('${category.name} on its own wash', hue, [wash]);
      }
    });

    testWidgets('AppTile draws text, so its own fill is a text surface', (tester) async {
      // The regression this guards: the tile fill used to be the same token as
      // the 6–8dp progress bars, and the track was excluded from the surface
      // lists above because nothing draws on a bar. That exclusion was written
      // for one consumer and applied to two.
      //
      // It is still the same token as the track today, and it is still a
      // caption surface -- `design_tokens_test.dart` asserts the identity and
      // that the list covers it. What this pins is the consequence: the five
      // caption colours have to clear AA on the fill the tile *actually*
      // paints, which is the lightest surface in the app and therefore the
      // worst case for every one of them.
      final fill = (await _tileDecoration(tester)).color!;
      for (final entry in {
        'faintColor': faintColor,
        'statusOk': statusOk,
        'statusWarn': statusWarn,
        'statusBad': statusBad,
        'statusAlert': statusAlert,
      }.entries) {
        expectClearsAa('${entry.key} on the tile fill', entry.value, [fill]);
      }
    });

    // A test used to sit here: "the tile fill is not the progress-bar track".
    // It was a leftover from the previous system, where the track was a lighter
    // step than the tile and carried no text. Under these tokens
    // `AppSurfaces.track` *is* [AppSurfaces.surfaceAlt] and the tile is meant to
    // be `surfaceAlt` too, so the only way to satisfy it was to draw the tile in
    // the card's own fill -- which is how every metric tile in the app ended up
    // invisible against the card behind it, on a build where this file's other
    // tests were green. `design_tokens_test.dart` asserts the identity it
    // contradicted. See the header of this file.

    test('the surfaces this file measures against are the ones the app paints',
        () {
      // The guard against the drift that actually bit. It cannot be written as
      // a comparison against a literal — a literal here is the same copy that
      // went stale — so what is asserted is the *property* that made the old
      // list wrong: the binding surface is the deepest tonal step, because that
      // is the hardest one, and a caption has to clear AA on all of them.
      expect(
        AppSurfaces.captionSurfaces().last,
        AppSurfaces.bindingCaptionSurface,
        reason: 'the deepest step is the binding one and it has to be in the '
            'list, or the tests above quietly stop testing it',
      );
      expect(
        _surfaces,
        [AppSurfaces.page, AppSurfaces.surface, AppSurfaces.surfaceAlt],
        reason: 'a copy of this list in the test would drift again; read it '
            'out of AppSurfaces instead',
      );
    });

    test('the status colours stay distinguishable from each other', () {
      // Clearing the contrast bar is not enough if "ok" and "bad" are the same
      // green as each other.
      expect(statusOk, isNot(statusBad));
      expect(statusWarn, isNot(statusBad));
      expect(statusAlert, isNot(statusWarn));
    });

    test('a healthy reading does not take a status colour', () {
      // `statusOk` is `AppPalette.success`, a green. The rule in this app is
      // that green means "a problem is absent" and a healthy reading takes the
      // accent and ordinary text instead, so `statusOk` is for alarm *history*
      // rather than for a live value. Pinned because the two are the same hex
      // and only the call sites tell them apart.
      expect(statusOk, AppPalette.success);
      expect(
        categoryColor(MetricCategory.environment),
        isNot(AppPalette.success),
        reason: 'a category hue that is the success green would put a second '
            'green palette on screen next to a status colour',
      );
    });
  });
}

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();