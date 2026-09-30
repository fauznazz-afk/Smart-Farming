import './dashboard/utils/color_helpers.dart';
import 'package:flutter/material.dart';

import '../services/alarm_history_service.dart';
import '../theme/app_theme_of.dart';
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
    // One resolution, threaded everywhere. This screen has no
    // `AppThemeController` -- it is pushed without one -- so the appearance comes
    // from the context, and it has to be resolved *once* rather than per widget:
    // `Theme.of(context).brightness` is identical for the app's dark theme and
    // for Dracula, so a screen that asked for a `bool` per row would render
    // Dracula's page with the app's dark ramp. See `appThemeOf` for the rule and
    // the contract on `main.dart` that it depends on.
    final appTheme = appThemeOf(context);
    final isDark = appTheme.isDark;
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
        theme: appTheme,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _alarms.isEmpty
            ? _emptyState(isDark)
            : Column(
                children: [
                  _filterBar(isDark),
                  Expanded(child: _alarmList(appTheme)),
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

  /// Takes the [AppTheme] rather than a `bool` even though the only two things
  /// that need the *appearance* are [AppCard] and [AppBadge], because the text
  /// and status colours on this screen are the `bool` half of the split — see
  /// `faintColor` and `appPrimaryText` for why they are deliberately not keyed on
  /// [AppTheme]. The list and the status badge are handed the enum so each one
  /// takes `isDark` off it locally rather than taking two parameters that must
  /// agree.
  Widget _alarmList(AppTheme appTheme) {
    final isDark = appTheme.isDark;
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
        // **The ring is a status colour only while the condition is live.**
        // `_statusBadge` already gave up its green pill for a resolved row
        // because `statusOk` reads in the present tense, and leaving the ring on
        // `severityColor` is the same mistake one element to the left: a red
        // circle on a row that is a statement about the past, printed directly
        // above a live critical alarm whose ring is red *because* there is a
        // problem right now. One hue, two opposite jobs, one screen — which is
        // the defect the single-series chart rule exists to prevent.
        //
        // The counter-argument was real and it is the reason this is a two-part
        // change rather than a recolour. Recolouring alone *does* drop
        // information: nothing else on the row says how serious this was, and
        // `_statusBadge` deliberately prints the word "Resolved" in that slot
        // instead of "Critical"/"Warning", so on a resolved row the severity was
        // genuinely carried by the ring alone. It is now carried by a **word**
        // in that same slot instead (`Resolved · Critical`), which is a better
        // carrier than the hue was: it survives being read aloud, in a
        // screenshot, by someone who cannot resolve red, and greyscale. The
        // severity is also queryable independently through the Critical and
        // Warning filters, so nothing rests on the ring any more.
        //
        // The neutral is [appPrimaryText] — the app's own ordinary text colour,
        // already on this row and already measured against this card — at the
        // same 0.15/0.28 alphas the wash and border used, so the ring keeps its
        // shape and the row does not lose a badge. No hue was added, and
        // nothing here was given a colour that means "resolved"; the resolved
        // state is stated in words, exactly where it already was.
        final isResolved = alarm.resolved;
        final ringColor = isResolved
            ? appPrimaryText(isDark)
            : _colorForSeverity(alarm.severity, isDark);
        return AppCard(
          theme: appTheme,
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
                        color: ringColor.withValues(alpha: 0.15),
                        // The wash alone left the circle with no edge of its
                        // own; against the now-opaque card it read as a
                        // floating smudge rather than a badge.
                        border: Border.all(
                          color: ringColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        _iconForType(alarm.type),
                        size: 20,
                        color: ringColor,
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
                        _statusBadge(alarm, ringColor, appTheme),
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

  /// [appTheme] rather than a `bool` for [AppBadge]'s wash alpha, which is keyed
  /// on brightness only, and `isDark` is taken off it for the text colours here.
  Widget _statusBadge(AlarmRecord alarm, Color ringColor, AppTheme appTheme) {
    final isDark = appTheme.isDark;
    final severityLabel = alarm.severity == AlarmSeverity.critical
        ? 'Critical'
        : 'Warning';
    // The state word and the severity word are orthogonal facts about the
    // record, and this slot is the only place on the row that names either.
    // A live row can afford to show them one at a time because the ring beside
    // it is *severity*-coloured and is doing that job in the present tense. A
    // resolved row has no live ring to lean on — the ring is neutral, because a
    // past-tense row in a live-status colour is the defect this badge was
    // already fixed for — so both words are printed here instead. That is what
    // keeps "this was critical" on the row after the ring stops carrying it.
    final label = alarm.resolved
        ? 'Resolved · $severityLabel'
        : alarm.acknowledged
        ? 'Acknowledged'
        : severityLabel;
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
    // Nothing is lost. The words "Resolved" and the severity are still in the
    // same position, in ordinary text, and a word is a better carrier of this
    // than a hue anyway: the reader who cannot resolve the green could not have
    // read it before, and the same goes for the red ring this slot now also
    // covers.
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
    //
    // `ringColor` is the severity colour on this path, not the neutral: the
    // caller only substitutes the neutral for a resolved row, and this branch is
    // reached only when the row is not resolved.
    final color = alarm.acknowledged ? statusAlert(isDark) : ringColor;
    return AppBadge(
      theme: appTheme,
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
