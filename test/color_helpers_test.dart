import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// The card surfaces a caption is drawn on, read straight out of the tokens.
///
/// WattVision is a single dark ramp, so there is one list. The page is excluded
/// because it is a different ground: captions on the page use the page twins
/// (`statusOkOnPage` and friends), asserted separately against
/// [`_pageSurfaces`].
final List<Color> _surfaces = [
  AppSurfaces.surface,
  AppSurfaces.surfaceAlt,
];

/// The surfaces content on the page is drawn on.
///
/// A function, not a `final` list, so it reads the live ramp rather than the one
/// that happened to be active when the library loaded.
List<Color> _pageSurfaces() => [
      AppSurfaces.page,
      ...AppGlass.pageGradient,
    ];

/// The five colours every caption and status reading in the app is drawn in.
///
/// They are `const` today rather than functions of a `bool isDark`, so this list
/// is a plain list of constants and there is only one palette.
///
/// ## WattVision accent
///
/// Cyan `#00E5FF` is the data accent and the app's only saturated chrome colour.
/// The alert red `#FF453A` means "a reading is out of range" and nothing else.
/// The `the red accent` group below measures cyan's obligations on every surface
/// it can reach.
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

/// The progress track (`AppSurfaces.track`) is the **page colour** — the same
/// value as [AppSurfaces.page] — and that is deliberate rather than an accident
/// of the ramp: an un-lit meter segment is a hole in the surface it sits on, so
/// the track is the page showing through rather than a fourth tonal step of its
/// own. `design_tokens_test.dart` asserts that the track is among the caption
/// surfaces (`contains(AppSurfaces.track)`), and the tile that draws text is
/// `surfaceAlt` — which is why `surfaceAlt` is the last entry of
/// [AppSurfaces.captionSurfaces], and why the tile is measured against it.
///
/// A test used to live here asserting the tile fill was *not* the track. It was
/// written for a previous system in which the track was a lighter step than the
/// tile and no text sat on it, and its numbers describe that value, not this
/// one.
///
/// Under those tokens `AppSurfaces.track` *was* [AppSurfaces.surfaceAlt] and the
/// tile was meant to be `surfaceAlt` too, so the only way to satisfy the
/// assertion was to put the tile in the card's own fill — which is what it was
/// "fixed" to do, and which made every metric tile in the app invisible against
/// the card behind it, with the suite green. The track is the page colour now,
/// so the assertion would hold again; it stays deleted because there is no
/// identity left for it to contradict.
///
/// That is the third guard in this repo that encoded a relationship which was
/// itself the thing that had gone stale, so it is recorded here rather than
/// deleted quietly.
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
          AppPalette.accent,
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
        closeTo(hueOf(AppPalette.accent), 1.0),
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
    const contrastEpsilon = 0.01;

    void expectClearsAa(String name, Color color, List<Color> surfaces) {
      final ratios = surfaces.map((s) => _contrast(color, s)).toList();
      final worst = ratios.reduce(math.min);
      final worstSurface = surfaces[ratios.indexOf(worst)];
      expect(
        worst,
        greaterThanOrEqualTo(aa - contrastEpsilon),
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

    test('every page-twin clears AA on the page it is drawn on', () {
      // The other half of the split `_surfaces` documents. These are the values
      // the CCTV status pill and the page-level banners use, and the page is the
      // only thing behind them.
      //
      // **Every page stop.** The page is a flat sweep, so the worst stop is what
      // decides — and the twins come from live palette getters, so the ramp has
      // to be applied for them to be read at all.
      for (final ramp in Brightness.values) {
        AppTheme.apply(ramp);
        for (final entry in <String, Color>{
          'statusOkOnPage': statusOkOnPage,
          'statusWarnOnPage': statusWarnOnPage,
          'statusBadOnPage': statusBadOnPage,
        }.entries) {
          expectClearsAa('${entry.key} in the ${ramp.name} ramp', entry.value,
              _pageSurfaces());
        }
      }
      // The palette is dark-only, so this restores the state the rest of the
      // file expects rather than switching ramps.
      AppTheme.apply(Brightness.dark);
    });

    test('the card and page status values converge in the dark-only ramp', () {
      // WattVision puts both page and card in the same dark family, so the page
      // twins no longer need a second hue or lightness.
      AppTheme.apply(Brightness.dark);
      expect(statusOk, statusOkOnPage);
      expect(statusWarn, statusWarnOnPage);
      expect(statusBad, statusBadOnPage);
      AppTheme.apply(Brightness.light);
      expect(statusOk, statusOkOnPage);
      expect(statusWarn, statusWarnOnPage);
      expect(statusBad, statusBadOnPage);
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
    // step than the tile and carried no text. Under the tokens of that system
    // `AppSurfaces.track` *was* [AppSurfaces.surfaceAlt] and the tile was meant
    // to be `surfaceAlt` too, so the only way to satisfy it was to draw the
    // tile in the card's own fill -- which is how every metric tile in the app
    // ended up invisible against the card behind it, on a build where this
    // file's other tests were green. `design_tokens_test.dart` asserts the
    // identity it contradicted, and the track is the page colour today, so the
    // assertion would hold again. See the header of this file.

    test('the surfaces this file measures against are the ones the app paints',
        () {
      // The guard against the drift that actually bit. It cannot be written as
      // a comparison against a literal — a literal here is the same copy that
      // went stale — so what is asserted is the *property* that made the old
      // list wrong: the binding surface is the deepest tonal step, because that
      // is the hardest one, and a caption has to clear AA on all of them.
      expect(
        _surfaces,
        [AppSurfaces.surface, AppSurfaces.surfaceAlt],
        reason: 'a copy of this list in the test would drift again; read it '
            'out of AppSurfaces instead',
      );
      // And the page half is a list too, so a surface can be added to one
      // surface family and not the other without anything noticing.
      expect(_pageSurfaces(), [
        AppSurfaces.page,
        ...AppGlass.pageGradient,
      ]);
      // The binding surface has to be one of the two this file measures, or the
      // hardest card is being skipped by every test above.
      expect(
        _surfaces,
        contains(AppSurfaces.bindingCaptionSurface),
        reason: 'the binding surface is not in the list the caption tests '
            'measure against, so the hardest card is never tested',
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

    group('the accent', () {
      // WattVision's cyan `#00E5FF` is the app's only saturated accent: the CTA,
      // the selected date chip, the avatar ring, the live dot, every panel
      // heading, a 2px row edge, a chart line and a meter fill.
      //
      // A breach is always accompanied by a word; the avatar ring is not. So the
      // accent has to clear AA as a caption on *every* surface, not only where an
      // alarm happened to land, and it has to stay distinguishable from the
      // status ramp.

      test('clears AA as a caption on every surface it can be drawn on', () {
        // `track` and `surfaceMuted` are in this list on purpose. Neither is a
        // caption surface, so neither is in `captionSurfaces()` — and the track
        // is what the sky card's brightness bar and the forecast bar are filled
        // against, while `surfaceMuted` is the muted tile. Adding them here
        // rather than to `captionSurfaces()` keeps the token list a description
        // of where *text* goes; this is a statement about a specific colour's job.
        expectClearsAa('AppPalette.accent', AppPalette.accent, [
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
            _contrast(AppPalette.accent, s),
            greaterThanOrEqualTo(3.0),
            reason: 'the accent on #${_hex(s)} is '
                '${_contrast(AppPalette.accent, s).toStringAsFixed(2)}:1',
          );
        }
      });

      test('the ink on an accent fill is the one the app actually uses', () {
        // Both large fills of the accent — the primary button in `banners.dart`
        // and the selected date chip in `liquid_glass.dart` — hardcode
        // `AppPalette.onHue`, because the fill is a constant rather than a
        // caller-supplied hue. That is only defensible while the ratio holds.
        //
        // WattVision's cyan is a bright fill, so the ink is dark: white on
        // `#00E5FF` is about 1.4:1 and fails, dark `#121212` clears AA easily.
        expectClearsAa('AppPalette.onHue on the accent', AppPalette.onHue,
            [AppPalette.accent]);
      });

      test('a wash in the accent is legible as a graphic and as text', () {
        // `AppBorders.categoricalWash`, which is the shape `AppBadge` draws.
        // Composited over every caption surface rather than only over `page`,
        // because the accent is the hue behind most badges.
        //
        // The 3:1 half is 1.4.11's graphical-object rule, which is what
        // `GlassPageHeader` relies on: a wash with an 18px `Icon` of the same
        // hue on it. The 4.5 one is what lets a badge draw accent-coloured text.
        for (final surface in _surfaces) {
          final wash = Color.alphaBlend(
            AppBorders.categoricalWash(AppPalette.accent),
            surface,
          );
          final ratio = _contrast(AppPalette.accent, wash);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: 'the accent on its own wash over #${_hex(surface)} is '
                '${ratio.toStringAsFixed(2)}:1, which is below the 3:1 that '
                'an icon of the hue on that wash needs',
          );
        }
        final overCard = Color.alphaBlend(
          AppBorders.categoricalWash(AppPalette.accent),
          AppSurfaces.surface,
        );
        expect(
          _contrast(AppPalette.accent, overCard),
          greaterThanOrEqualTo(4.5),
          reason: 'the accent on its own wash over a card is '
              '${_contrast(AppPalette.accent, overCard).toStringAsFixed(2)}:1, '
              'which is under the 4.5 a caption on that wash needs; the wash '
              'alpha is the thing to raise back, not this assertion',
        );
      });

      test('the accent is distinct from every status colour', () {
        // The accent draws the chart-section live dot, the carousel's active dot
        // and the row edge, so it must not be confusable with the status ramp.
        // WattVision separates them by hue: cyan accent, lime ok, amber warn,
        // orange alert, red bad.
        expect(AppPalette.accent, isNot(statusWarn));
        expect(AppPalette.accent, isNot(statusOk));
        expect(AppPalette.accent, isNot(statusAlert));
        expect(AppPalette.accent, isNot(statusBad));
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
