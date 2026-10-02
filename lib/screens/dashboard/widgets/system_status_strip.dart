import 'package:flutter/material.dart';

import '../../../utils/battery_sign.dart';
import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import 'shortcut.dart';

/// Snapshot values shown for the battery.
///
/// Carries `power` and not just `current` because the charge direction has to be
/// read from the same key the hero card reads. This used to derive it from
/// `current < 0`, which was a second, independent interpretation of the BMS sign
/// using a different telemetry key: the hero card said one thing and this strip
/// said the opposite, on the same screen, from the same pack. Two readings of one
/// measurement is worse than either being alone.
///
/// **Every field is nullable, and that is the whole point of this record.** They
/// were `double` with `?? 0.0` at the call site, so a BMS that had never
/// reported -- a fresh install, or a pack that dropped off the Bluetooth link --
/// rendered as a red **0%** beside `min 20%` and a `battery_alert` glyph. That
/// is a critical claim about the pack, manufactured out of an absence, and it
/// contradicted the two widgets above and below it on the same screen:
/// `LivePowerCard` prints `Power flow unavailable until the inverter reports`
/// when its reading is missing, and `MetricGrid` prints `--` with a `Stale data`
/// tag. Three widgets, one page, two different answers to "what does absence
/// mean", and the most alarming of them belonged to the one that had been handed
/// a non-nullable field.
///
/// A missing reading is not a zero. `0%` says the pack is empty; `--` says the
/// pack is not talking to us, and only the second of those is something a user
/// can act on.
typedef BatteryStatus = ({
  double? soc,
  double? voltage,
  double? current,
  double? power,
});

/// Snapshot values shown for the AC side.
///
/// Nullable for the same reason as [BatteryStatus]. `voltage` and `frequency`
/// are the two that decide the grid verdict, so those are the two where
/// fabricating a zero turns "we cannot tell" into "unstable".
typedef AcStatus = ({
  double? voltage,
  double? current,
  double? power,
  double? frequency,
});

/// One-line verdicts for the three things a user checks on a glance.
///
/// This replaced two side-by-side cards that were about 200 px tall, and the
/// duplication was the reason: the hero card already showed a SOC gauge, the
/// battery page already had voltage and current, and the AC page had voltage,
/// current, power and frequency. So the one thing this section actually added
/// was a stable-or-not verdict on the grid, and it cost 200 px to say it.
///
/// A verdict also ages better than raw numbers. A row of readings is something
/// the user has to interpret every time; "STABIL" is not.
class SystemStatusStrip extends StatelessWidget {
  const SystemStatusStrip({
    super.key,
    required this.battery,
    required this.ac,
    required this.theme,
    required this.seedColor,
    required this.onOpenBattery,
    required this.lowSocThreshold,
    required this.activeAlerts,
  });

  final BatteryStatus battery;
  final AcStatus ac;

  /// The appearance to paint, as an `AppTheme`.
  ///
  /// Required because the strip's own `AppCard` draws the `raised` pair and a
  /// hairline, and both have a separately derived Dracula set. The three
  /// verdicts and the two rules between them pass `theme.isDark` down, since a
  /// status colour is shared by the two dark presets.
  final AppTheme theme;

  final Color seedColor;
  /// Takes the user to the battery readings.
  ///
  /// A bare callback rather than a page index, because Battery is no longer a
  /// destination of its own: it is a view inside the Power tab, so getting there
  /// takes two steps and only the screen knows what they are. Hard-coding an index
  /// here is how this widget ended up pointing at the wrong tab the moment the
  /// navigation changed.
  final VoidCallback onOpenBattery;

  /// The user's low-SOC limit, so the verdict says what it is judged against.
  final double lowSocThreshold;

  /// How many alarms are currently active, or zero.
  final int activeAlerts;

@override
  Widget build(BuildContext context) {
    // **Absence is now a third state, not a zero.** Both of these used to be
    // computed from `double` fields that the call site filled with `?? 0.0`, so a
    // device that had never reported was indistinguishable from a device reading
    // zero -- and both comparisons fail on zero, so an absent battery rendered as
    // a red `0%` with `battery_alert` and an absent meter as a red `Unstable`.
    //
    // `ok` is therefore `bool?`, not `bool`: `null` is "no reading", and it is
    // deliberately neither of the other two. It is not coloured as good (green
    // means a problem is absent, and the user did not choose that colour) and it
    // is not coloured as bad (nothing is wrong with the pack; it is not talking).
    // Ordinary text and a faint glyph, which is what `MetricGrid` does with its
    // `--` and its `Stale data` tag.
    final soc = battery.soc;
    final voltage = ac.voltage;
    final frequency = ac.frequency;

    final bool? batteryOk =
        soc == null ? null : soc >= lowSocThreshold;
    final bool? gridOk = (voltage == null || frequency == null)
        ? null
        : (frequency - 50).abs() < 2 && voltage > 200 && voltage < 240;

    // One interpretation, shared with the hero card. The three states rather than
    // the old `current < 0` binary, because this BMS reports 0.00 A for stretches
    // while idling and a bare comparison flips the label several times a minute
    // while asserting a direction the data does not establish.
    //
    // Only consulted when the pack is actually reporting: `batteryChargeState`
    // takes a `double` for a reason, and passing a fabricated zero in here to
    // keep the call total would put the pack in standby when in fact we have not
    // heard from it.
    final chargeState =
        battery.power == null ? null : batteryChargeState(battery.power!);
    final charging = chargeState == BatteryChargeState.charging;

    return DashboardShortcut(
      onTap: onOpenBattery,
      semanticLabel: 'Battery and grid status. Opens the battery readings.',
      child: AppCard(
        theme: theme,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _Verdict(
              // Low charge is the actionable state, so the alert glyph wins over
              // the direction glyph. Previously the icon was a full charging
              // battery whenever the SOC was healthy, which drew a battery
              // charging on a pack that was discharging - a third signal, and the
              // one most likely to be read before the label.
              //
              // A missing reading gets a cloud glyph rather than `battery_alert`,
              // because that glyph means "low" and the pack is not known to be
              // low. It was the glyph being drawn next to a fabricated 0%.
              icon: batteryOk == null
                  ? Icons.cloud_off_rounded
                  : !batteryOk
                      ? Icons.battery_alert
                      : switch (chargeState!) {
                          BatteryChargeState.charging =>
                            Icons.battery_charging_full,
                          BatteryChargeState.discharging =>
                            Icons.battery_5_bar_rounded,
                          BatteryChargeState.standby =>
                            Icons.battery_std_rounded,
                        },
              // Only charging is worth naming here. Standby and discharging both
              // read as "Battery", which says less than the hero card but never
              // contradicts it.
              label: charging ? 'Charging' : 'Battery',
              value: soc == null ? '--' : '${soc.toStringAsFixed(0)}%',
              ok: batteryOk,
              // The threshold is printed because "baterai 18%" means nothing on
              // its own; whether that is a problem is the user's setting. With no
              // reading there is nothing to judge against, so it is not shown -
              // printing `min 20%` under a `--` invites reading it as a verdict.
              detail: soc == null
                  ? 'not reporting'
                  : 'min ${lowSocThreshold.toStringAsFixed(0)}%',
              isDark: theme.isDark,
              seedColor: seedColor,
            ),
            _divider(theme),
            _Verdict(
              icon: switch (gridOk) {
                null => Icons.cloud_off_rounded,
                true => Icons.check_circle_outline,
                false => Icons.error_outline,
              },
              label: 'AC grid',
              value: switch (gridOk) {
                null => '--',
                true => 'Stable',
                false => 'Unstable',
              },
              ok: gridOk,
              detail: (voltage == null || frequency == null)
                  ? 'not reporting'
                  : '${voltage.toStringAsFixed(0)} V \u00b7 '
                      '${frequency.toStringAsFixed(0)} Hz',
              isDark: theme.isDark,
              seedColor: seedColor,
            ),
            if (activeAlerts > 0) ...[
              _divider(theme),
              _Verdict(
                icon: Icons.notifications_active,
                label: 'Alarm',
                value: '$activeAlerts',
                ok: false,
                detail: 'active',
                isDark: theme.isDark,
                seedColor: seedColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The one-pixel rule between two verdicts.
  ///
  /// `AppTheme`, not `bool`, because `appDivider` keys on the theme and Dracula
  /// reuses the dark white rather than carrying a third value — see
  /// [appDivider]. The opacity is still keyed on brightness alone, unchanged:
  /// 0.10 on both dark presets, 0.08 in light.
  Widget _divider(AppTheme theme) => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: appDivider(theme: theme, opacity: theme.isDark ? 0.10 : 0.08),
  );
}

/// An icon, a headline verdict, and one line of supporting detail.
///
/// `ok` is tri-state and the third state is the interesting one. `null` means
/// "nothing is reporting", and it renders as ordinary text with a faint glyph:
/// not the status colour, because nothing has gone wrong, and not the accent,
/// because the accent here means "this verdict is good" and we do not know that.
/// Treating an absence as `false` is what produced a red `0%` and a red
/// `Unstable` for a device that had simply not spoken yet.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    required this.detail,
    required this.isDark,
    required this.seedColor,
  });

  final IconData icon;
  final String label;
  final String value;
  /// `null` for "no reading". See the class doc.
  final bool? ok;
  final String detail;
  final bool isDark;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    // The verdict is a warning, so only a warning is coloured. A healthy
    // reading is printed in ordinary text and the tick stays green.
    //
    // The value used to take the status colour unconditionally, which put three
    // green elements next to an amber theme's amber everything and read as two
    // unrelated colour systems. "70%" is not a status; whether 70% is enough is
    // the user's own threshold, and the icon already says it is fine. A low
    // battery still turns the number red, which is the case that matters.
    // **Three cases, not two, and the third one is the point of `bool?`.**
    //
    // `false` is the only one that gets a status colour, and `false` now means
    // "we measured it and it is wrong" rather than "we did not get a number".
    // `null` gets ordinary text: nothing is wrong with the pack, it is simply not
    // answering, and colouring that would be a false alarm about the hardware.
    final color = switch (ok) {
      null => appPrimaryText(isDark),
      true => appPrimaryText(isDark),
      false => statusBad(isDark),
    };
    // Same rule for the icon: the accent when the verdict is good, a status
    // colour when it is bad, and faint when there is nothing to judge. A green
    // tick beside an amber theme is the clearest statement that two palettes are
    // on screen at once, and it says nothing the icon shape does not already say.
    final iconColor = switch (ok) {
      null => faintColor(isDark),
      true => themeColor(seedColor: seedColor, lightness: isDark ? 0.68 : 0.38),
      false => statusBad(isDark),
    };
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // **Every one of these three lines was `maxLines: 1` with
          // `ellipsis`, and all three of them were cut on the device.**
              //
              // Measured on the Xiaomi 24090RA29G at a 2.0 system font, with the
              // card at its real width inside the page's 24 dp margins:
              // `Bat...` for Battery, `AC ...` for AC grid, `Ala...` for Alarm,
              // `Sta...` for the word **Stable**, `min 1...` for the minimum
              // state of charge and `221 V ...` for the mains reading. This widget
              // had no test at all, so nothing in the suite could have noticed,
              // and the plainest reading of the screen at that font scale is a
              // grid of fragments.
              //
              // The three are treated differently on purpose, because they are
              // not three copies of the same kind of text:
              //
              //  * the **label** is a category name, one or two words, so it is
              //    allowed to wrap onto a second line. `AC grid` on two lines is
              //    a legible caption; `AC ...` is not a caption at all.
              //  * the **value** is the verdict, and it is the one thing on this
              //    strip that must not be ambiguous. `Stable` and `Unstable` are
              //    the whole claim, and `Sta...` cannot be told from `Standby` or
              //    from a truncated `Stable` of something else. It scales down
              //    instead, which is the same trade the hero card's figure makes
              //    and for the reason `AGENTS.md` records: a cut-off reading is
              //    worse than a small one, because a cut one can be mistaken for
              //    a different reading.
              //  * the **detail** is supplementary and already two facts on one
              //    line (`221 V · 50 Hz`), so it wraps to two lines.
              //
              // `maxLines: 2` rather than unbounded so a long value cannot grow
              // the strip without limit, and no `ellipsis` anywhere: if two lines
              // still cannot hold it, scaling is the honest answer, and this
              // widget is three equal columns of a dashboard rather than prose.
              //
              // **Wrapping was tried first and does not work here, which is worth
              // recording because it is the obvious thing to reach for.** The
              // three columns are `Expanded`, so at 320 dp with the page margin
              // each is about 85 dp, and the labels are single words: `Battery`
              // cannot wrap at all, it can only be cut. The measurement said
              // `{'Battery': 'B...', 'AC grid': 'A...'}`. So all three fields
              // scale instead, and the only rigid parts left in a column are
              // three `SizedBox`es of a few dp.
              Row(
                children: [
                  Icon(icon, size: 13, color: iconColor),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          color: faintColor(isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    detail,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 10, color: faintColor(isDark)),
                  ),
                ),
              ),
            ],
          ),
      );
  }
}
