import 'package:flutter/material.dart';

import '../services/alarm_history_service.dart';
import '../widgets/liquid_glass.dart';

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
        title: const Text('Clear Alarm History'),
        content: const Text(
          'Are you sure you want to remove all alarm records? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
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
    AlarmType.deviceOffline => Icons.cloud_off_outlined,
  };

  Color _colorForSeverity(AlarmSeverity severity, bool isDark) {
    if (severity == AlarmSeverity.critical) {
      return isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F);
    }
    return isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);
  }

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
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: AmbientBackground(
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
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No alarms recorded',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
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
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
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
        return LiquidGlassCard(
          isDark: isDark,
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
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
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(alarm.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          if (isExpanded && alarm.value != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Value: ${alarm.value!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
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
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusBadge(alarm, severityColor),
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

  Widget _statusBadge(AlarmRecord alarm, Color severityColor) {
    final label = alarm.resolved
        ? 'Resolved'
        : alarm.acknowledged
        ? 'Acknowledged'
        : alarm.severity == AlarmSeverity.critical
        ? 'Critical'
        : 'Warning';
    final color = alarm.resolved
        ? Colors.green
        : alarm.acknowledged
        ? Colors.blue
        : severityColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
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
