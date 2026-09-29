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
library;

const double kMeaningfulEnergyKwh = 0.1;
