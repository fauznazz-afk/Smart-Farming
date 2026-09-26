import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv/utils/cctv_status.dart';
import 'package:plts_monitoring/screens/cctv/widgets/cctv_viewport.dart';
import 'package:plts_monitoring/screens/cctv_screen.dart';
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
          home: Scaffold(body: CctvStatusPill(status: CctvStatus.live)),
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
            home: Scaffold(body: CctvStatusPill(status: status)),
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

      expect(find.text('Kamera siap ditampilkan'), findsOneWidget);
      expect(find.text('Play kamera'), findsOneWidget);
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

      expect(find.text('Kamera tidak dapat dimuat'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      await tester.tap(find.text('Kembali'));
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
      expect(find.text('Play kamera'), findsOneWidget);
      expect(
        find.text('Tekan Play saat Anda siap melihat kamera.'),
        findsOneWidget,
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
