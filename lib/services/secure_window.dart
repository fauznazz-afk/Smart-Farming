import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Window-level screen capture control, for the screens that must not be
/// photographable.
///
/// `FLAG_SECURE` has no Flutter API. It is set here rather than in the widget
/// tree because it belongs to the window, not to a widget, and it survives a
/// rebuild — which is what makes it worth having a channel at all: a flag applied
/// in `build` would be reapplied on every frame and would not survive the route
/// change that follows.
///
/// Every call is best effort. A `MissingPluginException` means the host is not
/// Android, and there is no window flag to set there in any case.
class SecureWindow {
  const SecureWindow._();

  static const MethodChannel _channel =
      MethodChannel('tech.mbkm.energrow/secure_window');

  static int _holders = 0;

  /// The single observer every secure screen subscribes to.
  ///
  /// **One instance, shared, and registered on `MaterialApp.navigatorObservers`.**
  /// A screen that is covered by a pushed route is not visible, so it must not
  /// hold a flag whose entire purpose is to prevent being photographed. Without
  /// this, the flag outlives the screen's visibility and the app becomes
  /// un-screenshottable everywhere.
  static final RouteObserver<ModalRoute<void>> observer =
      RouteObserver<ModalRoute<void>>();

  /// Block screenshots, screen recording and the Recents thumbnail.
  ///
  /// **Reference-counted, and that is not ceremony.** `FLAG_SECURE` belongs to
  /// the window, not to a widget, so two CCTV screens on screen at once -- the
  /// embedded view and the fullscreen route pushed over it -- share one flag. A
  /// plain boolean released in `dispose` lets whichever state disposes first
  /// clear the flag while a camera is still visible, which is precisely the
  /// finding this exists to close. Found in review on 6 October 2026.
  ///
  /// **Counting alone was not enough, and the device said so.** Measured on the
  /// Xiaomi on 7 October 2026: opening Settings from the Hydroponics tab, which
  /// carries an inline camera panel, left `dumpsys window` reporting `SECURE` on
  /// the *dashboard*. Pushing a route covers a screen without disposing it, so
  /// `dispose` -- the only place [release] was called from -- never ran, the
  /// count stayed at 1, and every later screenshot of every other screen in the
  /// app was a black frame.
  ///
  /// The cost is not a security win. It is an app the user cannot screenshot
  /// anywhere, cannot file a bug report from, and that the developer cannot
  /// inspect -- and it is the same failure the count was introduced to prevent,
  /// reached from the other side: not releasing early, but never releasing at
  /// all. The previous comment here called the worst case "a flag left set until
  /// the app is killed", which described the bug accurately and then declined to
  /// treat it as one.
  ///
  /// **[observer] is what the count was missing.** A screen that is covered is
  /// not visible, so it should not hold a flag that protects against being
  /// photographed. `didPush` releases, `didPopNext` re-acquires, and `dispose`
  /// releases for good. The count is unchanged, so two genuinely-visible
  /// cameras still share one flag and neither can be cleared by the other.
  static Future<void> acquire() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _holders++;
    await _apply();
  }

  static Future<void> release() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_holders > 0) _holders--;
    await _apply();
  }

  static Future<void> _apply() async {
    final secure = _holders > 0;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException catch (e) {
      // Not fatal: the screen still works, it is just photographable. Worth
      // saying, because "it failed quietly" is indistinguishable from "it is
      // protected" until the moment someone photographs it.
      debugPrint('SecureWindow: could not apply secure=$secure (${e.message})');
    } on MissingPluginException {
      // Host without the plugin. Nothing to do, and nothing to report.
    }
  }
}
