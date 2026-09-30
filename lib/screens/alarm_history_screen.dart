import './dashboard/utils/color_helpers.dart';
import 'package:flutter/material.dart';

import '../services/alarm_history_service.dart';
import '../widgets/liquid_glass.dart';
import 'dashboard/utils/design_tokens.dart';

class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  final _service = AlarmHistoryService();
  List<AlarmRecord> _alarms = [];
  bool _loading = true;
  final _expandedIds = <String>{};
  _AlarmFilter _filter = _AlarmFilter.all;

  List<AlarmRecord> get _visibleAlarms => _alarms.where((alarm) {
    return switch (_filter) {
      _AlarmFilter.all => true,
      _AlarmFilter.active => !alarm.resolved,
      _AlarmFilter.acknowledged => alarm.acknowledged && !alarm.resolved,
      _AlarmFilter.resolved => alarm.resolved,
      _AlarmFilter.critical => alarm.severity == AlarmSeverity.critical,
      _AlarmFilter.warning => alarm.severity == AlarmSeverity.warning,
    };
  }).toList();

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    final alarms = await _service.getAlarms();
    if (!mounted) return;
    setState(() {
      _alarms = alarms;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alarm History'),
        content: const Text(
          'Delete every recorded alarm? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.clearAlarms();
    if (!mounted) return;
    setState(() {
      _alarms = [];
      _expandedIds.clear();
    });
  }

  IconData _iconForType(AlarmType type) => switch (type) {
    AlarmType.lowSoc => Icons.battery_alert_outlined,
    AlarmType.staleTelemetry => Icons.schedule_outlined,
    AlarmType.environmentTemp => Icons.thermostat_outlined,
    AlarmType.environmentHumidity => Icons.water_drop_outlined,
    AlarmType.environmentTds => Icons.science_outlined,
    AlarmType.fishPh => Icons.water_drop_outlined,
    AlarmType.fishTemp => Icons.thermostat_outlined,
    AlarmType.fishTurbidity => Icons.blur_on_outlined,
    AlarmType.deviceOffline => Icons.cloud_off_outlined,
  };

  Color _colorForSeverity(AlarmSeverity severity, bool isDark) =>
      severity == AlarmSeverity.critical
          ? alarmCritical(isDark)
          : alarmWarning(isDark);

  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Alarm History'),
        centerTitle: true,
        actions: [
          if (_alarms.isNotEmpty)
            IconButton(
              tooltip: 'Delete all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: AppBackground(
        isDark: isDark,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _alarms.isEmpty
            ? _emptyState(isDark)
            : Column(
                children: [
                  _filterBar(isDark),
                  Expanded(child: _alarmList(isDark)),
                ],
              ),
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 56,
            color: faintColor(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            'No alarms recorded',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: faintColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alarmList(bool isDark) {
    final alarms = _visibleAlarms;
    if (alarms.isEmpty) {
      return Center(
        child: Text(
          'No alarms match this filter',
          style: TextStyle(color: faintColor(isDark)),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      itemCount: alarms.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        final isExpanded = _expandedIds.contains(alarm.id);
        final severityColor = _colorForSeverity(alarm.severity, isDark);
        return AppCard(
          isDark: isDark,
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // Was 19: `LiquidGlassCard`'s old radius of 20 minus one, so the
              // splash would not poke past the card's own corner. It was never
              // written down and it is now 3dp out from a 16dp card, so the
              // splash visibly clips inside the corner. Token instead.
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedIds.remove(alarm.id);
                  } else {
                    _expandedIds.add(alarm.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: severityColor.withValues(alpha: 0.15),
                        // The wash alone left the circle with no edge of its
                        // own; against the now-opaque card it read as a
                        // floating smudge rather than a badge.
                        border: Border.all(
                          color: severityColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        _iconForType(alarm.type),
                        size: 20,
                        color: severityColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            alarm.message,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: appPrimaryText(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(alarm.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: faintColor(isDark),
                            ),
                          ),
                          if (isExpanded && alarm.value != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Value: ${alarm.value!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: faintColor(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (isExpanded) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Type: ${alarm.type.label}',
                              style: TextStyle(
                                fontSize: 12,
                                color: faintColor(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusBadge(alarm, severityColor, isDark),
                        PopupMenuButton<_AlarmAction>(
                          tooltip: 'Alarm actions',
                          onSelected: (action) => _applyAction(action, alarm),
                          itemBuilder: (context) => [
                            if (!alarm.acknowledged)
                              const PopupMenuItem(
                                value: _AlarmAction.acknowledge,
                                child: Text('Acknowledge'),
                              ),
                            if (!alarm.resolved)
                              const PopupMenuItem(
                                value: _AlarmAction.resolve,
                                child: Text('Resolve'),
                              ),
                            if (alarm.acknowledged || alarm.resolved)
                              const PopupMenuItem(
                                value: _AlarmAction.reopen,
                                child: Text('Reopen'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        12,
        8,
      ),
      child: Row(
        children: _AlarmFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusBadge(AlarmRecord alarm, Color severityColor, bool isDark) {
    final label = alarm.resolved
        ? 'Resolved'
        : alarm.acknowledged
        ? 'Acknowledged'
        : alarm.severity == AlarmSeverity.critical
        ? 'Critical'
        : 'Warning';
    // **A resolved alarm is a record, and that is what the treatment is
    // derived from.** The badge used to take `statusOk`, on the reading that a
    // problem being absent is good news. Two rules in AGENTS.md say otherwise
    // and the second is the one that settles it. `statusOk` is a *status*
    // colour, so on this screen it reads in the present tense — "there is no
    // problem right now" — while the row is a statement about the past: an
    // event in a list ordered by when the alarm fired, printed one line away
    // from a live unresolved alarm that legitimately is red or amber. So the
    // green that means "healthy" everywhere else is sitting beside a real
    // warning, and one hue is doing two opposite jobs on one screen. That is
    // the same defect as the single-series chart, and
    // `system_status_strip.dart` already resolved it from the other direction
    // by taking `appPrimaryText` for a healthy reading.
    //
    // Dropping the green is not sufficient on its own, which is the part a
    // colour-only fix would miss. **The wash is what makes a badge a badge**: a
    // tinted pill is an attention shape, it says "this has a status, look at
    // it", and a resolved record is the one state in this list the user can
    // neither act on nor is unaware of. So the resolved case gives up the pill
    // too and is printed as a plain caption in the same slot at the same size,
    // so the row does not change shape between states.
    //
    // This is where the live-condition and the historical-record cases part
    // company, and it is a difference of *shape*, not of hue. A live condition
    // is the case the "say nothing when nothing is wrong" rule was written
    // for: `system_status_strip` can drop the green outright because the
    // reader only ever looks at the current value. A record cannot, because a
    // list of the last thirty alarms is a table and the column has to hold its
    // shape as the rows scroll past. So the resolved state keeps a label in
    // every case — it is never silent — and what it gives up is the thing that
    // was making a *historical* row look like a *live* one.
    //
    // Nothing is lost. The word "Resolved" is still in the same position, in
    // ordinary text, and a word is a better carrier of this than a hue anyway:
    // the reader who cannot resolve the green could not have read it before.
    if (alarm.resolved) {
      return Padding(
        // `AppBadge`'s own padding, kept so a row does not change width as it
        // is acknowledged and resolved. No fill: that padding is the pill's
        // geometry, not an assertion of a status.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: appPrimaryText(isDark),
          ),
        ),
      );
    }
    // `statusAlert` for "Acknowledged" is deliberate and stays. Acknowledged is
    // not the resolved case: the condition is still open, the user has seen it
    // and not fixed it, and that is a live verdict — hence the neither-good-
    // nor-bad slot rather than ordinary text. Both replaced raw `Colors.green`
    // and `Colors.blue` here; those are tuned for large fills and measured about
    // 2.3:1 and 3.0:1 as 10dp text.
    final color = alarm.acknowledged ? statusAlert(isDark) : severityColor;
    return AppBadge(
      isDark: isDark,
      color: color,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _applyAction(_AlarmAction action, AlarmRecord alarm) async {
    final updated = switch (action) {
      _AlarmAction.acknowledge => alarm.copyWith(acknowledged: true),
      _AlarmAction.resolve => alarm.copyWith(
        acknowledged: true,
        resolved: true,
      ),
      _AlarmAction.reopen => alarm.copyWith(
        acknowledged: false,
        resolved: false,
      ),
    };
    await _service.updateAlarm(updated);
    if (!mounted) return;
    setState(() {
      final index = _alarms.indexWhere((item) => item.id == alarm.id);
      if (index != -1) _alarms[index] = updated;
    });
  }
}

enum _AlarmFilter {
  all('All'),
  active('Active'),
  acknowledged('Acknowledged'),
  resolved('Resolved'),
  critical('Critical'),
  warning('Warning');

  const _AlarmFilter(this.label);
  final String label;
}

enum _AlarmAction { acknowledge, resolve, reopen }
