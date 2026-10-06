import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/utils/app_log.dart';

/// Pins the debug-mode half of `appLog`.
///
/// The half that matters for security — that nothing is evaluated in release —
/// cannot be tested here, and this file does not pretend otherwise. `flutter
/// test` runs with asserts enabled, so `kReleaseMode` is false and the `assert`
/// body always executes; a test asserting "prints nothing in release" would pass
/// for the wrong reason and prove nothing. Verifying that a release APK is
/// silent is a device job: build it, install it, read `adb logcat`.
///
/// What *is* worth pinning is the contract the call sites depend on, because
/// both plausible refactors of this helper break it silently and neither is a
/// compile error:
///
/// - Swapping the body for a bare `debugPrint(message)` and passing a `String`
///   instead of a thunk, which reintroduces the bug the thunk exists to prevent.
///   That reappears as a release build doing the interpolation work for nothing.
/// - Emptying the body, which reads like a harmless "this logs too much" cleanup
///   and silently deletes every alarm-sync diagnostic line in the process. The
///   rule-id list is the only place the armed rule set is visible anywhere --
///   Settings reports thresholds, not the rules they produced -- so losing it
///   makes "the background check armed the wrong rules" undiagnosable.
void main() {
  final lines = <String?>[];

  setUp(() {
    final original = debugPrint;
    addTearDown(() => debugPrint = original);
    lines.clear();
    // `flutter_test` overrides `debugPrint` itself; replacing that is
    // intentional, and restoring the captured value in `addTearDown` leaves the
    // suite as it found it.
    debugPrint = (message, {wrapWidth}) => lines.add(message);
  });

  test('emits the message it is given', () {
    appLog(() => 'Alarm sync: rules=low_soc,stale_fish');

    expect(lines, ['Alarm sync: rules=low_soc,stale_fish']);
  });

  test('evaluates the thunk exactly once', () {
    // The evaluation count is the observable form of "the argument is not
    // computed twice", which is the thing that would make the helper expensive
    // enough for someone to bypass it.
    var calls = 0;
    appLog(() {
      calls++;
      return 'x';
    });

    expect(calls, 1);
    expect(lines, ['x']);
  });

  test('an exception in the thunk propagates in debug rather than vanishing', () {
    // Deliberately not wrapped in a try/catch. A logger that swallowed its own
    // failures would take the message with them, and the messages are the only
    // record of a background alarm arming the wrong rules.
    expect(() => appLog(() => throw StateError('boom')), throwsStateError);
  });
}
