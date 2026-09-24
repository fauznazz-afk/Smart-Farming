// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:plts_monitoring/widgets/brand_logo.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('brand logo renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLogo(size: 64))),
    );
    expect(find.byType(BrandLogo), findsOneWidget);
  });

  test(
    'AppThemeController defaults to dark mode and toggles mode properly',
    () async {
      final controller = AppThemeController();
      await controller.load();
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);

      await controller.toggleDarkMode(false);
      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isDarkMode, isFalse);

      await controller.toggleDarkMode(true);
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);
    },
  );
}
