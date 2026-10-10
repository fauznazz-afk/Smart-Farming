import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/screens/dashboard/widgets/date_strip.dart';

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
      testWidgets('no day name is clipped at $label, scale $scale',
          (tester) async {
        await pumpStrip(tester, width: width, scale: scale);

        expect(tester.takeException(), isNull);
        final cut = clipped(tester);
        expect(
          cut.keys.where((k) => k.length <= 3 && !k.contains(' ')),
          isEmpty,
          // Named explicitly because a bare "isEmpty" on a map of day names does
          // not say which day broke, and "which day" is the whole question.
          reason: 'day names were clipped at $label scale $scale: '
              '${cut.entries.where((e) => e.key.length <= 3).map((e) => '${e.key} -> ${e.value}').join(', ')}',
        );
      });
    }
  });

  testWidgets('the strip is not scrollable at 1.0, where everything fits',
      (tester) async {
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

  testWidgets('the widest day is the widest chip, so no chip is oversized',
      (tester) async {
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

  testWidgets('the selected day is still the full-height raised chip',
      (tester) async {
    // The strip grew taller with the font scale and now scrolls. Neither may have
    // cost the selected chip its own geometry: it is the one day the user is
    // pointing at, and it is distinguished by being a raised block filled with the
    // accent rather than a well.
    await pumpStrip(tester, width: 411, scale: 2.0);
    final selected = find.text('2');
    expect(selected, findsOneWidget);
    expect(tester.getSize(selected).height, greaterThan(0));
  });
}
