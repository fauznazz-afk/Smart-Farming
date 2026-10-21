import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/app_motion.dart';

/// The motion helpers, and the claims that are invisible in the source.
void main() {
  group('the figure counts, and starts where it is', () {
    /// Pumps one figure and returns the text on screen.
    ///
    /// **The key is a parameter, because the difference matters.** A fresh key
    /// is a first build — "the card opened on the reading"; the same key is an
    /// update — "the card counted to the reading".
    Future<String> pumpFigure(
      WidgetTester tester,
      String text, {
      Key? key,
      Duration? settle,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TweenedFigure(
            key: key,
            text: text,
            builder: (context, text) => Text(text),
          ),
        ),
      );
      if (settle != null) await tester.pump(settle);
      return tester.widget<Text>(find.byType(Text)).data!;
    }

    testWidgets('the first build paints the value, not a count from zero', (
      tester,
    ) async {
      // **The claim that matters most.** A tween that started at zero would
      // open every card on a count-up from nothing, and the dashboard opens on
      // the Overview.
      expect(await pumpFigure(tester, '25.4', key: UniqueKey()), '25.4');
      expect(await pumpFigure(tester, '1834', key: UniqueKey()), '1834');
    });

    testWidgets('a change counts to the new value', (tester) async {
      const key = ValueKey('figure');
      await pumpFigure(tester, '25.4', key: key);
      await pumpFigure(tester, '26.4', key: key);

      // **Halfway is halfway.** The figure is between the two readings, not
      // snapped to one of them.
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.widget<Text>(find.byType(Text)).data!;
      expect(mid, isNot('25.4'));
      expect(mid, isNot('26.4'));

      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byType(Text)).data, '26.4');
    });

    testWidgets('the count starts on the figure that is already there', (
      tester,
    ) async {
      // **The precision of the old figure, not the new one.** `25.4` heading
      // for `25` has to leave from `25.4`; rounding it to the target's
      // precision would show `25` on the first frame, which is the jump this
      // widget exists to remove.
      const key = ValueKey('figure');
      await pumpFigure(tester, '25.4', key: key);
      await pumpFigure(tester, '25', key: key);
      await tester.pump();
      expect(tester.widget<Text>(find.byType(Text)).data, '25.4');

      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byType(Text)).data, '25');
    });

    testWidgets('a figure that is not a number is drawn as it arrives', (
      tester,
    ) async {
      // `--`, `Discharging` and a `min / avg / max` triple have nothing to
      // count between, and re-printing them would change what the panel says.
      expect(
        await pumpFigure(tester, '--', key: UniqueKey()),
        '--',
      );
      expect(
        await pumpFigure(tester, 'Discharging', key: UniqueKey()),
        'Discharging',
      );
      expect(
        await pumpFigure(tester, '40.1 / 71.6 / 94.9', key: UniqueKey()),
        '40.1 / 71.6 / 94.9',
      );
    });

    testWidgets('a figure that becomes a word jumps rather than counts', (
      tester,
    ) async {
      const key = ValueKey('figure');
      await pumpFigure(tester, '25.4', key: key);
      await pumpFigure(tester, 'Discharging', key: key);
      await tester.pump();
      expect(tester.widget<Text>(find.byType(Text)).data, 'Discharging');
    });
  });

  group('the route is one route', () {
    testWidgets('it fades and slides, and reverses on the way back', (
      tester,
    ) async {
      // **The shape the whole app now shares.** A fade and a short slide up,
      // and the same in reverse — the login screen had this transition on its
      // own and every other screen had Material's side slide.
      final route = appPageRoute<void>(page: const Text('page'));
      expect(route, isA<PageRoute<void>>());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(route),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // **Halfway through, the page is neither fully in nor fully out.**
      // Scoped to the transition's own fade, because the theme's page
      // transition has one of its own.
      final fade = find.byType(FadeTransition).last;
      final fading = tester.widget<FadeTransition>(fade);
      expect(fading.opacity.value, greaterThan(0.0));
      expect(fading.opacity.value, lessThan(1.0));
      final slide = find.descendant(
        of: fade,
        matching: find.byType(SlideTransition),
      );
      final sliding = tester.widget<SlideTransition>(slide);
      expect(sliding.position.value.dy, greaterThan(0.0));

      await tester.pumpAndSettle();
      final settled = tester.widget<FadeTransition>(find.byType(FadeTransition).last);
      expect(settled.opacity.value, 1.0);

      // **And the pop is the same transition backwards** — the page fades out
      // and slides down, rather than vanishing.
      Navigator.of(tester.element(find.text('page'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final leaving = tester.widget<FadeTransition>(find.byType(FadeTransition).last);
      expect(leaving.opacity.value, lessThan(1.0));
      final leavingSlide = tester.widget<SlideTransition>(
        find.descendant(
          of: find.byType(FadeTransition).last,
          matching: find.byType(SlideTransition),
        ),
      );
      expect(leavingSlide.position.value.dy, greaterThan(0.0));
    });
  });
}
