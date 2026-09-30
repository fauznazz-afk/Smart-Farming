import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plts_monitoring/screens/settings_screen.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether [ancestor] sits above [descendant] in the element tree.
///
/// Read from the tree rather than from `find.ancestor`, whose result order is
/// not part of its contract — and the whole ink guard is about *which* of two
/// ancestors comes first, so an unspecified order would make the assertion
/// meaningless rather than merely fragile.
bool _isAncestorOf(Element ancestor, Element descendant) {
  var found = false;
  descendant.visitAncestorElements((candidate) {
    if (identical(candidate, ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

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
  // Order and strings are taken from buildSettingsSections in
  // lib/screens/settings/settings_section.dart, which returns nine sections.
  //
  // There were ten. "Performance" was the tenth, holding one switch that
  // promised frosted cards and smoother scrolling, and it went when the surface
  // system was replaced: the `BackdropFilter` it gated had one caller in the
  // whole app and the fills are opaque now, so there was nothing left to frost
  // and nothing left to switch off. The count here is load-bearing — it is the
  // only assertion that notices a section leaving the list.
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
      'Background checks', // settings_section.dart:70
      'About', // settings_section.dart:76
      'Account', // settings_section.dart:82
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
    expect(find.byType(ListTile), findsNWidgets(9));
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

  // ── The ink guard ────────────────────────────────────────────────────────────
  //
  // AGENTS.md claimed this file already catches "AppCard loses its transparent
  // Material between the decorated box and the content". It did not, and it
  // could not have: every other assertion in this file is a `find.text`, a tile
  // count or a tap, and a missing ink layer changes none of those. The
  // regression is invisible to exactly the kind of assertion the file was made
  // of. It is only visible as paint order, so this asserts paint order.
  //
  // The defect it guards, from `AppCard`'s own comment: a `Container` with a
  // `BoxDecoration` paints its background on the same layer as everything inside
  // it, so a `Material` placed *outside* the decorated box is still underneath.
  // The card fill covers the ink layer, and every `ListTile`, `SwitchListTile`
  // and `InkWell` inside loses its splash and its hover state. The fix is the
  // `Material` being between the decorated box and the content.
  //
  // The invariant is checked by walking the element tree rather than by
  // rendering, so it is deterministic and does not depend on a splash being
  // mid-animation.
  testWidgets('keeps a Material between the card fill and its ink', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('Monitoring'));
    await tester.pumpAndSettle();

    // MonitoringSection's `SwitchListTile` is the control that loses its ink.
    // It is the only one on that page, so this cannot pass by finding the wrong
    // tile.
    final switchTile = find.byType(SwitchListTile);
    expect(switchTile, findsOneWidget);
    final switchElement = switchTile.evaluate().single;

    // The decorated box that paints the card fill. `AppCard` builds it as an
    // `AnimatedContainer`, and it is the nearest one above the switch — the
    // page has no other.
    Element? cardBox;
    switchElement.visitAncestorElements((element) {
      if (element.widget is AnimatedContainer) {
        cardBox = element;
        return false;
      }
      return true;
    });
    expect(
      cardBox,
      isNotNull,
      reason: 'the switch must be inside an AppCard for this guard to mean '
          'anything; if SectionCard stopped using AppCard, the ink ownership '
          'moved somewhere else and this test is asserting the wrong tree',
    );

    // The nearest `Material` above the switch — the one that would own its
    // splash. Found by walking outward and stopping at the first one.
    Element? nearestMaterial;
    switchElement.visitAncestorElements((element) {
      if (element.widget is Material) {
        nearestMaterial = element;
        return false;
      }
      return true;
    });
    expect(
      nearestMaterial,
      isNotNull,
      reason: 'a Material must exist above the switch or it has no ink at all',
    );

    expect(
      cardBox!.widget,
      isA<AnimatedContainer>(),
      reason: 'AppCard must keep building its decoration in an AnimatedContainer',
    );

    // The assertion that would actually fail on the regression: the card box
    // must sit *above* the ink-owning Material, i.e. the Material is nested
    // inside the decorated box and paints over the fill.
    //
    // The inverted arrangement — Material wrapping the box — is what a
    // `Material` outside the `Container` looks like, and it is exactly the
    // regression. Both are "a Material is an ancestor of the switch", so the
    // naive check passes either way; the ordering is the whole content.
    expect(
      _isAncestorOf(cardBox!, nearestMaterial!),
      isTrue,
      reason: 'the Material must be a DESCENDANT of the decorated box, not an '
          'ancestor of it. Outside it, the opaque card fill paints over the ink '
          'layer and every switch on this screen loses its splash.',
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
