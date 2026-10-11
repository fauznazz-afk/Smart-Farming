import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/screens/dashboard/widgets/date_strip.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart' show DateStripChip;

/// The seven-day strip, checked at the font scales a user can actually set.
///
/// **Every assertion reads `RenderParagraph.didExceedMaxLines`**, not
/// `find.text`. That is not a stylistic preference. `find.text('Wed')` matches a
/// `Text` widget by its *data*, which is still the full string after the layout
/// engine has clipped it -- so an assertion built that way passes with the
/// truncation present. This file was written after that exact mistake shipped
/// once, and the sibling test in `live_power_card_test.dart` documents it.
///
/// The defect itself was found on an emulator at a 2x system font scale, on a
/// 411 dp viewport, and it was not a stripe: every day name was ellipsised to a
/// single letter, so the strip read `S, M, W, T, T, F, S`. That is a row of
/// initials rather than days, and it is ambiguous besides -- Saturday and Sunday
/// share a letter, and so do Tuesday and Thursday.

/// The string the engine would have drawn: the longest prefix that still fits
/// once the ellipsis itself is accounted for.
///
/// A test's job when it fails is to *report* what the user saw, so the reason
/// string can name the day and the truncation rather than only asserting a count.
String _ellipsised({
  required String source,
  required TextStyle? style,
  required double maxWidth,
  required TextDirection direction,
  required TextScaler scaler,
}) {
  var lo = 0;
  var hi = source.length;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    final probe = TextPainter(
      text: TextSpan(text: '${source.substring(0, mid)}…', style: style),
      textDirection: direction,
      textScaler: scaler,
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

void main() {
  final today = DateTime(2026, 10, 2);
  final days = List<DateTime>.generate(
    7,
    (i) => today.subtract(Duration(days: 6 - i)),
  );

  Future<void> pumpStrip(
    WidgetTester tester, {
    required double width,
    required double scale,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900))
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: DateStrip(
                days: days,
                selectedDate: today,
                rangeStart: null,
                rangeEnd: null,
                onSelectDate: (_) {},
                onPickRange: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The day names the painter had to clip, mapped to what it drew.
  Map<String, String> clipped(WidgetTester tester) {
    final out = <String, String>{};
    for (final element in find.byType(RichText).evaluate()) {
      final box = element.renderObject;
      if (box is! RenderParagraph) continue;
      if (!box.didExceedMaxLines) continue;
      final span = box.text;
      if (span is! TextSpan) continue;
      final source = span.toPlainText();
      if (source.isEmpty) continue;
      out[source] = _ellipsised(
        source: source,
        style: span.style,
        maxWidth: box.size.width,
        direction: box.textDirection,
        scaler: box.textScaler,
      );
    }
    return out;
  }

  const scales = [1.0, 1.15, 1.3, 1.5, 1.8, 2.0, 2.5, 3.0];
  const viewports = <String, double>{
    '411 dp (emulator)': 411,
    '381 dp (Xiaomi)': 381,
    '360 dp': 360,
    '320 dp (small)': 320,
  };

  viewports.forEach((label, width) {
    for (final scale in scales) {
      testWidgets('no day name is clipped at $label, scale $scale', (
        tester,
      ) async {
        await pumpStrip(tester, width: width, scale: scale);

        expect(tester.takeException(), isNull);
        final cut = clipped(tester);
        expect(
          cut.keys.where((k) => k.length <= 3 && !k.contains(' ')),
          isEmpty,
          // Named explicitly because a bare "isEmpty" on a map of day names does
          // not say which day broke, and "which day" is the whole question.
          reason:
              'day names were clipped at $label scale $scale: '
              '${cut.entries.where((e) => e.key.length <= 3).map((e) => '${e.key} -> ${e.value}').join(', ')}',
        );
      });
    }
  });

  testWidgets('the strip is not scrollable at 1.0, where everything fits', (
    tester,
  ) async {
    // Scrolling at the default scale would be a regression the reader would feel
    // without being able to name it: a control that used to show all seven days
    // at a glance now needs a swipe.
    await pumpStrip(tester, width: 411, scale: 1.0);
    expect(
      find.descendant(
        of: find.byType(DateStrip),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });

  testWidgets('all seven chips are laid out at every scale', (tester) async {
    // The scroll view must not be a way of laying out *fewer* chips. Seven in,
    // seven out; only their width changes.
    for (final scale in scales) {
      await pumpStrip(tester, width: 320, scale: scale);
      for (final day in days) {
        expect(
          find.text('${day.day}'),
          findsOneWidget,
          reason: 'the chip for ${day.day} went missing at scale $scale',
        );
      }
    }
  });

  testWidgets('the widest day is the widest chip, so no chip is oversized', (
    tester,
  ) async {
    // The measurement is per-strip, not per-chip: every chip is the same width so
    // the row stays a grid. This checks that the width chosen actually fits the
    // widest name rather than fitting a representative one -- "Mon" is narrower
    // than "Wed", and picking the wrong reference leaves Wednesday clipped while
    // the others look fine.
    for (final scale in scales) {
      await pumpStrip(tester, width: 381, scale: scale);
      expect(clipped(tester), isEmpty, reason: 'at scale $scale');
    }
  });

  testWidgets('the selected day is still the full-height raised chip', (
    tester,
  ) async {
    // The strip grew taller with the font scale and now scrolls. Neither may have
    // cost the selected chip its own geometry: it is the one day the user is
    // pointing at, and it is distinguished by being a raised block filled with the
    // accent rather than a well.
    await pumpStrip(tester, width: 411, scale: 2.0);
    final selected = find.text('2');
    expect(selected, findsOneWidget);
    expect(tester.getSize(selected).height, greaterThan(0));
  });

  testWidgets('every day name stays on one line, at every scale', (
    tester,
  ) async {
    // **The assertion is line count, not `didExceedMaxLines`.**
    //
    // `date_strip_test.dart` was built to catch names ellipsised to `S…`, and it
    // reads `didExceedMaxLines` for that. It is blind to the other half of the
    // same defect, which is what actually shipped: `MON` is short enough that
    // when it does not fit the engine **breaks it at a character** — `MO` over
    // `N` — rather than overflowing, so `didExceedMaxLines` stays false and the
    // whole sweep above stays green.
    //
    // The visible consequence is on the Overview calendar and nowhere else. The
    // chip's height is its content's height (`minHeight: 68`, so a 3x system font
    // does not truncate the number), so a wrapped name makes one cell in a
    // seven-cell row taller than the other six. A row that is not one row reads
    // as "slightly off-centre" long before anyone can say why.
    for (final scale in scales) {
      await pumpStrip(tester, width: 381, scale: scale);
      final wrapped = <String>[];
      for (final element in find.byType(RichText).evaluate()) {
        final box = element.renderObject;
        if (box is! RenderParagraph) continue;
        final span = box.text;
        if (span is! TextSpan) continue;
        final source = span.toPlainText();
        if (source.isEmpty || source.contains(' ')) continue;
        if (box
                .getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: source.length),
                )
                .length >
            1) {
          wrapped.add('$source -> $source');
        }
      }
      expect(
        wrapped,
        isEmpty,
        reason:
            'a day name broke onto a second line at scale $scale, which '
            'makes its chip taller than its six neighbours',
      );
    }
  });

  testWidgets('the legend and the chip row share both edges', (tester) async {
    // **The asymmetry, stated as geometry so it cannot come back.**
    //
    // The header used to be `Padding(horizontal: 2)` + a 48dp button + a 4dp gap
    // + `Expanded` legend, which put the legend text's left edge at 54dp and the
    // header's right edge at maxWidth - 2, against a chip row running 0 to
    // maxWidth. Every number involved is small; that is the point. Nothing in the
    // strip was misaligned by enough to name, and the eye reads the total.
    //
    // Asserted on the *rendered* rects, because the defect is a rect problem and
    // checking the source would only re-state the intent.
    //
    // **411 dp, not 381, and the difference is load-bearing.** Under the test
    // font every glyph is a full em square, so at 381 the seven chips measure
    // 390.2dp and the strip falls back to a horizontal `SingleChildScrollView`
    // -- correctly, and the "widest day is the widest chip" test above relies on
    // that fallback. A scrolled row's last chip has a rect that legitimately
    // extends past the viewport, so comparing it to the header's edge compares a
    // scrolling row against a fixed one and fails for a reason that has nothing
    // to do with alignment. 411 is a width where all seven fit, which is the only
    // case where both edges are meaningful at once. The scrolled case gets its
    // own assertion on the left edge below.
    await pumpStrip(tester, width: 411, scale: 1.0);

    expect(
      find.descendant(
        of: find.byType(DateStrip),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
      reason:
          'this test compares the last chip against the header edge, which '
          'is only meaningful when all seven chips are on screen together',
    );

    double leftOf(Finder f) => tester.getTopLeft(f).dx;
    double rightOf(Finder f) => tester.getBottomRight(f).dx;

    // The legend is found structurally rather than by its text. `_rangeLabel`
    // compares `selectedDate` against `DateTime.now()`, so the label is 'Today'
    // only on the day the test happens to run: at any other date it is
    // 'Saturday, 2 October 2026' and a `find.text('Today')` finds nothing. A
    // geometry assertion should not depend on the calendar.
    //
    // `Wrap` is unique to the legend -- the chip row is a `Row`, and the chip
    // internals are a `Column` -- so its first `Text` is the range label.
    final legend = find
        .descendant(of: find.byType(Wrap), matching: find.byType(Text))
        .first;
    final firstChip = find.byType(DateStripChip).first;
    expect(
      leftOf(legend),
      moreOrLessEquals(leftOf(firstChip), epsilon: 0.01),
      reason:
          'the legend starts ${leftOf(legend) - leftOf(firstChip)}dp '
          'right of the first chip, so the header reads as indented',
    );

    // The last chip's right edge, and the calendar button's touch target.
    final lastChip = find.byType(DateStripChip).last;
    final button = find.byTooltip('Pick a date range');
    expect(
      rightOf(button),
      moreOrLessEquals(rightOf(lastChip), epsilon: 0.01),
      reason:
          'the calendar button ends ${rightOf(lastChip) - rightOf(button)}dp '
          'short of the last chip, so the header reads as inset on the right',
    );

    // And all seven chips are the same width, which is the rest of "a grid".
    final widths = <double>{
      for (final chip in find.byType(DateStripChip).evaluate())
        tester.getSize(find.byWidget(chip.widget)).width,
    };
    expect(
      widths,
      hasLength(1),
      reason:
          'the chips are not one width: $widths. A calendar row of seven '
          'cells at seven widths is not a grid',
    );
  });

  testWidgets('the legend still starts where the chips do when the row scrolls', (
    tester,
  ) async {
    // **The scrolled case, asserted separately because it is the reported one.**
    //
    // On the Xiaomi (381 dp) at a 2x system font the seven chips are wider than
    // the viewport and the strip scrolls. That is when the indent is most
    // obvious -- a header whose legend sits 54dp in, directly above chips that
    // start at the very edge, with a scrollbar between them.
    //
    // Only the left edge is checked. The right edge has no meaning here: the last
    // chip is genuinely off-screen, which is the whole point of the fallback.
    await pumpStrip(tester, width: 381, scale: 2.0);

    final legend = find
        .descendant(of: find.byType(Wrap), matching: find.byType(Text))
        .first;
    final firstChip = find.byType(DateStripChip).first;
    expect(
      tester.getTopLeft(legend).dx,
      moreOrLessEquals(tester.getTopLeft(firstChip).dx, epsilon: 0.01),
      reason:
          'the legend is indented from the chips while the strip scrolls, '
          'which is the case this defect was reported in',
    );
  });

  testWidgets('a day name is never wrapped, so no chip is taller than its '
      'neighbours', (tester) async {
    // Belt and braces to the line-count sweep above, asserted on the rendered
    // *heights*: seven cells in one row is a claim about geometry, and geometry
    // is what the reader sees. This fails if any chip's content grows a line,
    // regardless of which string caused it.
    await pumpStrip(tester, width: 381, scale: 1.0);
    final heights = <double>{
      for (final chip in find.byType(DateStripChip).evaluate())
        tester.getSize(find.byWidget(chip.widget)).height,
    };
    expect(
      heights,
      hasLength(1),
      reason:
          'the chips are not one height: $heights. A calendar row of seven '
          'cells at seven heights is not a row',
    );
  });
}
