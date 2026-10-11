import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/utils/solar_irradiance.dart';

/// Pins the lux → W/m² conversion and the sky-condition thresholds.
///
/// **The 93 constant is the whole justification, so it is pinned rather than
/// left as a comment.** `luxToIrradiance` divides by the luminous efficacy of
/// sunlight so that a clear noon lands near 1000 W/m². Change the divisor and
/// every figure on the Sun card moves with it, and nothing about the constants
/// would look wrong on a code review — 93 and 100 are both "about a hundred".
/// The property that distinguishes them is the one asserted below.
void main() {
  group('luxToIrradiance', () {
    test('is lux divided by the luminous efficacy of sunlight', () {
      // 100 lx / 93 lm/W. If the divisor moves, this is the first thing that
      // fails and the message names the constant it moved.
      expect(
        luxToIrradiance(100),
        closeTo(100 / 93.0, 1e-9),
        reason:
            'sunlightLuminousEfficacy changed. If it did, the clear-noon '
            'identity below has to be re-derived, not just updated.',
      );
      expect(sunlightLuminousEfficacy, 93.0);
    });

    test('a clear noon of 100000 lx lands within a few percent of one sun', () {
      // The reason the divisor is 93 and not the usual rounded lux/100: at 93 a
      // 100 000 lx reading is 1075 W/m² (7.5% high), while at 100 it would be
      // exactly 1000 by construction — the rounded version only agrees on this
      // one value and drifts everywhere else. The 7% gap between the two is
      // larger than the spread between a hazy noon and a thin-cloud one, which
      // is what would otherwise decide a condition.
      final wm2 = luxToIrradiance(100000);
      expect(wm2, closeTo(oneSunWm2, oneSunWm2 * 0.08));
    });

    test('clamps a negative reading to zero', () {
      // A real sensor reports a small negative in the dark, the same way the
      // BMS reports -0.01 A while idle. `-0.9 W/m²` on a panel output is a
      // number nobody can act on, so the clamp is the whole point of the
      // branch. -0.01 lx is the shape of the reading actually observed.
      expect(luxToIrradiance(-0.01), 0);
      expect(luxToIrradiance(-1), 0);
      expect(luxToIrradiance(-50000), 0);
      expect(luxToIrradiance(-0.0), 0);
    });

    test('clamps zero itself to zero', () {
      expect(luxToIrradiance(0), 0);
    });
  });

  group('sunFraction', () {
    test('is 0 at zero lux', () {
      expect(sunFraction(0), 0);
      // Same clamp as above, seen through the fraction the bar is drawn with.
      expect(sunFraction(-0.01), 0);
    });

    test('clamps above 1.0 — a 200000 lx sky is still one sun', () {
      // Direct normal readings on a very clear day exceed 100 000 lx. Unclamped
      // that is 2150 W/m², a 215% bar drawn inside a 100% track.
      expect(
        sunFraction(200000),
        1.0,
        reason:
            'The fraction is a fraction of one sun. If this goes above 1.0, '
            'the bar overflows its track on a clear day.',
      );
      // 100 000 lx is *also* over the clamp, not a near-miss of it: it is 1075
      // W/m², 7.5% past one sun. This is the line that used to assert 1.075
      // here, which contradicted the assertion 40 characters above it and
      // contradicted the clamp the whole test exists to check.
      expect(
        sunFraction(100000),
        1.0,
        reason: 'A clear noon is 7.5% over one sun and must still draw a full '
            'track, not a bar that runs off the end of it.',
      );
      // The 1075 is real, though — it is what the *irradiance* is. Asserting it
      // on `luxToIrradiance` is what pins "the clamp is in the fraction, not in
      // the conversion": a future edit that clamps inside `luxToIrradiance`
      // would flatten every W/m² reading to 1000 and this is the line that
      // catches it.
      expect(luxToIrradiance(100000), closeTo(1075.27, 0.01));
      expect(sunFraction(93000), 1.0, reason: 'Exactly one sun at 93 lm/W.');
      // And just under the ceiling is genuinely proportional, not pinned at 1.
      expect(sunFraction(50000), closeTo(0.5376, 0.001));
    });

    test('is monotonic across the useful range', () {
      // A bar that is not monotonic would read as a measurement rather than a
      // trend, which is the failure the chart-group rules in AGENTS.md warn
      // about. Cheap to assert and impossible to regress by accident.
      var previous = -1.0;
      for (final lux in [
        0.0,
        100.0,
        1800.0,
        9000.0,
        28000.0,
        55000.0,
        93000.0,
      ]) {
        final f = sunFraction(lux);
        expect(f, greaterThanOrEqualTo(previous));
        previous = f;
      }
    });
  });

  group('skyConditionFor thresholds', () {
    // One row per boundary, both sides. The daylight thresholds are `>=`, so the
    // value exactly at the boundary belongs to the band ABOVE it and one lx
    // below belongs below — that off-by-one is the only thing this table can
    // catch, and every one of these numbers is a lux value a greenhouse grower
    // reads off a manual, not an arbitrary constant.
    final cases = <String, ({double lux, SkyCondition expected, String why})>{
      'noon sun reads clear': (
        lux: 100000,
        expected: SkyCondition.clear,
        why: 'a clear noon, the top of the scale',
      ),
      '28000 lx is the first band of clear': (
        lux: 28000,
        expected: SkyCondition.clear,
        why: 'the first row of a greenhouse roof in full sun',
      ),
      'just under 28000 lx is broken cloud': (
        lux: 27999,
        expected: SkyCondition.partlyCloudy,
        why: 'thin cloud; the sun is behind something',
      ),
      '9000 lx is a dark overcast day': (
        lux: 9000,
        expected: SkyCondition.partlyCloudy,
        why: 'the low end of broken cloud',
      ),
      'just under 9000 lx is a solid sheet': (
        lux: 8999,
        expected: SkyCondition.overcast,
        why: 'diffuse light, no shadows',
      ),
      'one lx is light, so it is not night': (
        lux: 1,
        expected: SkyCondition.overcast,
        why: 'a lux reading measures what arrived, not whether the sun is up; '
            '1 lx arrived, so the only remaining daylight state is overcast',
      ),
      'zero is night': (
        lux: 0,
        expected: SkyCondition.night,
        why: 'no light arrived at all, which is the whole night condition',
      ),
      'a negative dark reading is night': (
        lux: -0.4,
        expected: SkyCondition.night,
        why: 'the negative lux a real sensor reports at night, the same way '
            'the BMS reports -0.01 A while idle — so the boundary has to be '
            '<= 0, not < 0',
      ),
      'a negative dark reading is night at BMS scale': (
        lux: -0.01,
        expected: SkyCondition.night,
        why: 'the sub-lux dark reading the test device actually produced',
      ),
    };

    cases.forEach((description, c) {
      test('$description → ${c.expected.name}', () {
        expect(
          skyConditionFor(c.lux),
          c.expected,
          reason:
              '${c.lux} lx is ${c.why}. If this fails, a threshold in '
              'skyConditionFor moved; the boundary numbers in the util doc '
              'comment are the ones to re-check.',
        );
      });
    });

    test('the scale is monotonic, so a darker sky never reads brighter', () {
      // The old table could not catch a reordering across the collapsed bands;
      // this can, and it costs one loop.
      var previous = SkyCondition.clear;
      for (final lux in [100000.0, 55000.0, 28000.0, 27999.0, 9000.0, 8999.0, 1.0]) {
        final condition = skyConditionFor(lux);
        expect(
          condition.index,
          greaterThanOrEqualTo(previous.index),
          reason: '$lux lx reads $condition after ${previous.name}.',
        );
        previous = condition;
      }
    });

    test('only zero and below are night', () {
      for (final lux in [0.0, -0.0001, -1.0, -40.0]) {
        expect(skyConditionFor(lux), SkyCondition.night, reason: '$lux lx');
      }
      for (final lux in [0.001, 0.5, 1.0]) {
        expect(
          skyConditionFor(lux),
          isNot(SkyCondition.night),
          reason: '$lux lx is daylight, however faint.',
        );
      }
    });
  });

  group('SkyCondition.label', () {
    test('every value has a non-empty label', () {
      for (final c in SkyCondition.values) {
        expect(
          c.label,
          isNotEmpty,
          reason: '${c.name} would render as an empty caption.',
        );
      }
    });

    test('every value has a distinct label', () {
      // All three daylight states deliberately share a colour, so the label is
      // the only thing distinguishing them. Two states sharing a word would
      // make the condition meaningless.
      final labels = SkyCondition.values.map((c) => c.label).toList();
      expect(
        labels.toSet().length,
        SkyCondition.values.length,
        reason: 'Two sky conditions read the same on screen. Labels: $labels',
      );
    });

    test('is the word shown on the card', () {
      expect(SkyCondition.clear.label, 'Clear');
      expect(SkyCondition.partlyCloudy.label, 'Partly cloudy');
      expect(SkyCondition.overcast.label, 'Overcast');
      expect(SkyCondition.night.label, 'Night');
    });

    test('no label carries trailing punctuation', () {
      // These sit inline in a card caption, where a full stop reads as a
      // sentence about nothing.
      for (final c in SkyCondition.values) {
        expect(
          c.label,
          isNot(matches(RegExp(r'[.!?,;:]$'))),
          reason: '"${c.label}" ends in punctuation.',
        );
      }
    });
  });

  group('SkyCondition.isDaylight', () {
    test('every daylight state says yes', () {
      for (final c in SkyCondition.values.where((c) => c != SkyCondition.night)) {
        expect(c.isDaylight, isTrue, reason: c.name);
      }
    });

    test('night is the only one that says no', () {
      expect(SkyCondition.night.isDaylight, isFalse);
      expect(
        SkyCondition.values.where((c) => !c.isDaylight),
        [SkyCondition.night],
        reason: 'If a state other than night reports no daylight, it is a '
            'fourth kind of reading and the enum doc has to say so.',
      );
    });
  });
}
