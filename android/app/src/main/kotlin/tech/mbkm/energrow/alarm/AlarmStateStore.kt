package tech.mbkm.energrow.alarm

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists everything a background check needs between ticks, apart from the
 * credentials: the rule list, the set of alarms currently active, and the
 * history of what has already been reported.
 *
 * The active set is the mechanism that keeps notifications to one per alarm
 * occurrence. A check every fifteen minutes that re-notified an ongoing
 * low-SOC condition would be indistinguishable from spam, and the user cannot
 * silence it without silencing the app. Dart reads and writes the same set, so
 * an alarm that is already reported in the background is not reported a second
 * time when the dashboard happens to be open.
 *
 * This deliberately does not live in `FlutterSharedPreferences`, which is where
 * `shared_preferences` keeps app data. That file stores Dart `List<String>`
 * values as a Base64 Java-serialized blob, an encoding this module would have to
 * reproduce byte for byte and keep compatible across plugin versions. A private
 * file of plain JSON is the cheap way to stay independent of that.
 */
class AlarmStateStore(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveConfig(payload: JSONObject) {
        prefs.edit()
            .putString(KEY_CONFIG, payload.toString())
            .putLong(KEY_SAVED_AT, System.currentTimeMillis())
            .apply()
    }

    fun configPayload(): JSONObject? {
        val raw = prefs.getString(KEY_CONFIG, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (error: Exception) {
            Log.w(TAG, "stored alarm config is not valid JSON; discarding it", error)
            prefs.edit().remove(KEY_CONFIG).apply()
            null
        }
    }

    fun configSavedAt(): Long = prefs.getLong(KEY_SAVED_AT, 0L)

    fun clearConfig() {
        prefs.edit().remove(KEY_CONFIG).apply()
    }

    /** Alarm IDs that are currently active and have already been reported. */
    fun activeAlerts(): Set<String> = readStringSet(KEY_ACTIVE)

    fun saveActiveAlerts(ids: Set<String>) = writeStringSet(KEY_ACTIVE, ids)

    /** Appends one record, newest last, trimming to [MAX_RECORDS]. */
    fun appendRecord(record: JSONObject) {
        val records = readRecords()
        records.put(record)
        while (records.length() > MAX_RECORDS) {
            records.remove(0)
        }
        prefs.edit()
            .putString(KEY_RECORDS, records.toString())
            .putLong(KEY_RECORDS_SAVED_AT, System.currentTimeMillis())
            .apply()
    }

    /** Newest first, matching what `AlarmHistoryService.getAlarms` returns. */
    fun records(): List<JSONObject> {
        val records = readRecords()
        return (0 until records.length())
            .mapNotNull { records.optJSONObject(it) }
            .sortedByDescending { it.optLong(KEY_TIMESTAMP, 0L) }
    }

    /**
     * Applies an acknowledgement or resolution coming from the history screen.
     *
     * The Dart side keeps its own copy of anything the dashboard recorded, and
     * the two are merged on read, so an update has to be mirrored on both sides
     * or the badge would reappear the next time the screen reloads.
     */
    fun updateRecord(id: String, acknowledged: Boolean, resolved: Boolean): Boolean {
        val records = readRecords()
        var changed = false
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            if (record.optString("id") != id) continue
            record.put("acknowledged", acknowledged)
            record.put("resolved", resolved)
            changed = true
        }
        if (!changed) return false
        prefs.edit().putString(KEY_RECORDS, records.toString()).apply()
        return true
    }

    fun clearRecords() {
        prefs.edit().remove(KEY_RECORDS).apply()
    }

    /** When the last successful check finished, for the diagnostics screen. */
    fun lastCheckAt(): Long = prefs.getLong(KEY_LAST_CHECK, 0L)

    fun recordCheck(atMs: Long, outcome: String) {
        prefs.edit()
            .putLong(KEY_LAST_CHECK, atMs)
            .putString(KEY_LAST_OUTCOME, outcome)
            .apply()
    }

    /**
     * Whether the dashboard is on screen and evaluating alarms itself.
     *
     * Set by the app on resume and cleared on pause. The check stands down while
     * this is true: the dashboard already evaluates the same rules on a ten
     * second poll, so a background tick during that time is duplicated work
     * against the same ThingsBoard instance, and at a one minute interval that
     * doubles the request rate for no new information.
     */
    fun setForeground(foreground: Boolean) {
        prefs.edit().putBoolean(KEY_FOREGROUND, foreground).apply()
    }

    fun isForeground(): Boolean = prefs.getBoolean(KEY_FOREGROUND, false)

    fun lastOutcome(): String = prefs.getString(KEY_LAST_OUTCOME, "").orEmpty()

    private fun readRecords(): JSONArray {
        val raw = prefs.getString(KEY_RECORDS, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (error: Exception) {
            Log.w(TAG, "stored alarm history is not valid JSON; discarding it", error)
            prefs.edit().remove(KEY_RECORDS).apply()
            JSONArray()
        }
    }

    private fun readStringSet(key: String): Set<String> {
        val raw = prefs.getString(key, null) ?: return emptySet()
        return try {
            val array = JSONArray(raw)
            buildSet {
                for (index in 0 until array.length()) {
                    add(array.optString(index))
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "stored $key is not valid JSON; discarding it", error)
            prefs.edit().remove(key).apply()
            emptySet()
        }
    }

    private fun writeStringSet(key: String, ids: Set<String>) {
        val array = JSONArray()
        ids.forEach(array::put)
        prefs.edit().putString(key, array.toString()).apply()
    }

    companion object {
        private const val TAG = "EnerGrowAlarmState"
        private const val PREFS = "energrow_alarm_state"

        const val KEY_CONFIG = "config"
        const val KEY_SAVED_AT = "config_saved_at"
        const val KEY_ACTIVE = "active_alerts"
        const val KEY_RECORDS = "records"
        const val KEY_RECORDS_SAVED_AT = "records_saved_at"
        const val KEY_LAST_CHECK = "last_check_at"
        const val KEY_LAST_OUTCOME = "last_check_outcome"
        const val KEY_FOREGROUND = "app_foreground"
        const val KEY_TIMESTAMP = "timestamp"

        /** Matches `AlarmHistoryService._maxEntries`, so both sides keep 100. */
        const val MAX_RECORDS = 100
    }
}
