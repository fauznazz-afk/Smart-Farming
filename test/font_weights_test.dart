// The font-weight guard.
//
// **Why this file exists.** Flutter resolves a requested `fontWeight` to the
// NEAREST cut a family declares, and it says nothing when it does that. The
// app asked for `w500` and `w600`; only 400/700/900 were declared; so a
// `w600` style painted as Bold 700 and a `w500` style painted as Regular 400 -
// two declared weights silently became two others, and nothing in the app
// looked wrong enough to report. The fix was to ship the missing instances
// (`Inter-Medium-500.ttf`, `Inter-SemiBold-600.ttf`) and declare them.
//
// **What it checks, in two halves, because one half cannot cover both.**
//
//  * **The instance is the weight it claims to be.** `Inter` is proportional,
//    so each cut has its own advance width. Requiring the widths painted at the
//    scale's weights to differ is what proves the shipped instances are five
//    different files rather than five copies of one - and, because a static
//    instance carries its weight inside the file, that a renamed or
//    mislabelled asset is caught as well.
//  * **The family declares every weight the app requests.** That is a
//    property of the *manifest*, not of the font files: an instance that is
//    present on disk but undeclared in `pubspec.yaml` is not in the bundle, so
//    the engine never offers it and the request falls back to the nearest
//    declared cut. `FontManifest.json` is the file the engine reads, so this
//    reads that rather than `pubspec.yaml` - a copy of the declaration would
//    drift from the thing that is actually shipped.
//
// `JetBrainsMono` is monospaced, so every cut has the same advance width and
// the width half cannot see it. Its claim is therefore the manifest half only:
// both its cuts are declared, so neither can collapse onto the other.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

/// The advance width of [text] painted in [family] at [weight].
///
/// The probe is deliberately a width and not an image: an image comparison would
/// be a golden, and a golden is not portable between platforms, while the
/// advance width of a proportional face is a property of the font.
double widthOf(String family, FontWeight weight) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Hamburgefonstiv 0123',
      style: TextStyle(fontFamily: family, fontSize: 100, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The weights the app asks of each family, read from the tokens themselves.
///
/// **Referenced by name, not written down.** A token that changes its weight
/// is followed here rather than being contradicted by a list that was correct
/// when it was written. The five are the scale's cuts: 400 body, 500 caption,
/// 600 label, 700 display, 900 the status word. `design_tokens_test.dart` pins
/// that scale, so a new cut there is caught there first.
///
/// [TextStyle.fontWeight] is nullable, and a token that left it null would
/// paint at the platform's default - which is not a cut anybody declared. So
/// each weight is read through a helper that refuses the null case rather than
/// quietly measuring the wrong thing.
FontWeight _weightOf(TextStyle style, String name) {
  final weight = style.fontWeight;
  if (weight == null) {
    throw StateError('$name declares no fontWeight, so it paints at whatever '
        'the platform defaults to rather than at a declared cut');
  }
  return weight;
}

final Map<String, FontWeight> interScale = {
  'body': _weightOf(AppType.bodyMd, 'bodyMd'),
  'caption': _weightOf(AppType.caption, 'caption'),
  'label': _weightOf(AppType.labelUppercase, 'labelUppercase'),
  'display': _weightOf(AppType.displayLg, 'displayLg'),
  'status word': _weightOf(AppType.statusWord, 'statusWord'),
};

/// The same for the terminal panel's family.
final Map<String, FontWeight> monoScale = {
  'code': _weightOf(AppType.code, 'code'),
  'hero figure': _weightOf(AppType.heroFigure, 'heroFigure'),
};

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final asset in [
    'assets/fonts/Inter-Regular-400.ttf',
    'assets/fonts/Inter-Medium-500.ttf',
    'assets/fonts/Inter-SemiBold-600.ttf',
    'assets/fonts/Inter-Bold-700.ttf',
    'assets/fonts/Inter-Black-900.ttf',
  ]) {
    inter.addFont(rootBundle.load(asset));
  }
  await inter.load();

  final mono = FontLoader('JetBrainsMono');
  for (final asset in [
    'assets/fonts/JetBrainsMono-Medium.ttf',
    'assets/fonts/JetBrainsMono-Bold.ttf',
  ]) {
    mono.addFont(rootBundle.load(asset));
  }
  await mono.load();
}

void main() {
  // `FontLoader` and `rootBundle` both go through the binding, so this file
  // needs one. A plain `test()` would fail in `setUpAll` with "Binding has not
  // yet been initialized".
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  test('every weight the app requests paints as its own face', () {
    // **Inter only, and monospace is why.** A monospaced face has one advance
    // width for every cut, so the width cannot tell Medium from Bold there and
    // the assertion would be vacuous rather than passing.
    final widths = <String, double>{};
    final weights = <String, int>{};
    for (final entry in interScale.entries) {
      widths[entry.key] = widthOf('Inter', entry.value);
      weights[entry.key] = entry.value.value;
    }
    expect(
      widths.values.toSet().length,
      widths.length,
      reason: 'two of Inter\'s weights paint at the same width '
          '(${weights.entries.map((e) => '${e.key} (${e.value})').join(', ')}), '
          'so one of the declared cuts is a copy of another rather than its own '
          'instance, and the scale is a lie',
    );
  });

  test('the family declares every weight the app requests', () async {
    // **The manifest, because that is what the engine reads.** An instance on
    // disk that `pubspec.yaml` does not declare is not in the bundle, so the
    // engine never offers it and the request falls back to the nearest
    // declared cut - silently, which is the whole failure this file guards.
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    final declared = <String, List<int>>{};
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final cuts = (entry['fonts'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((f) => f['weight'])
          .whereType<int>()
          .toList();
      declared[entry['family'] as String] = cuts;
    }

    for (final scale in {
      'Inter': interScale,
      'JetBrainsMono': monoScale,
    }.entries) {
      final cuts = declared[scale.key] ?? const <int>[];
      final wanted = scale.value.values.map((w) => w.value).toSet().toList()
        ..sort();
      expect(
        cuts,
        containsAll(wanted),
        reason: 'the ${scale.key} family declares $cuts but the type scale '
            'asks for $wanted; an undeclared weight is resolved to the '
            'nearest declared cut and nothing reports it',
      );
    }
  });
}
