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
    // One row per boundary, both sides. The threshold is `>=`, so the value
    // exactly at the boundary belongs to the band ABOVE it and one lx below
    // belongs below — that off-by-one is the only thing this table can catch,
    // and every one of these numbers is a lux value a greenhouse grower reads
    // off a manual, not an arbitrary constant.
    final cases = <String, ({double lux, SkyCondition expected, String why})>{
      '55000 lx is the first band of clear sky': (
        lux: 55000,
        expected: SkyCondition.clear,
        why: 'the first row of a greenhouse roof in full sun',
      ),
      'just under 55000 lx is mostly clear': (
        lux: 54999,
        expected: SkyCondition.mostlyClear,
        why: 'haze, one lx below the clear threshold',
      ),
      '28000 lx is a bright overcast day': (
        lux: 28000,
        expected: SkyCondition.mostlyClear,
        why: 'thin cloud, still bright enough to cast a shadow',
      ),
      'just under 28000 lx is broken cloud': (
        lux: 27999,
        expected: SkyCondition.partlyCloudy,
        why: 'the sun is behind something',
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
      '1800 lx is storm cloud': (
        lux: 1800,
        expected: SkyCondition.overcast,
        why: 'the low end of a solid sheet',
      ),
      'just under 1800 lx is heavily overcast': (
        lux: 1799,
        expected: SkyCondition.heavilyOvercast,
        why: 'storm cloud, or a sensor that has been covered',
      ),
      'a dark sensor reads heavily overcast': (
        lux: 0,
        expected: SkyCondition.heavilyOvercast,
        why: 'the covered-sensor case shares the storm band',
      ),
      'a negative dark reading reads heavily overcast': (
        lux: -0.01,
        expected: SkyCondition.heavilyOvercast,
        why: 'the negative lux a real sensor reports at night',
      ),
      'noon sun reads clear': (
        lux: 100000,
        expected: SkyCondition.clear,
        why: 'a clear noon, the top of the scale',
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
      // Two bands sharing a word would make the condition meaningless: the
      // label is the only thing distinguishing clear from mostly clear, because
      // the two deliberately share a colour.
      final labels = SkyCondition.values.map((c) => c.label).toList();
      expect(
        labels.toSet().length,
        SkyCondition.values.length,
        reason: 'Two sky conditions read the same on screen. Labels: $labels',
      );
    });

    test('is the word shown on the card', () {
      expect(SkyCondition.clear.label, 'Clear sky');
      expect(SkyCondition.mostlyClear.label, 'Mostly clear');
      expect(SkyCondition.partlyCloudy.label, 'Partly cloudy');
      expect(SkyCondition.overcast.label, 'Overcast');
      expect(SkyCondition.heavilyOvercast.label, 'Heavily overcast');
    });
  });
}
