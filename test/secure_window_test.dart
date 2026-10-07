import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/cctv_screen.dart';
import 'package:plts_monitoring/services/secure_window.dart';

/// `FLAG_SECURE` follows the camera's *visibility*, not its lifetime.
///
/// Found on the Xiaomi on 7 October 2026: opening Settings from the Hydroponics
/// tab, which carries an inline camera panel, left `dumpsys window` reporting
/// `SECURE` on the dashboard. A pushed route covers a screen without disposing
/// it, so a flag released only in `dispose` stayed set, and every later
/// screenshot of every screen in the app was a black frame. This replays that
/// sequence over the method channel the flag is set through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('tech.mbkm.energrow/secure_window');
  final calls = <bool>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setSecure') {
        calls.add((call.arguments as Map)['secure'] as bool);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('a page pushed over the camera releases the flag, and popping '
      'it back restores it', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [SecureWindow.observer],
        home: const Scaffold(
          body: SingleChildScrollView(
            child: CctvScreen(
              streamUrl: 'https://cctv.mbkm20262027.tech/stream.html?src=cam1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.last, isTrue, reason: 'the camera is on screen');

    // Settings, pushed over the tab that holds the camera.
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      calls.last,
      isFalse,
      reason: 'the camera is covered, so the rest of the app must be '
          'screenshottable again - this is the leak measured on the device',
    );

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls.last, isTrue, reason: 'the camera is visible again');

    // And leaving for good releases it, with no throw from `dispose`.
    await tester.pumpWidget(const MaterialApp(home: Text('gone')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls.last, isFalse, reason: 'the camera is gone');
  });

  testWidgets('a camera on a hidden tab holds no flag', (tester) async {
    // **The case that actually failed on the device.** Both cameras live in the
    // dashboard's `IndexedStack`, so both are mounted on every tab and neither
    // is disposed when the tab changes. `RouteAware` cannot see a tab change --
    // the camera's route is topmost whichever tab is up -- so `didPopNext`
    // re-acquired for a camera sitting behind two other tabs, and `dumpsys
    // window` reported `SECURE` with no camera anywhere on screen.
    bool visible = true;
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [SecureWindow.observer],
        home: StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return Scaffold(
              body: CctvScreen(
                streamUrl: 'https://cctv.mbkm20262027.tech/stream.html?src=cam1',
                isVisible: visible,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.last, isTrue, reason: 'the camera tab is showing');

    setState(() => visible = false);
    await tester.pumpAndSettle();
    expect(
      calls.last,
      isFalse,
      reason: 'a camera on a hidden tab is not being photographed, so it must '
          'not hold a window-wide flag',
    );

    setState(() => visible = true);
    await tester.pumpAndSettle();
    expect(calls.last, isTrue);
  });
}
