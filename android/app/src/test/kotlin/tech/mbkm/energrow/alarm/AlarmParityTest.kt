package tech.mbkm.energrow.alarm

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/**
 * Replays the shared parity vectors through the native evaluator.
 *
 * The counterpart of this is `test/alarm_parity_test.dart`, which replays the
 * same file through the Dart evaluator. Both assert the same expected messages,
 * which is the only thing that keeps the two implementations of these rules in
 * agreement. The native one has no other test, because on a device it needs a
 * token, a network and a live ThingsBoard.
 */
class AlarmParityTest {

    private val fixture: JSONObject by lazy {
        val stream = javaClass.classLoader!!.getResourceAsStream(FIXTURE)
            ?: throw IllegalStateException("$FIXTURE is not on the test classpath")
        JSONObject(stream.bufferedReader().use { it.readText() })
    }

    @Test
    fun `the fixture is present and not empty`() {
        val scenarios = fixture.getJSONArray("scenarios")
        assertTrue("no scenarios in the parity fixture", scenarios.length() > 0)
    }

    @Test
    fun `every scenario produces the same alarms as the Dart evaluator`() {
        val scenarios = fixture.getJSONArray("scenarios")
        for (index in 0 until scenarios.length()) {
            val scenario = scenarios.getJSONObject(index)
            val name = scenario.getString("name")
            val config = parseAlarmConfig(
                JSONObject().apply {
                    put("version", SUPPORTED_VERSION)
                    put("baseUrl", "https://$BASE_URL")
                    put("devices", devicesFor(scenario.getJSONArray("rules")))
                    put("rules", scenario.getJSONArray("rules"))
                },
            )
            val nowMs = Instant.parse(scenario.getString("now")).toEpochMilli()
            val signals = AlarmEvaluator.evaluate(
                rules = config.rules,
                readings = readingsFor(scenario.getJSONArray("readings")),
                nowMs = nowMs,
            )

            val expected = scenario.getJSONArray("expected")
            assertEquals(
                "scenario \"$name\" raised a different number of alarms",
                expected.length(),
                signals.size,
            )
            for (signalIndex in 0 until expected.length()) {
                val wanted = expected.getJSONObject(signalIndex)
                assertEquals(
                    "scenario \"$name\" alarm $signalIndex id",
                    wanted.getString("id"),
                    signals[signalIndex].id,
                )
                assertEquals(
                    "scenario \"$name\" alarm ${signals[signalIndex].id} message",
                    wanted.getString("message"),
                    signals[signalIndex].message,
                )
            }
        }
    }

    @Test
    fun `the fixture covers the environment freshness gate`() {
        // The gate is the easiest thing to get wrong and the hardest to notice:
        // without it, an environment alarm fires for a reading that is hours old
        // and describes a condition that has already ended.
        val scenarios = fixture.getJSONArray("scenarios")
        val stale = scenario(scenarios, "environment_is_silent_while_the_sensor_is_stale")
        assertEquals(0, stale.getJSONArray("expected").length())
        val fresh = scenario(scenarios, "environment_high_needs_fresh_sensor")
        assertEquals(1, fresh.getJSONArray("expected").length())
    }

    @Test
    fun `the fixture covers a reading with no timestamp`() {
        // The Kotlin counterpart of the same guard in test/alarm_parity_test.dart.
        // Both are needed because both suites are driven *by* the fixture: delete
        // the undated vectors and every remaining test still passes, so nothing
        // would report the loss. `readings: []` does not stand in for it -- a
        // missing reading is skipped at the `reading == null` check, while a null
        // timestamp reaches `AlarmEvaluator.isStale`, so the two exercise
        // different branches.
        val scenarios = fixture.getJSONArray("scenarios")
        var undated = 0
        for (index in 0 until scenarios.length()) {
            val readings = scenarios.getJSONObject(index).getJSONArray("readings")
            for (readingIndex in 0 until readings.length()) {
                if (readings.getJSONObject(readingIndex).isNull("lastUpdate")) undated++
            }
        }
        assertTrue(
            "no vector has a null lastUpdate, so the stale-by-default path in " +
                "AlarmEvaluator.isStale is no longer pinned",
            undated > 0,
        )
    }

    @Test
    fun `a config without a rule list is rejected instead of silently ignored`() {
        val failure = runCatching {
            parseAlarmConfig(
                JSONObject().put("version", SUPPORTED_VERSION).put("baseUrl", "https://$BASE_URL"),
            )
        }.exceptionOrNull()
        assertTrue("expected a rejection, got $failure", failure is AlarmConfigException)
    }

    @Test
    fun `a config with a future version is rejected`() {
        val failure = runCatching {
            parseAlarmConfig(
                JSONObject()
                    .put("version", SUPPORTED_VERSION + 1)
                    .put("baseUrl", "https://$BASE_URL")
                    .put("devices", JSONArray())
                    .put("rules", JSONArray()),
            )
        }.exceptionOrNull()
        assertTrue(failure is AlarmConfigException)
    }

    @Test
    fun `a plain http base url is refused so a token is never sent in clear`() {
        assertRejected("http://$BASE_URL")
    }

    @Test
    fun `a different https host is refused so a token cannot be exfiltrated`() {
        // The important half of the check. A prefix test would accept this, and
        // the result would be a live bearer token posted to someone else's
        // server the first time the base URL became configurable.
        assertRejected("https://evil.example.com")
        assertRejected("https://dashboard.mbkm20262027.tech.evil.example")
        assertRejected("https://notdashboard.mbkm20262027.tech")
    }

    @Test
    fun `userinfo cannot smuggle a second host past the check`() {
        assertRejected("https://$BASE_URL@evil.example.com")
    }

    @Test
    fun `a non default port is refused`() {
        assertRejected("https://$BASE_URL:8443")
    }

    @Test
    fun `a path is refused so the api prefix cannot be redirected`() {
        assertRejected("https://$BASE_URL/somewhere-else")
    }

    @Test
    fun `the real host is accepted and normalised`() {
        val config = parseAlarmConfig(
            JSONObject()
                .put("version", SUPPORTED_VERSION)
                .put("baseUrl", "https://$BASE_URL/")
                .put("devices", JSONArray())
                .put("rules", JSONArray()),
        )
        assertEquals("https://$BASE_URL", config.baseUrl)
    }

    @Test
    fun `a device id that is not a uuid is refused so it cannot retarget the token`() {
        // Found in review on 6 October 2026. `deviceId` is interpolated straight
        // into `/DEVICE/$deviceId/values/timeseries`, so `../../rpc` would move
        // the bearer token to a different endpoint on the *same* host -- which is
        // precisely the case the host allowlist is blind to, because the host
        // never moves.
        for (hostile in listOf("../../rpc", "../auth/user", "x/../../y", "a b")) {
            val failure = runCatching {
                parseAlarmConfig(
                    JSONObject()
                        .put("version", SUPPORTED_VERSION)
                        .put("baseUrl", "https://$BASE_URL")
                        .put(
                            "devices",
                            JSONArray().put(
                                JSONObject()
                                    .put("device", "battery")
                                    .put("deviceId", hostile)
                                    .put("keys", JSONArray().put("soc")),
                            ),
                        )
                        .put(
                            "rules",
                            JSONArray().put(
                                JSONObject()
                                    .put("id", "low_soc")
                                    .put("type", "lowSoc")
                                    .put("severity", "critical")
                                    .put("device", "battery")
                                    .put("metric", "soc")
                                    .put("comparison", "lessThan")
                                    .put("limit", 20.0)
                                    .put("label", "Battery")
                                    .put("unit", "%")
                                    .put("decimals", 0)
                                    .put("message", "lowSoc")
                                    .put("staleMinutes", 10),
                            ),
                        ),
                )
            }.exceptionOrNull()
            assertTrue(
                "expected \"$hostile\" to be rejected, got $failure",
                failure is AlarmConfigException,
            )
        }
    }

    @Test
    fun `a real uuid device id is accepted`() {
        // The other half: a check that rejects everything is not a check.
        val config = parseAlarmConfig(
            JSONObject()
                .put("version", SUPPORTED_VERSION)
                .put("baseUrl", "https://$BASE_URL")
                .put(
                    "devices",
                    JSONArray().put(
                        JSONObject()
                            .put("device", "battery")
                            .put("deviceId", "9465cf90-b264-11f1-9294-d92385142e6d")
                            .put("keys", JSONArray().put("soc")),
                    ),
                )
                .put(
                    "rules",
                    JSONArray().put(
                        JSONObject()
                            .put("id", "low_soc")
                            .put("type", "lowSoc")
                            .put("severity", "critical")
                            .put("device", "battery")
                            .put("metric", "soc")
                            .put("comparison", "lessThan")
                            .put("limit", 20.0)
                            .put("label", "Battery")
                            .put("unit", "%")
                            .put("decimals", 0)
                            .put("message", "lowSoc")
                            .put("staleMinutes", 10),
                    ),
                ),
        )
        // Pinned on the id rather than the enum name, because the id is what goes
        // into the request path and that is the thing the check protects.
        assertEquals("9465cf90-b264-11f1-9294-d92385142e6d", config.devices.single().deviceId)
        assertEquals(listOf("soc"), config.devices.single().keys)
    }

    private fun assertRejected(baseUrl: String) {
        val failure = runCatching {
            parseAlarmConfig(
                JSONObject()
                    .put("version", SUPPORTED_VERSION)
                    .put("baseUrl", baseUrl)
                    .put("devices", JSONArray())
                    .put("rules", JSONArray()),
            )
        }.exceptionOrNull()
        assertTrue("expected \"$baseUrl\" to be rejected, got $failure", failure is AlarmConfigException)
    }

    private fun scenario(scenarios: JSONArray, name: String): JSONObject {
        for (index in 0 until scenarios.length()) {
            val candidate = scenarios.getJSONObject(index)
            if (candidate.getString("name") == name) return candidate
        }
        throw AssertionError("no scenario named \"$name\" in the parity fixture")
    }

    private fun devicesFor(rules: JSONArray): JSONArray {
        val wanted = mutableSetOf<String>()
        for (index in 0 until rules.length()) {
            wanted += rules.getJSONObject(index).optString("device")
        }
        val devices = JSONArray()
        for (device in AlarmDevice.entries) {
            if (device.wireName !in wanted) continue
            devices.put(
                JSONObject()
                    .put("device", device.wireName)
                    .put("deviceId", "00000000-0000-0000-0000-000000000000")
                    .put("keys", JSONArray().put(freshnessKeyFor(device))),
            )
        }
        return devices
    }

    private fun freshnessKeyFor(device: AlarmDevice): String = when (device) {
        AlarmDevice.BATTERY -> "soc"
        AlarmDevice.PZEM -> "voltage_ac"
        AlarmDevice.SENSOR -> "temp_dht"
        AlarmDevice.FISH -> "ph"
    }

    private fun readingsFor(raw: JSONArray): Map<AlarmDevice, AlarmReading> {
        val readings = mutableMapOf<AlarmDevice, AlarmReading>()
        for (index in 0 until raw.length()) {
            val entry = raw.getJSONObject(index)
            val device = AlarmDevice.fromWireName(entry.getString("device"))!!
            val values = mutableMapOf<String, Double>()
            val valueJson = entry.getJSONObject("values")
            val keys = valueJson.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                values[key] = valueJson.getDouble(key)
            }
            // Explicit null rather than a missing key, because org.json's
            // `optString` returns the "" default for an absent key and
            // `getString` throws on JSONObject.NULL -- so `isNull` is the only
            // spelling that distinguishes "no timestamp" from a broken fixture.
            // AlarmEvaluator.isStale treats that null as stale immediately, and
            // the Dart side has to agree; the shared vectors are what pins it.
            val lastUpdateMs = if (entry.isNull("lastUpdate")) {
                null
            } else {
                Instant.parse(entry.getString("lastUpdate")).toEpochMilli()
            }
            readings[device] = AlarmReading(device, values, lastUpdateMs)
        }
        return readings
    }

    private companion object {
        const val FIXTURE = "alarm_parity_vectors.json"
        const val BASE_URL = "dashboard.mbkm20262027.tech"
    }
}
