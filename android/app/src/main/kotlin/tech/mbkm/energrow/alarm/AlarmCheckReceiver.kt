package tech.mbkm.energrow.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

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
        // The alarm manager can deliver a second tick while a slow one is still
        // in flight. Dropping the overlap is better than running two checks that
        // would each notify for the same condition.
        if (!running.compareAndSet(false, true)) {
            Log.d(TAG, "a check is already running; skipping this tick")
            return
        }
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
                running.set(false)
                executor.shutdown()
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "EnerGrowAlarmCheck"
        val running = AtomicBoolean(false)
    }
}
