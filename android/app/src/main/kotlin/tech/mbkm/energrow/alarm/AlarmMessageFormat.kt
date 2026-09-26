package tech.mbkm.energrow.alarm

import java.math.BigDecimal
import java.math.RoundingMode

/**
 * Renders an alarm message.
 *
 * This duplicates `formatAlarmMessage` in `lib/utils/alarm_rules.dart`, and it
 * has to: the notification is built while Dart is not running, so there is no
 * way to call the Dart function from here. Two implementations of the same four
 * strings is the price of a background check that does not spin up a Flutter
 * engine, and it is bounded by
 * `android/app/src/test/resources/alarm_parity_vectors.json`, which pins both
 * sides to the same expected output. If one drifts, one of the two tests fails.
 */
object AlarmMessageFormat {

    fun format(rule: AlarmRule, value: Double?): String = when (rule.message) {
        AlarmMessageKind.LOW_SOC ->
            "SOC baterai rendah: ${fixed(value ?: 0.0, rule.decimals)}%"
        AlarmMessageKind.STALE ->
            "Data ${rule.label} belum diperbarui"
        AlarmMessageKind.RANGE_LOW ->
            "${rule.label} rendah: ${fixed(value ?: 0.0, rule.decimals)} ${rule.unit} " +
                "(batas ${plain(rule.limit)} ${rule.unit})"
        AlarmMessageKind.RANGE_HIGH ->
            "${rule.label} tinggi: ${fixed(value ?: 0.0, rule.decimals)} ${rule.unit} " +
                "(batas ${plain(rule.limit)} ${rule.unit})"
    }

    /**
     * Equivalent of Dart's `toStringAsFixed`.
     *
     * `BigDecimal.valueOf` goes through `Double.toString`, i.e. the shortest
     * round-tripping representation, which is also the digits Dart rounds. Using
     * `String.format` instead would round the exact binary expansion and
     * disagree with Dart on values ending in a 5, such as 31.25.
     */
    fun fixed(value: Double, decimals: Int): String =
        BigDecimal.valueOf(value).setScale(decimals, RoundingMode.HALF_UP).toPlainString()

    /**
     * Equivalent of Dart's `'$double'`.
     *
     * Kotlin would print `1.0E7` where Dart prints `10000000.0`, so the value is
     * routed through [BigDecimal] to get plain notation, with a `.0` appended
     * when Dart's output would still carry a decimal point.
     */
    fun plain(value: Double?): String {
        if (value == null) return "null"
        val text = BigDecimal.valueOf(value).toPlainString()
        return if (text.contains('.')) text else "$text.0"
    }
}
