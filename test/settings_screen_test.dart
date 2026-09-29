import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plts_monitoring/screens/settings_screen.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
  // A tall surface keeps all ten category tiles laid out at once, so the
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
  // Order and strings are taken from buildSettingsSections in
  // lib/screens/settings/settings_section.dart, which returns ten sections.
  testWidgets('lists every settings category', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    for (final title in [
      'Appearance', // settings_section.dart:34
      'Monitoring', // settings_section.dart:40
      'Energy alerts', // settings_section.dart:46
      'Environment alerts', // settings_section.dart:52
      'Fish tank alerts', // settings_section.dart:58
      'CCTV source', // settings_section.dart:64
      'Performance', // settings_section.dart:70
      'Background checks', // settings_section.dart:76
      'About', // settings_section.dart:82
      'Account', // settings_section.dart:88
    ]) {
      expect(find.text(title), findsOneWidget, reason: 'missing $title');
    }
  });

  // settings_section.dart:144-165 builds one ListTile per section, so the
  // rendered tile count is the section count. This is what catches a section
  // that exists in the list but is never laid out.
  testWidgets('renders one tile per category', (tester) async {
    await _pumpSettings(tester);

    // settings_screen.dart:144 - `itemCount: _sections.length`.
    expect(find.byType(ListTile), findsNWidgets(10));
  });

  testWidgets('opens the background checks category', (tester) async {
    await _pumpSettings(tester);

    // settings_section.dart:75-80 - the section that was not asserted before.
    await tester.tap(find.text('Background checks'));
    await tester.pumpAndSettle();

    // settings_section.dart:77 - the subtitle is rendered by
    // settings_screen.dart:150 as the detail page's own subtitle.
    expect(
      find.text('Is the alarm check running, and can Android delay it?'),
      findsOneWidget,
    );
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
      find.widgetWithText(TextField, 'Hydroponics camera URL'),
      'http://evil.example.com/stream.html',
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(
      find.text('The CCTV URL must be HTTPS and use an approved host'),
      findsOneWidget,
    );
    expect(find.text('Settings'), findsOneWidget, reason: 'must stay on screen');
  });

  testWidgets('rejects an invalid fish camera url instead of saving', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('CCTV source'));
    await tester.pumpAndSettle();
    // The hydroponics URL is left valid, so the failure can only come from the
    // fish one. Validating only the first field would pass this test silently.
    await tester.enterText(
      find.widgetWithText(TextField, 'Fish camera URL'),
      'https://cctv.mbkm20262027.tech.evil.example/stream.html?src=cam2',
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();

    expect(
      find.text('The fish camera URL must be HTTPS and use an approved host'),
      findsOneWidget,
    );
    expect(find.text('Settings'), findsOneWidget, reason: 'must stay on screen');
  });
}
