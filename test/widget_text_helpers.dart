import 'package:flutter/material.dart';
// `RenderParagraph`, for `didExceedMaxLines`. Not exported by `material.dart` --
// and not by `flutter_test.dart` either, which is why the import is explicit
// rather than free.
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

/// Every label a widget under test had to truncate, mapped to what it drew.
///
/// Read off [RenderParagraph.didExceedMaxLines] rather than inferred from the
/// widget tree, because the widget tree still reports the full string after the
/// engine has clipped it. That distinction is the whole point: an assertion built
/// on `find.text` passes with the truncation present.
///
/// This is the check that the three label regressions of 27 September 2026 all
/// needed and none of the 581 tests had. `PV Output` printed three times in one
/// card is a duplication fault and is caught by a count. `109....` is a
/// truncation fault and is caught only here, because the tree still says
/// `109.... V` in full. And `DateStripChip` laid its label out at 20 sp and then
/// scaled it back to 13 dp, which no text assertion can see at all.
Map<String, String> clippedLabels(WidgetTester tester) {
  final clipped = <String, String>{};
  for (final element in find.byType(RichText).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderParagraph) continue;
    if (!box.didExceedMaxLines) continue;
    final span = box.text;
    if (span is! TextSpan) continue;
    if (span.toPlainText().isEmpty) continue;
    clipped[span.toPlainText()] = ellipsised(
      source: span.toPlainText(),
      style: span.style,
      // Read off the render object rather than the span. The paragraph is what
      // resolved the direction and the scale for this particular layout, so it is
      // the authority -- a `TextSpan` carries a `TextStyle`, and a style knows
      // nothing about the user's font-scale setting.
      direction: box.textDirection,
      scaler: box.textScaler,
      maxWidth: box.size.width,
    );
  }
  return clipped;
}

/// The string the engine would have drawn: the longest prefix that still fits once
/// the ellipsis itself is accounted for.
///
/// Not a prettification. A test's job when it fails is to *report* what the user
/// saw, and "the label was truncated" without saying to what is a much weaker
/// thing to act on from a log.
String ellipsised({
  required String source,
  required TextStyle? style,
  required TextDirection direction,
  required TextScaler scaler,
  required double maxWidth,
}) {
  var lo = 0;
  var hi = source.length;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    final probe = TextPainter(
      text: TextSpan(text: '${source.substring(0, mid)}…', style: style),
      textDirection: direction,
      textScaler: scaler,
      // **No `maxWidth` here, and passing one is a silent bug.** The painter lays
      // out at its natural width and the comparison below is made against
      // `maxWidth` by hand. Hand it `maxWidth` instead and the painter wraps the
      // probe to fit, `probe.width` becomes `<= maxWidth` for *every* candidate,
      // and this function returns the source string with an ellipsis glued on --
      // which would then be compared against the card's real label and mismatch
      // for reasons that have nothing to do with the card.
    )..layout();
    final fits = probe.width <= maxWidth;
    probe.dispose();
    if (fits) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return '${source.substring(0, lo)}…';
}

/// Asserts that nothing under test was truncated, and names what was if it was.
///
/// The message matters as much as the assertion. A bare
/// `expect(clippedLabels(tester), isEmpty)` prints an empty map when it fails,
/// which tells a reader nothing about which label broke or what the user would
/// have seen instead.
///
/// [ignore] exempts specific strings, and it exists so that a **deliberate**
/// truncation is written down at the call site instead of quietly weakening the
/// assertion for everything else. The distinction being protected is between a
/// *figure* and a *control label*: `1.53 kWh` cut to `1.53 k…` is the
/// `109....` regression and there is no width at which it is the right answer,
/// while a range selector reading `7 da…` at a 2.0 system font on a 320 dp phone
/// is a control that is still operable and is the lesser of two evils against a
/// layout that throws on every frame.
void expectNothingClipped(
  WidgetTester tester, {
  String? because,
  Set<String> ignore = const {},
}) {
  final clipped = clippedLabels(tester)
    ..removeWhere((label, _) => ignore.contains(label));
  expect(
    clipped,
    isEmpty,
    reason:
        '${because ?? 'A label was truncated'}\n'
        'The card must never amputate a figure: a value the user cannot read is '
        'worse than a value that is missing, because the layout looks fine.\n'
        'Truncated: $clipped',
  );
}

/// The width of the smallest phone this app is expected to run on, in logical
/// pixels.
///
/// 360 dp is the narrowest mainstream Android width and the width `PRD §7.2`
/// asks to be checked on a device. The 320 dp entry is below it deliberately:
/// `live_power_card_test.dart` parametrizes down to 320, and a card that only
/// holds together at 360 is a card that will break on a budget handset.
const List<double> kNarrowWidthsDp = [320, 360, 411];

/// The text scales that have actually broken something in this app.
///
/// 2.0 is not hypothetical: `DateStripChip` laid its label out at 20 sp and then
/// scaled it back down, and nothing in the suite could see it.
const List<double> kTextScales = [1.0, 1.5, 2.0];
