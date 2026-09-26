import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plts_monitoring/screens/settings_screen.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
  // A tall surface keeps all nine category tiles laid out at once, so the
  // lazily built ListView does not need scrolling in these assertions.
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'EnerGrow',
    packageName: 'tech.mbkm.energrow',
    version: '1.3.1',
    buildNumber: '9',
    buildSignature: '',
  );
  final themeController = AppThemeController();
  await themeController.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeController.seedColor),
      ),
      home: SettingsScreen(
        themeController: themeController,
        onLogout: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every settings category', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    for (final title in [
      'Appearance',
      'Monitoring',
      'Energy alerts',
      'Environment alerts',
      'Weather',
      'CCTV source',
      'Performance',
      'About',
      'Account',
    ]) {
      expect(find.text(title), findsOneWidget, reason: 'missing $title');
    }
  });

  testWidgets('shows the app version on the About section', (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('EnerGrow monitoring application'), findsOneWidget);
    expect(find.text('v1.3.1+9'), findsOneWidget);
  });

  testWidgets('renders environment limit fields from the controller',
      (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('Environment alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Ambient temperature'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('Water TDS'), findsOneWidget);
    expect(find.text('Min (°C)'), findsOneWidget);
    expect(find.text('Max (ppm)'), findsOneWidget);
  });

  testWidgets('back navigation returns to the category list', (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('Monitoring'));
    await tester.pumpAndSettle();
    expect(find.text('Auto refresh telemetry'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('CCTV source'), findsOneWidget);
  });

  testWidgets('rejects an invalid CCTV url instead of saving',
      (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('CCTV source'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Stream URL'),
      'http://evil.example.com/stream.html',
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(
      find.text('CCTV URL harus HTTPS dan memakai host resmi'),
      findsOneWidget,
    );
    expect(find.text('Settings'), findsOneWidget, reason: 'must stay on screen');
  });
}
