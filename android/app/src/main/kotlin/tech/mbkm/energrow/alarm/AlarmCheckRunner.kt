package tech.mbkm.energrow.alarm

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * One cycle of the background alarm check.
 *
 * Deliberately parallel and deliberately unretrying. The three ThingsBoard
 * reads go out at once so the cycle fits inside the ten seconds a manifest
 * receiver is allowed, and a failure is not retried because the next tick is
 * fifteen minutes away and a retry inside a background window only risks being
 * killed halfway through. The previous Dart implementation polled the three
 * devices one after another with up to four attempts each, which could run for
 * over three minutes.
 */
class AlarmCheckRunner(context: Context) {
    private val context = context.applicationContext
    private val state = AlarmStateStore(context)
    private val notifier = AlarmNotifier(context)

    /**
     * Matches Dart's `DateTime.toIso8601String()` for a local time, which is
     * what the dashboard writes, so background and foreground records display and
     * sort identically. An instance field rather than a constant because
     * `SimpleDateFormat` is not thread safe.
     */
    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

    /**
     * Why every catch below logs `error.javaClass.simpleName` and not
     * `error.message`.
     *
     * `org.json` embeds a fragment of the input in its parse errors, so an
     * exception message thrown while reading a ThingsBoard response can carry a
     * slice of that response body into logcat. `AlarmCheckRunner` reads
     * telemetry, so those are sensor values; on the refresh path they are the
     * token itself, which is why `ThingsBoardClient` already logs the class
     * name only and says so in a comment.
     *
     * This file did not follow that, so the rule was half-applied. The class
     * name is what actually identifies a failure -- `JSONException` versus
     * `SocketTimeoutException` says everything useful, and the fragment of JSON
     * says nothing except what the server sent.
     *
     * Found in review on 6 October 2026. Nothing here logged a credential; this
     * is about sensor values and response bodies reaching a world-readable log.
     */

    /**
     * Runs one check, unless another one is already in flight.
     *
     * Three entry points reach this class: the scheduled receiver, the "check
     * now" bridge call, and the debug trigger. They used to have separate
     * threads with no shared guard, so two of them could read the same
     * previously-active set and both decide an alarm was new, which is exactly
     * the duplicate notification the active set exists to prevent. One
     * process-wide lock fixes it for all of them.
     *
     * [force] exists for the manual trigger: a user pressing "check now" while
     * the app is on screen means it, so it bypasses the foreground stand-down.
     */
    fun run(force: Boolean = false) {
        if (!running.compareAndSet(false, true)) {
            Log.i(TAG, "a check is already running; skipping")
            return
        }
        // Everything below has to finish inside the receiver's window, or the
        // process is killed mid-write and the next tick reports the same alarms
        // again. The deadline is enforced rather than assumed: an expired access
        // token is the normal reason to hit the slow path, and that is exactly
        // when the window runs out.
        val deadline = System.currentTimeMillis() + BUDGET_MS
        try {
            runGuarded(force, deadline)
        } finally {
            running.set(false)
        }
    }

    private fun runGuarded(force: Boolean, deadline: Long) {
        Log.i(TAG, "check started")
        // Re-arm first, so a check that then fails or ends the session still
        // leaves a scheduled trigger behind. A vendor power manager that dropped
        // the alarm cannot be recovered from here directly, but every successful
        // run repairs it.
        AlarmScheduler.rearm(context)
        if (!force && state.isForeground()) {
            // The dashboard is on screen and evaluating the same rules against
            // the same ThingsBoard devices on a much shorter poll. Doing the work
            // twice would double the request rate for no new information, and it
            // would risk the two disagreeing about which alarms are active.
            Log.i(TAG, "app is in the foreground; standing down")
            return
        }
        val config = loadConfig() ?: return finish("no alarm config stored")
        if (config.rules.isEmpty()) {
            return finish("no rules armed")
        }
        val token = AlarmTokenStore.accessToken(context)
        if (token == null) {
            // The usual reason on a fresh install or after a logout. Not an
            // error, and saying so keeps it from being mistaken for one.
            return finish("no credentials stored")
        }

        // `readDevices` calls `endSession` itself before returning null, so the
        // bare `return` here is deliberate: the caller must not finish a second
        // time. It used to call `endSession` again with a vaguer message, which
        // meant the truthful "refresh token rejected" line was recorded and then
        // immediately overwritten by whatever this check went on to conclude --
        // including "ok, no alarms", on the very tick where the server had just
        // refused the session. A check that reports success because its session
        // died is indistinguishable from a check that is not running.
        val readings = readDevices(config, token, deadline) ?: return
        if (readings.isEmpty()) {
            // No device produced data. That is a network or credential problem,
            // not stale telemetry, and reporting it as stale would turn an outage
            // into three misleading alarms.
            return finish("no telemetry; ${config.devices.size} device(s) unreadable")
        }

        val now = System.currentTimeMillis()
        val signals = AlarmEvaluator.evaluate(config.rules, readings, now)
        val active = signals.mapTo(mutableSetOf()) { it.id }
        val previouslyActive = state.activeAlerts()
        val newlyActive = active - previouslyActive

        for (signal in signals) {
            if (signal.id in newlyActive) {
                recordAndNotify(signal, now)
            }
        }
        state.saveActiveAlerts(active)
        finish(if (signals.isEmpty()) {
            "ok, no alarms"
        } else {
            "${active.size} active (${newlyActive.size} new): ${active.sorted().joinToString()}"
        })
    }

    /**
     * Records and logs how a check ended.
     *
     * Every outcome is logged, including the boring ones. A background check
     * that fails quietly is indistinguishable from one that is not running, and
     * the previous implementation's silence is why its alarms went unnoticed.
     */
    private fun finish(outcome: String) {
        state.recordCheck(System.currentTimeMillis(), outcome)
        Log.i(TAG, "check finished: $outcome")
    }

    private fun loadConfig(): AlarmConfig? {
        val payload = state.configPayload() ?: run {
            Log.i(TAG, "no alarm config has been pushed yet")
            return null
        }
        return try {
            parseAlarmConfig(payload)
        } catch (error: AlarmConfigException) {
            // Keep the stored config: it is probably from an app version this
            // build cannot read, and the next launch will replace it. Disabling
            // checks now would make the problem permanent instead of temporary.
            Log.e(TAG, "stored alarm config is unusable: ${error.javaClass.simpleName}")
            null
        }
    }

    /**
     * Fetches every configured device concurrently, dropping any that fail.
     *
     * Partial results are used on purpose. A PZEM that is unreachable should
     * still leave the battery and environment rules evaluated. The single
     * exception is an expired access token, which would otherwise look like
     * three unreachable devices: the token is refreshed once and the devices
     * that failed on 401 are read again.
     *
     * Returns null only when the session is over, meaning the caller should stop
     * checking altogether.
     */
    private fun readDevices(
        config: AlarmConfig,
        token: String,
        deadline: Long,
    ): Map<AlarmDevice, AlarmReading>? {
        val first = readAll(config, ThingsBoardClient(config.baseUrl, token), deadline)
        val unauthorized = first.unauthorizedDevices
        if (unauthorized.isEmpty()) return first.readings

        if (System.currentTimeMillis() >= deadline) {
            Log.w(TAG, "out of time before the token refresh; retrying next tick")
            return first.readings
        }
        // Three outcomes, not two, and the distinction is the whole point of this
        // return type.
        //
        // `Renewed` and `Unavailable` both mean "no session decision", so they
        // carry on with the readings already in hand and the next tick retries.
        // `Rejected` means the server ended the session, and that is not something
        // to carry on from: nothing here should keep polling with a token the user
        // expects to be gone.
        //
        // This used to be a nullable `TokenRefresh`, which collapsed `Rejected`
        // into `Unavailable` and made the caller's `?: return endSession(...)`
        // unreachable -- every path in this function returned a non-null map. The
        // result was that `endSession` ran from inside the refresh and then the
        // caller ran to the end and finished a second time, overwriting the
        // session-ended outcome with the verdict of a check that had no session.
        when (val outcome = refreshToken(config, deadline)) {
            RefreshOutcome.Rejected -> {
                endSession("refresh token rejected; background check disabled")
                return null
            }

            // "Could not ask" is not "told no". Both of these mean the next tick
            // tries again, and neither is a reason to discard readings that were
            // fetched successfully before the 401.
            RefreshOutcome.Unavailable,
            RefreshOutcome.Failed,
            -> return first.readings

            is RefreshOutcome.Renewed -> {
                Log.i(
                    TAG,
                    "refreshed the access token and retrying ${unauthorized.size} device(s)",
                )
                AlarmTokenStore.put(
                    context,
                    outcome.token,
                    outcome.refreshToken ?: AlarmTokenStore.refreshToken(context),
                )
                val client = ThingsBoardClient(config.baseUrl, outcome.token)
                val readings = first.readings.toMutableMap()
                for (deviceConfig in config.devices) {
                    if (deviceConfig.device !in unauthorized) continue
                    if (System.currentTimeMillis() >= deadline) {
                        Log.w(
                            TAG,
                            "out of time before retrying every device; deferring to next tick",
                        )
                        break
                    }
                    try {
                        readings[deviceConfig.device] =
                            client.fetch(deviceConfig.device, deviceConfig)
                    } catch (error: Exception) {
                        Log.w(
                            TAG,
                            "could not read ${deviceConfig.device.wireName} after refresh: ${error.javaClass.simpleName}",
                        )
                    }
                }
                return readings
            }
        }
    }

    /**
     * What trying to renew the access token actually produced.
     *
     * [Unavailable] and [Rejected] were one `null` before, and the two need
     * opposite handling: one means "nothing to decide, carry on with what we
     * have and let the next tick try again", the other means "the session is
     * over" and is a decision the check must not paper over.
     */
    private sealed interface RefreshOutcome {
        /** A new access token. */
        data class Renewed(val token: String, val refreshToken: String?) : RefreshOutcome

        /** No refresh token is stored, so renewal is impossible right now. */
        data object Unavailable : RefreshOutcome

        /** The server refused the refresh token, so the session has ended. */
        data object Rejected : RefreshOutcome

        /**
         * The renewal request itself failed -- offline, timed out, 5xx.
         *
         * A fourth case that the nullable `TokenRefresh` used to hide. "We could
         * not ask" is not "the server said no", and only the second one ends a
         * session. Collapsing them would let a flaky network tear down a working
         * session.
         */
        data object Failed : RefreshOutcome
    }

    /** Renews the access token, distinguishing "could not" from "no longer allowed". */
    private fun refreshToken(config: AlarmConfig, deadline: Long): RefreshOutcome {
        val refreshToken = AlarmTokenStore.refreshToken(context) ?: run {
            Log.i(TAG, "no refresh token stored; cannot renew the access token")
            return RefreshOutcome.Unavailable
        }
        val client = ThingsBoardClient(config.baseUrl, AlarmTokenStore.accessToken(context).orEmpty())
        return try {
            val renewed = client.refresh(refreshToken, deadline)
            if (renewed == null) {
                Log.w(TAG, "could not renew the access token; retrying next tick")
                RefreshOutcome.Failed
            } else {
                RefreshOutcome.Renewed(renewed.accessToken, renewed.refreshToken)
            }
        } catch (error: RefreshRejectedException) {
            // The session ended somewhere else, most likely the user signed out.
            // The caller tears the check down; it is not decided here, because
            // `endSession` records an outcome and this function must not record
            // one that the caller is about to overwrite.
            RefreshOutcome.Rejected
        }
    }

    /** Records a terminated session and stops the check. */
    private fun endSession(outcome: String) {
        AlarmTokenStore.clear(context)
        state.clearConfig()
        state.saveActiveAlerts(emptySet())
        AlarmScheduler.cancel(context)
        finish(outcome)
    }

    private data class ReadAttempt(
        val readings: Map<AlarmDevice, AlarmReading>,
        val unauthorizedDevices: Set<AlarmDevice>,
    )

    private fun readAll(
        config: AlarmConfig,
        client: ThingsBoardClient,
        deadline: Long,
    ): ReadAttempt {
        val executor = Executors.newFixedThreadPool(config.devices.size.coerceAtLeast(1))
        return try {
            val futures = config.devices.map { deviceConfig ->
                executor.submit(
                    Callable {
                        try {
                            Fetched(client.fetch(deviceConfig.device, deviceConfig), deviceConfig.device)
                        } catch (error: ThingsBoardHttpException) {
                            if (error.status == HttpURLConnection.HTTP_UNAUTHORIZED) {
                                Log.i(TAG, "${deviceConfig.device.wireName} rejected the access token")
                                Unauthorized(deviceConfig.device)
                            } else {
                                Log.w(
                                    TAG,
                                    "could not read ${deviceConfig.device.wireName}: ${error.javaClass.simpleName}",
                                )
                                null
                            }
                        } catch (error: Exception) {
                            Log.w(
                                TAG,
                                "could not read ${deviceConfig.device.wireName}: ${error.javaClass.simpleName}",
                            )
                            null
                        }
                    },
                )
            }
            val readings = mutableMapOf<AlarmDevice, AlarmReading>()
            val unauthorized = mutableSetOf<AlarmDevice>()
            for (future in futures) {
                try {
                    when (val result = future.get(remainingMs(deadline), TimeUnit.MILLISECONDS)) {
                        is Fetched -> readings[result.device] = result.reading
                        is Unauthorized -> unauthorized += result.device
                        else -> Unit
                    }
                } catch (error: Exception) {
                    Log.w(TAG, "device read did not finish: ${error.javaClass.simpleName}")
                }
            }
            ReadAttempt(readings, unauthorized)
        } finally {
            executor.shutdownNow()
        }
    }

    private data class Fetched(val reading: AlarmReading, val device: AlarmDevice)

    private data class Unauthorized(val device: AlarmDevice)

    private fun recordAndNotify(signal: AlarmSignal, nowMs: Long) {
        val timestamp = isoFormat.format(Date(nowMs))
        state.appendRecord(
            JSONObject().apply {
                // Same shape as `AlarmRecord.toJson` on the Dart side, so the
                // merged history screen needs no translation.
                put("id", "${nowMs}_${signal.id}")
                put("timestamp", timestamp)
                put("type", signal.rule.type)
                put("severity", signal.rule.severity)
                put("message", signal.message)
                signal.value?.let { put("value", it) }
                put("acknowledged", false)
                put("resolved", false)
            },
        )
        notifier.notify(signal)
    }

    /** Milliseconds left for a device read, never more than the budget. */
    private fun remainingMs(deadline: Long): Long =
        (deadline - System.currentTimeMillis()).coerceAtLeast(1L)

    private companion object {
        const val TAG = "EnerGrowAlarmCheck"

        /**
         * A manifest `BroadcastReceiver` is allowed roughly ten seconds before
         * the process is killed, and being killed mid-write is worse than not
         * checking: the active set never gets updated, so the next tick sees the
         * same alarms as new and notifies again. The budget is deliberately
         * under the platform's allowance, leaving room for the finish() call.
         */
        const val BUDGET_MS = 8_000L

        /** Shared by every entry point, see [run]. */
        val running = java.util.concurrent.atomic.AtomicBoolean(false)
    }
}

