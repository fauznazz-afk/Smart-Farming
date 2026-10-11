/// Solar irradiance estimated from a lux reading, and what that says about the
/// sky.
///
/// **Why this exists.** A greenhouse dashboard already shows lux, but lux is a
/// number the user has no feel for — 40 000 lx means nothing, 412 W/m² means
/// "the panel could be producing that". The conversion is the whole point, and
/// it is why this file is pure: it takes a number and returns a reading, which
/// is what `test/` can cover without a sensor.
///
/// ## The conversion, and what it is not
///
/// A lux meter is a **photometric** sensor: it weights every wavelength by the
/// eye's sensitivity, which peaks at 555 nm in the green and is blind to the
/// near-infrared that carries roughly half of the sun's energy. A pyranometer
/// is **radiometric** and flat across the band. So lux → W/m² is not a physical
/// identity, it is an empirical one — and it is only valid for one source.
///
/// For sunlight the luminous efficacy is about **93 lm/W**, which makes
///
///     irradiance ≈ lux / 93
///
/// and puts a clear noon — 100 000 lx — within a few percent of the 1000 W/m²
/// that defines "one sun". That single property is the justification. The usual
/// shortcut, lux / 100, is the same claim rounded, and the difference is 7%,
/// which is larger than the spread between a hazy noon and a thin-cloud one.
///
/// **Indoor readings break it in both directions**, and nothing in this file
/// tries to fix that. A white LED peaks exactly where the eye is most sensitive,
/// so a room can report 2000 lx while a cloudy sky reports less — the ratio is
/// right and the answer is still nonsense. That is not a failure of the
/// conversion, it is the conversion being asked about the wrong light, and the
/// honest handling is what the call site does: a greenhouse lux sensor pointing
/// at the sky is sunlight by construction.
///
/// No `package:flutter` import here, deliberately: a `Color` would put a
/// presentation decision in this file, and it lives in
/// `screens/dashboard/utils/color_helpers.dart` with the rest of them.
library;

/// The luminous efficacy of sunlight, in lumens per watt.
const double sunlightLuminousEfficacy = 93.0;

/// Convert a lux reading to solar irradiance in W/m².
///
/// **Clamped at zero, because a negative reading is not a negative sun.** The
/// sensors this app reads report a small negative value in the dark (the BMS
/// reports `-0.01 A` while idle, and the light sensor does the same), and
/// `-0.9 W/m²` on a panel output is a number nobody can act on.
double luxToIrradiance(double lux) =>
    lux <= 0 ? 0 : lux / sunlightLuminousEfficacy;

/// The irradiance of a clear sky at solar noon: the reference "one sun".
///
/// 1000 W/m² is the standard test condition for a PV module and the number the
/// whole panel industry quotes against, so a bar scaled by it answers the
/// question the user actually has — *what fraction of the panel's rated output
/// is the sky currently offering?*
const double oneSunWm2 = 1000.0;

/// How bright the sky is, as a fraction of one sun.
///
/// **Clamped at 1.0, because the panel cannot receive more than one sun.** An
/// un-clamped bar on a 200 000 lx reading overflows the track it is drawn in.
double sunFraction(double lux) =>
    (luxToIrradiance(lux) / oneSunWm2).clamp(0.0, 1.0);

/// What a lux reading says about the sky.
///
/// **Three daylight states and a night, not five states on one ladder.** The
/// lux scale spans five decades and the distinctions are wildly non-linear: a
/// drop from 100 000 lx to 90 000 is haze, while a drop from 10 000 to 1 000
/// is the weather changing. That spread is the reason not to enumerate bands —
/// each extra step needs a lux number of its own, and each number is a threshold
/// the grower has to be able to picture, or it is just a number.
///
/// The three daylight states are the only distinctions that change what anyone
/// does:
///
/// - is the array getting anything worth harvesting (**overcast**, or **clear**
///   which is the top of the same question),
/// - is it partial, so a battery is worth filling now while the diffuse light
///   lasts (**partlyCloudy**),
/// - is it just daylight at all (**night**).
///
/// Haze versus thin cloud versus broken cloud versus a solid sheet were four
/// ways of answering "is it bright", and the answer to that is already on the
/// card as a number. The label is not where a reading repeats itself.
///
/// **`night` is a different kind of reading, not another rung.** It is the
/// absence of a measurement of the sky rather than a dimmer sky, which is why
/// it is not `overcast` with a low threshold — and why it is also where a
/// covered or failed sensor lands, since both look identical from here. The
/// old `heavilyOvercast` band tried to be that state as a step on the ladder
/// and was wrong twice: it claimed a storm at 1 800 lx, which is not what 1 800
/// lx is, and it swallowed the 0 lx covered-sensor case into a weather word.
///
/// **`overcast` therefore covers both ends.** A solid sheet at 9 000 lx and a
/// nearly-dark 3 lx both mean *there is light, and it is not sunny*; there is
/// no action a grower would take about the difference. If that band is ever
/// found to be too wide, widen it with a number from a measurement, not by
/// adding a state back.
enum SkyCondition {
  /// Direct sun.
  clear,

  /// Broken cloud; the sun is behind something but still contributes.
  partlyCloudy,

  /// A solid sheet; diffuse light, no shadows.
  overcast,

  /// No usable light at all — night, or the sensor is covered/dark.
  night,
}

/// The condition a lux reading indicates.
///
/// **Reads the raw lux, and `<= 0` is `night`, because that is the only way to
/// reach it.** The same sensors that report `-0.01 A` from an idle BMS report a
/// small negative lux in the dark; a `< 0` test would classify that night as a
/// dim overcast afternoon. `luxToIrradiance` clamps the same readings at zero,
/// so the two agree by construction — the difference is that this one says so
/// out loud instead of inheriting it.
///
/// One lux is `overcast`, not `night`, and that boundary is the point: a lux
/// reading is not a test for "is the sun up", it is a measurement of what
/// arrived, and one lux did arrive.
SkyCondition skyConditionFor(double lux) {
  if (lux >= 28000) return SkyCondition.clear;
  if (lux >= 9000) return SkyCondition.partlyCloudy;
  if (lux > 0) return SkyCondition.overcast;
  return SkyCondition.night;
}

extension SkyConditionLabel on SkyCondition {
  /// The label, as the UI draws it: short, sentence case, no punctuation, since
  /// it sits inline in a card and is not a heading.
  String get label => switch (this) {
    SkyCondition.clear => 'Clear',
    SkyCondition.partlyCloudy => 'Partly cloudy',
    SkyCondition.overcast => 'Overcast',
    SkyCondition.night => 'Night',
  };

  /// Whether there is usable daylight, i.e. anything other than [SkyCondition.night].
  ///
  /// Exists so a call site can ask the question without listing three values
  /// and getting the fourth wrong when one is added.
  bool get isDaylight => this != SkyCondition.night;
}
