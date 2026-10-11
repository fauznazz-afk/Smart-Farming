import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/overview_panel.dart';

/// The Overview's own readout, pumped on its own.
///
/// The panel was built to replace four cards and it inherited a bug that the
/// cards' layout had hidden, so these are less about the layout than about the
/// **labels agreeing with the figures beside them**.
void main() {
  Widget wrap(OverviewReadings r) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: OverviewPanel(readings: r)),
        ),
      );

  testWidgets('the SOC caption reads the SOC, not a literal', (tester) async {
    // The left caption used to be the string `'BAT_SOC 0%'` — hardcoded — while
    // the right caption beside it read the real value. On a continuous bar
    // that was merely redundant. The moment the meter became segmented it was
    // a visible contradiction: `0%` printed over eight lit blocks, which is the
    // state this was found in on the device.
    //
    // Asserted as "contains the figure" rather than as an exact string so the
    // separator between the two captions can change without breaking it.
    await tester.pumpWidget(
      wrap(const OverviewReadings(soc: 37)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('BAT_SOC 37%'),
      findsOneWidget,
      reason: 'the caption must say what the pack is actually at',
    );
  });

  testWidgets('an absent SOC prints -- rather than a fabricated zero',
      (tester) async {
    // A device that has never reported is a state to draw, not an error to
    // avoid, and `0%` is a claim about the world.
    await tester.pumpWidget(wrap(const OverviewReadings()));
    await tester.pumpAndSettle();
    expect(find.text('BAT_SOC --%'), findsOneWidget);
  });
}
