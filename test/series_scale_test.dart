import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/charts/series_scale.dart';

/// The device charts draw voltage, current and power together because seeing
/// all three is the point. Three units cannot share one raw axis — power is
/// hundreds of times larger than current — so each is scaled to its own range.
///
/// The failure this guards against is quiet: a chart that still draws, still
/// animates, and shows two of the three traces flat on the axis, which reads as
/// "nothing is happening" rather than as a broken chart. Nothing about that
/// fails a smoke test.
void main() {
  List<FlSpot> spots(List<double> ys) =>
      [for (var i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i])];

  group('SeriesScale', () {
    test('maps the range onto 0..1', () {
      final scale = SeriesScale.of(spots([15, 20, 30, 10, 25]));
      expect(scale.base, 10);
      expect(scale.span, 20); // 30 - 10
      expect(scale.normalise(10), 0);
      expect(scale.normalise(30), 1);
      expect(scale.normalise(20), 0.5);
    });

    test('unscale is the inverse of normalise', () {
      // The tooltip prints real units while the axis is normalised, so every
      // value the user can touch has to survive the round trip.
      final scale = SeriesScale.of(spots([15, 20, 30, 10, 25]));
      for (final value in [10.0, 15.0, 20.0, 30.0, 27.5]) {
        expect(scale.unscale(scale.normalise(value)), closeTo(value, 1e-9));
      }
    });

    test('a flat series sits at the bottom instead of dividing by zero', () {
      // A constant 220 V mains voltage is the normal case, not an edge case.
      final scale = SeriesScale.of(spots([220, 220, 220]));
      expect(scale.span, 1);
      expect(scale.normalise(220), 0);
      // The tooltip must still report the true value, not a fraction of it.
      expect(scale.unscale(0), 220);
    });

    test('a single point is flat, not an infinite span', () {
      final scale = SeriesScale.of(spots([7]));
      expect(scale.base, 7);
      expect(scale.normalise(7), 0);
      expect(scale.unscale(0), 7);
    });

    test('an empty series is inert rather than a NaN', () {
      final scale = SeriesScale.of(const []);
      expect(scale.apply(const []), isEmpty);
      expect(scale.unscale(0.5).isFinite, isTrue);
    });

    test('a small current beside a large power is as visible as the power', () {
      // The actual AC-page shape: 220 V steady, current under 16 A, power
      // spiking to thousands of watts. On a shared raw axis the current would
      // occupy well under one percent of the height.
      final voltage = SeriesScale.of(spots([219, 220, 221, 220]));
      final current = SeriesScale.of(spots([0.2, 8.1, 15.4, 0.1]));
      final power = SeriesScale.of(spots([44, 1782, 3388, 22]));

      for (final scale in [voltage, current, power]) {
        expect(scale.normalise(scale.span + scale.base), 1);
      }
      // Every series uses the whole plot height regardless of its unit.
      final heights = [
        current.normalise(8.1) - current.normalise(0.2),
        power.normalise(1782) - power.normalise(44),
      ];
      for (final h in heights) {
        expect(h, greaterThan(0.2));
      }
    });

    test('a negative range works, which a battery discharge has', () {
      // A discharging pack reports negative current. If the scale assumed
      // positive values, min and max would come out inverted.
      final scale = SeriesScale.of(spots([-1.5, -4.0, -0.2]));
      expect(scale.base, -4.0);
      expect(scale.span, 3.8);
      expect(scale.normalise(-4.0), 0);
      expect(scale.normalise(-0.2), closeTo(1, 1e-9));
    });

    test('apply keeps the x positions and rewrites only y', () {
      final input = [FlSpot(100, 4), FlSpot(200, 6), FlSpot(300, 2)];
      final out = SeriesScale.of(input).apply(input);
      expect(out.map((s) => s.x), [100, 200, 300]);
      expect(out.map((s) => s.y), [0.5, 1.0, 0.0]);
    });
  });
}
