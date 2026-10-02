import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/live_power_card.dart';

import 'widget_text_helpers.dart';

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

    // **The battery figure here was changed from -100 to 0, and that is the whole
    // point of this test now.** It used to be -100, which is *discharging*, so the
    // card was asserting an amber "the array is not covering the house" about a
    // house the battery was in fact supplying -- a warning that was structurally
    // true every evening and therefore never wrong and never useful. The
    // shortfall warning is real, but only when nothing is making the difference
    // up, so the fixture is standby. `pv 100 / ac 500` is unchanged: the array is
    // still four fifths short, and the amber sentence is still the correct one.
    testWidgets('shows warning when array is short and the battery is idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 100,
            acPower: 500,
            batteryPower: 0,
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

    // The dusk case, with the device's own numbers from 2 October 2026 at 15:50:
    // `Solar 5 W / House 17 W / Discharging -30 W`. The house is supplied, the
    // array is not the supplier, and the card used to say so in amber.
    testWidgets('a shortfall the battery covers is not a warning', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 5,
            acPower: 17,
            batteryPower: -30,
            soc: 99,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.text('The array is short, and the battery adds 30 W'),
        findsOneWidget,
      );
      // The old sentence must be gone, and this is the half that carries the
      // fix: a substring match on "the array" would pass on either wording.
      expect(
        find.text('The array is not covering the house load right now'),
        findsNothing,
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

    // The figures are the ones the test device reported on 2 October 2026, and
    // they are the whole defect: a 7 W surplus next to a 19 W battery draw. The
    // old sentence printed only the surplus, so the card showed "The array covers
    // the house, 7 W spare" directly above "Discharging -19 W" -- the array
    // reading as the main contributor when it was the smaller of the two.
    //
    // Asserting the old string is *absent* is the half that matters. Finding the
    // new text is a weaker check, because a substring match on "The array covers
    // the house" would also be satisfied by the misleading sentence.
    testWidgets('names the battery when it supplies more than the surplus', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 25,
            acPower: 18,
            batteryPower: -19,
            soc: 99,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(
        find.text('The array covers the house, and the battery adds 19 W'),
        findsOneWidget,
      );
      // The surplus is real, so this is not a replacement -- it is the clause
      // that was hiding the larger contributor.
      expect(find.textContaining('W spare'), findsNothing);
    });

    // The other side of the same boundary. A 100 W draw against a 300 W surplus
    // leaves the array as the larger contributor, so the original sentence was
    // fair and must not have grown a clause. Without this the fix would quietly
    // start narrating the battery on every clear afternoon.
    testWidgets('keeps the spare sentence when the array contributes more', (
      tester,
    ) async {
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
        find.text('The array covers the house, 300 W spare'),
        findsOneWidget,
      );
      expect(find.textContaining('the battery adds'), findsNothing);
    });

    // Standby is not a direction, so a battery sitting at zero draw must not
    // trigger the new clause even though `abs()` of it is small and positive.
    // This is the `battery_sign.dart` rule reaching this widget.
    testWidgets('does not name the battery while it is in standby', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          LivePowerCard(
            pvPower: 32,
            acPower: 18,
            batteryPower: 0,
            soc: 99,
            pzemStale: false,
            pzemAgeLabel: null,
            theme: AppTheme.light,
            seedColor: seedColor,
          ),
        ),
      );

      expect(find.textContaining('the battery adds'), findsNothing);
      expect(find.text('Standby'), findsOneWidget);
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
