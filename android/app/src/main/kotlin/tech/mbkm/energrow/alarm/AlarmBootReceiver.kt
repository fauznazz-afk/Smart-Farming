package tech.mbkm.energrow.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-arms the check after a reboot.
 *
 * Alarms do not survive a restart, so without this the background check would
 * quietly stop after the first reboot and nothing would say so. It only
 * reschedules when a config was already pushed, which is what distinguishes a
 * signed-in user from someone who has not logged in yet.
 */
class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val appContext = context.applicationContext
        if (AlarmStateStore(appContext).configPayload() == null) {
            Log.d(TAG, "no alarm config stored; not arming the background check")
            return
        }
        AlarmScheduler.schedule(appContext)
    }

    private companion object {
        const val TAG = "EnerGrowAlarmBoot"
    }
}
