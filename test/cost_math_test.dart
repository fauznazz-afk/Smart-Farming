import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/energy_helpers.dart';

/// The money and performance arithmetic behind the cost card.
///
/// ## Why these need pinning at all
///
/// Every one of them has a null case that is *deliberate* — a missing tariff, a
/// missing nameplate — and a null case is the one that produces a plausible,
/// wrong number rather than a crash. A card that quietly says `Rp 0` every
/// morning because a setting was never filled in is worse than no card.
void main() {
  group('moneyForPeriod', () {
    test('prices generation and consumption at the same tariff', () {
      final money = moneyForPeriod(
        solarKwh: 12.0,
        loadKwh: 8.0,
        tariffPerKwh: 1500,
      )!;
      expect(money.solarValue, 18000);
      expect(money.loadCost, 12000);
      expect(money.balance, 6000);
    });

    // **A house that draws more than the array makes is an ordinary night, not
    // an alarm.** Clamping the balance at zero would quietly delete half the
    // year.
    test('a negative balance stays negative', () {
      final money = moneyForPeriod(
        solarKwh: 1.0,
        loadKwh: 9.0,
        tariffPerKwh: 1500,
      )!;
      expect(money.balance, -12000);
    });

    // **Unset tariff is null, not zero.** The card is hidden in this case and
    // "Rp 0" would read as a measurement.
    test('an unset or non-positive tariff yields nothing', () {
      for (final tariff in [null, 0.0, -100.0]) {
        expect(
          moneyForPeriod(solarKwh: 12, loadKwh: 8, tariffPerKwh: tariff),
          isNull,
          reason: 'tariff $tariff must not produce a figure',
        );
      }
    });

    test('NaN inputs yield nothing', () {
      expect(
        moneyForPeriod(
          solarKwh: double.nan,
          loadKwh: 8,
          tariffPerKwh: 1500,
        ),
        isNull,
      );
    });
  });

  group('pvPerformance', () {
    test('full load hours are energy over nameplate', () {
      // 10 kWh from a 5 kW array is two hours at full output.
      final performance = pvPerformance(
        solarKwh: 10.0,
        installedWp: 5000,
        hours: 24,
      )!;
      expect(performance.fullLoadHours, closeTo(2.0, 0.001));
      expect(performance.capacityFactor, closeTo(2.0 / 24, 0.001));
    });

    // **The morning case.** At 09:00 a day window is nine hours, and dividing
    // by 24 would report the array as a quarter of its real output. This is
    // why the caller passes the window's real length rather than a flat 24.
    test('a part-day window divides by the hours that have happened', () {
      final performance = pvPerformance(
        solarKwh: 4.5,
        installedWp: 5000,
        hours: 9,
      )!;
      expect(performance.capacityFactor, closeTo(0.1, 0.001));
    });

    test('a missing or zero nameplate yields nothing', () {
      for (final wp in [null, 0.0, -500.0]) {
        expect(
          pvPerformance(solarKwh: 10, installedWp: wp, hours: 24),
          isNull,
          reason: 'nameplate $wp must not produce a ratio',
        );
      }
    });

    test('a zero-length window yields nothing rather than dividing by zero', () {
      expect(
        pvPerformance(solarKwh: 10, installedWp: 5000, hours: 0),
        isNull,
      );
    });
  });

  group('rupiah', () {
    test('groups thousands with a dot', () {
      expect(rupiah(0), 'Rp 0');
      expect(rupiah(999), 'Rp 999');
      expect(rupiah(1000), 'Rp 1.000');
      expect(rupiah(1234567), 'Rp 1.234.567');
    });

    // **The sign carries meaning** — the balance is routinely negative at night,
    // and a currency formatter that drops the sign would print a house that
    // draws more than the array makes as though it were a saving.
    test('a negative amount keeps its sign', () {
      expect(rupiah(-12400), '-Rp 12.400');
      expect(rupiah(-1000), '-Rp 1.000');
    });

    // **Sub-rupiah is dropped rather than rounded.** The grid meters whole
    // rupiah; showing "Rp 1.500,67" would claim a precision nobody has.
    test('drops the fraction', () {
      expect(rupiah(1500.67), 'Rp 1.501');
    });

    test('NaN prints a dash rather than Rp NaN', () {
      expect(rupiah(double.nan), '--');
    });
  });
}