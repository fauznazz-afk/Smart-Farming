package tech.mbkm.energrow.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

/**
 * Runs one background alarm check.
 *
 * The work is done on a short-lived thread under `goAsync` rather than in a
 * service, because a service would need a foreground notification to be
 * reliably startable from the background on modern Android, and that would cost
 * the user a permanent notification and a permanently resident process. A
 * manifest receiver is allowed roughly ten seconds, which is ample for three
 * small ThingsBoard reads issued in parallel.
 */
class AlarmCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appContext = context.applicationContext
        val pendingResult = goAsync()
        val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "energrow-alarm-check")
        }
        executor.execute {
            try {
                AlarmCheckRunner(appContext).run()
            } catch (error: Throwable) {
                // A background check that throws would be silent, and silent
                // failure is what made the previous implementation impossible to
                // diagnose. Log instead.
                Log.e(TAG, "background alarm check failed", error)
            } finally {
                executor.shutdown()
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "EnerGrowAlarmCheck"
    }
}
