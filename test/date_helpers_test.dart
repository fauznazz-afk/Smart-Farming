import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/date_helpers.dart';

/// The property that matters on a time axis: **no two adjacent labels are the
/// same string**.
///
/// Asserting that directly is what makes this a guard rather than a snapshot. A
/// snapshot pins one window and passes while the rule is wrong for every other
/// one, which is exactly how `29/09 30/09 30/09 30/09 30/09 01/10` shipped: the
/// rule was a boolean on the range, correct for a two-day window with daily
/// ticks and meaningless for a three-day window with four-hourly ones.
void main() {
  const hour = 3600000.0;

  DateTime at(int day, int hour_, [int minute = 0]) =>
      DateTime(2026, 9, day, hour_, minute);

  double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();

  /// Builds the labels an axis would draw for a window starting at [from] with
  /// the given [interval], including one tick either side so the first and last
  /// ticks get their neighbours' comparison too.
  List<String> labelsFor({
    required DateTime from,
    required int ticks,
    required double intervalMs,
  }) {
    return [
      for (var i = -1; i <= ticks; i++)
        formatAxisTick(
          ms(from) + i * intervalMs,
          spansMultipleDays: true,
          tickIntervalMs: intervalMs,
        ),
    ];
  }

  group('no two adjacent labels collide', () {
    // Swept rather than sampled. The bug lived in the interaction between the
    // range length and the tick spacing, so the cases that matter are the ones
    // where those two disagree.
    const intervalsMs = <double>[
      900000, // 15 min
      hour, // 1 h
      4 * hour, // 4 h -- the interval that produced the duplicate run
      6 * hour,
      12 * hour,
      86400000, // 1 day
      7 * 86400000, // 1 week
    ];

    // Inside a test(), not the group body. A bare expect() in a group callback
    // runs while the file is still being declared, which throws
    // OutsideTestException and fails the whole file with no test name.
    test('across every interval and window start', () {
      for (final interval in intervalsMs) {
        for (final startDay in [28, 29, 30]) {
          for (final startHour in [0, 3, 14, 22]) {
            final from = at(startDay, startHour);
            final labels = labelsFor(
              from: from,
              ticks: 12,
              intervalMs: interval,
            );

            for (var i = 1; i < labels.length; i++) {
              expect(
                labels[i],
                isNot(labels[i - 1]),
                reason: 'interval ${(interval / 60000).round()}min from '
                    '${from.toIso8601String()}: adjacent labels '
                    '"${labels[i - 1]}" and "${labels[i]}" are identical',
              );
            }
          }
        }
      }
    });
  });

  group('which information each case carries', () {
    test('a single-day window is labelled with the time alone', () {
      // The time is unambiguous inside one day, so the date would be noise.
      expect(
        formatAxisTick(ms(at(30, 14, 30)), spansMultipleDays: false),
        '14:30',
      );
    });

    test('a daily interval on a multi-day window is labelled with the date alone', () {
      // Every tick is a new day, so the date distinguishes them all.
      expect(
        formatAxisTick(
          ms(at(30, 6)),
          spansMultipleDays: true,
          tickIntervalMs: 86400000,
        ),
        '30/09',
      );
    });

    test('sub-daily ticks on a multi-day window carry the date at each day turn', () {
      final fourHours = 4 * hour;
      // 00:00 on the 30th is the first tick of its day, so it prints the date.
      // Date *alone*: "30/09 00:00" is eleven characters and overlapped its
      // neighbours on the device, which a distinctness-only guard cannot catch.
      expect(
        formatAxisTick(
          ms(at(30, 0)),
          spansMultipleDays: true,
          tickIntervalMs: fourHours,
        ),
        '30/09',
      );
      // 04:00 is not a day turn, so it prints the time.
      expect(
        formatAxisTick(
          ms(at(30, 4)),
          spansMultipleDays: true,
          tickIntervalMs: fourHours,
        ),
        '04:00',
      );
      // October, back over midnight, gets the date again. Spelled out rather
      // than built from `at()`, which takes a day-of-September and would have
      // quietly produced 1 September here.
      expect(
        formatAxisTick(
          ms(DateTime(2026, 10, 1)),
          spansMultipleDays: true,
          tickIntervalMs: fourHours,
        ),
        '01/10',
        reason: 'month must roll over, not repeat September',
      );
    });

    test('a day turn is never wider than the time label it replaces', () {
      // The second half of the device-only failure. Distinct labels can still be
      // too wide for the gap between ticks, and this is the property that stops
      // the axis from printing on top of itself.
      for (final interval in [hour, 2 * hour, 4 * hour, 6 * hour, 12 * hour]) {
        for (var day = 28; day <= 30; day++) {
          for (var h = 0; h < 24; h += 2) {
            final atMidnight = at(day, 0);
            final label = formatAxisTick(
              ms(atMidnight),
              spansMultipleDays: true,
              tickIntervalMs: interval,
            );
            expect(
              label.length,
              lessThanOrEqualTo('00:00'.length),
              reason: 'interval ${(interval / 60000).round()}min: the day-turn '
                  'label "$label" at $atMidnight is wider than the time labels '
                  'either side of it and will overlap them',
            );
          }
        }
      }
    });

    test('an unknown interval falls back to the date rather than to a collision', () {
      // The old signature had no interval at all. Behaviour with it absent is
      // the pre-existing format, which is the safe default.
      expect(
        formatAxisTick(ms(at(30, 14)), spansMultipleDays: true),
        '30/09',
      );
    });
  });

  group('isDayBoundaryTick', () {
    test('is true when the step back crosses midnight', () {
      expect(isDayBoundaryTick(ms(at(30, 0)), 4 * hour), isTrue);
    });

    test('is false inside a day', () {
      expect(isDayBoundaryTick(ms(at(30, 12)), 4 * hour), isFalse);
    });

    test('treats a non-positive interval as a boundary rather than dividing by it', () {
      expect(isDayBoundaryTick(ms(at(30, 12)), 0), isTrue);
      expect(isDayBoundaryTick(ms(at(30, 12)), -1), isTrue);
    });
  });
}
