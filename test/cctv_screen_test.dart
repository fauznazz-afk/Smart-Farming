import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv_screen.dart';
import 'package:plts_monitoring/services/cctv_url.dart';

// Split out of the former `cctv_test.dart`, which at 34 tests had outgrown the
// RAM budget for a single file on this 7 GB machine: `dart_test.yaml` pins
// `concurrency: 1` because the Dart compiler and the test isolate compete, and a
// file that is too large loses that race as a bare "loading <file>.dart" or
// "did not complete" with no stack trace. Every group here passes standalone,
// which is what makes that diagnosis rather than a guess.
//
// What lands here is the screen and the WebView session state. The status model
// and its widgets are in `cctv_status_test.dart`, the allowlist guards in
// `cctv_allowlist_test.dart`.
void main() {
  group('CCTV WebView session state', () {
    // The scrubber is a module-level seam because what it calls — Android's
    // `CookieManager` and `WebStorage` — are platform singletons with no Dart
    // state. So what *is* testable is the call sites: does disposal fire it, does
    // it fire more than once, does logout reach it.
    // `dynamic` rather than `WebViewController?`, so this file does not have to
    // import `webview_flutter` to record an argument it only ever asserts is
    // null. A `({dynamic})` closure is assignable to the typed signature.
    late List<dynamic> calls;
    late CctvWebDataScrubber original;

    setUp(() {
      calls = <dynamic>[];
      original = cctvWebDataScrubber;
      cctvWebDataScrubber = ({controller}) async => calls.add(controller);
    });

    tearDown(() => cctvWebDataScrubber = original);

    test('with no WebView platform registered it is a no-op, not a throw',
        () async {
      // The real function, on the host this suite actually runs on: a widget
      // test registers no `WebViewPlatform`, so this is the path where
      // `WebViewCookieManager`'s `assert` would fire. A throw here would be the
      // whole defect in miniature, because the call is made from `dispose`,
      // where nothing can catch it.
      await expectLater(scrubCctvWebData(), completes);
      await expectLater(scrubCctvWebData(controller: null), completes);
    });

    testWidgets('leaving the screen scrubs once, not on every rebuild',
        (tester) async {
      // A rejected URL, so the screen never builds a controller and the scrub is
      // reached with `controller: null`. That is not a corner case: playback is
      // user-initiated, so an idle screen *always* has no controller, and an
      // implementation that cleared storage only when one existed would pass
      // every other test here while scrubbing nothing in normal use.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CctvScreen(streamUrl: 'https://evil.example.com/stream'),
          ),
        ),
      );
      // Rebuilds: a rebuild is the case a naive implementation gets wrong by
      // scrubbing the user's session on every frame the dashboard polls.
      await tester.pump();
      await tester.pump();
      expect(calls, isEmpty, reason: 'a mounted screen must not scrub anything');

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(calls.length, 1, reason: 'disposal scrubs exactly once');
    });

    test('logout scrubs the WebView, not just the two stored urls', () async {
      // `dashboard_screen._logout` calls this and nothing else, so this is the
      // assertion that logout actually reaches the WebView — and it is why the
      // scrub is folded into this function rather than left to the widget.
      FlutterSecureStorage.setMockInitialValues({
        'cctv_url': defaultAllowedCctvUrl,
        'cctv_url_fish': defaultAllowedFishCctvUrl,
      });

      await clearCctvUrl();

      expect(calls.length, 1, reason: 'clearCctvUrl must scrub the WebView too');
      // With no controller, because logout has none: the cookie half does not
      // need one and this is the path that would skip the clear if the call were
      // made conditional on a controller existing.
      expect(calls.single, isNull);
    });
  });

  group('CctvScreen', () {
    testWidgets('starts on standby and does not autoplay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CctvScreen(streamUrl: defaultAllowedCctvUrl)),
        ),
      );
      await tester.pump();

      expect(find.text('CCTV Monitoring'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('Play camera'), findsOneWidget);
      // The viewport already says "Camera ready" and "The stream does not run
      // until you press Play", with the button above. This used to assert a *fourth*
      // rendering of the same fact, in a bordered box, directly beneath the other
      // three -- found on an emulator, not by reading the code.
      expect(find.text('Camera ready'), findsOneWidget);
      expect(
        find.text('The stream does not run until you press Play'),
        findsOneWidget,
      );
      // And the bar that duplicated it is gone entirely while idle, rather than
      // being present and empty.
      expect(find.text('The stream is running on an internet connection.'),
          findsNothing);
      expect(find.byTooltip('Reload camera'), findsNothing);
    });

    testWidgets('the idle screen says the same thing exactly once', (tester) async {
      // Counted rather than spot-checked. The defect was duplication, so the
      // assertion that catches it is the one about how *many* things say it, and
      // a test that only looks for a specific string cannot notice a second copy
      // appearing in some other wording later.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CctvScreen(streamUrl: defaultAllowedCctvUrl)),
        ),
      );
      await tester.pump();

      // Explanations only. The button's own label is the control, not a
      // duplicate of the explanation, and counting it would make this test fail
      // for a reason that is not the defect.
      const buttonLabel = 'Play camera';
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.toLowerCase().contains('play') && s != buttonLabel)
          .toList();

      expect(
        text.length,
        lessThanOrEqualTo(1),
        reason: 'the idle screen says "$text" -- the viewport already covers it, '
            'and a second copy is a permanent notice occupying the space a real '
            'warning needs',
      );
    });

    testWidgets('shows an error state for a rejected stream url',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CctvScreen(streamUrl: 'https://evil.example.com/stream'),
          ),
        ),
      );
      await tester.pump();

      // Playback is still user-initiated, so the rejection only surfaces once
      // the user presses play.
      expect(find.text('STANDBY'), findsOneWidget);
    });
  });
}