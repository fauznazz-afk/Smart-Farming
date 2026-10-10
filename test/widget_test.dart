import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:plts_monitoring/widgets/brand_logo.dart';

void main() {

  testWidgets('brand logo renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLogo(size: 64))),
    );
    expect(find.byType(BrandLogo), findsOneWidget);
  });

  test(
    'AppThemeController survives load and dispose with no state',
    () async {
      // The appearance settings it used to carry (an `AppTheme` option and an
      // accent seed) were removed when the app became single-theme. `load()` is
      // retained for its one call site in `main.dart`, so what is pinned here is
      // that loading and disposing still work and that it never notifies.
      final controller = AppThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.load();
      expect(notified, 0, reason: 'there is no state, so there is nothing to announce');

      controller.dispose();
    },
  );
}
