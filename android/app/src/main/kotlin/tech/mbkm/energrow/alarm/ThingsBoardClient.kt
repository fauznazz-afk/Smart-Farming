package tech.mbkm.energrow.alarm

import android.util.Log
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * The minimum ThingsBoard client a background check needs: read the newest
 * value of a few keys, and refresh the access token when it has expired.
 *
 * `ThingsBoardApi` does the same work with far more capability, but reaching it
 * means starting a Flutter engine, which costs tens of megabytes and a second or
 * more per tick. This uses `HttpURLConnection` and `org.json`, both already on
 * the platform, so the whole check stays inside the app process with no engine.
 *
 * The endpoint, the header name and the response shape are the app's existing
 * contract; see `fetchLatestTelemetry` in `lib/services/thingsboard_api.dart`.
 */
class ThingsBoardClient(
    private val baseUrl: String,
    private val token: String,
) {
    private val maxBodyBytes = 1 shl 18 // 256 KiB; a handful of keys never needs more

    /**
     * Fetches the newest value of each requested key.
     *
     * Only the first point of each series is read, which is what
     * `DeviceTelemetry.fromJson` does, and the returned [AlarmReading.lastUpdate]
     * is the newest of those points. Throws [IOException] on any transport or
     * HTTP failure, so the caller can treat a failed fetch as "no information"
     * rather than as stale telemetry.
     */
    fun fetch(device: AlarmDevice, config: AlarmDeviceConfig): AlarmReading {
        val url = URL(
            "$baseUrl/api/plugins/telemetry/DEVICE/${config.deviceId}" +
                "/values/timeseries?keys=${config.keys.joinToString(",")}",
        )
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            setRequestProperty("X-Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
            useCaches = false
        }
        try {
            val status = connection.responseCode
            if (status != HttpURLConnection.HTTP_OK) {
                // A 401 is separated out because it is the one failure worth
                // retrying with a fresh token rather than waiting for the next
                // scheduled tick.
                throw ThingsBoardHttpException(status, device)
            }
            val body = connection.inputStream.use { stream ->
                val buffer = ByteArray(maxBodyBytes)
                var total = 0
                while (total < buffer.size) {
                    val read = stream.read(buffer, total, buffer.size - total)
                    if (read < 0) break
                    total += read
                }
                String(buffer, 0, total, Charsets.UTF_8)
            }
            return parseReading(device, JSONObject(body))
        } finally {
            connection.disconnect()
        }
    }

    /**
     * Exchanges a refresh token for a new access token.
     *
     * The background check needs this because ThingsBoard access tokens expire.
     * Without it a check that runs hours after the last app launch would fail
     * with 401, produce no readings, and silently stop reporting for the rest of
     * the session.
     *
     * Returns null when the server could not be reached or answered with
     * something unexpected, which is a reason to try again on the next tick.
     * A rejected refresh token raises [RefreshRejectedException] instead, because
     * retrying it is pointless: the session is over.
     */
    fun refresh(refreshToken: String): TokenRefresh? {
        val url = URL("$baseUrl/api/auth/token")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            useCaches = false
        }
        return try {
            val payload = JSONObject().put("refreshToken", refreshToken).toString()
            connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
            when (val status = connection.responseCode) {
                HttpURLConnection.HTTP_OK -> {
                    val body = connection.inputStream.use {
                        it.readBytes().toString(Charsets.UTF_8)
                    }
                    val json = JSONObject(body)
                    val accessToken = json.optString("token")
                    if (accessToken.isBlank()) {
                        Log.w(TAG, "token refresh succeeded but returned no token")
                        null
                    } else {
                        // The server may rotate the refresh token too, in which
                        // case the old one is spent and keeping it would fail the
                        // next refresh.
                        TokenRefresh(
                            accessToken = accessToken,
                            refreshToken = json.optString("refreshToken")
                                .takeIf { it.isNotBlank() },
                        )
                    }
                }
                HttpURLConnection.HTTP_UNAUTHORIZED,
                HttpURLConnection.HTTP_FORBIDDEN,
                -> {
                    Log.i(TAG, "ThingsBoard rejected the refresh token; session is over")
                    throw RefreshRejectedException()
                }
                else -> {
                    Log.w(TAG, "ThingsBoard token refresh returned HTTP $status")
                    null
                }
            }
        } catch (error: RefreshRejectedException) {
            throw error
        } catch (error: Exception) {
            Log.w(TAG, "ThingsBoard token refresh failed", error)
            null
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val TAG = "EnerGrowAlarmTb"
        private const val CONNECT_TIMEOUT_MS = 5_000
        private const val READ_TIMEOUT_MS = 5_000

        /**
         * Reads the first point of each series, matching `DeviceTelemetry`.
         *
         * Values arrive as strings and are parsed leniently, because a single
         * unparseable reading should not discard the whole device.
         */
        fun parseReading(device: AlarmDevice, json: JSONObject): AlarmReading {
            val values = mutableMapOf<String, Double>()
            var latest: Long? = null
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val series = json.optJSONArray(key) ?: continue
                if (series.length() == 0) continue
                val point = series.optJSONObject(0) ?: continue
                val timestamp = point.optLong("ts", 0L)
                if (timestamp <= 0L) continue
                val value = point.opt("value")?.let { raw ->
                    raw.toString().trim().toDoubleOrNull()
                } ?: continue
                values[key] = value
                if (latest == null || timestamp > latest) latest = timestamp
            }
            return AlarmReading(device, values, latest)
        }
    }
}

/** Raised when ThingsBoard refuses a refresh token, meaning the session ended. */
class RefreshRejectedException : Exception("refresh token rejected")

/** An HTTP failure that carries its status, so a 401 can be told from a 500. */
class ThingsBoardHttpException(val status: Int, val device: AlarmDevice) :
    IOException("ThingsBoard returned HTTP $status for ${device.wireName}")

/** The outcome of a successful token refresh. */
data class TokenRefresh(
    val accessToken: String,
    /** Present only when the server rotated the refresh token. */
    val refreshToken: String?,
)
