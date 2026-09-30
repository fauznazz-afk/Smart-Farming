import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/screens/energy_report_screen.dart';
import 'package:plts_monitoring/services/energy_report_service.dart';
import 'package:plts_monitoring/services/thingsboard_api.dart';

/// Records the window the service asked for, so the tests can assert on what the
/// picker must and must not re-request rather than only on the dates themselves.
///
/// `EnergyReportService.load` chunks its range into 28-day requests, so
/// [starts] and [ends] hold one entry per chunk and only the outermost bounds
/// are interesting here.
class _RecordingApi extends ThingsBoardApi {
  final List<DateTime> starts = <DateTime>[];
  final List<DateTime> ends = <DateTime>[];

  @override
  Future<Map<String, List<TelemetryPoint>>> fetchHistoryForKeys(
    String deviceId,
    List<String> keys, {
    required DateTime start,
    required DateTime end,
    int intervalMs = 300000,
    int limit = 2000,
  }) async {
    starts.add(start);
    ends.add(end);
    return {
      'power_dc': <TelemetryPoint>[
        TelemetryPoint(timestamp: start, value: 1000),
      ],
    };
  }

  DateTime get windowStart => starts.first;
  DateTime get windowEnd => ends.last;
}

void main() {
  group('canonicalPeriodDate', () {
    test('drops the time-of-day in daily mode', () {
      final result = canonicalPeriodDate(
        DateTime(2026, 3, 10, 17, 45, 12),
        monthly: false,
      );
      expect(result, DateTime(2026, 3, 10));
    });

    test('collapses to the 1st in monthly mode', () {
      // The whole point: the monthly view aggregates the month, so the day the
      // picker happened to return carries no meaning and must not leak into the
      // button label or the CSV filename.
      final result = canonicalPeriodDate(
        DateTime(2026, 3, 27),
        monthly: true,
      );
      expect(result, DateTime(2026, 3));
    });

    test('is idempotent, so re-picking the shown period is a no-op', () {
      // `_selectedDate` is seeded from `DateTime.now()`, which carries a
      // time-of-day. Without normalisation the equality guard in `_pickPeriod`
      // could never fire and every confirm would setState and reload.
      final once = canonicalPeriodDate(
        DateTime(2026, 3, 10, 9, 30),
        monthly: false,
      );
      final twice = canonicalPeriodDate(once, monthly: false);
      expect(twice, once);

      final monthOnce = canonicalPeriodDate(
        DateTime(2026, 3, 10, 9, 30),
        monthly: true,
      );
      expect(canonicalPeriodDate(monthOnce, monthly: true), monthOnce);
    });
  });

  group('periodWindowChanged', () {
    test('is false for a day move inside one month', () {
      // Must not re-request: the buckets are already resident and
      // `bucketsForPeriod` filters them in memory.
      expect(
        periodWindowChanged(DateTime(2026, 3, 1), DateTime(2026, 3, 28)),
        isFalse,
      );
    });

    test('is true across a month boundary', () {
      expect(
        periodWindowChanged(DateTime(2026, 3, 28), DateTime(2026, 4, 1)),
        isTrue,
      );
    });

    test('is true across a year boundary', () {
      expect(
        periodWindowChanged(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        isTrue,
      );
    });
  });

  group('the fetch window the month-scoped predicate depends on', () {
    // These are the reason `periodWindowChanged` ignores the day. If the service
    // window ever stops covering the previous month, both the daily and the
    // monthly "compared with the previous period" figures silently degrade to
    // 'No comparison data yet' while every screen still renders confidently —
    // so the invariant is pinned here rather than only asserted in a comment.
    test('covers the selected month and the whole month before it', () async {
      final api = _RecordingApi();
      await EnergyReportService(api).load(
        referenceDate: DateTime(2026, 3, 15),
      );

      expect(api.windowStart, DateTime(2026, 2));
      expect(api.windowEnd, DateTime(2026, 4));
      expect(
        api.windowStart.isBefore(DateTime(2026, 2)),
        isFalse,
        reason: 'the preceding day of 1 March is 28 February and must be fetched',
      );
    });

    test('a day move inside a month requests the identical window', () async {
      // The assertion behind the `if (windowChanged) await _load()` gate: the
      // early return is only sound because a same-month day move cannot change
      // what the service would return.
      final first = _RecordingApi();
      final second = _RecordingApi();
      await EnergyReportService(first).load(
        referenceDate: DateTime(2026, 3, 1),
      );
      await EnergyReportService(second).load(
        referenceDate: DateTime(2026, 3, 28),
      );

      expect(second.windowStart, first.windowStart);
      expect(second.windowEnd, first.windowEnd);
    });
  });
}