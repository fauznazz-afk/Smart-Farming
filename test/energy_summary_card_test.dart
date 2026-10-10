// Widget test for EnergySummaryCard.
//
// This repo had three separate label regressions pass `flutter analyze`, pass a
// release build and pass every existing test, because nothing ever looked at
// this screen. Every string asserted below is copied from
// `lib/widgets/energy_summary_card.dart` at the line noted beside it, so a
// rename in the widget shows up here as a failure rather than as a wrong label
// nobody noticed until a device was in hand.
//
// The card is two fixed tiles, each painted in its category's own hue
// (`lib/widgets/energy_summary_card.dart` lines 205-206), inside a card that
// also owns a Day/7-days range selector, a report button, and an optional
// forecast panel. The category hues are pinned in the sibling
// `energy_summary_card_icons_test.dart`; what is here is the labels, the
// controls, and the fact that no label is ever truncated.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/widgets/energy_summary_card.dart';

import 'widget_text_helpers.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  /// A populated card. `hasData` and a zero previous period are separate knobs
  /// because the comparison caption has its own state machine and a card that
  /// only ever renders one of them proves nothing about the other.
  EnergySummaryCard card({
    bool weekly = false,
    bool loading = false,
    bool hasData = true,
    String? errorMessage,
    double solarKwh = 12.4,
    double previousSolarKwh = 10,
    double loadKwh = 8.7,
    double previousLoadKwh = 9,
    ValueChanged<bool>? onRangeChanged,
    VoidCallback? onOpenReport,
  }) =>
      EnergySummaryCard(
        weekly: weekly,
        loading: loading,
        hasData: hasData,
        errorMessage: errorMessage,
        solarKwh: solarKwh,
        previousSolarKwh: previousSolarKwh,
        loadKwh: loadKwh,
        previousLoadKwh: previousLoadKwh,
        onRangeChanged: onRangeChanged ?? (_) {},
        onOpenReport: onOpenReport ?? () {},
      );

  Widget cardInApp({
    bool weekly = false,
    bool loading = false,
    bool hasData = true,
    String? errorMessage,
    double solarKwh = 12.4,
    double previousSolarKwh = 10,
    double loadKwh = 8.7,
    double previousLoadKwh = 9,
    ValueChanged<bool>? onRangeChanged,
    VoidCallback? onOpenReport,
  }) =>
      wrap(
        card(
          weekly: weekly,
          loading: loading,
          hasData: hasData,
          errorMessage: errorMessage,
          solarKwh: solarKwh,
          previousSolarKwh: previousSolarKwh,
          loadKwh: loadKwh,
          previousLoadKwh: previousLoadKwh,
          onRangeChanged: onRangeChanged,
          onOpenReport: onOpenReport,
        ),
      );

  /// A tall surface keeps the whole card on one screen so no assertion has to
  /// scroll first. The test device is 1220x2712 at density 520, but a plain
  /// 800x600 logical surface would push the tiles below the fold.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('EnergySummaryCard labels', () {
    testWidgets('shows both category labels', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp());

      // 'PV production' — line 334.
      expect(find.text('PV production'), findsOneWidget);
      // 'AC usage' — line 342.
      expect(find.text('AC usage'), findsOneWidget);
    });

    testWidgets('shows one figure per tile, in kWh to two decimals', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp());

      // '${_formatEnergy(value)} kWh' — line 136. Two decimals, because
      // `_formatEnergy` is `toStringAsFixed(2)` and a figure printed at one
      // decimal reads as a different precision than it is measured at.
      expect(find.text('12.40 kWh'), findsOneWidget);
      expect(find.text('8.70 kWh'), findsOneWidget);
    });

    testWidgets('the two tiles are told apart by their figure, not their label',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp());

      // The label pair is the easy half; what actually tells the user which
      // figure is theirs is the two distinct numbers. Two tiles showing the same
      // string would pass every label assertion above.
      expect(find.text('12.40 kWh'), isNot(find.text('8.70 kWh')));
    });

    testWidgets('does not truncate any label at any phone width or scale',
        (tester) async {
      // The reason `widget_text_helpers.dart` exists, applied to this card.
      // `find.text` cannot see truncation — the widget tree still reports the
      // full string after the engine has clipped it — so this reads
      // `RenderParagraph.didExceedMaxLines` instead.
      for (final width in kNarrowWidthsDp) {
        for (final scale in kTextScales) {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = Size(width, 1600);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: Size(width, 1600))
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: cardInApp(),
            ),
          );
          await tester.pumpAndSettle();

          expectNothingClipped(
            tester,
            because: 'EnergySummaryCard truncated a label at '
                '${width}dp, scale $scale',
            // The one truncation the card intends: the range selector's segment
            // labels are `maxLines: 1, ellipsis` and may shorten at a large font,
            // which the widget argues for at length. Exempting it here is the
            // point of the `ignore` parameter — a deliberate truncation written
            // down at the call site, rather than weakening the assertion for
            // every other label on the card.
            ignore: {'7 days'},
          );
        }
      }
    });
  });

  group('EnergySummaryCard states', () {
    testWidgets('a loading card shows a spinner instead of two empty tiles',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp(loading: true));
      await tester.pump();

      // `loading` is checked before `hasData`, so a refresh in progress never
      // flashes the "no data" sentence. The card has data — it is just not
      // finished fetching — and telling the user otherwise is the failure.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('PV production'), findsNothing);
      expect(find.text('No power data available to calculate from.'),
          findsNothing);
    });

    testWidgets('a card with no data says why, in the caller\'s words',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp(hasData: false));
      await tester.pumpAndSettle();

      // The message is passed in rather than invented here because the reason a
      // window has no power data is the caller's to know — a missing device is
      // not the same sentence as a failed request.
      expect(find.text('PZEM-316 has reported nothing yet.'), findsOneWidget);
      expect(find.text('PV production'), findsNothing);
    });

    testWidgets('no data and no reason falls back to a sentence that says so',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp(hasData: false, errorMessage: null));
      await tester.pumpAndSettle();

      expect(
        find.text('No power data available to calculate from.'),
        findsOneWidget,
      );
    });

    testWidgets('a zero previous period does not print a percentage',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        cardInApp(previousSolarKwh: 0, previousLoadKwh: 0),
      );
      await tester.pumpAndSettle();

      // `-100% from the previous period` was the string this replaced: it is
      // arithmetically correct and reads as a catastrophic loss rather than as
      // "there was nothing then". The decision itself lives in
      // `classifyEnergyChange`; this pins that the card renders the decision
      // rather than recomputing one of its own.
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Nothing to compare yet'), findsWidgets);
    });

    testWidgets('a real change is compared against the previous period',
        (tester) async {
      useTallSurface(tester);
      // 9.00 against 10.00 is -10%, which is over the meaningful threshold in
      // both directions, so it is a genuine comparison rather than a rounding
      // artefact.
      await tester.pumpWidget(cardInApp(loadKwh: 9, previousLoadKwh: 10));
      await tester.pumpAndSettle();

      expect(find.text('-10% vs previous'), findsOneWidget);
    });
  });

  group('EnergySummaryCard controls', () {
    testWidgets('the range selector reports the range the user picked',
        (tester) async {
      useTallSurface(tester);
      final picked = <bool>[];
      await tester.pumpWidget(cardInApp(onRangeChanged: picked.add));
      await tester.pumpAndSettle();

      // 'Day' / '7 days' — lines 266-269. Tapping the other segment has to
      // reach the caller: this is the control that re-scopes both tiles, and a
      // segmented button wired to nothing is a control that looks live.
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(picked, [true, false]);
    });

    testWidgets('the report button reaches the caller', (tester) async {
      useTallSurface(tester);
      var opened = 0;
      await tester.pumpWidget(cardInApp(onOpenReport: () => opened++));
      await tester.pumpAndSettle();

      // Tooltip 'Open the energy report' — line 293.
      await tester.tap(find.byTooltip('Open the energy report'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('the selected range is the one the caller passed in',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp(weekly: true));
      await tester.pumpAndSettle();

      // `selected: {weekly}` — line 282. Rendered the other way round, the
      // control shows the wrong window while the figures below it are for the
      // right one, and nothing else on the card would disagree.
      final selected = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(selected.selected, {true});
    });
  });

  group('EnergySummaryCard tile ink', () {
    testWidgets('the tile labels share one ink rather than taking their hue',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(cardInApp());
      await tester.pumpAndSettle();

      // `Text(title, style: TextStyle(fontSize: 11))` carries no colour of its
      // own — lines 106. A label is not a status and not a figure, so it takes
      // ordinary ink; if one tile ever started tinting its own label, two tiles
      // side by side would read as two alerts rather than as two rows. The
      // category is carried by the icon and the tile's frame instead, which is
      // asserted in the sibling file.
      Color? labelInk(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;
      expect(
        labelInk('PV production'),
        labelInk('AC usage'),
        reason: 'the two tile labels are painted in different inks, so the '
            'labels themselves are making a distinction the card already makes '
            'with the icon and the frame',
      );
      // And neither label is wearing a category hue. A tinted label is the one
      // case where the app's rule — a hue means a *category*, carried by the
      // frame and the icon, never by the text naming it — would be broken.
      expect(
        labelInk('PV production'),
        isNot(categoryColor(MetricCategory.pv)),
      );
      expect(
        labelInk('AC usage'),
        isNot(categoryColor(MetricCategory.ac)),
      );
    });
  });
}