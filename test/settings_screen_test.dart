import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plts_monitoring/screens/settings_screen.dart';
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

Future<void> _pumpSettings(WidgetTester tester, {Size? surface}) async {
  // A tall surface keeps all nine category tiles laid out at once, so the
  // lazily built ListView does not need scrolling in these assertions.
  //
  // [surface] overrides it for the subtitle tests. They need a phone *width* --
  // at 900 logical px no subtitle wraps, so they would assert nothing about the
  // thing they exist to check. 375dp is the test device's logical width (1220 at
  // density 3.25).
  //
  // The height stays tall even there, and that is deliberate rather than an
  // oversight: wrapping is decided by width alone, so 375 is what these tests
  // are about, while `ListView.builder` lays out lazily and a real 812dp phone
  // viewport (~692dp after app bar and save button) is not reliably enough to
  // build all nine ~80dp tiles. `findsNWidgets(8)` would then fail on how many
  // children the cache extent happened to reach, which has nothing to do with
  // the bug.
  tester.view.physicalSize = surface ?? const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'EnerGrow',
    packageName: 'tech.mbkm.energrow',
    version: '1.3.1',
    buildNumber: '8',
    buildSignature: '',
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: SettingsScreen(onLogout: () async {}),
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
      // Appearance was deleted, not renamed. It held the theme picker and
      // the accent swatches, and both are gone with the four presets: the app
      // is one design, and colour is now categorical -- a hue means a category
      // of data -- so letting the user repaint the app would destroy the one
      // thing the palette is for. The count below is what notices that.
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
    expect(find.byType(ListTile), findsNWidgets(8));
  });

  // The truncation regression. Eight of the nine category subtitles were
  // clipped to one line with an ellipsis on a 375dp phone, so the only prose on
  // the screen explaining what a category does was unreadable on every tile
  // whose string was longer than one line -- all of them except "Application
  // information."
  //
  // These assert the clamp itself rather than a rendered pixel count, so they
  // are independent of font metrics, text scale and the exact strings: the bug
  // was a property on the `Text`, and that is what has to stay gone.
  testWidgets('does not clamp category subtitles to one line', (tester) async {
    // Phone width, so this runs against the layout that actually truncated.
    await _pumpSettings(tester, surface: const Size(375, 1600));

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(8));
    for (var i = 0; i < 8; i++) {
      final tile = tester.widget<ListTile>(tiles.at(i));
      final title = (tile.title! as Text).data;
      final subtitle = tile.subtitle! as Text;
      expect(
        subtitle.maxLines,
        anyOf(isNull, greaterThan(1)),
        reason: 'tile $i ("$title") clamps its subtitle to one line, so the '
            'text is ellipsized on a narrow phone',
      );
      expect(
        subtitle.overflow,
        isNot(TextOverflow.ellipsis),
        reason: 'tile $i ("$title") ellipsizes its subtitle',
      );
    }
  });

  // The cost side of the same change, which is what makes removing the clamp
  // acceptable rather than merely tidy: does the list get taller?
  //
  // Yes, and by more than the two lines it reveals -- measured, not derived.
  // Two earlier versions of this comment predicted the tiles would come out
  // *shorter* than the clamped 72 (arithmetic read out of `ListTile._computeSizes`
  // predicting a "compact" mode) and then that every tile would measure 88.
  // The renderer's actual heights at 375dp are:
  //
  //     72  88  88  128  128  88  128  72  88
  //
  // Three tiles are 128, which is a **four-line** subtitle, and one is the 72
  // single-line tile ("Application information."). So the clamp was hiding two
  // to four lines per tile, not reserving room for one.
  //
  // Both predictions were arithmetic derived from `list_tile.dart` and both were
  // wrong -- the fourth and fifth times in this repo that a relationship derived
  // from source has been the thing that was wrong, after the Dracula alphas, the
  // stale surface list, and the shadow balance probe. Every number here is what
  // the renderer printed.
  //
  // **The 144 is those 128 plus the card padding change, and that is the whole
  // derivation.** `AppCard`'s padding went from 14 to the brief's 20, so every
  // tile grows by 12 and the tallest lands at 144. Nothing about the subtitles
  // changed. Recorded because the previous version of this file would have had
  // to be edited 128 -> 144 with no explanation, and the next reader has no way
  // to tell a re-derivation from a nudge.
  //
  // The cost is real: nine tiles at those heights rather than nine at 72 is about
  // 200dp more scrolling. That is the cheap direction in which to be wrong,
  // because a clipped subtitle cannot be recovered by scrolling and a taller
  // tile can. The Save button is in `bottomNavigationBar`, so it is pinned by
  // construction and cannot be pushed off screen.
  testWidgets('no settings tile grows past a four-line subtitle', (
    tester,
  ) async {
    // Phone width again -- a height measured at 900px would be the height of a
    // list where nothing wrapped, i.e. the layout that was already fine.
    await _pumpSettings(tester, surface: const Size(375, 1600));

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(8));
    for (var i = 0; i < 8; i++) {
      final height = tester.getSize(tiles.at(i)).height;
      expect(
        height,
        lessThanOrEqualTo(144.0),
        reason: 'tile $i is ${height}dp, past the 128dp the longest wrapped '
            'subtitle measures at this width. The tallest tiles are '
            'four-line subtitles; a fifth line is what would show up here, and '
            'it is the point at which the copy wants shortening rather than '
            'more height.',
      );
    }
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
    // **Matched, not written down.** This used to assert a literal
    // `v1.3.1+9`, which is the copy-that-rots shape: it passed while the app was
    // at 1.8.0+17 and would have kept passing, because nothing about the rest of
    // the assertion changes when only the version moves. The version is a
    // *property of the build*, and the same rule applies here as for the surface
    // list in `color_helpers_test.dart` — if it can be read, read it.
    expect(
      find.textContaining(RegExp(r'^v\d+\.\d+\.\d+\+\d+$')),
      findsOneWidget,
      reason: 'the About section shows the app name and the version it was '
          'built from',
    );
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
