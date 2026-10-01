import 'package:flutter/material.dart';
// `RenderParagraph`, for `didExceedMaxLines`. Not exported by `material.dart` --
// and not by `flutter_test.dart` either, which is why the import is explicit
// rather than free.
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/live_power_card.dart';

/// Every label the card's painter had to truncate, mapped to what it drew.
///
/// Read off [RenderParagraph.didExceedMaxLines] rather than inferred from the
/// widget tree, because the widget tree still reports the full string after the
/// engine has clipped it. That distinction is the whole point: an assertion built
/// on `find.text` passes with the truncation present.
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
  const seedColor = Color(0xFF35A968);

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('LivePowerCard', () {
    testWidgets('renders with normal data', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: '5s ago',
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Live power'), findsOneWidget);
      expect(find.text('Solar'), findsOneWidget);
      expect(find.text('House'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('renders with stale data', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: true,
            pzemAgeLabel: '2m ago',
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('2m ago'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders unavailable state when pvPower is null', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: null,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.text('Power flow unavailable until the inverter reports'),
        findsOneWidget,
      );
    });

    // The sign convention is the current BMS's, measured on 27 September 2026:
    // negative watts means the pack is DISCHARGING. The previous pack reported
    // the opposite, and this test was written against that one — it had never
    // run, because the filename did not match the `*_test.dart` pattern.
    testWidgets('shows discharging state for negative battery power', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Discharging'), findsOneWidget);
      expect(find.byIcon(Icons.battery_5_bar_rounded), findsOneWidget);
    });

    testWidgets('shows charging state for positive battery power', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: 100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Charging'), findsOneWidget);
      expect(find.byIcon(Icons.battery_charging_full), findsOneWidget);
    });

    testWidgets('shows standby state for zero battery power', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: 0,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Standby'), findsOneWidget);
    });

    testWidgets('shows warning when array is not covering load', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 100,
            acPower: 500,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.text('The array is not covering the house load right now'),
        findsOneWidget,
      );
    });

    testWidgets('shows spare power when array covers load', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.textContaining('The array covers the house'),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: '5s ago',
            theme: AppTheme.dark,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Live power'), findsOneWidget);
    });

    testWidgets('renders without age label', (tester) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 500,
            acPower: 200,
            batteryPower: -100,
            soc: 75,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.text('Live power'), findsOneWidget);
    });

    // Dracula is the reason this widget takes an `AppTheme` and not a bool, so
    // the test that matters here is the one that asks for a *surface* Dracula
    // derives separately rather than one that just checks it still renders.
    //
    // The charge bar's track is the sharpest case in the file:
    // `AppSurfaces.trackDracula` is `#1E1F29` and `trackDark` is `#131A18`, and
    // Dracula's is the one that is *darker than its own page* — the inverse of
    // both existing modes. A `bool isDark` threaded down here would render
    // Dracula's card with the app's dark track, which still builds, still finds
    // every text and is wrong in a way only a pixel comparison catches.
    //
    // Asserting against the token rather than a hex is deliberate, for the
    // reason `color_helpers_test.dart` documents about its own surface lists: a
    // literal written here is a copy, and copies drift silently.
    for (final theme in AppTheme.values) {
      testWidgets('paints the charge track with ${theme.name} track token',
          (tester) async {
        await tester.pumpWidget(
          wrap(
            LivePowerCard(
              pvPower: 500,
              acPower: 200,
              batteryPower: -100,
              soc: 75,
              pzemStale: false,
              pzemAgeLabel: '5s ago',
              theme: theme,
              seedColor: seedColor,
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == AppSurfaces.track(theme),
          ),
          findsWidgets,
          reason: 'AppSurfaces.track(${theme.name}) is '
              '${AppSurfaces.track(theme)} and no bar behind the charge figure '
              'uses it',
        );
      });
    }
  });

  group('LivePowerCard with nothing reporting', () {
    // **Absence is not zero, and this group is the regression guard for that.**
    //
    // `acPower`, `batteryPower` and `soc` were `double` with `?? 0.0` at the call
    // site, so a device that had never sent a value printed `House 0 W` and
    // `Charge 0%` and then went on to state "The array covers the house load" --
    // a comparison of a real solar figure against a fabricated zero. Three widgets
    // on the Overview page disagreed about what absence means, and the one with
    // the non-nullable field was the one that made a claim.
    //
    // `LivePowerCard` already handled the solar side correctly
    // ("Power flow unavailable until the inverter reports"), which is why this is
    // a nullability change and not a new idea: the card already had the right
    // answer for one of its three terms.

    LivePowerCard card({
      double? pvPower = 500,
      double? acPower,
      double? batteryPower,
      double? soc,
    }) =>
        LivePowerCard(
          pvPower: pvPower,
          acPower: acPower,
          batteryPower: batteryPower,
          soc: soc,
          pzemStale: false,
          pzemAgeLabel: '5s ago',
          theme: AppTheme.light,
          seedColor: seedColor,
        );

    testWidgets('prints -- for every missing figure', (tester) async {
      await tester.pumpWidget(wrap(card()));

      expect(find.text('--'), findsNWidgets(3));
      // The three term labels survive, so the row does not collapse or shift.
      expect(find.text('Solar'), findsOneWidget);
      expect(find.text('House'), findsOneWidget);
    });

    testWidgets('does not claim the array covers the house load',
        (tester) async {
      await tester.pumpWidget(wrap(card()));

      expect(
        find.text('The array is just covering the house load'),
        findsNothing,
      );
      expect(
        find.text('The array covers the house, 300 W spare'),
        findsNothing,
      );
      expect(
        find.text('The array is not covering the house load right now'),
        findsNothing,
      );
      expect(
        find.text('House draw unavailable until the meter reports'),
        findsOneWidget,
      );
    });

    testWidgets('names the pack Battery rather than inventing a direction',
        (tester) async {
      await tester.pumpWidget(wrap(card()));

      // `batteryChargeState` calls a zero reading "standby". An absent reading is
      // not standby, and the label must not claim a direction.
      expect(find.text('Standby'), findsNothing);
      expect(find.text('Battery'), findsOneWidget);
    });

    testWidgets('still draws solar when only the meter is silent',
        (tester) async {
      await tester.pumpWidget(wrap(card(acPower: 200, batteryPower: -100)));

      expect(find.text('500'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(
        find.text('The array covers the house, 300 W spare'),
        findsOneWidget,
      );
    });

    testWidgets('tells a screen reader the real charge', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(card(soc: 64)));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'State of charge: 64 percent')),
        findsOneWidget,
      );
      expect(find.text('64%'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('tells a screen reader the charge is unknown', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(wrap(card()));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'State of charge: not reporting')),
        findsOneWidget,
      );
      // And not the old sentence, which asserted a measurement.
      expect(
        find.bySemanticsLabel(RegExp(r'State of charge: 0 percent')),
        findsNothing,
      );

      handle.dispose();
    });
  });

  group('LivePowerCard figure sizing', () {
    // The three flow terms share the card's content width, which is about 89 dp
    // each at the documented 381 dp viewport. A battery figure of `-1250` needs
    // roughly that much for the sign, four digits, icon, gaps and unit at 24 sp,
    // so any system font scale above 1.0 used to overflow the slot and draw the
    // stripe across the number.
    //
    // `Flexible` plus `FittedBox.scaleDown` rather than `TextOverflow.ellipsis`,
    // because this project has shipped a truncated figure twice -- `109....` and
    // `239...` -- and both times the toolchain was green.

    const viewports = <String, double>{
      '381 dp': 381,
      '320 dp': 320,
    };

    viewports.forEach((label, width) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('a four-digit negative figure fits at $label, scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(width, 800))
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: LivePowerCard(
                      pvPower: 1250,
                      acPower: 1250,
                      batteryPower: -1250,
                      soc: 75,
                      pzemStale: false,
                      pzemAgeLabel: '5s ago',
                      theme: AppTheme.light,
                      seedColor: seedColor,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // And the figure is not abbreviated away, which is the whole reason
          // this is a FittedBox and not an ellipsis.
          expect(find.text('-1250'), findsOneWidget);
        });
      }
    });
  });

  group('the battery state label is never amputated', () {
    // **Found on an emulator at a 2x system font scale, not by reasoning.**
    //
    // The label was `maxLines: 1, overflow: ellipsis`, with a comment accepting
    // the consequence: "the label gets the full slot and ellipsises on its own if a
    // future one is longer still." At 2x in a ~89 dp slot, "Discharging" rendered as
    // `Dischar…`.
    //
    // This string is the one the app is least allowed to get wrong. `AGENTS.md` is
    // explicit that the direction of the pack has to be carried by the label,
    // because a minus sign is not a direction and the two are deliberately not
    // interchangeable -- a previous BMS swap inverted every battery display without
    // one red indicator. A half-word for a direction is the exact failure that
    // section exists to prevent.
    //
    // Wrapping alone was rejected: the row is `CrossAxisAlignment.start`, so a
    // two-line third label would drop the *Discharging* figure a line below the
    // Solar and House figures. So all three label blocks are given one height.

    Future<void> pumpAtScale(
      WidgetTester tester, {
      required double width,
      required double scale,
      required double batteryPower,
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
                child: LivePowerCard(
                  pvPower: 0,
                  acPower: 18,
                  batteryPower: batteryPower,
                  soc: 81,
                  pzemStale: false,
                  pzemAgeLabel: 'Just now',
                  theme: AppTheme.light,
                  seedColor: seedColor,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // **Every clipping assertion in this group reads the laid-out paragraph, not
    // `find.text`.**
    //
    // `find.text('Discharging')` matches a `Text` widget by its *data*, which is
    // still the full string after the layout engine has clipped it. So the obvious
    // assertion passes with the bug present -- and it did: with
    // `maxLines: 1, ellipsis` restored, all 32 tests in this file still passed.
    // `RenderParagraph.didExceedMaxLines` is the flag the painter itself sets when
    // it has dropped content, and it is the only thing here that describes what
    // the user sees.

    Future<void> expectNotClipped(WidgetTester tester, String label) async {
      final clipped = clippedLabels(tester);
      expect(
        clipped,
        isNot(contains(label)),
        reason: 'the label "$label" was drawn as "${clipped[label]}" -- a '
            'direction the reader cannot recover',
      );
    }

    /// The y of each figure's box, so "aligned" is measured rather than assumed.
    ///
    /// The three figures are `-34` for the battery and, with `acPower: 18` and
    /// `pvPower: 0`, the literal strings `0` and `18` for the other two.
    Future<List<double>> figureTops(WidgetTester tester) async {
      final tops = <double>[];
      for (final label in const ['0', '18', '-34']) {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) continue;
        tops.add(tester.getTopLeft(finder.first).dy);
      }
      return tops;
    }

    /// Every flow-row label, with the height it needs at the width it was given
    /// and the height it was actually allotted.
    ///
    /// **This is the assertion that caught the third attempt's bug, and it is not
    /// `didExceedMaxLines`.** That flag only goes true when a paragraph has a
    /// `maxLines`, and the label deliberately has none -- so a label that wraps
    /// into a box one line too short is *silently cut*: no flag, no stripe, no
    /// exception. On the emulator it rendered `Dischargir`. The text needed two
    /// lines at the width the row actually handed it, the block reserved one, and
    /// the second line was simply not painted.
    ///
    /// So the check is arithmetic against a `TextPainter` at the laid-out width,
    /// which is the only place both numbers are knowable.
    Future<void> expectNoLabelIsCut(WidgetTester tester) async {
      for (final label in const ['Solar', 'House', 'Discharging']) {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) continue;
        final box = tester.renderObject<RenderParagraph>(finder.first);
        final allotted = box.size.height;
        final granted = box.size.width;
        final span = box.text;
        if (span is! TextSpan) continue;

        final probe = TextPainter(
          text: span,
          textDirection: box.textDirection,
          textScaler: box.textScaler,
        )..layout(maxWidth: granted);
        final needed = probe.height;
        probe.dispose();

        expect(
          needed,
          lessThanOrEqualTo(allotted + 0.5),
          reason: '"$label" needs ${needed.toStringAsFixed(1)} px at the '
              '${granted.toStringAsFixed(1)} px it was given, but the block '
              'allotted ${allotted.toStringAsFixed(1)} px -- the rest is not '
              'painted and nothing reports it',
        );
      }
    }

    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('"Discharging" is whole at scale $scale', (tester) async {
        await pumpAtScale(tester, width: 381, scale: scale, batteryPower: -34);

        expect(tester.takeException(), isNull);
        await expectNotClipped(tester, 'Discharging');
        await expectNoLabelIsCut(tester);
      });
    }

    // The emulator is 411 dp, the Xiaomi 381, and the label needed 170 dp of it.
    // A fix verified only at 381 would have been verified at a width the defect
    // did not reproduce at.
    for (final width in [411.0, 381.0, 360.0, 320.0]) {
      for (final scale in [1.0, 1.3, 1.5, 2.0, 2.5, 3.0]) {
        testWidgets('no label is cut at ${width.toInt()} dp, scale $scale',
            (tester) async {
          await pumpAtScale(
            tester,
            width: width,
            scale: scale,
            batteryPower: -34,
          );
          expect(tester.takeException(), isNull);
          await expectNoLabelIsCut(tester);
        });
      }
    }

    testWidgets('the three figures share a line at every scale', (tester) async {
      // The point of the shared label block: the figures are the content and they
      // must not drift apart because one annotation wrapped.
      for (final scale in [1.0, 1.5, 2.0, 3.0]) {
        await pumpAtScale(tester, width: 381, scale: scale, batteryPower: -34);
        final tops = await figureTops(tester);
        expect(tops.length, 3, reason: 'scale $scale did not find three figures');
        // Tolerance is one device pixel: the figures are baseline-aligned inside
        // each slot, and a slot's own rounding can differ by a fraction.
        expect(
          tops.reduce((a, b) => a > b ? a : b) -
              tops.reduce((a, b) => a < b ? a : b),
          lessThan(1.5),
          reason: 'the figures are misaligned by '
              '${(tops.reduce((a, b) => a > b ? a : b) - tops.reduce((a, b) => a < b ? a : b)).toStringAsFixed(1)} '
              'px at scale $scale',
        );
      }
    });

    testWidgets('a narrow viewport also keeps the label whole', (tester) async {
      // 320 dp is a real small phone, and the slot there is about 74 dp, so
      // "Discharging" wraps even closer to 1.0.
      await pumpAtScale(tester, width: 320, scale: 1.3, batteryPower: -34);
      await expectNotClipped(tester, 'Discharging');
    });

    testWidgets('every charge state keeps its label', (tester) async {
      // `batteryChargeState` has three states and the third is the one that gets
      // skipped -- `AGENTS.md` calls out standby specifically, because any UI that
      // picks one of two labels flips several times a minute while the pack sits
      // at 0.00 A.
      // A list rather than a map: a `double` key cannot be `const` in Dart, and
      // 0.0 as a map key is the kind of thing that reads as a mistake.
      const cases = <(double, String)>[
        (-34, 'Discharging'),
        (34, 'Charging'),
        (0, 'Standby'),
      ];
      for (final (watts, label) in cases) {
        await pumpAtScale(
          tester,
          width: 381,
          scale: 2.0,
          batteryPower: watts,
        );
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$watts W must carry a "$label" label at all',
        );
        await expectNotClipped(tester, label);
      }
    });
  });
}
