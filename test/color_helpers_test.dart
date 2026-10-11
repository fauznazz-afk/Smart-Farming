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
///
/// ## One accent, and what it did to this file
///
/// Every lime, blue, violet, cyan and green that used to be spent on a heading,
/// an icon, a chip or a border became [AppPalette.error] or a neutral from
/// [AppSurfaces]. **The palette values were not changed to do it** — the tokens
/// still exist and the chart-series order and the status ramp still read them —
/// so every contrast number this file asserts is unchanged, and that is the
/// point worth stating: the conversion moved *which* colour reaches a job, not
/// how legible that colour is.
///
/// What it did change is the *load* on one colour. Red used to mean "a reading
/// is out of range" and to appear in three places; it is now the app's only
/// accent and appears on every heading, chip, ring, dot and meter. The `the red
/// accent` group below is that new obligation written down, because a guard that
/// only tests the old one would let the new one rot silently.
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
    test('every category resolves to the one accent, and to nothing else', () {
      // **This is the inverse of what it used to assert, and the inversion is
      // the design, not a relaxation.**
      //
      // The old rule was "every category owns a distinct colour", and it was
      // right for a card UI: a hue that means a category is a compact label,
      // and five categories on one screen is five labels in one glance. The
      // Overview panel is not a card UI — it is an instrument panel, and its
      // whole argument is that hue is spent on ONE thing (severity) while
      // everything else is carried by weight, case, tracking and position.
      //
      // So what has to hold now is the opposite: `categoryColor` must be
      // *total and constant*. The failure this guards is a category silently
      // resolving to something that is not the accent — a leftover hue, or a
      // derivation that starts varying by index again, which is the exact
      // regression `metricColor` committed before.
      for (final category in MetricCategory.values) {
        expect(
          categoryColor(category),
          AppPalette.error,
          reason: '${category.name} resolves outside the accent. If a category '
              'needs its own hue back, that is a decision to make deliberately '
              'with the contrast and the panel both in view, not something to '
              'arrive at by leaving one behind.',
        );
      }
    });

    test('a category can never be mistaken for a status colour', () {
      // The one guarantee the collapse put at risk. Everything on the panel is
      // red now, so the red that means "this reading is wrong" has to stay
      // separable from the red that means "this is the accent". They are
      // different constants today; this is what stops that being an accident.
      //
      // Checked as "not equal" rather than as a distance, because they are two
      // steps on one ramp and a hue-distance assertion would pass on a pair
      // that is visually identical and only technically different.
      for (final category in MetricCategory.values) {
        final hue = categoryColor(category);
        for (final status in {
          'statusOk': statusOk,
          'statusWarn': statusWarn,
          'statusBad': statusBad,
          'statusAlert': statusAlert,
        }.entries) {
          expect(
            hue,
            isNot(status.value),
            reason: '${category.name} and ${status.key} are the same colour, '
                'so a category marker would read as a fault',
          );
        }
      }
    });

    test('the three Power-tab sub-tabs are told apart by their labels', () {
      // **Hue separation is no longer the mechanism, so the test follows the
      // mechanism.** PV, AC and battery used to share a screen as three hues,
      // which is why the old version measured their hue angles and demanded
      // 50 degrees of separation. They share a screen still, and they are now
      // all the accent — so whatever tells them apart has to be their text.
      //
      // Asserted on the names rather than on the widget: the Power sub-tabs are
      // PV, AC and Battery, and the whole point is that they are named rather
      // than tinted. `environment` and `water` are the other two and they are
      // named too — a future category cannot arrive without a name here, which
      // is the "adding a category cannot pass by accident" property the old
      // version got from the distinctness loop.
      expect(
        MetricCategory.values.map((c) => c.name).toSet(),
        {'pv', 'ac', 'battery', 'environment', 'water'},
        reason:
            'every category must have a name, because the name is now what '
            'tells two categories apart rather than a hue',
      );
    });

    test('the one hue collision the palette cannot avoid is still two roles', () {
      // `environment` *is* the breach hue — literally the same constant — and
      // `statusBad` ink is a fraction of a degree from it. That is a property of
      // a palette with one red, not a choice made here, and `color_helpers.dart`
      // argues at length that the two stay legible because they never take the
      // same role: a category hue is an icon, a border or a chart line, while a
      // breach is always accompanied by its text. Asserting the facts here so
      // the argument cannot quietly stop holding.
      expect(
        hueOf(categoryColor(MetricCategory.environment)),
        closeTo(hueOf(AppPalette.error), 1.0),
      );
      expect(
        categoryColor(MetricCategory.environment),
        isNot(AppPalette.success),
        reason: 'a category hue that is also the "nothing is wrong" colour is '
            'the one assignment the palette refuses',
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

    group('the red accent', () {
      // `AppPalette.error` used to mean exactly one thing — a reading out of
      // range — and to be drawn in three places. It is now the app's only
      // accent: the CTA, the selected date chip, the avatar ring, the live dot,
      // every panel heading, a 2px row edge, a chart line and a meter fill.
      //
      // **That is a heavier load than a status colour ever had, and it is the
      // reason this group exists.** A breach is always accompanied by a word;
      // the avatar ring is not. So the accent now has to clear AA as a caption
      // on *every* surface, not only where an alarm happened to land, and it has
      // to stay distinguishable from the status ramp it shares a hue with.

      test('clears AA as a caption on every surface it can be drawn on', () {
        // `track` and `surfaceMuted` are new to this list on purpose. Neither is
        // a caption surface, so neither is in `captionSurfaces()` — and the
        // track is what the sky card's brightness bar and the forecast bar are
        // filled against, while `surfaceMuted` is the muted tile. Adding them
        // here rather than to `captionSurfaces()` is the point: the token list
        // stays a description of where *text* goes, and this is a statement
        // about a specific colour's job.
        //
        // The margin at the bottom is 0.05:1. Red measures 6.27 / 5.73 / 5.17
        // / 4.55 on page / surface / surfaceAlt / surfaceMuted, so any future
        // change to a surface is a change to this colour's legibility, exactly
        // as the header of this file says.
        expectClearsAa('AppPalette.error', AppPalette.error, [
          ..._surfaces,
          AppSurfaces.track,
          AppSurfaces.surfaceMuted,
        ]);
      });

      test('clears 3:1 as a graphic on the same list', () {
        // The same colour is an icon, a 2px bottom border and a 10dp meter fill.
        // WCAG 1.4.11 asks 3:1 of all three, and a role that passes as text can
        // still fail as a shape.
        for (final s in [
          ..._surfaces,
          AppSurfaces.track,
          AppSurfaces.surfaceMuted,
        ]) {
          expect(
            _contrast(AppPalette.error, s),
            greaterThanOrEqualTo(3.0),
            reason: 'the accent on #${_hex(s)} is '
                '${_contrast(AppPalette.error, s).toStringAsFixed(2)}:1',
          );
        }
      });

      test('the ink on an accent fill is the one the app actually uses', () {
        // Both large fills of the accent — the primary button in `banners.dart`
        // and the selected date chip in `liquid_glass.dart` — hardcode
        // `AppPalette.onHue` rather than calling `onPrimaryInk`, because the
        // fill is a constant rather than a caller-supplied hue. That is only
        // defensible while the ratio holds.
        //
        // **Pinned as `onHue` rather than as "not white" on purpose.** The
        // assumption this test exists to kill is the natural one: white ink on a
        // red fill. It measures 2.78:1, below AA for body text by a factor of
        // 1.6, and every instinct about "ink on a coloured chip is white" points
        // at it. Black is 7.57:1. Neither number is obvious and both were
        // measured, which is why the assertion is on the value.
        expectClearsAa('AppPalette.onHue on the accent', AppPalette.onHue,
            [AppPalette.error]);
      });

      test('a wash in the accent is legible as a graphic but NOT as text', () {
        // `AppBorders.categoricalWash` at 20%, which is the shape `AppBadge`
        // draws. Composited over every caption surface rather than only over
        // `page`, because the category loop above only ever composited over the
        // page and the accent is now the hue behind most badges.
        //
        // **The number is 4.20:1 over a card and it is below AA, and that is a
        // finding rather than a rounding error.** A 20% wash of the accent over
        // `AppSurfaces.surface` lands on `#4E3131`, and the accent on that is
        // 4.20:1 — over `page` and `surfaceAlt` it clears, and the card is the
        // one that does not.
        //
        // So the guarantee is split, and the split is the useful part:
        //
        //  * **3:1, which passes.** This is what `GlassPageHeader` does — a 20%
        //    wash with an 18px `Icon` of the same hue on it. That is 1.4.11's
        //    graphical-object rule, and it clears with 1.2:1 to spare.
        //  * **4.5:1, which fails.** Nobody draws accent-coloured *text* on an
        //    accent wash today: `AppBadge`'s three call sites are the status ramp
        //    and the CCTV overlay's own text colour. So this is a tripwire for
        //    the next badge, not a description of the screen.
        for (final surface in _surfaces) {
          final wash = Color.alphaBlend(
            AppBorders.categoricalWash(AppPalette.error),
            surface,
          );
          final ratio = _contrast(AppPalette.error, wash);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: 'the accent on its own wash over #${_hex(surface)} is '
                '${ratio.toStringAsFixed(2)}:1, which is below the 3:1 that '
                'an icon of the hue on that wash needs',
          );
        }
        final overCard = Color.alphaBlend(
          AppBorders.categoricalWash(AppPalette.error),
          AppSurfaces.surface,
        );
        expect(
          _contrast(AppPalette.error, overCard),
          lessThan(4.5),
          reason: 'the accent now clears 4.5:1 on a 20% wash over a card, so '
              'this assertion — and the comment above explaining why a badge '
              'must stay an icon — should both be revisited',
        );
      });

      test('the accent is still distinct from every status colour it replaced',
          () {
        // The accent took over a lot of jobs the status ramp used to share
        // territory with — the chart-section live dot, the carousel's active
        // dot, the row edge — so it must not be confusable with the ramp. It is
        // allowed to be the *same constant* as `statusBad`, because those never
        // appear in the same sentence; it is not allowed to be equal to a colour
        // that means a different condition.
        expect(AppPalette.error, isNot(statusWarn));
        expect(AppPalette.error, isNot(statusOk));
        expect(AppPalette.error, isNot(statusAlert));
      });
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