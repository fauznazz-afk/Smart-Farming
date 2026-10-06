// A measurement probe, not an assertion.
//
// `AGENTS.md` and the note above `AppElevation.raised` both record that the
// *dark* halves of the pair were corrected from a scanline and the *light*
// halves were not, because no light-half scanline was ever taken. This prints
// the composited step each half makes on its own page, so the two halves can be
// compared on one scale before anyone changes an alpha.
//
// It prints and passes. Turning any of these numbers into an assertion is the
// decision this file exists to inform, and an assertion written before the
// measurement is the mistake the surrounding notes warn about twice.
//
// Run alone, because a full-file run of the suite does not fit in RAM here:
//   flutter test test/shadow_balance_probe_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The signed change in page luminance a shadow makes at its own alpha.
///
/// Identical to `luminanceStep` in `design_tokens_test.dart`. Copied rather than
/// imported because a test file is not a library, and six duplicated lines beat
/// restructuring the suite to share them.
double step(Color page, BoxShadow s) {
  final over = s.color.computeLuminance() < 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
  return Color.lerp(page, over, s.color.a)!.computeLuminance() -
      page.computeLuminance();
}

void main() {
  test('light/dark balance of the raised pair, per theme', () {
    for (final entry in {
      AppTheme.light: AppSurfaces.pageLight,
      AppTheme.dark: AppSurfaces.pageDark,
      AppTheme.dracula: AppSurfaces.pageDracula,
    }.entries) {
      final theme = entry.key;
      final page = entry.value;
      final shadows = AppElevation.raised(theme);
      final pageL = page.computeLuminance();

      var dark = 0.0;
      var light = 0.0;
      final lines = <String>[];
      for (final s in shadows) {
        final magnitude = step(page, s).abs();
        final isDark = s.color.computeLuminance() < 0.5;
        if (isDark) {
          dark += magnitude;
        } else {
          light += magnitude;
        }
        lines.add(
          '     ${isDark ? 'dark ' : 'light'} '
          'a=${s.color.a.toStringAsFixed(3)} '
          'blur=${s.blurRadius.toStringAsFixed(0).padLeft(2)} '
          'offset=(${s.offset.dx.toStringAsFixed(0)},'
          '${s.offset.dy.toStringAsFixed(0)}) '
          'dL=${magnitude.toStringAsFixed(5)}',
        );
      }

      final ratio = dark == 0 ? 0.0 : light / dark;
      // ignore: avoid_print
      print('  --- ${theme.name} on #${page.toARGB32().toRadixString(16).substring(2).toUpperCase()} (L=${pageL.toStringAsFixed(4)})');
      for (final line in lines) {
        // ignore: avoid_print
        print(line);
      }
      // ignore: avoid_print
      print('     dark total dL=${dark.toStringAsFixed(5)}  '
          'light total dL=${light.toStringAsFixed(5)}');
      // ignore: avoid_print
      print('     light/dark=${ratio.toStringAsFixed(3)}  '
          'dark as % of page=${(dark / pageL * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('');
    }
  });
}
