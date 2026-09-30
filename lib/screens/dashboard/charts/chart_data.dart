import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';

/// Defines a metric to display in telemetry cards.
class MetricDef {
  final String key;
  final String label;
  final String unit;
  final IconData icon;

  /// Decimal places for the displayed value.
  ///
  /// Everything used to be two, which is right for a current in amperes and
  /// absurd for anything else: the battery page read "Cycles 12.00" and
  /// "State of Charge 45.00 %". A count and a percentage do not have hundredths.
  final int decimals;

  const MetricDef(
    this.key,
    this.label,
    this.unit,
    this.icon, {
    this.decimals = 2,
  });
}

/// Statistics for a series of telemetry points.
class SeriesStats {
  final double latest;
  final double minimum;
  final double maximum;

  const SeriesStats({
    required this.latest,
    required this.minimum,
    required this.maximum,
  });

  static SeriesStats? fromPoints(List<TelemetryPoint> points) {
    if (points.isEmpty) return null;
    var latest = points.first;
    var minimum = points.first.value;
    var maximum = points.first.value;
    for (final point in points) {
      if (point.value < minimum) minimum = point.value;
      if (point.value > maximum) maximum = point.value;
      if (point.timestamp.isAfter(latest.timestamp)) latest = point;
    }
    return SeriesStats(
      latest: latest.value,
      minimum: minimum,
      maximum: maximum,
    );
  }
}

/// A chart series with its data points and styling.
class ChartSeries {
  final String label;
  final String unit;
  final List<TelemetryPoint> points;
  final List<FlSpot> spots;
  final Color color;
  final SeriesStats? stats;

  const ChartSeries(
    this.label,
    this.unit,
    this.points,
    this.spots,
    this.color,
    this.stats,
  );
}

/// Bounds for chart axes with calculated intervals.
class ChartBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double chartInterval;
  final double timeInterval;

  const ChartBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.chartInterval,
    required this.timeInterval,
  });

  /// Whether the x range covers more than a single day, in which case axis
  /// labels should show a date rather than a clock time.
  bool get spansMultipleDays =>
      (maxX - minX) > const Duration(days: 1).inMilliseconds;

  factory ChartBounds.fromSeries(
    List<ChartSeries> series, {
    bool zeroAnchored = true,
  }) {
    final points = series.expand((item) => item.points).toList();
    if (points.isEmpty) {
      return const ChartBounds(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        chartInterval: 1,
        timeInterval: 1,
      );
    }
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minimum = double.infinity;
    var maximum = double.negativeInfinity;
    for (final point in points) {
      final x = point.timestamp.millisecondsSinceEpoch.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (point.value < minimum) minimum = point.value;
      if (point.value > maximum) maximum = point.value;
    }

    // Snap the x axis to round clock boundaries so tick labels land on
    // readable times (:00, :30) instead of whatever the first sample was.
    final rawTimeStep = (maxX - minX) / _targetTicks;
    final timeInterval = niceTimeStep(rawTimeStep);
    minX = (minX / timeInterval).floorToDouble() * timeInterval;
    maxX = (maxX / timeInterval).ceilToDouble() * timeInterval;

    var minY = chartLowerBound(minimum, maximum, zeroAnchored: zeroAnchored);
    final rawMaxY = maximum <= 0 ? 1.0 : maximum * 1.1;
    final interval = niceStep(rawMaxY - minY, divisions: _targetTicks);

    // A derived bottom is snapped down to a whole interval, so the axis is a
    // count of intervals tall and every gridline fl_chart draws -- which
    // includes `minY` itself -- is a round pH value rather than a leftover like
    // 6.025.
    //
    // Only for a derived bottom. A zero-anchored axis is snapped for free,
    // because zero is a multiple of any interval; the one zero-anchored case
    // that is not free is the padded negative minimum, where -22 under a step of
    // 10 would have to become -30. That padding is deliberately tight and a
    // test pins it, so it is left alone.
    if (!zeroAnchored && interval > 0) {
      minY = (minY / interval).floorToDouble() * interval;
    }

    // Snap the top of the y axis to a whole number of intervals.
    //
    // Without this the axis drew two labels on top of each other. fl_chart
    // labels every gridline at a multiple of the interval *and* the top bound,
    // so a peak of 383.51 W gave `maxY = 421.86` with an interval of 100: the
    // labels 0/100/200/300/400 plus a final `421.86` twenty-two units above
    // 400, which on a phone is the same line. It was visible on the PV page and
    // it is the kind of defect no test catches, because both numbers are
    // individually correct.
    //
    // Only when there is real data. `rawMaxY = 1.0` on a flat or all-negative
    // series is a synthetic floor, not a measurement, and rounding it up to a
    // multiple of an interval derived from the *negatives* stretched the axis
    // to 10.0 -- an empty chart with a 10-unit ceiling. `chart_bounds_test`
    // caught exactly that, which is the argument for keeping that test.
    final maxY = maximum <= 0 || interval <= 0
        ? rawMaxY
        : (rawMaxY / interval).ceilToDouble() * interval;
    return ChartBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      chartInterval: interval,
      timeInterval: timeInterval,
    );
  }

  /// Number of intervals we aim to fit along each axis.
  static const _targetTicks = 4;
}

/// The bottom of the Y axis, before the interval is known.
///
/// Top-level and public, next to [niceStep] and for the same reason: this is
/// pure arithmetic, and the interesting part -- the proportionality of the
/// headroom to the data range -- is invisible once the result has been quantised
/// onto a gridline. A private static could only be tested through the finished
/// axis, and a finished axis rounds twice, so the property could not be stated
/// at all.
///
/// **Zero-anchored** (the default, and every group that plots a magnitude):
/// zero, or a 10% pad below the data when the data goes negative, because
/// battery power and current are negative while the pack discharges and an
/// axis that clipped them would hide the sign.
///
/// **Index-anchored**, for a bounded dimensionless scale where zero is an
/// arbitrary number rather than a state. pH runs 0-14 and the device data lives
/// between 6.37 and 7.75, so a zero baseline squeezed the entire drop -- the
/// news on the fish page -- into about the top fifth of the plot. An axis from 0
/// to 8.5 is technically correct and reads as a flat line.
///
/// The arithmetic is one term:
///
///   pad  = 0.25 * (maximum - minimum)   the observed range
///   minY = minimum - pad
///
/// The range term is what makes it work: it scales the headroom to the data, so
/// a 1.38-wide pH swing gets 0.345 of headroom while a wide excursion gets more,
/// and neither is padded into the same visual margin. 0.25 rather than something
/// larger because the top of the axis already adds its own 10% of the value, and
/// this is the bottom's half of the same job.
///
/// A range-only pad looks like it would close a series that never moves -- zero
/// range, zero pad, `minY == minimum`. It does not, and the reason is worth
/// keeping: the existing `maximum * 1.1` at the top opens that case on its own,
/// so a flat 7.0 pH still plots 7.0..7.8. Adding a 2%-of-value floor to the
/// bottom "for safety" was tried and removed, because it is a second magic
/// number and the `maxY` snap swallowed it whole: a 2.6-wide pH swing produced a
/// byte-identical axis with and without it. A term that changes nothing on any
/// real reading is a term that only has to be explained.
///
/// Rejected instead of these: a fixed 10%-of-value pad, which is the same
/// mistake in a different place (a flat 7.0 pH would open to 6.3-7.7, wider
/// than a real 1.38 swing and so wider than the interesting case); and the
/// scale's own minimum, which would need the 0-14 range restated here, and a
/// second copy of a number that already lives in Settings is a number that will
/// drift.
double chartLowerBound(
  double minimum,
  double maximum, {
  bool zeroAnchored = true,
}) {
  if (zeroAnchored) return minimum < 0 ? minimum * 1.1 : 0.0;
  return minimum - 0.25 * (maximum - minimum);
}

/// Rounds a raw axis step up to the next 1 / 2 / 2.5 / 5 x 10^n value.
///
/// Keeps y axis labels on human-friendly numbers such as 0.5 or 25 instead of
/// arbitrary values like 111.45.
double niceStep(double raw, {int divisions = 4}) {
  if (!raw.isFinite || raw <= 0) return 1;
  final target = raw / divisions;
  final magnitude = _pow10Floor(target);
  final normalized = target / magnitude;
  final double step;
  if (normalized <= 1) {
    step = 1;
  } else if (normalized <= 2) {
    step = 2;
  } else if (normalized <= 2.5) {
    step = 2.5;
  } else if (normalized <= 5) {
    step = 5;
  } else {
    step = 10;
  }
  return step * magnitude;
}

const double _minuteMs = 60000;

/// Candidate axis steps in minutes: sub-hour through multi-day.
const _timeStepMinutes = <double>[
  1, 2, 5, 10, 15, 30, //
  60, 120, 180, 360, 720, 1440, //
  2880, 4320, 10080, 20160, 43200, 129600, 259200, 525600,
];

/// Rounds a raw time step (in milliseconds) up to a whole number of minutes.
///
/// The step is always rounded up, never down, so a tick never lands closer
/// together than the caller asked for. Steps beyond a year fall back to one
/// year, which keeps very long custom ranges from collapsing to a single tick.
double niceTimeStep(double rawMs) {
  if (!rawMs.isFinite || rawMs <= 0) return _minuteMs;
  final minutes = rawMs / _minuteMs;
  for (final candidate in _timeStepMinutes) {
    if (minutes <= candidate) return candidate * _minuteMs;
  }
  return _timeStepMinutes.last * _minuteMs;
}

double _pow10Floor(double value) {
  var magnitude = 1.0;
  while (magnitude * 10 <= value) {
    magnitude *= 10;
  }
  while (magnitude > value && magnitude > 1e-9) {
    magnitude /= 10;
  }
  return magnitude;
}

/// Processes telemetry points into chart spots with downsampling.
List<FlSpot> processSpots(List<TelemetryPoint> points) {
  if (points.isEmpty) return const <FlSpot>[];
  if (points.length <= 180) {
    return points
        .map(
          (p) => FlSpot(p.timestamp.millisecondsSinceEpoch.toDouble(), p.value),
        )
        .toList(growable: false);
  }

  const targetBuckets = 90;
  final bucketSize = points.length / targetBuckets;
  final spots = <FlSpot>[];

  void addSpot(TelemetryPoint point) {
    final x = point.timestamp.millisecondsSinceEpoch.toDouble();
    if (spots.isEmpty || x > spots.last.x) {
      spots.add(FlSpot(x, point.value));
    }
  }

  addSpot(points.first);

  for (var b = 0; b < targetBuckets; b++) {
    final startIdx = (b * bucketSize).floor();
    var endIdx = ((b + 1) * bucketSize).floor();
    if (endIdx > points.length) endIdx = points.length;
    if (startIdx >= endIdx) continue;

    var minIdx = startIdx;
    var maxIdx = startIdx;
    for (var i = startIdx + 1; i < endIdx; i++) {
      if (points[i].value < points[minIdx].value) minIdx = i;
      if (points[i].value > points[maxIdx].value) maxIdx = i;
    }

    final firstIdx = minIdx < maxIdx ? minIdx : maxIdx;
    final secondIdx = minIdx < maxIdx ? maxIdx : minIdx;

    addSpot(points[firstIdx]);
    if (secondIdx != firstIdx) {
      addSpot(points[secondIdx]);
    }
  }

  final lastX = points.last.timestamp.millisecondsSinceEpoch.toDouble();
  if (spots.isNotEmpty && spots.last.x == lastX) {
    spots[spots.length - 1] = FlSpot(lastX, points.last.value);
  } else {
    spots.add(FlSpot(lastX, points.last.value));
  }

  return spots;
}
