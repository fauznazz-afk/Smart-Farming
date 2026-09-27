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
       max = TextEditingController(text: _format(defaultMax));

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
  for (final value in [minValue, maxValue]) {
    if (value == null) continue;
    final minAllowed = setting.minAllowed;
    final maxAllowed = setting.maxAllowed;
    if (minAllowed != null && value < minAllowed) {
      return '$errorLabel cannot be lower than $minAllowed.';
    }
    if (maxAllowed != null && value > maxAllowed) {
      return '$errorLabel cannot be higher than $maxAllowed.';
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
