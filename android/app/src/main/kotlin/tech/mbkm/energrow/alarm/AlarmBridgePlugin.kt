package tech.mbkm.energrow.alarm

import android.app.Activity
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * The bridge between the Dart alarm service and the native check.
 *
 * Deliberately narrow. Dart's whole job here is to hand over a rule list and
 * credentials, and to read back what the background recorded. It never asks the
 * native side to evaluate anything, because the rules already travelled as data
 * and the native side cannot invent a different answer from them.
 */
class AlarmBridgePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "energrow-alarm-bridge")
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
        context = null
        activityBinding = null
    }

    /**
     * The activity is only reachable through [ActivityAware].
     *
     * `FlutterPluginBinding` deliberately exposes only the application context,
     * so reading the intent that launched the app, which is how a tapped
     * notification is recognised, has to go through the activity binding.
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    private fun state(ctx: Context): AlarmStateStore = AlarmStateStore(ctx)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "the alarm bridge is not attached", null)
            return
        }
        try {
            when (call.method) {
                "configure" -> configure(ctx, call, result)
                "disable" -> disable(ctx, result)
                "activeAlerts" -> result.success(state(ctx).activeAlerts().toList())
                "setActiveAlerts" -> setActiveAlerts(ctx, call, result)
                "history" -> result.success(history(ctx))
                "acknowledge" -> updateRecord(ctx, call, result, resolved = false)
                "resolve" -> updateRecord(ctx, call, result, resolved = true)
                "clearHistory" -> {
                    state(ctx).clearRecords()
                    result.success(null)
                }
                "isScheduled" -> result.success(AlarmScheduler.isScheduled(ctx))
                "checkNow" -> checkNow(ctx, result)
                "status" -> status(ctx, result)
                "setForeground" -> {
                    state(ctx).setForeground(call.argument<Boolean>("value") == true)
                    result.success(null)
                }
                "launchAlarmId" -> result.success(pendingAlarmId())
                "ensureChannels" -> {
                    AlarmNotifier(ctx).ensureChannels()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: AlarmConfigException) {
            // Dart sent something this build cannot read. Saying so lets the
            // Dart side keep working with in-app alerts instead of going quiet.
            Log.e(TAG, "rejected alarm configuration", error)
            result.error("bad_config", error.message, null)
        } catch (error: Exception) {
            Log.e(TAG, "alarm bridge call ${call.method} failed", error)
            result.error("alarm_bridge", error.message, null)
        }
    }

    /**
     * Accepts the rule list and credentials, then arms the check.
     *
     * Parsing happens before anything is stored, so a malformed payload cannot
     * leave a half-applied configuration behind.
     */
    private fun configure(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<Any>("config")
        val payload = when (raw) {
            is Map<*, *> -> JSONObject(raw as Map<*, *>)
            is String -> JSONObject(raw)
            else -> throw AlarmConfigException("config must be a map")
        }
        val config = parseAlarmConfig(payload)
        state(ctx).saveConfig(payload)
        Log.i(
            TAG,
            "configured ${config.rules.size} rule(s) across " +
                "${config.devices.size} device(s), arm=${call.argument<Boolean>("arm") == true}",
        )

        val access = call.argument<String>("accessToken")
        if (access.isNullOrBlank()) {
            // Not an error: the app may not be signed in yet. Worth saying out
            // loud, because a check that finds no credentials looks identical to
            // one that never ran.
            Log.w(TAG, "configure arrived without an access token; background checks will idle")
        } else {
            AlarmTokenStore.put(ctx, access, call.argument("refreshToken"))
            Log.i(TAG, "stored credentials for the background check")
        }
        if (call.argument<Boolean>("clearCredentials") == true) {
            AlarmTokenStore.clear(ctx)
        }

        AlarmNotifier(ctx).ensureChannels()
        if (call.argument<Boolean>("arm") == true) {
            AlarmScheduler.schedule(ctx)
        } else {
            AlarmScheduler.cancel(ctx)
        }
        result.success(null)
    }

    private fun disable(ctx: Context, result: MethodChannel.Result) {
        AlarmScheduler.cancel(ctx)
        AlarmTokenStore.clear(ctx)
        state(ctx).clearConfig()
        state(ctx).saveActiveAlerts(emptySet())
        result.success(null)
    }

    private fun setActiveAlerts(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        val ids = call.argument<List<String>>("ids")
            ?: throw AlarmConfigException("ids must be a list of strings")
        state(ctx).saveActiveAlerts(ids.filter { it.isNotBlank() }.toSet())
        result.success(null)
    }

    private fun history(ctx: Context): List<Map<String, Any?>> =
        state(ctx).records().map { record ->
            val entry = mutableMapOf<String, Any?>(
                "id" to record.optString("id"),
                "timestamp" to record.optString("timestamp"),
                "type" to record.optString("type"),
                "severity" to record.optString("severity"),
                "message" to record.optString("message"),
                "acknowledged" to record.optBoolean("acknowledged"),
                "resolved" to record.optBoolean("resolved"),
            )
            if (!record.isNull("value")) entry["value"] = record.optDouble("value")
            entry
        }

    private fun updateRecord(
        ctx: Context,
        call: MethodCall,
        result: MethodChannel.Result,
        resolved: Boolean,
    ) {
        val id = call.argument<String>("id")
            ?: throw AlarmConfigException("id must be a string")
        val found = state(ctx).updateRecord(id, acknowledged = true, resolved = resolved)
        result.success(found)
    }

    /** Runs a check off the platform thread so the UI never waits on the network. */
    private fun checkNow(ctx: Context, result: MethodChannel.Result) {
        executor.execute {
            try {
                AlarmCheckRunner(ctx).run()
            } catch (error: Exception) {
                Log.e(TAG, "manual alarm check failed", error)
            }
        }
        result.success(null)
    }

    private fun status(ctx: Context, result: MethodChannel.Result) {
        val store = state(ctx)
        result.success(
            mapOf(
                "scheduled" to AlarmScheduler.isScheduled(ctx),
                "intervalMinutes" to AlarmScheduler.INTERVAL_MINUTES,
                "configSavedAt" to store.configSavedAt(),
                "hasCredentials" to (AlarmTokenStore.accessToken(ctx) != null),
                "lastCheckAt" to store.lastCheckAt(),
                "lastOutcome" to store.lastOutcome(),
            ),
        )
    }

    /**
     * Returns the alarm the app was opened for, if any.
     *
     * Read from the activity's current intent rather than captured at attach
     * time, so a notification tapped while the app is already running is picked
     * up as well as a cold start. `MainActivity.onNewIntent` keeps
     * `getIntent()` current, and the extra staying on it is fine because Dart
     * calls this once per launch to decide where to navigate.
     */
    private fun pendingAlarmId(): String? =
        activityBinding?.activity?.intent?.let(AlarmNotifier::alarmIdFrom)

    companion object {
        const val CHANNEL = "tech.mbkm.energrow/alarm"
        private const val TAG = "EnerGrowAlarmBridge"
    }
}
