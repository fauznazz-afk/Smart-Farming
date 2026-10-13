import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/services/widget_refresh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetRefresh', () {
    // The widget exists only on Android, so a plugin that is simply not there is
    // the normal case on every other platform and in a test. The point of these
    // is that it does not throw - the caller is a fire-and-forget chain attached
    // to the dashboard's telemetry poll, and an exception there would be a
    // red-screen on every launch of a desktop build.
    test('a missing plugin is a false, not a throw', () async {
      const refresh = WidgetRefresh();
      // No handler registered for the channel, so the platform replies
      // MissingPluginException.
      final delivered = await refresh.refresh();
      expect(delivered, isFalse);
    });

    test('calls refreshWidget on its channel', () async {
      const channel = MethodChannel('tech.mbkm.energrow/widget');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final delivered = await const WidgetRefresh().refresh();

      expect(delivered, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'refreshWidget');
    });
  });
}