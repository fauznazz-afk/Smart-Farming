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
                    put("baseUrl", BASE_URL)
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
    fun `a config without a rule list is rejected instead of silently ignored`() {
        val failure = runCatching {
            parseAlarmConfig(
                JSONObject().put("version", SUPPORTED_VERSION).put("baseUrl", BASE_URL),
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
                    .put("baseUrl", BASE_URL)
                    .put("devices", JSONArray())
                    .put("rules", JSONArray()),
            )
        }.exceptionOrNull()
        assertTrue(failure is AlarmConfigException)
    }

    @Test
    fun `a plain http base url is refused so a token is never sent in clear`() {
        val failure = runCatching {
            parseAlarmConfig(
                JSONObject()
                    .put("version", SUPPORTED_VERSION)
                    .put("baseUrl", "http://dashboard.example.com")
                    .put("devices", JSONArray())
                    .put("rules", JSONArray()),
            )
        }.exceptionOrNull()
        assertTrue(failure is AlarmConfigException)
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
            readings[device] = AlarmReading(
                device,
                values,
                Instant.parse(entry.getString("lastUpdate")).toEpochMilli(),
            )
        }
        return readings
    }

    private companion object {
        const val FIXTURE = "alarm_parity_vectors.json"
        const val BASE_URL = "https://dashboard.mbkm20262027.tech"
    }
}
