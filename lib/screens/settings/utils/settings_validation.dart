import 'package:flutter/widgets.dart';

/// A min/max limit pair for one environment sensor.
class EnvRangeSetting {
  EnvRangeSetting({
    required this.id,
    required this.label,
    required this.unit,
    this.minAllowed,
    this.maxAllowed,
  });

  /// Stable id used to build the preference keys (`environment_<id>_min`).
  final String id;

  /// Human readable sensor name shown above the fields.
  final String label;

  /// Unit appended to the field labels, e.g. `°C`.
  final String unit;

  /// Optional lower bound accepted by validation.
  final double? minAllowed;

  /// Optional upper bound accepted by validation.
  final double? maxAllowed;

  final TextEditingController min = TextEditingController();
  final TextEditingController max = TextEditingController();

  String get minKey => 'environment_${id}_min';

  String get maxKey => 'environment_${id}_max';

  bool get isEmpty => min.text.trim().isEmpty && max.text.trim().isEmpty;

  void dispose() {
    min.dispose();
    max.dispose();
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
    return '$errorLabel harus berupa angka yang valid.';
  }
  for (final value in [minValue, maxValue]) {
    if (value == null) continue;
    final minAllowed = setting.minAllowed;
    final maxAllowed = setting.maxAllowed;
    if (minAllowed != null && value < minAllowed) {
      return '$errorLabel tidak boleh kurang dari $minAllowed.';
    }
    if (maxAllowed != null && value > maxAllowed) {
      return '$errorLabel tidak boleh lebih dari $maxAllowed.';
    }
  }
  if (minValue != null && maxValue != null && minValue >= maxValue) {
    return 'Batas minimum $errorLabel harus lebih kecil dari batas maksimum.';
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
    return 'Target produksi harus berupa angka lebih besar dari 0.';
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
    return 'Isi minimal satu batas sensor untuk mengaktifkan peringatan.';
  }
  return null;
}
