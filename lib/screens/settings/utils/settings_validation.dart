import 'package:flutter/widgets.dart';

/// A min/max limit pair for one environment sensor.
class EnvRangeSetting {
  EnvRangeSetting({
    required this.id,
    required this.label,
    required this.unit,
    this.minAllowed,
    this.maxAllowed,
    this.minKey,
    this.maxKey,
    double? defaultMin,
    double? defaultMax,
  }) : min = TextEditingController(text: _format(defaultMin)),
       max = TextEditingController(text: _format(defaultMax)),
       // A default typed into the field is not yet a limit. It only becomes one
       // when Settings writes it out, and until then the alarm engine reads the
       // key, finds nothing, and treats the sensor as unmonitored. So a field
       // holding a default starts out flagged as inactive, and the flag is only
       // cleared by a load that actually found a stored value.
       //
       // Without this the screen showed a number for a limit that was not armed:
       // a user who saved their settings before a limit existed kept seeing the
       // new default in the field, and reasonably concluded the tank was
       // guarded. It was found on a test device reading 2396 NTU against a
       // "Max 100 NTU" that no rule anywhere was enforcing.
       minIsPrefill = defaultMin != null && minKey != null,
       maxIsPrefill = defaultMax != null && maxKey != null;

  /// Stable id of the sensor, e.g. `temp`.
  final String id;

  /// Human readable sensor name shown above the fields.
  final String label;

  /// Unit appended to the field labels, e.g. `°C`.
  final String unit;

  /// Optional lower bound accepted by validation.
  final double? minAllowed;

  /// Optional upper bound accepted by validation.
  final double? maxAllowed;

  /// Preference keys, passed in from `SettingsController`.
  ///
  /// They used to be built here by interpolating [id], which duplicated
  /// `SettingsKeys` and meant the two lists could drift with nothing to catch it.
  /// The caller now names the keys explicitly.
  final String? minKey;
  final String? maxKey;

  final TextEditingController min;
  final TextEditingController max;

  /// True while the field still holds the shipped default rather than something
  /// the user has saved, so no rule is enforcing it yet.
  bool minIsPrefill;
  bool maxIsPrefill;

  /// Marks both sides as stored. Called after a successful save, because from
  /// that moment the values on screen are the values the alarm engine reads.
  void markSaved() {
    minIsPrefill = false;
    maxIsPrefill = false;
  }

  bool get isEmpty => min.text.trim().isEmpty && max.text.trim().isEmpty;

  void dispose() {
    min.dispose();
    max.dispose();
  }

  /// Renders a default limit for the editor, without a trailing `.0`.
  static String? _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

/// Validates one min/max pair, returning a user-facing error or null.
///
/// Blank fields are allowed (the limit is simply not monitored).
String? validateEnvRange(
  EnvRangeSetting setting, {
  required String errorLabel,
}) {
  final minText = setting.min.text.trim();
  final maxText = setting.max.text.trim();
  final minValue = minText.isEmpty ? null : double.tryParse(minText);
  final maxValue = maxText.isEmpty ? null : double.tryParse(maxText);

  if ((minText.isNotEmpty && minValue == null) ||
      (maxText.isNotEmpty && maxValue == null)) {
    return '$errorLabel must be a valid number.';
  }
// **The loop carried no idea which field it was checking,** so the sentence
  // named a floor while the user was standing in the ceiling box. Type `-1` into
  // Turbidity *Max* and it said "Turbidity cannot be lower than 0.0." -- telling
  // someone who has just asked to raise a maximum that the problem is that it is
  // too low. Turbidity is the case that makes it reachable: its `minKey` is null
  // while `minAllowed` is 0, so the ceiling is validated against a floor at all.
  //
  // The field name travels with the value so the sentence can name it, and the
  // wording is the other half of the fix: for the maximum, a value under
  // `minAllowed` is not "too low", it is *below the lowest this sensor can
  // report*, which is a different and more useful thing to be told.
  for (final (field, value) in [
    ('minimum', minValue),
    ('maximum', maxValue),
  ]) {
    if (value == null) continue;
    final minAllowed = setting.minAllowed;
    final maxAllowed = setting.maxAllowed;
    if (minAllowed != null && value < minAllowed) {
      return field == 'maximum'
          ? 'The $errorLabel maximum cannot be below $minAllowed, the lowest '
                'this sensor can report.'
          : '$errorLabel cannot be lower than $minAllowed.';
    }
    if (maxAllowed != null && value > maxAllowed) {
      return field == 'minimum'
          ? 'The $errorLabel minimum cannot be above $maxAllowed, the highest '
                'this sensor can report.'
          : '$errorLabel cannot be higher than $maxAllowed.';
    }
  }
  if (minValue != null && maxValue != null && minValue >= maxValue) {
    return 'The minimum $errorLabel limit must be lower than the maximum limit.';
  }
  return null;
}

/// Error message for an invalid daily production target, or null when valid.
///
/// An empty field is valid and means "no target configured".
String? validateDailyTargetError(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || value <= 0) {
    return 'The production target must be a number greater than 0.';
  }
  return null;
}

/// Requires at least one limit when environment alerts are switched on.
String? validateEnvironmentAlertsEnabled({
  required bool enabled,
  required List<EnvRangeSetting> ranges,
}) {
  if (!enabled) return null;
  if (ranges.every((setting) => setting.isEmpty)) {
    return 'Set at least one sensor limit to enable alerts.';
  }
  return null;
}
