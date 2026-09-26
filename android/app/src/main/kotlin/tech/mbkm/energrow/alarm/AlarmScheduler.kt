package tech.mbkm.energrow.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Schedules the background check with the platform alarm manager.
 *
 * `setInexactRepeating` is the deliberate choice over an exact alarm. Exact
 * alarms on Android 12 and newer need `SCHEDULE_EXACT_ALARM`, which the user
 * has to grant through a settings screen, and on Android 14 the
 * `USE_EXACT_ALARM` alternative is reserved for clock and calendar apps and is
 * reviewed as such. Neither is worth asking the user for a greenhouse
 * monitoring app, and the cadence does not need it: alarms are about "the
 * battery has been low for a while", not about a stopwatch.
 *
 * Being inexact has a second effect worth stating plainly. The system batches
 * these, and Doze can defer one for a long time, so a check may land minutes
 * late or, on an aggressively optimised device, hours late. The check is
 * written to tolerate that: it reads the age of the telemetry rather than
 * assuming a tick happened, and a skipped tick simply means the next one sees
 * the same conditions.
 */
object AlarmScheduler {
    private const val TAG = "EnerGrowAlarmSchedule"
    private const val REQUEST_CADENCE = 71_025
    private const val REQUEST_IDLE = 71_026
    private const val PREFS = "energrow_alarm_state"
    private const val PREF_SCHEDULED = "check_scheduled"

    /**
     * How often the check runs.
     *
     * One minute, chosen deliberately. A greenhouse alarm is only useful while
     * the condition is still worth acting on: a flat battery or a heat spike
     * found ten minutes late is a problem that has already become a loss. The
     * old Dart implementation could not afford that interval, because every tick
     * started a Flutter engine, but a check here is three small HTTPS reads on a
     * plain thread that finishes in about 0.4 seconds.
     *
     * The cost is real and worth stating: at one minute this is roughly 4300
     * ThingsBoard requests a day, three per tick, and the dashboard stands the
     * background check down while it is in the foreground so the app is not
     * polled twice at once. If the ThingsBoard instance is on a shared Orange Pi,
     * raising this to 5 is a one-line change here.
     *
     * The interval is a floor, not a guarantee. The alarm is inexact, so Doze and
     * the vendor's power manager may defer it; see [schedule].
     */
    const val INTERVAL_MINUTES = 1L

    private val intervalMs get() = INTERVAL_MINUTES * 60_000L

    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        if (alarms == null) {
            Log.w(TAG, "AlarmManager is unavailable; background checks are off")
            return
        }
        try {
            // Two independent triggers, both permission free.
            //
            // The repeating one sets the cadence, but a plain repeating alarm is
            // batched by Doze and is also the first thing vendor power managers
            // drop. On the test device (MIUI/HyperOS) the repeating alarm was
            // registered, fired six times, and then silently disappeared from
            // `dumpsys alarm`, leaving no way to tell that from "nothing to
            // report".
            //
            // The idle one is exempt from Doze batching. Armed here and re-armed
            // by the receiver after every run, so if either trigger is dropped
            // the other tends to survive, and a dropped alarm repairs itself on
            // the next successful run.
            alarms.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                intervalMs,
                cadencePendingIntent(context),
            )
            alarms.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                idlePendingIntent(context),
            )
            setScheduledFlag(context, true)
            Log.i(TAG, "armed the background check every $INTERVAL_MINUTES minute(s)")
        } catch (error: SecurityException) {
            // Not expected: neither call needs a permission. Losing the schedule
            // silently would be the worst outcome, so say so.
            Log.e(TAG, "could not schedule the background alarm check", error)
        }
    }

    /** Re-arms the Doze-exempt trigger. Called after every check. */
    fun rearm(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        if (!isScheduled(context)) return
        try {
            alarms.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + intervalMs,
                idlePendingIntent(context),
            )
        } catch (error: SecurityException) {
            Log.e(TAG, "could not re-arm the background check", error)
        }
    }

    fun cancel(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        if (alarms != null) {
            alarms.cancel(cadencePendingIntent(context))
            alarms.cancel(idlePendingIntent(context))
        }
        setScheduledFlag(context, false)
    }

    /**
     * Whether this module believes it armed the check.
     *
     * A recorded flag rather than a query, because `AlarmManager` has no public
     * way to ask whether a `PendingIntent` is still registered; the nearest
     * thing, `getScheduledAlarm`, is not part of the SDK. The flag can drift from
     * reality if something outside the app cancels the alarm, so it is written
     * only where this code also arms or disarms, and it drives a diagnostic
     * rather than anything functional.
     */
    fun isScheduled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(PREF_SCHEDULED, false)

    private fun setScheduledFlag(context: Context, value: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_SCHEDULED, value)
            .apply()
    }

    private fun checkPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, AlarmCheckReceiver::class.java).apply {
            action = ACTION_CHECK
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun cadencePendingIntent(context: Context) =
        checkPendingIntent(context, REQUEST_CADENCE)

    private fun idlePendingIntent(context: Context) =
        checkPendingIntent(context, REQUEST_IDLE)

    const val ACTION_CHECK = "tech.mbkm.energrow.action.CHECK_ALARMS"
}
