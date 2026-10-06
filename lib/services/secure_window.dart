import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Block screenshots, screen recording and the Recents thumbnail.
  ///
  /// **Reference-counted, and that is not ceremony.** `FLAG_SECURE` belongs to
  /// the window, not to a widget, so two CCTV screens on screen at once -- the
  /// embedded view and the fullscreen route pushed over it -- share one flag. A
  /// plain boolean released in `dispose` lets whichever state disposes first
  /// clear the flag while a camera is still visible, which is precisely the
  /// finding this exists to close. Found in review on 6 October 2026.
  ///
  /// The count is per-process and is not restored across a hot restart, so the
  /// worst case is a flag left set until the app is killed — which makes
  /// screenshots fail elsewhere rather than exposing a camera.
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
