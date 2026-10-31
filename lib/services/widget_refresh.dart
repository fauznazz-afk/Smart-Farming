import 'package:flutter/services.dart';

import '../utils/app_log.dart';

/// Asks the native side to redraw every placed home-screen widget.
///
/// ## Why this exists
///
/// Android's declared widget period has a floor of thirty minutes, and the
/// launcher honours nothing shorter. So a widget on its own schedule would be
/// showing a number up to half an hour old while the app was open and polling
/// every ten seconds - which is exactly the arrangement that makes a home-screen
/// widget worthless, since the user would have to open the app to learn anything.
///
/// The data was already written by the same poll. This only says "look again".
///
/// ## Why it is fire-and-forget
///
/// [refresh] never throws and never blocks. A widget that failed to redraw is
/// stale, and it says so - it carries its own age line - so a failed call costs
/// the user a number they are already being told is old. Propagating the
/// failure into the poll would put an optional convenience on the critical path
/// of the dashboard's data.
class WidgetRefresh {
  const WidgetRefresh();

  static const MethodChannel _channel = MethodChannel(
    'tech.mbkm.energrow/widget',
  );

  /// Redraws every placed widget. Returns whether the call reached the platform.
  ///
  /// **A `MissingPluginException` is the normal case on desktop, iOS and in a
  /// widget test**, and it is not an error: the widget exists only on Android.
  /// It is caught and reported as `false` rather than thrown so a caller does
  /// not need to know that.
  Future<bool> refresh() async {
    try {
      await _channel.invokeMethod<void>('refreshWidget');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      appLog(() => 'WidgetRefresh: ${error.code}');
      return false;
    }
  }
}