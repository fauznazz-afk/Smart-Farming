package tech.mbkm.energrow.alarm

import android.util.Log
import tech.mbkm.energrow.BuildConfig

/**
 * The one door to `android.util.Log` for the background alarm module.
 *
 * **Why the indirection.** `Log.d` and friends are *not* stripped in a release
 * build: the call ships, and on Android logcat is readable by anyone with USB
 * debugging enabled or anyone who can take an `adb bugreport` off the device.
 * The rating of that is low -- `READ_LOGS` has been signature/privileged since
 * Android 4.1 -- but "low" describes who can read it, not what is in it. What
 * these lines carried was reconnaissance: device wire names, the armed rule-id
 * list, the ThingsBoard host. None of it is a credential, and it is exactly the
 * material that makes a stolen JWT worth stealing. The Dart half of the app
 * already routes through `appLog()` for the same reason; this is the native
 * half of that rule, which `lib/utils/app_log.dart` says was still missing.
 *
 * **Debug and profile only.** `BuildConfig.DEBUG` is false in profile, so a
 * profile APK handed to a colleague with a bug report is silent too.
 *
 * **What this does not promise.** The message argument is already built by the
 * time it arrives here, so the interpolation still runs in a release build and
 * is thrown away. That is a few string allocations on a background thread, and
 * no value leaves the process.
 * shortcut: message is still built in release; upgrade to inline functions taking a () -> String if that ever matters.
 *
 * **What this gives up.** `adb logcat` is how the alarm module is diagnosed at
 * all -- there is no UI that reports which rules were armed -- so chasing a
 * user-reported alarm bug from a release APK now needs a debug build.
 */
internal object AlarmLog {
    fun d(tag: String, message: String) {
        if (BuildConfig.DEBUG) Log.d(tag, message)
    }

    fun i(tag: String, message: String) {
        if (BuildConfig.DEBUG) Log.i(tag, message)
    }

    fun w(tag: String, message: String) {
        if (BuildConfig.DEBUG) Log.w(tag, message)
    }

    fun w(tag: String, message: String, error: Throwable) {
        if (BuildConfig.DEBUG) Log.w(tag, message, error)
    }

    fun e(tag: String, message: String) {
        if (BuildConfig.DEBUG) Log.e(tag, message)
    }

    fun e(tag: String, message: String, error: Throwable) {
        if (BuildConfig.DEBUG) Log.e(tag, message, error)
    }
}
