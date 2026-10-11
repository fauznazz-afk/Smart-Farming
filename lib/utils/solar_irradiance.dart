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

/// The sky conditions this file distinguishes, brightest first.
///
/// **Five because the lux scale spans five decades and the useful distinctions
/// are not linear.** A drop from 100 000 lx to 90 000 is haze; from 10 000 to
/// 1000 is weather. The thresholds are therefore spaced by roughly a factor of
/// three to ten, and each one lands on a lux value a greenhouse grower already
/// knows: 55 000 lx is the first row of a greenhouse roof in full sun, 28 000 is
/// a bright overcast day, 9 000 is a dark one, and 1 800 is a storm.
enum SkyCondition {
  /// ≥ 55 000 lx. Direct sun, sharp shadows.
  clear,

  /// ≥ 28 000 lx. Thin cloud or haze; still bright enough to cast a shadow.
  mostlyClear,

  /// ≥ 9 000 lx. Broken cloud; the sun is behind something.
  partlyCloudy,

  /// ≥ 1 800 lx. A solid sheet; diffuse light, no shadows.
  overcast,

  /// < 1 800 lx. Storm cloud, or a sensor that has been covered.
  heavilyOvercast,
}

/// The condition a lux reading indicates.
SkyCondition skyConditionFor(double lux) {
  if (lux >= 55000) return SkyCondition.clear;
  if (lux >= 28000) return SkyCondition.mostlyClear;
  if (lux >= 9000) return SkyCondition.partlyCloudy;
  if (lux >= 1800) return SkyCondition.overcast;
  return SkyCondition.heavilyOvercast;
}

extension SkyConditionLabel on SkyCondition {
  /// The label, as the UI draws it: short, uppercase, human.
  String get label => switch (this) {
    SkyCondition.clear => 'Clear sky',
    SkyCondition.mostlyClear => 'Mostly clear',
    SkyCondition.partlyCloudy => 'Partly cloudy',
    SkyCondition.overcast => 'Overcast',
    SkyCondition.heavilyOvercast => 'Heavily overcast',
  };
}
