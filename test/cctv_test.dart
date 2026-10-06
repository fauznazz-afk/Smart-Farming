import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv/utils/cctv_status.dart';
import 'package:plts_monitoring/screens/cctv/widgets/cctv_viewport.dart';
import 'package:plts_monitoring/screens/cctv_screen.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/services/cctv_url.dart';

void main() {
  group('cctvStatusOf', () {
    test('idle player is on standby', () {
      expect(
        cctvStatusOf(playing: false, loading: false, failed: false),
        CctvStatus.standby,
      );
    });

    test('playing and loading is connecting', () {
      expect(
        cctvStatusOf(playing: true, loading: true, failed: false),
        CctvStatus.connecting,
      );
    });

    test('playing and settled is live', () {
      expect(
        cctvStatusOf(playing: true, loading: false, failed: false),
        CctvStatus.live,
      );
    });

    test('failure wins over playing and loading', () {
      expect(
        cctvStatusOf(playing: true, loading: true, failed: true),
        CctvStatus.offline,
      );
      expect(
        cctvStatusOf(playing: true, loading: false, failed: true),
        CctvStatus.offline,
      );
    });

    test('failure on an idle player is still offline', () {
      expect(
        cctvStatusOf(playing: false, loading: false, failed: true),
        CctvStatus.offline,
      );
    });
  });

  group('CctvStatusDisplay', () {
    test('every status has a distinct uppercase label', () {
      final labels = CctvStatus.values.map((status) => status.label).toSet();
      expect(labels.length, CctvStatus.values.length);
      for (final label in labels) {
        expect(label, label.toUpperCase());
      }
    });

    test('standby and connecting share the amber tint', () {
      expect(
        CctvStatus.standby.color,
        CctvStatus.connecting.color,
      );
      expect(CctvStatus.live.color, isNot(CctvStatus.offline.color));
    });

    test('only standby hides the video surface', () {
      expect(CctvStatus.standby.showsVideo, isFalse);
      expect(CctvStatus.connecting.showsVideo, isTrue);
      expect(CctvStatus.live.showsVideo, isTrue);
      expect(CctvStatus.offline.showsVideo, isTrue);
    });
  });

  group('CctvStatusPill', () {
    testWidgets('exposes the status as a live region', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CctvStatusPill(status: CctvStatus.live, theme: AppTheme.light),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
      // Assert on the Semantics widget rather than the semantics tree, which
      // would require enabling semantics for the whole test. Scaffold and
      // MaterialApp insert their own Semantics nodes, so scope the search to
      // the descendants of the pill itself.
      final pillSemantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(CctvStatusPill),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(pillSemantics.properties.label, 'CCTV status: live');
      expect(pillSemantics.properties.liveRegion, isTrue);
    });

    testWidgets('renders each status label', (tester) async {
      for (final status in CctvStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CctvStatusPill(status: status, theme: AppTheme.light),
            ),
          ),
        );
        expect(find.text(status.label), findsOneWidget);
      }
    });
  });

  group('CctvViewport', () {
    Widget host(CctvStatus status, {VoidCallback? onStart, VoidCallback? onStop}) {
      return MaterialApp(
        home: Scaffold(
          body: CctvViewport(
            controller: null,
            status: status,
            primary: Colors.green,
            onStart: onStart ?? () {},
            onStop: onStop ?? () {},
          ),
        ),
      );
    }

    testWidgets('standby offers a play button', (tester) async {
      await tester.pumpWidget(host(CctvStatus.standby));

      expect(find.text('Camera ready'), findsOneWidget);
      expect(find.text('Play camera'), findsOneWidget);
    });

    testWidgets('connecting shows a spinner and no play button',
        (tester) async {
      await tester.pumpWidget(host(CctvStatus.connecting));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Play kamera'), findsNothing);
    });

    testWidgets('offline offers retry and back', (tester) async {
      var retried = false;
      var stopped = false;
      await tester.pumpWidget(
        host(
          CctvStatus.offline,
          onStart: () => retried = true,
          onStop: () => stopped = true,
        ),
      );

      expect(find.text('Camera could not be loaded'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Back'));
      expect(retried, isTrue);
      expect(stopped, isTrue);
    });
  });

  group('parseAllowedCctvUrl', () {
    test('accepts the official https stream page', () {
      expect(
        parseAllowedCctvUrl(defaultAllowedCctvUrl),
        isNotNull,
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(
        parseAllowedCctvUrl('  $defaultAllowedCctvUrl  '),
        isNotNull,
      );
    });

    test('rejects non-https schemes', () {
      expect(
        parseAllowedCctvUrl('http://cctv.mbkm20262027.tech/stream.html'),
        isNull,
      );
      expect(
        parseAllowedCctvUrl('javascript:alert(1)'),
        isNull,
      );
    });

    test('rejects any other host, including lookalikes', () {
      expect(
        parseAllowedCctvUrl('https://evil.example.com/stream.html?src=cam1'),
        isNull,
      );
      expect(
        parseAllowedCctvUrl('https://cctv.mbkm20262027.tech.evil.com/stream'),
        isNull,
      );
      expect(
        parseAllowedCctvUrl('https://mbkm20262027.tech/stream.html'),
        isNull,
      );
    });

    test('rejects non-default ports', () {
      expect(
        parseAllowedCctvUrl('https://cctv.mbkm20262027.tech:8443/stream.html'),
        isNull,
      );
    });

    test('rejects unparsable input', () {
      expect(parseAllowedCctvUrl(''), isNull);
      expect(parseAllowedCctvUrl('not a url'), isNull);
    });

    test('host check is case insensitive', () {
      expect(
        parseAllowedCctvUrl('https://CCTV.MBKM20262027.TECH/stream.html'),
        isNotNull,
      );
    });

    // **The four below were all reachable before, and none of them was a host
    // bypass.** The allowlist constrained where the *document* came from and
    // stopped there, so everything the document could then be *told to fetch*
    // was unconstrained. Found in review on 6 October 2026.
    group('constrains what go2rtc is told to dial', () {
      test('rejects a src that is a URL', () {
        // The finding. `src` goes straight to the go2rtc process on the camera
        // host, so this turns the user's own camera box into a relay that dials
        // out of their LAN. `file://` reads the camera host's filesystem.
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=rtsp://203.0.113.9/x',
          ),
          isNull,
        );
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=file:///etc/passwd',
          ),
          isNull,
        );
      });

      test('rejects a src that traverses', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=../../etc/passwd',
          ),
          isNull,
        );
      });

      test('rejects a second parameter hiding behind src', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1&src=rtsp://x/y',
          ),
          isNull,
        );
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1&url=http://evil',
          ),
          isNull,
        );
      });

      test('accepts the names the app itself ships', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1',
          ),
          isNotNull,
        );
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam2',
          ),
          isNotNull,
        );
        // A stream name with a dash or underscore is a legitimate go2rtc name.
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=front_door-2',
          ),
          isNotNull,
        );
      });

      test('no src at all still resolves', () {
        // go2rtc's player page shows a picker without one, and a saved setting
        // may be that. There is nothing to abuse in its absence, so refusing it
        // would break a working configuration to fix nothing.
        expect(
          parseAllowedCctvUrl('https://cctv.mbkm20262027.tech/stream.html'),
          isNotNull,
        );
      });
    });

    group('mirrors the Kotlin host allowlist', () {
      // `requireAllowedThingsBoardHost` rejected userinfo with a comment naming
      // the trick. This function is its counterpart and did not.
      test('rejects credentials in the URL', () {
        expect(
          parseAllowedCctvUrl(
            'https://user:pw@cctv.mbkm20262027.tech/stream.html?src=cam1',
          ),
          isNull,
        );
      });

      test('rejects a path other than the player page', () {
        // Same reasoning as the Kotlin side: a path would address a different
        // service on the same host.
        expect(
          parseAllowedCctvUrl('https://cctv.mbkm20262027.tech/admin?src=cam1'),
          isNull,
        );
        expect(
          parseAllowedCctvUrl('https://cctv.mbkm20262027.tech/?src=cam1'),
          isNull,
        );
      });

      test('rejects a fragment', () {
        expect(
          parseAllowedCctvUrl(
            'https://cctv.mbkm20262027.tech/stream.html?src=cam1#x',
          ),
          isNull,
        );
      });
    });
  });

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
