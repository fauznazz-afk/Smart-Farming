/// Which way the pack is moving, as reported by the BMS.
///
/// Pure logic, so the convention is testable. This used to be two comparisons
/// inline in `live_power_card.dart` with a comment asserting a sign convention
/// that had since been invalidated by a BMS swap, which is precisely the kind of
/// claim that survives a month of being wrong.
enum BatteryChargeState {
  charging,
  discharging,
  standby;

  String get label => switch (this) {
    BatteryChargeState.charging => 'Charging',
    BatteryChargeState.discharging => 'Discharging',
    BatteryChargeState.standby => 'Standby',
  };
}

/// Below this magnitude the pack is treated as idle rather than moving.
const kBatteryStandbyWatts = 1.0;

/// Classifies a signed battery power reading into one of three states.
///
/// ## The sign convention is measured, not assumed
///
/// This is the second convention this pack has had, and the two are opposite:
///
///  * **27 September 2026, previous BMS.** `Power -12.92 W` while the state of
///    charge was *rising* to 69 %. Negative meant charging.
///  * **27 September 2026, current BMS.** `Power -22 W` while the state of charge
///    was *falling*. Negative means discharging.
///
/// Only the SOC trend settles which is which; the sign on its own cannot, and
/// most people assume the opposite of the first reading. `AGENTS.md` recorded the
/// risk in advance — the convention was measured on one device, and replacing the
/// BMS would invert every battery display in the app. That is what happened.
///
/// So: **negative is discharging, positive is charging.** If you replace the BMS
/// again, do not edit this function from a screenshot. Watch the state of charge
/// for a minute, note which way it moves while the sign is fixed, and update
/// `test/battery_sign_convention_test.dart` with the measurement in the reason.
///
/// Three states rather than two, because the pack genuinely sits at zero for
/// stretches and the sign of a zero reading is noise: a two-state version flips
/// between two labels several times a minute while asserting a direction the data
/// does not establish. Standby is the state that gets skipped, and the one this
/// BMS reports most often.
BatteryChargeState batteryChargeState(
  double watts, {
  double standbyWatts = kBatteryStandbyWatts,
}) {
  if (watts < -standbyWatts) return BatteryChargeState.discharging;
  if (watts > standbyWatts) return BatteryChargeState.charging;
  return BatteryChargeState.standby;
}
