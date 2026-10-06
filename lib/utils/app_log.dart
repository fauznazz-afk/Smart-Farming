import 'package:flutter/foundation.dart';

/// Writes one diagnostic line to the platform log, and to nothing at all in a
/// release or profile build.
///
/// **Why a helper rather than `debugPrint` at each call site.** `debugPrint` is
/// *not* stripped in release builds. It is the same function in every mode, it
/// lands in logcat, and on Android logcat is readable by anyone with USB
/// debugging enabled or by anyone who can take an `adb bugreport` off the
/// device. The rating of that is genuinely low — `READ_LOGS` has been
/// signature/privileged since Android 4.1, so no third-party app on the phone
/// can read these — but "low" is a statement about who can read them, not about
/// what is in them. What these particular lines carried was reconnaissance: the
/// armed rule-id list names every monitored condition (`low_soc`, `stale_fish`,
/// `environment_tds_high`, `fish_ph_low`), the thresholds say which values this
/// particular installation cares about, and the target host says whose
/// ThingsBoard it is. None of that is a credential, and it is exactly the
/// material that makes a stolen JWT worth stealing. So it does not ship.
///
/// **The thunk is the point, not the guard.** The argument is a
/// `String Function()` and not a `String` because the interesting call sites
/// build their message out of a `join(',')` over the rule list or a
/// `$exception` interpolation. With a plain `String` parameter the message is
/// evaluated at the call site *before* the function is entered, so any guard
/// living inside the helper cannot stop it — the sensitive string is built,
/// allocated and thrown away in a release build even though it is never printed.
/// Taking a thunk moves the work inside the `assert`, and `assert` is removed by
/// the front end in release and profile builds, so neither the message nor the
/// closure ever exists.
///
/// An `if (kDebugMode)` guard was rejected for this reason rather than a
/// preference: it happens to work today, because `kDebugMode` is a `const false`
/// in profile and release and the tree shaker removes the dead branch and the
/// argument with it. But that is a property of the optimizer, not of the
/// language, and it is one tree-shaker regression away from building every
/// message in every build. The `assert` version is removed by the front end
/// before optimization is even a question. `kReleaseMode` was rejected for the
/// opposite reason: it is true in release but *false* in profile, so it would
/// leave the full rule list in logcat for anyone testing a profile build, which
/// is exactly the build a developer hands to a colleague with a bug report.
///
/// **What this does not promise.** The `appLog(...)` call and the allocation of
/// the closure object itself survive into a release build; only the closure
/// *body* — and therefore every string interpolation inside it — is removed.
/// So nothing sensitive is evaluated, but nothing structural is either, and this
/// file is not a way to prove a release APK is silent. That is `adb logcat` on a
/// real device. Do not read a passing analyzer run as evidence either way.
///
/// **What this gives up.** `adb logcat` is a legitimate debugging tool, and the
/// lines this replaces are load-bearing for the alarm module: the rule-id list
/// is how "the background check armed the wrong rules" is diagnosed at all, and
/// there is no UI that reports it — a wrong rule set simply means no
/// notification appears, which is indistinguishable from no alarm. Anyone
/// chasing a user-reported alarm bug from a release APK now has to ask for a
/// debug build, or reproduce locally. That is a real cost and it was accepted
/// deliberately: the information is worth less than the fact that a user's
/// monitoring profile should not be readable off their phone by a USB cable.
///
/// Note that the Kotlin side logs device wire names and check outcomes through
/// `android.util.Log`, and `Log.d` is *also* not stripped in release. This helper
/// covers the Dart half only; the native half needs the same treatment with
/// `BuildConfig.DEBUG`, and that file is owned elsewhere.
void appLog(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}
