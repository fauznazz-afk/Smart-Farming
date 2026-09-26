package tech.mbkm.energrow.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log
import java.util.concurrent.Executors

/**
 * Runs one alarm check on demand, so the background path can be exercised
 * without waiting for the schedule.
 *
 * This exists because the production trigger is hard to test: an inexact
 * `AlarmManager` alarm is batched by the system and by the vendor's power
 * manager, so a one minute interval can take several minutes to produce a
 * result, and on a heavily optimised ROM the alarm can be dropped entirely. That
 * makes "the alarm is quiet" ambiguous between "the check found nothing" and
 * "the check never ran", which is precisely the confusion this project already
 * spent time on.
 *
 * ## Why it is safe
 *
 * The component is declared **only** in `src/debug/AndroidManifest.xml`, so it is
 * not present in a release APK at all and no other app can reach it. On top of
 * that this receiver refuses to act unless the running app is debuggable, so
 * declaring it in a release manifest by mistake would not open a hole:
 *
 * ```
 * adb shell am broadcast -a tech.mbkm.energrow.action.DEBUG_CHECK_ALARMS \
 *   -n tech.mbkm.energrow/tech.mbkm.energrow.alarm.AlarmDebugReceiver
 * ```
 *
 * It runs the same [AlarmCheckRunner] as the scheduled receiver. It does not
 * bypass any alarm logic, so what it proves is what the timer would have done.
 */
class AlarmDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val debuggable =
            context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (!debuggable) {
            Log.w(TAG, "refusing to run: this receiver is meant for debug builds only")
            return
        }
        if (intent?.action != ACTION_DEBUG_CHECK && intent?.action != ACTION_DEBUG_RESET) {
            Log.w(TAG, "ignoring unexpected action ${intent?.action}")
            return
        }
        val appContext = context.applicationContext
        if (intent.action == ACTION_DEBUG_RESET) {
            // Forgets which alarms have been reported, so the next check treats
            // whatever is currently firing as new and posts a notification. That
            // is the only way to exercise the notification path on demand: an
            // ongoing condition is correctly silent, so waiting for one to appear
            // on its own could take hours.
            AlarmStateStore(appContext).saveActiveAlerts(emptySet())
            AlarmNotifier(appContext).ensureChannels()
            Log.i(TAG, "cleared the reported-alarm set; the next check will announce")
            return
        }
        val pending = goAsync()
        val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "energrow-alarm-debug")
        }
        executor.execute {
            try {
                AlarmCheckRunner(appContext).run(force = true)
            } catch (error: Throwable) {
                Log.e(TAG, "debug-triggered check failed", error)
            } finally {
                executor.shutdown()
                pending.finish()
            }
        }
    }

    companion object {
        private const val TAG = "EnerGrowAlarmDebug"
        const val ACTION_DEBUG_CHECK = "tech.mbkm.energrow.action.DEBUG_CHECK_ALARMS"
        const val ACTION_DEBUG_RESET = "tech.mbkm.energrow.action.DEBUG_RESET_ALARMS"
    }
}
