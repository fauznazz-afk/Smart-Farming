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
}
