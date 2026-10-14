import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/utils/csv_export.dart';

/// The CSV a supervisor opens in a spreadsheet.
///
/// ## The claim this file exists to protect
///
/// **A hole in the table is a moment the device did not speak, and it must stay
/// a hole.** The obvious way to make a wide table readable is to carry each key's
/// last value forward until its next sample — and the PZEM reports every 30
/// seconds while the fish tank reports every five minutes, so that would fill
/// roughly nine of every ten fish-tank cells with numbers nothing ever asserted.
/// Every assertion below is about that not happening.
void main() {
  DateTime at(int minute, {int second = 0}) =>
      DateTime(2026, 10, 14, 9, minute, second);

  List<TelemetryPoint> points(List<(int, double)> pairs) => [
    for (final (minute, value) in pairs)
      TelemetryPoint(timestamp: at(minute), value: value),
  ];

  List<String> lines(String csv) => csv.trim().split('\n');

  test('an empty history is an empty file, not a header-only one', () {
    expect(buildTelemetryCsv(history: const {}), '');
    expect(buildTelemetryCsv(history: {'power_dc': const []}), '');
  });

  test('writes a header of time plus every key, sorted', () {
    final csv = buildTelemetryCsv(
      history: {
        'soc': points([(0, 50)]),
        'power_dc': points([(0, 100)]),
      },
    );
    expect(lines(csv).first, 'time,power_dc,soc');
  });

  test('one row per sample, in time order', () {
    final csv = buildTelemetryCsv(
      history: {
        'power_dc': points([(2, 3), (0, 1)]),
      },
    );
    final rows = lines(csv);
    expect(rows[1], contains('2026-10-14 09:00:00'));
    expect(rows[2], contains('2026-10-14 09:02:00'));
  });

  // **The core of it.** Two keys sampled at different times produce two rows,
  // each with a hole in the column that did not report — never a carried-forward
  // number.
  test('a key that did not report leaves an empty cell, never a stale one', () {
    final csv = buildTelemetryCsv(
      history: {
        'power_dc': points([(0, 100), (1, 200), (2, 300)]),
        'soc': points([(0, 50)]),
      },
    );
    final rows = lines(csv);
    expect(rows[1], '2026-10-14 09:00:00,100.0,50.0');
    // Two minutes later the battery has said nothing.
    expect(rows[2], '2026-10-14 09:01:00,200.0,');
    expect(rows[3], '2026-10-14 09:02:00,300.0,');
    // The trap: 300.0 has not been copied down into soc.
    expect(csv, isNot(contains('300.0,300.0')));
  });

  // **A merge, not a choice.** Two keys that both spoke at the same instant
  // share one row; neither value is dropped and neither is invented.
  test('two keys reporting at the same instant share one row', () {
    final csv = buildTelemetryCsv(
      history: {
        'power_dc': points([(0, 100)]),
        'soc': points([(0, 50)]),
      },
    );
    expect(lines(csv), hasLength(2));
    expect(lines(csv).last, '2026-10-14 09:00:00,100.0,50.0');
  });

  // **Zero and absent are different facts, and this file is evidence.**
  test('a reported zero is written, not treated as a hole', () {
    final csv = buildTelemetryCsv(
      history: {
        'power_dc': points([(0, 0)]),
        'soc': points([(0, 50)]),
      },
    );
    expect(lines(csv).last, '2026-10-14 09:00:00,0.0,50.0');
  });

  // **Full precision survives the trip out.** Rounding to the grid's one decimal
  // would destroy the measurement on the way out of the app whose only job is to
  // report what a device said.
  test('keeps the full precision of a fractional reading', () {
    final csv = buildTelemetryCsv(
      history: {
        'voltage_dc': points([(0, 16.53127)]),
      },
    );
    expect(lines(csv).last, '2026-10-14 09:00:00,16.53127');
  });

  test('a NaN or infinite sample is a hole, not the word NaN', () {
    final csv = buildTelemetryCsv(
      history: {
        'power_dc': [
          TelemetryPoint(timestamp: at(0), value: double.nan),
          TelemetryPoint(timestamp: at(1), value: double.infinity),
        ],
      },
    );
    expect(lines(csv).last, '2026-10-14 09:01:00,');
    expect(csv, isNot(contains('NaN')));
    expect(csv, isNot(contains('Infinity')));
  });

  // **Spreadsheet separators.** A semicolon locale or a locale using a decimal
  // comma would import this as a single column, and the file would look like it
  // worked while being unreadable.
  test('uses a dot decimal separator and a comma delimiter', () {
    final csv = buildTelemetryCsv(
      history: {
        'tds_ppm': points([(0, 850.4)]),
      },
    );
    expect(csv, contains('850.4'));
    expect(csv, isNot(contains('850,4')));
  });

  // **Escaping, for the day someone names a device with a comma in it.**
  test('quotes a header that contains a comma', () {
    final csv = buildTelemetryCsv(
      history: {
        'device,name': points([(0, 1)]),
      },
    );
    expect(lines(csv).first, 'time,"device,name"');
  });

  // **Times are local, not UTC.** A sample that arrived at 14:00 local written
  // as 07:00Z disagrees with every other record of the same event.
  test('writes local wall-clock time', () {
    final csv = buildTelemetryCsv(
      history: {
        'power_dc': points([(0, 100)]),
      },
    );
    final stamp = lines(csv).last.split(',').first;
    final parsed = DateTime.parse(stamp);
    expect(parsed.hour, 9);
    expect(parsed.isUtc, isFalse);
  });
}