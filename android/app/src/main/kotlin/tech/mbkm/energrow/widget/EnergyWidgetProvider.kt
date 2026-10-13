package tech.mbkm.energrow.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import tech.mbkm.energrow.MainActivity
import tech.mbkm.energrow.R

/**
 * The home-screen readout: PV output, house load, battery state and the sky.
 *
 * ## Why this reads a cache and does not poll
 *
 * **A widget is not a Flutter engine and this project has already paid to learn
 * what the alternative costs.** The alarm module is native Kotlin precisely
 * because `android_alarm_manager_plus` starts a `FlutterEngine` per tick that
 * stays resident: tens of megabytes and a second of startup, forever. A widget
 * that polled ThingsBoard itself would either start an engine - the same bill,
 * on a schedule nobody chose - or be a second native HTTP client to maintain,
 * with its own token handling, its own refresh path and its own budget guard.
 *
 * So the widget reads `cached_telemetry`, which `ThingsBoardApi.cacheTelemetrySnapshot`
 * already writes once per poll. The trade is stated rather than hidden: the
 * numbers are whatever the app last saw, so a widget with the app closed is as
 * old as the last time the app was opened, and it says so by showing the age.
 * A figure with no timestamp is a figure being passed off as current, and this
 * app's rule is that it never does that.
 */
class EnergyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, id))
        }
    }

    /**
     * Redraw every placed widget.
     *
     * Called from Dart after each successful telemetry write. **Without it the
     * widget would only ever change on the system's own schedule**, which Android
     * floors at thirty minutes, and a grower checking the array would be looking
     * at a half-hour-old number.
     *
     * A companion method rather than an instance one, so `MainActivity` can call
     * it without instantiating a provider - the system does that itself when it
     * broadcasts, and two ways to reach the same code would be two ways for them
     * to disagree.
     */
    companion object {
        @JvmStatic
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(
                    context,
                    EnergyWidgetProvider::class.java,
                ),
            )
            if (ids.isEmpty()) return
            val provider = EnergyWidgetProvider()
            for (id in ids) {
                manager.updateAppWidget(id, provider.buildViews(context, id))
            }
        }
    }

    private fun buildViews(context: Context, id: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_energy)
        val cached = readCache(context)

        // **The colours live in the layout, not here.** `RemoteViews` has no
        // `setTextViewTextColor` - it is not part of the API, and the compile
        // error is the platform telling us so rather than a runtime no-op. The
        // palette's values are therefore pinned in `widget_energy.xml`, next to
        // the widgets that use them, which is the one place a palette change has
        // to touch for this surface.
        //
        // That is a copy of the dark palette, and it is a copy on purpose:
        // `design_tokens.dart` is Dart, a widget process runs none, and shipping
        // the palette across a channel on every theme change would be a second
        // source of truth for colours that have to agree. This repo has had a
        // hand-written surface list drift silently twice already.

        views.setTextViewText(R.id.widget_pv, value(cached.values, "power_dc", "--", "W"))
        views.setTextViewText(R.id.widget_load, value(cached.values, "power_ac", "--", "W"))
        views.setTextViewText(
            R.id.widget_battery,
            value(cached.values, "soc", "--", "%"),
        )
        views.setTextViewText(R.id.widget_lux, value(cached.values, "lux", "--", "lx"))

        // **The age, always, including "never".** A widget that can only show a
        // stale number and cannot say so is worse than no widget: it is a
        // reading with no provenance, on the surface the user looks at most.
        views.setTextViewText(R.id.widget_updated, age(cached.updatedAt))

        // Tapping opens the app rather than anything in-widget: there is nothing
        // here a grower can act on without the readings behind it.
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, open)

        return views
    }

    private data class Cached(val values: Map<String, Double>, val updatedAt: Long)

    /**
     * The offline cache, or empty values when there is none.
     *
     * **Every failure is empty, and the widget shows `--` rather than throwing.**
     * This runs on the launcher's behalf with no supervision; an exception here
     * surfaces as a widget that refuses to draw, and the cache is by definition
     * the most optional thing in the app.
     */
    private fun readCache(context: Context): Cached {
        val preferences: SharedPreferences = try {
            context.getSharedPreferences(
                context.packageName + "_preferences",
                Context.MODE_PRIVATE,
            )
        } catch (_: Exception) {
            return Cached(emptyMap(), 0L)
        }
        val raw = try {
            preferences.getString("cached_telemetry", null)
        } catch (_: Exception) {
            null
        } ?: return Cached(emptyMap(), 0L)

        return try {
            val root = JSONObject(raw)
            val values = root.optJSONObject("latestValues")
            val parsed = mutableMapOf<String, Double>()
            if (values != null) {
                val keys = values.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val raw2 = values.opt(key)
                    if (raw2 is Number) parsed[key] = raw2.toDouble()
                }
            }
            Cached(parsed, System.currentTimeMillis())
        } catch (_: Exception) {
            Cached(emptyMap(), 0L)
        }
    }

    /**
     * A reading, formatted the way the app formats one.
     *
     * **Trailing zeros are trimmed**, and this is the same rule `slotNumber`
     * applies on the Dart side: the device reported `26.0 W`, and printing that
     * in a monospace column beside three other readings is false precision.
     */
    private fun value(
        values: Map<String, Double>,
        key: String,
        fallback: String,
        unit: String,
    ): String {
        val raw = values[key] ?: return "$fallback $unit"
        val text = if (raw == raw.toLong().toDouble()) {
            raw.toLong().toString()
        } else {
            val rounded = Math.round(raw * 10.0) / 10.0
            if (rounded == rounded.toLong().toDouble()) {
                rounded.toLong().toString()
            } else {
                rounded.toString()
            }
        }
        return "$text $unit"
    }

    /**
     * How old the cache is, in the reader's own units.
     *
     * **"just now" under a minute, minutes under an hour, hours after that.**
     * Days would be more precise and less useful: the interesting distinction is
     * between a widget that was refreshed ten seconds ago and one that was last
     * touched before lunch.
     */
    private fun age(updatedAt: Long): String {
        if (updatedAt <= 0L) return "never updated"
        val minutes = (System.currentTimeMillis() - updatedAt) / 60_000L
        return when {
            minutes < 1 -> "updated just now"
            minutes < 60 -> "updated ${minutes}m ago"
            else -> "updated ${minutes / 60}h ago"
        }
    }
}