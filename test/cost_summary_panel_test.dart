import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/cost_summary_panel.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/terminal_panel.dart';

/// The cost card, and the two rules it exists to enforce: it says nothing until
/// it can say something true, and it never borrows a status colour.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 381, child: child),
      ),
    ),
  );

  CostSummaryPanel panel({
    double tariff = 1500,
    double? wp = 5000,
    double solarKwh = 12,
    double loadKwh = 8,
    double hours = 24,
  }) => CostSummaryPanel(
    solarKwh: solarKwh,
    loadKwh: loadKwh,
    periodLabel: 'Last 24 hours',
    hours: hours,
    tariffPerKwh: tariff,
    installedWp: wp,
  );

  testWidgets('renders nothing when the user has supplied neither number', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CostSummaryPanel(
          solarKwh: 12,
          loadKwh: 8,
          periodLabel: 'Last 24 hours',
          hours: 24,
        ),
      ),
    );

    // **Absent, not empty.** A frame with dashes in it says "we looked and found
    // nothing", and the truth is "you have not told us the price of a kWh".
    expect(find.byType(TerminalPanel), findsNothing);
    expect(find.byType(TerminalRow), findsNothing);
  });

  testWidgets('a tariff alone shows money and no performance', (tester) async {
    await tester.pumpWidget(wrap(panel(wp: null)));

    expect(find.text('SOLAR_VALUE'), findsOneWidget);
    expect(find.text('LOAD_COST'), findsOneWidget);
    expect(find.text('BALANCE'), findsOneWidget);
    expect(find.text('Rp 18.000'), findsOneWidget);
    // No nameplate means no ratio, so those rows must not exist at all.
    expect(find.text('PERFORMANCE'), findsNothing);
    expect(find.text('FULL_LOAD'), findsNothing);
  });

  testWidgets('a nameplate alone shows performance and no money', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const CostSummaryPanel(
          solarKwh: 10,
          loadKwh: 8,
          periodLabel: 'Last 24 hours',
          hours: 24,
          installedWp: 5000,
        ),
      ),
    );

    expect(find.text('PERFORMANCE'), findsOneWidget);
    expect(find.text('SOLAR_VALUE'), findsNothing);
    // 10 kWh from a 5 kW array is two full-load hours, 8.3% of the day.
    expect(find.text('2.00'), findsOneWidget);
    expect(find.text('8.3'), findsOneWidget);
  });

  // **The nameplate is echoed back because every other row is that number
  // divided by something.** A mis-keyed 4500 for 450 produces a set of ratios
  // that are wrong by ten and look entirely plausible.
  testWidgets('the nameplate is shown so a mis-keyed value is visible', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(panel()));

    expect(find.text('RATED_WP'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  // **A negative balance is an ordinary night, not a breach.** The app's rule is
  // that a status colour means a condition, and colouring this red would put a
  // permanent alarm on the dashboard for something nobody can act on.
  testWidgets('a negative balance is not painted as an alert', (tester) async {
    await tester.pumpWidget(
      wrap(
        panel(
          solarKwh: 1,
          loadKwh: 9,
        ),
      ),
    );

    expect(find.text('-Rp 12.000'), findsOneWidget);
    final row = tester.widget<TerminalRow>(
      find.widgetWithText(TerminalRow, 'BALANCE'),
    );
    expect(row.alert, isFalse, reason: 'a loss is not a breach');
  });

  testWidgets('announces itself as cost and performance, not as Overview', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(panel()));

    expect(find.bySemanticsLabel('Cost and performance'), findsOneWidget);
    handle.dispose();
  });
}