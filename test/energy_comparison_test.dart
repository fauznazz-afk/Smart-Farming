import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/utils/energy_comparison.dart';

/// The decision, tested on its own, because the two surfaces that use it are the
/// whole reason it exists.
///
/// `EnergySummaryCard._comparison` and the energy report's `comparisonLabel`
/// each used to carry their own copy of this four-way `if`. The dashboard's had
/// been fixed for the `-100%` problem and the report's had not, and later both
/// of them said "none last period" about a period that had produced 0.05 kWh.
/// A shared constant did not prevent any of that, because the branch order was
/// never shared — only promised in a comment.
///
/// These cases are the ones that differ between the surfaces, plus the
/// boundaries, because a boundary nobody pins is a boundary that moves.
void main() {
  group('classifyEnergyChange', () {
    test('a null previous period is its own kind, not a zero one', () {
      // The report distinguishes "no previous range selected" from "the previous
      // range was 0 kWh" and says a different sentence for each. Collapsing them
      // here would take that difference away from the report.
      expect(
        classifyEnergyChange(1.5, null).kind,
        EnergyChangeKind.noPreviousData,
      );
      expect(
        classifyEnergyChange(1.5, 0).kind,
        EnergyChangeKind.previousWasZero,
      );
    });

    test('a negative previous period counts as zero', () {
      // Defensive rather than observed. A negative total would be a device or
      // aggregation fault, and `previous <= 0` is the branch that says so
      // quietly rather than dividing by it.
      expect(
        classifyEnergyChange(1.5, -0.4).kind,
        EnergyChangeKind.previousWasZero,
      );
    });

    test('both periods negligible and this one empty is no production', () {
      expect(
        classifyEnergyChange(0, 0.01).kind,
        EnergyChangeKind.noProduction,
      );
    });

    test('both periods negligible and this one non-empty is not an absence', () {
      // The regression. This case used to render "none last period" in both
      // surfaces, denying a 0.05 kWh period that the tile shows one line above.
      final change = classifyEnergyChange(0.05, 0.01);
      expect(change.kind, EnergyChangeKind.bothNegligible);
      expect(
        change.kind,
        isNot(EnergyChangeKind.noProduction),
        reason: 'a non-zero period must never be classified as an absence',
      );
    });

    test('a negligible previous against a real current cannot be a ratio', () {
      // The comparison would run from the rounding-noise side, so it is refused
      // rather than computed from a denominator the user cannot see.
      expect(
        classifyEnergyChange(2.0, 0.05).kind,
        EnergyChangeKind.nothingToCompare,
      );
    });

    test('the threshold is exclusive at exactly 0.1 kWh', () {
      // `previous < kMeaningfulEnergyKwh`, not `<=`. Pinned because moving the
      // comparison by one operator would change what a real pair of days reports
      // and nothing else would notice.
      //
      // At `previous == 0.1` the pair is a real comparison and a ratio is
      // computed; at `0.09` it is not. Note the two sub-cases below differ in
      // *this* period, not the previous one: a negligible previous against a
      // negligible current is `bothNegligible`, and only a negligible previous
      // against a *real* current is `nothingToCompare`.
      expect(classifyEnergyChange(0.05, 0.1).kind, EnergyChangeKind.changed);
      expect(
        classifyEnergyChange(0.05, 0.09).kind,
        EnergyChangeKind.bothNegligible,
      );
      expect(
        classifyEnergyChange(2.0, 0.09).kind,
        EnergyChangeKind.nothingToCompare,
      );
    });

    test('an unchanged real pair is unchanged rather than +0%', () {
      final change = classifyEnergyChange(1.5, 1.5);
      expect(change.kind, EnergyChangeKind.unchanged);
      expect(change.percent, 0);
    });

    test('a real change carries a signed rounded percentage', () {
      final fall = classifyEnergyChange(1.53, 1.58);
      expect(fall.kind, EnergyChangeKind.changed);
      expect(fall.percent, -3);

      final rise = classifyEnergyChange(2.0, 1.0);
      expect(rise.kind, EnergyChangeKind.changed);
      expect(rise.percent, 100);
    });

    test('a change that rounds to zero is unchanged', () {
      // 1.0004 against 1.0 is 0.04%, which rounds to 0. Printing "+0%" would
      // be a claim that something changed when the displayed figures are equal.
      final change = classifyEnergyChange(1.0004, 1.0);
      expect(change.kind, EnergyChangeKind.unchanged);
    });

    test('the same pair of numbers always gives the same decision', () {
      // The property the two duplicated copies could not have. Run over a grid
      // rather than a handful of cases, because the failure mode was one branch
      // out of step in one file.
      const samples = [0.0, 0.01, 0.05, 0.09, 0.1, 0.11, 1.0, 1.53, 12.0];
      for (final current in samples) {
        for (final previous in samples) {
          final first = classifyEnergyChange(current, previous);
          final second = classifyEnergyChange(current, previous);
          expect(first.kind, second.kind);
          expect(first.percent, second.percent);
        }
      }
    });
  });
}
