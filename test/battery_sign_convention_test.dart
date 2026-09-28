import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/utils/battery_sign.dart';

/// Pins the battery sign convention, which has now been measured twice and was
/// opposite both times.
///
/// `AGENTS.md` warned in advance that the convention was measured on a single
/// device and that replacing the BMS would invert every battery display without
/// a single red indicator. That is exactly what happened: a month of comments
/// asserting "negative means charging" outlived the hardware they described, and
/// the hero card labelled a discharging pack as charging.
///
/// A comment cannot fail. This can.
void main() {
  group('batteryChargeState', () {
    test('negative watts mean DISCHARGING on the current BMS', () {
      // Measured 27 September 2026 on the Xiaomi 24090RA29G: the card read
      // `Power -22 W` while the state of charge was falling. Falling SOC plus
      // negative watts is discharging, whatever the sign convention is.
      expect(batteryChargeState(-22), BatteryChargeState.discharging);
      expect(batteryChargeState(-1.5), BatteryChargeState.discharging);
      expect(batteryChargeState(-120), BatteryChargeState.discharging);
    });

    test('positive watts mean CHARGING on the current BMS', () {
      // The corollary of the measurement above, not an assumption: a pack taking
      // power in is charging by definition of the word.
      expect(batteryChargeState(22), BatteryChargeState.charging);
      expect(batteryChargeState(1.5), BatteryChargeState.charging);
      expect(batteryChargeState(120), BatteryChargeState.charging);
    });

    test('a near-zero reading is standby, not a coin toss', () {
      // The pack genuinely idles, and the sign of a zero reading is noise. A
      // two-state version flipped between two labels several times a minute while
      // asserting a direction the data does not establish. Standby is the state
      // that gets skipped, and this BMS reports it most often.
      expect(batteryChargeState(0), BatteryChargeState.standby);
      expect(batteryChargeState(-0.0), BatteryChargeState.standby);
      expect(batteryChargeState(0.9), BatteryChargeState.standby);
      expect(batteryChargeState(-0.9), BatteryChargeState.standby);
    });

    test('the deadband boundary is exclusive on both sides', () {
      // Exactly at the threshold is not yet moving. Pinned because widening or
      // narrowing the band changes how often the card says Standby, and a pack
      // idling at 1.4 W would otherwise read as a direction it has not taken.
      expect(batteryChargeState(-kBatteryStandbyWatts), BatteryChargeState.standby);
      expect(batteryChargeState(kBatteryStandbyWatts), BatteryChargeState.standby);
      expect(
        batteryChargeState(-kBatteryStandbyWatts - 0.01),
        BatteryChargeState.discharging,
      );
      expect(
        batteryChargeState(kBatteryStandbyWatts + 0.01),
        BatteryChargeState.charging,
      );
    });

    test('the previous BMS had the opposite convention', () {
      // This is the regression, stated as a fact about history rather than as a
      // wish. Under the pack measured on 27 September 2026 the same input mapped
      // the other way, so if a future BMS brings that back, these two expectations
      // are what must change together — and the reason string on the failure is
      // the measurement to redo.
      expect(
        batteryChargeState(-12.92),
        BatteryChargeState.discharging,
        reason:
            'If the pack is CHARGING while reading negative again, the BMS was '
            'swapped back. Watch the state of charge for a minute, confirm the '
            'direction, then flip batteryChargeState and this expectation '
            'together. Do not flip it from a screenshot.',
      );
    });
  });

  group('BatteryChargeState.label', () {
    test('is the word shown on the hero card', () {
      expect(BatteryChargeState.charging.label, 'Charging');
      expect(BatteryChargeState.discharging.label, 'Discharging');
      expect(BatteryChargeState.standby.label, 'Standby');
    });
  });
}
