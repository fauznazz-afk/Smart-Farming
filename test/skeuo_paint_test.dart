import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/widgets/liquid_glass.dart';

/// The skeuomorphic surfaces must actually *paint*.
///
/// `flutter analyze` cannot see a decoration Flutter refuses to draw: a
/// `Border` whose sides differ in colour, combined with a `borderRadius` or a
/// circle, is rejected at paint time. A bevel is exactly that shape of border,
/// so every surface carrying one is pumped here.
void main() {
  Widget host(AppTheme theme, Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
      );

  for (final theme in AppTheme.values) {
    for (final variant in ['raised', 'inset', 'pressed']) {
      testWidgets('AppCard $variant paints on ${theme.name}', (tester) async {
        await tester.pumpWidget(host(
          theme,
          AppCard(
            theme: theme,
            inset: variant == 'inset',
            pressed: variant == 'pressed',
            padding: const EdgeInsets.all(16),
            child: const Text('Reading'),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('AppTile paints on ${theme.name}', (tester) async {
      await tester.pumpWidget(host(
        theme,
        AppTile(theme: theme, child: const Text('Tile')),
      ));
      expect(tester.takeException(), isNull);
    });
  }
}
