package tech.mbkm.energrow.alarm

import org.json.JSONObject
import java.net.URI
import java.net.URISyntaxException

/**
 * The alarm rule contract, mirroring `lib/utils/alarm_rules.dart`.
 *
 * The Dart side owns the rules. They travel to this side as JSON so that a
 * threshold edited in Settings changes the background behaviour too, and so
 * that the wording in a notification can never drift from the wording in the
 * app's alert banner: there is only one list, and both consumers walk it.
 *
 * Nothing in this file touches the Android framework, which is what lets
 * [AlarmEvaluatorTest] exercise it on the JVM.
 */

/** Which ThingsBoard device a rule reads from. */
enum class AlarmDevice(val wireName: String) {
    BATTERY("battery"),
    PZEM("pzem"),
    SENSOR("sensor");

    companion object {
        fun fromWireName(value: String): AlarmDevice? =
            entries.firstOrNull { it.wireName == value }
    }
}

/** How a rule decides that it is active. */
enum class AlarmComparison {
    LESS_THAN,
    GREATER_THAN,
    STALE,
    OFFLINE;

    companion object {
        /** Parses the Dart enum name, e.g. `lessThan`. */
        fun fromName(value: String): AlarmComparison? = when (value) {
            "lessThan" -> LESS_THAN
            "greaterThan" -> GREATER_THAN
            "stale" -> STALE
            "offline" -> OFFLINE
            else -> null
        }
    }
}

/** Which wording to render. See `AlarmMessageFormat` for the actual strings. */
enum class AlarmMessageKind {
    LOW_SOC,
    STALE,
    OFFLINE,
    RANGE_LOW,
    RANGE_HIGH;

    companion object {
        fun fromName(value: String): AlarmMessageKind? = when (value) {
            "lowSoc" -> LOW_SOC
            "stale" -> STALE
            "offline" -> OFFLINE
            "rangeLow" -> RANGE_LOW
            "rangeHigh" -> RANGE_HIGH
            else -> null
        }
    }
}

/**
 * One armed alarm condition.
 *
 * [type] and [severity] are kept as the Dart enum names rather than Kotlin
 * enums on purpose: they are written verbatim into persisted history records,
 * and duplicating the enums here would create a second place to keep in sync
 * with no benefit.
 */
data class AlarmRule(
    val id: String,
    val type: String,
    val severity: String,
    val device: AlarmDevice,
    val metric: String?,
    val comparison: AlarmComparison,
    val limit: Double?,
    val label: String,
    val unit: String,
    val decimals: Int,
    val message: AlarmMessageKind,
    val staleMinutes: Int,
    val requireFreshSensor: Boolean,
) {
    val isCritical: Boolean get() = severity == "critical"
}

/** The values and freshness of one device, as the evaluator needs them. */
data class AlarmReading(
    val device: AlarmDevice,
    val values: Map<String, Double>,
    val lastUpdate: Long?,
)

/** An active rule together with its rendered message. */
data class AlarmSignal(
    val rule: AlarmRule,
    val message: String,
    val value: Double?,
) {
    val id: String get() = rule.id
}

/** One ThingsBoard device the background check should poll. */
data class AlarmDeviceConfig(
    val device: AlarmDevice,
    val deviceId: String,
    /** Telemetry keys to request. Never empty. */
    val keys: List<String>,
)

/**
 * The full background configuration, as handed over by Dart.
 *
 * Dart also decides *which* keys to request, derived from the armed rules, so
 * a background check with only a low-SOC rule armed downloads three numbers
 * rather than the twenty-two the dashboard charts need.
 */
data class AlarmConfig(
    val baseUrl: String,
    val devices: List<AlarmDeviceConfig>,
    val rules: List<AlarmRule>,
)

/** Thrown when the configuration Dart sent cannot be understood. */
class AlarmConfigException(message: String, cause: Throwable? = null) :
    Exception(message, cause)

/**
 * Parses the payload produced by `alarmRulesToJson` in Dart.
 *
 * @param payload the `configure` method argument, containing `baseUrl`,
 *   `devices` and `rules`.
 */
fun parseAlarmConfig(payload: JSONObject): AlarmConfig {
    val version = payload.optInt("version", -1)
    if (version != SUPPORTED_VERSION) {
        throw AlarmConfigException("unsupported alarm config version $version")
    }
    val baseUrl = requireAllowedThingsBoardHost(
        payload.optString("baseUrl").takeIf { it.isNotBlank() }
            ?: throw AlarmConfigException("alarm config has no baseUrl"),
    )

    val rawDevices = payload.optJSONArray("devices")
        ?: throw AlarmConfigException("alarm config has no devices")
    val devices = mutableListOf<AlarmDeviceConfig>()
    val seenDevices = mutableSetOf<AlarmDevice>()
    for (index in 0 until rawDevices.length()) {
        val entry = rawDevices.optJSONObject(index)
            ?: throw AlarmConfigException("device $index is not an object")
        val wireName = entry.optString("device")
        val device = AlarmDevice.fromWireName(wireName)
            ?: throw AlarmConfigException("unknown alarm device \"$wireName\"")
        val deviceId = entry.optString("deviceId")
        if (deviceId.isBlank()) {
            throw AlarmConfigException("device $wireName has no deviceId")
        }
        if (!seenDevices.add(device)) {
            throw AlarmConfigException("device $wireName appears twice")
        }
        val rawKeys = entry.optJSONArray("keys")
            ?: throw AlarmConfigException("device $wireName has no keys")
        val keys = mutableListOf<String>()
        for (keyIndex in 0 until rawKeys.length()) {
            rawKeys.optString(keyIndex).takeIf { it.isNotBlank() }?.let(keys::add)
        }
        if (keys.isEmpty()) {
            throw AlarmConfigException("device $wireName has no usable keys")
        }
        devices += AlarmDeviceConfig(device, deviceId, keys)
    }
    if (rawDevices.length() > 0 && devices.isEmpty()) {
        throw AlarmConfigException("alarm config lists devices but none of them were usable")
    }

    val rawRules = payload.optJSONArray("rules")
        ?: throw AlarmConfigException("alarm config has no rules")
    val rules = mutableListOf<AlarmRule>()
    for (index in 0 until rawRules.length()) {
        rules += parseAlarmRule(rawRules.optJSONObject(index)
            ?: throw AlarmConfigException("rule $index is not an object"))
    }
    if (rules.isNotEmpty() && devices.isEmpty()) {
        throw AlarmConfigException("alarm config has rules but no devices to poll them")
    }
    // A rule naming a device that is not polled could never fire, and would look
    // like a monitor that is silently blind. Caught here rather than at 3am.
    val known = devices.mapTo(mutableSetOf()) { it.device }
    for (rule in rules) {
        if (rule.device !in known) {
            throw AlarmConfigException(
                "rule ${rule.id} reads ${rule.device.wireName}, which is not polled",
            )
        }
    }

    return AlarmConfig(baseUrl.trimEnd('/'), devices, rules)
}

/** Payload version understood by this build. Bump on a breaking shape change. */
const val SUPPORTED_VERSION = 1

private fun parseAlarmRule(json: JSONObject): AlarmRule {
    val id = json.optString("id")
    if (id.isBlank()) throw AlarmConfigException("rule has no id")
    val device = AlarmDevice.fromWireName(json.optString("device"))
        ?: throw AlarmConfigException("rule $id has an unknown device")
    val comparison = AlarmComparison.fromName(json.optString("comparison"))
        ?: throw AlarmConfigException("rule $id has an unknown comparison")
    val message = AlarmMessageKind.fromName(json.optString("message"))
        ?: throw AlarmConfigException("rule $id has an unknown message kind")
    return AlarmRule(
        id = id,
        type = json.optString("type"),
        severity = json.optString("severity"),
        device = device,
        metric = json.optString("metric").takeIf { it.isNotBlank() },
        comparison = comparison,
        limit = json.optDouble("limit").takeIf { !json.isNull("limit") },
        label = json.optString("label"),
        unit = json.optString("unit"),
        decimals = json.optInt("decimals", 1),
        message = message,
        staleMinutes = json.optInt("staleMinutes", 10),
        requireFreshSensor = json.optBoolean("requireFreshSensor", false),
    )
}

/**
 * The only host this module will send a ThingsBoard token to.
 *
 * Checking for an `https://` prefix is not enough, and the difference matters:
 * a prefix test accepts *any* TLS host, so the moment the base URL becomes
 * configurable — a normal request for an app like this — a mistyped or
 * malicious host would receive a live bearer token with no warning. An exact
 * host list turns that into a startup failure instead.
 *
 * This mirrors `parseAllowedCctvUrl` on the Dart side, which already does it
 * properly. If the ThingsBoard instance ever moves, change it in one place here
 * and one there.
 */
private const val ALLOWED_THINGSBOARD_HOST = "dashboard.mbkm20262027.tech"

internal fun requireAllowedThingsBoardHost(baseUrl: String): String {
    val uri = try {
        URI(baseUrl)
    } catch (error: URISyntaxException) {
        throw AlarmConfigException("alarm config baseUrl is not a valid URL")
    }
    if (!uri.scheme.equals("https", ignoreCase = true)) {
        throw AlarmConfigException("alarm config baseUrl must be https")
    }
    // Userinfo is the classic way to smuggle a second host past a naive check:
    // https://allowed.host@evil.example/ has evil.example as the real host.
    if (uri.userInfo != null) {
        throw AlarmConfigException("alarm config baseUrl must not carry credentials")
    }
    if (!uri.host.equals(ALLOWED_THINGSBOARD_HOST, ignoreCase = true)) {
        throw AlarmConfigException(
            "alarm config baseUrl host \"${uri.host}\" is not $ALLOWED_THINGSBOARD_HOST",
        )
    }
    if (uri.port != -1 && uri.port != 443) {
        throw AlarmConfigException("alarm config baseUrl must use port 443")
    }
    // A path here would be prepended to /api/... and quietly address a different
    // service on the same host.
    val path = uri.path.orEmpty()
    if (path.isNotEmpty() && path != "/") {
        throw AlarmConfigException("alarm config baseUrl must not have a path")
    }
    return "https://$ALLOWED_THINGSBOARD_HOST"
}
