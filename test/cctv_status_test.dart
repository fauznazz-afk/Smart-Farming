import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv/utils/cctv_status.dart';
import 'package:plts_monitoring/screens/cctv/widgets/cctv_viewport.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';

// Split out of the former `cctv_test.dart`, which at 34 tests had outgrown the
// RAM budget for a single file on this 7 GB machine: `dart_test.yaml` pins
// `concurrency: 1` because the Dart compiler and the test isolate compete, and a
// file that is too large loses that race as a bare "loading <file>.dart" or
// "did not complete" with no stack trace. Every group here passes standalone,
// which is what makes that diagnosis rather than a guess.
//
// What lands here is the status model and the two widgets that render it. The
// allowlist guards are in `cctv_allowlist_test.dart` and the screen is in
// `cctv_screen_test.dart`.
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
}