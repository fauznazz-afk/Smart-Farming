package tech.mbkm.energrow.alarm

/**
 * Decides which alarms are active.
 *
 * This is a walk of the rule list Dart produced, holding no thresholds of its
 * own, and it is the same logic `evaluateAlarmRules` runs in Dart for the
 * in-app banner. No Android imports, so [AlarmEvaluatorTest] can run it on the
 * JVM against the shared parity fixture.
 */
object AlarmEvaluator {

    /**
     * Mirrors `DeviceTelemetry.isStale` and `AlarmReading.isStale`.
     *
     * A device that has never reported counts as stale, and the comparison is
     * strictly greater than, truncated to whole minutes. A timestamp in the
     * future yields a negative age, which is never greater than the limit, so a
     * device whose clock disagrees does not immediately raise an alarm.
     */
    fun isStale(reading: AlarmReading, minutes: Int, nowMs: Long): Boolean {
        val last = reading.lastUpdate ?: return true
        return (nowMs - last) / 60_000L > minutes
    }

    /**
     * Returns the signals for every rule that is currently active.
     *
     * [nowMs] is injected for the same reason as Dart's `now`: staleness has to
     * be deterministic under test.
     */
    fun evaluate(
        rules: List<AlarmRule>,
        readings: Map<AlarmDevice, AlarmReading>,
        nowMs: Long,
    ): List<AlarmSignal> {
        val signals = mutableListOf<AlarmSignal>()
        for (rule in rules) {
            val reading = readings[rule.device]
            // A device that produced no reading at all cannot raise an alert.
            // This is deliberately different from a device that is stale:
            // staleness is the alarm, silence is not.
            if (reading == null) continue

            if (rule.comparison == AlarmComparison.STALE ||
                rule.comparison == AlarmComparison.OFFLINE
            ) {
                if (isStale(reading, rule.staleMinutes, nowMs)) {
                    signals += AlarmSignal(rule, AlarmMessageFormat.format(rule, null), null)
                }
                continue
            }

            val metric = rule.metric ?: continue
            val value = reading.values[metric] ?: continue

            if (rule.requireFreshSensor) {
                val device = readings[rule.device]
                if (device == null || isStale(device, rule.staleMinutes, nowMs)) continue
            }

            val limit = rule.limit ?: continue
            val breached = when (rule.comparison) {
                AlarmComparison.LESS_THAN -> value < limit
                AlarmComparison.GREATER_THAN -> value > limit
                AlarmComparison.STALE, AlarmComparison.OFFLINE -> false
            }
            if (!breached) continue

            signals += AlarmSignal(rule, AlarmMessageFormat.format(rule, value), value)
        }
        return signals
    }
}
