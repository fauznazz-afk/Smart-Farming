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
            "Battery charge low: ${fixed(value ?: 0.0, rule.decimals)}%"
        AlarmMessageKind.STALE ->
            "No fresh data from ${rule.label}"
        AlarmMessageKind.OFFLINE ->
            "${rule.label} has stopped reporting"
        AlarmMessageKind.RANGE_LOW ->
            "${rule.label} too low: ${fixed(value ?: 0.0, rule.decimals)}${unit(rule)} " +
                "(limit ${plain(rule.limit)}${unit(rule)})"
        AlarmMessageKind.RANGE_HIGH ->
            "${rule.label} too high: ${fixed(value ?: 0.0, rule.decimals)}${unit(rule)} " +
                "(limit ${plain(rule.limit)}${unit(rule)})"
    }

    /**
     * ` ppm` for a rule that carries a unit, empty for one that does not.
     *
     * The mirror of Dart's `_unit` in `alarm_rules.dart`, and for the same
     * reason: pH is built with an empty unit, and interpolating `' $unit '`
     * unconditionally produced `pH too high: 9.10  (limit 8.5 )` -- a doubled
     * space and a trailing one, in the in-app banner, the stored record and the
     * background notification alike.
     *
     * Both sides had it and both sides' tests were green, because
     * `alarm_parity_vectors.json` is generated from the Dart formatter. A golden
     * fixture produced by the thing under test cannot catch a defect in it: it
     * pins the two languages to each other and says nothing about whether the
     * shared string is right.
     *
     * Leading space only. The space before `(limit` is a literal above, so
     * adding one here as well would double it for every rule that has a unit.
     */
    private fun unit(rule: AlarmRule): String =
        if (rule.unit.isEmpty()) "" else " ${rule.unit}"

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
