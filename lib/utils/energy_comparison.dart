/// The energy comparison threshold, shared by everything that compares two
/// periods of production.
///
/// Below this, two periods are both too small for a ratio to mean anything. A
/// tenth of a kilowatt-hour is 360 Wh; under it both figures are rounding noise,
/// and a percentage would only dramatise a number displayed to two decimals.
///
/// **This exists as one constant because it used to be two.** The dashboard's
/// `EnergySummaryCard` and the energy report's `comparisonLabel` each held their
/// own `0.1` literal, and the card's copy was the one that had already been
/// fixed for the "-100% from the previous period" problem while the report's had
/// not. The dashboard and the report are showing the reader the same two numbers
/// in the same session, so two copies of the threshold are two chances to
/// disagree about whether a change was a catastrophe or a rounding artefact —
/// which is exactly the failure that was already live in one of the two places.
///
/// The wording is deliberately *not* shared: the card's two tiles sit side by
/// side and wrap independently, so its caption is short, while the report label
/// has a full line. Only the decision has to be the same decision.
///
/// **And the decision is shared now, which the paragraph above only promised.**
/// The threshold had been extracted; the *branch order* had not. Both surfaces
/// carried their own copy of the same four-way `if`, and a comment in the report
/// said they "cannot disagree" — which was an assertion about a convention, not
/// anything a compiler or a test could check. They did disagree: the branch
/// reached when both periods are under the threshold and this one is non-zero
/// said "none last period" in **both** files, which denies a figure the tile is
/// displaying one line above. Fixing it in one place would have left the other
/// lying, which is the same failure this file exists to end.
library;

const double kMeaningfulEnergyKwh = 0.1;

/// What two periods of production are actually saying, before any surface words
/// it.
///
/// Separate from [EnergyChange] because the kind carries no data and the
/// percentage has nowhere to live in an enum.
enum EnergyChangeKind {
  /// There is no previous period at all — the first one the user ever selected.
  noPreviousData,

  /// The previous period is recorded as zero energy.
  previousWasZero,

  /// Both periods are under [kMeaningfulEnergyKwh] and this one produced
  /// nothing at all.
  noProduction,

  /// Both periods are under [kMeaningfulEnergyKwh] and **neither is empty**.
  ///
  /// This is the case that was mislabelled "none last period". The threshold
  /// exists because a ratio between two rounding-noise figures is meaningless;
  /// it does not mean the energy was absent, and a surface that says "none"
  /// about a period showing `0.05 kWh` is stating something the number above it
  /// contradicts.
  bothNegligible,

  /// The previous period is under the threshold and this one is not, so the
  /// comparison would run from the rounding-noise side.
  nothingToCompare,

  /// A real change that rounds to zero percent.
  unchanged,

  /// A real change; [EnergyChange.percent] is signed and non-zero.
  changed,
}

/// The outcome of comparing two periods: what kind of comparison it is, and the
/// signed percentage when there is one.
class EnergyChange {
  const EnergyChange(this.kind, {this.percent = 0});

  final EnergyChangeKind kind;

  /// Signed, rounded, and non-zero only for [EnergyChangeKind.changed].
  final int percent;
}

/// Classifies [current] against [previous] once, for every surface that shows
/// the pair.
///
/// [previous] is nullable because the energy report has a genuine "no previous
/// period selected" state and the dashboard's tile does not. Both are
/// represented rather than collapsed, so a surface that wants to treat them
/// differently still can — but neither has to re-derive which one it is looking
/// at.
EnergyChange classifyEnergyChange(double current, double? previous) {
  if (previous == null) {
    return const EnergyChange(EnergyChangeKind.noPreviousData);
  }
  if (previous <= 0) {
    return const EnergyChange(EnergyChangeKind.previousWasZero);
  }
  if (previous < kMeaningfulEnergyKwh) {
    if (current < kMeaningfulEnergyKwh) {
      return EnergyChange(
        current <= 0
            ? EnergyChangeKind.noProduction
            : EnergyChangeKind.bothNegligible,
      );
    }
    return const EnergyChange(EnergyChangeKind.nothingToCompare);
  }
  final percent = ((current - previous) / previous * 100).round();
  return EnergyChange(
    percent == 0 ? EnergyChangeKind.unchanged : EnergyChangeKind.changed,
    percent: percent,
  );
}
