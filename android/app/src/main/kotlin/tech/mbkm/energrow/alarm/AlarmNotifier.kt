package tech.mbkm.energrow.alarm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import tech.mbkm.energrow.MainActivity
import tech.mbkm.energrow.R

/**
 * Posts alarm notifications without a Flutter engine.
 *
 * Two channels rather than one, matching the `critical ? max : high` split the
 * Dart side used. A separate channel also means the user can silence warnings
 * while keeping the battery alert, which is the distinction they actually care
 * about, and it sidesteps a real problem with a single channel: a channel's
 * importance is fixed the first time it is created, so whichever of the two
 * writers got there first would decide it for good.
 *
 * The ids match the ones `AlarmNotificationService` uses, so notifications from
 * the background and from the dashboard land in the same place and replace each
 * other by id rather than stacking.
 */
class AlarmNotifier(private val context: Context) {
    private val manager = NotificationManagerCompat.from(context)

    fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val service = context.getSystemService(NotificationManager::class.java) ?: return
        service.createNotificationChannel(
            NotificationChannel(
                CHANNEL_WARNING,
                context.getString(R.string.alarm_channel_warnings),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = context.getString(R.string.alarm_channel_warnings_description)
                enableVibration(true)
                setShowBadge(true)
            },
        )
        service.createNotificationChannel(
            NotificationChannel(
                CHANNEL_CRITICAL,
                context.getString(R.string.alarm_channel_critical),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = context.getString(R.string.alarm_channel_critical_description)
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            },
        )
    }

    /**
     * Shows one alarm.
     *
     * Silently does nothing when notifications are not permitted, which is the
     * case on Android 13+ until the user grants POST_NOTIFICATIONS. Losing a
     * notification is not a reason to lose the alarm, so the record is still
     * written to history by the caller either way.
     */
    fun notify(signal: AlarmSignal) {
        if (!manager.areNotificationsEnabled()) return
        ensureChannels()

        val critical = signal.rule.isCritical
        val channel = if (critical) CHANNEL_CRITICAL else CHANNEL_WARNING
        val notification = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_energrow)
            .setContentTitle(title(signal))
            .setContentText(signal.message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(signal.message))
            .setPriority(if (critical) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(signal.id))
            .build()

        // A stable id per alarm replaces the previous notification for the same
        // condition rather than stacking a new one every tick.
        manager.notify(notificationId(signal.id), notification)
    }

    private fun title(signal: AlarmSignal): String = context.getString(
        if (signal.rule.isCritical) R.string.alarm_title_critical else R.string.alarm_title_warning,
    )

    private fun openAppIntent(alarmId: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ALARM_ID, alarmId)
        }
        return PendingIntent.getActivity(
            context,
            alarmId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val CHANNEL_WARNING = "energrow_alarms"
        const val CHANNEL_CRITICAL = "energrow_critical_alarms"

        /** Read by the bridge when the app is opened from a notification. */
        const val EXTRA_ALARM_ID = "tech.mbkm.energrow.ALARM_ID"

        /** Returns the alarm a notification tap carried, if any. */
        fun alarmIdFrom(intent: Intent?): String? =
            intent?.getStringExtra(EXTRA_ALARM_ID)?.takeIf { it.isNotBlank() }

        private fun notificationId(alarmId: String): Int = alarmId.hashCode()
    }
}
