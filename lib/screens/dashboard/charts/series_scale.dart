import 'package:fl_chart/fl_chart.dart';

/// Rescales a series so it can share one axis with series in other units.
///
/// Voltage, current and power are three different units on three very different
/// scales. On the AC page power reaches 3500 W while current stays under 16 A
/// and voltage sits near-constant at 220, so plotting the raw values puts two
/// of the three traces flat on the X axis and the reader concludes there is
/// nothing there. This maps each series onto 0..1 of its own range instead, and
/// [unscale] maps a position on that axis back to real units for the tooltip.
///
/// The scale comes from the *already downsampled* points, so the expensive
/// reduction still happens once and the axis does not jump every time a coarse
/// window happens to include an outlier.
///
/// A series that never moved is given a unit span and sits flat at the bottom.
/// That reads as "no variation", where plotting it at 1.0 would read as "pegged
/// at full scale", and [unscale] still returns its true value.
class SeriesScale {
  const SeriesScale._(this.base, this.span);

  final double base;

  /// The real value range that normalised 0..1 covers. 1 for a flat series.
  final double span;

  /// Builds the scale for a set of already-reduced spots.
  factory SeriesScale.of(List<FlSpot> spots) {
    if (spots.isEmpty) return const SeriesScale._(0, 1);
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final spot in spots) {
      if (spot.y < low) low = spot.y;
      if (spot.y > high) high = spot.y;
    }
    final span = high - low;
    // A flat series would divide by zero. A unit span keeps the arithmetic
    // finite and, combined with [normalise] returning 0, keeps the line honest.
    return span == 0
        ? SeriesScale._(low, 1)
        : SeriesScale._(low, span);
  }

  double normalise(double value) => (value - base) / span;

  double unscale(double normalised) => base + normalised * span;

  /// The downsampled spots mapped onto 0..1.
  List<FlSpot> apply(List<FlSpot> spots) => [
    for (final spot in spots) FlSpot(spot.x, normalise(spot.y)),
  ];
}
