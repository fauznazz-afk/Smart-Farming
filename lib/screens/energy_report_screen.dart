import 'dart:async';

import 'package:flutter/material.dart';

import '../services/energy_report_service.dart';
import '../services/thingsboard_api.dart';
import '../widgets/liquid_glass.dart';
import 'dashboard/utils/design_tokens.dart';
import 'energy_report/utils/period_buckets.dart';
import 'energy_report/widgets/period_selector.dart';
import 'energy_report/widgets/totals_card.dart';
import 'energy_report/widgets/chart_card.dart';
import 'energy_report/widgets/data_note.dart';
import 'energy_report/widgets/empty_and_error_views.dart';
import 'energy_report/widgets/export_button.dart';

/// The single canonical representation of a selected period.
///
/// Time-of-day is always dropped, and monthly collapses to the 1st. These two
/// live in this file rather than in `energy_report/utils/period_buckets.dart`
/// only because of an agent-ownership boundary, not by preference: the
/// repository rule is that pure logic belongs in `utils/`, and this is pure
/// logic with no widget or I/O in it. If the next change touches
/// `period_buckets.dart` anyway, move these two there and re-export nothing —
/// they have exactly one caller and one test file.
///
/// The collapse matters because `_selectedDate` has three readers that all
/// format it — the period button label, the CSV `Period` row and the CSV
/// filename — and the monthly view aggregates the whole month, so a day-of-month
/// picked by accident is a value that carries no meaning and shows up in a
/// filename the user then shares.
DateTime canonicalPeriodDate(DateTime value, {required bool monthly}) => monthly
    ? DateTime(value.year, value.month)
    : DateTime(value.year, value.month, value.day);

/// Whether moving from [current] to [next] changes the window the service fetches.
///
/// [EnergyReportService.load] is month-scoped by construction: it reads from the
/// first of the previous month through the first of the next, in 28-day chunks.
/// That deliberate over-fetch is what lets `previousPeriodTotals` answer *both*
/// the preceding-day question (daily) and the preceding-month question (monthly)
/// from a single round of requests, so the "compared with the previous period"
/// wording stays true without a second fetch.
///
/// The consequence is that this predicate is month-scoped, and both directions
/// matter. A day change inside one month must **not** re-request — the buckets
/// are already resident and `bucketsForPeriod` filters them in memory, so a
/// reload would be a wasted ThingsBoard round trip for a purely client-side
/// result. A month change **must** re-request, because the resident buckets
/// cover a different window entirely and would otherwise show a stale month that
/// still renders confidently.
bool periodWindowChanged(DateTime current, DateTime next) =>
    current.year != next.year || current.month != next.month;

class EnergyReportScreen extends StatefulWidget {
  const EnergyReportScreen({super.key, required this.api});

  final ThingsBoardApi api;

  @override
  State<EnergyReportScreen> createState() => _EnergyReportScreenState();
}

class _EnergyReportScreenState extends State<EnergyReportScreen> {
  late final EnergyReportService _service = EnergyReportService(widget.api);
  Timer? _refreshTimer;
  EnergyReportData? _data;
  DateTime _selectedDate = DateTime.now();
  bool _monthly = false;
  bool _loading = true;
  final ValueNotifier<bool> _sharing = ValueNotifier<bool>(false);
  bool _requestInFlight = false;
  final ValueNotifier<int?> _touchedBucketNotifier = ValueNotifier<int?>(null);
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _touchedBucketNotifier.dispose();
    // `_sharing` is the third resource here and it was missing. It is a
    // `ValueNotifier`, so `ExportButton`'s `ValueListenableBuilder` registers
    // against it and `shareEnergyReport` is handed it by reference -- neither of
    // which makes the owner responsible for disposing it. Flutter disposes a
    // controller it created, never one it was given.
    _sharing.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await _service.load(referenceDate: _selectedDate);
      if (!mounted) return;
      _touchedBucketNotifier.value = null;
      setState(() {
        _data = data;
        _loading = false;
        _requestInFlight = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _requestInFlight = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = canonicalPeriodDate(_selectedDate, monthly: _monthly);
    final selected = await showDatePicker(
      context: context,
      // The 1st in monthly mode, so the grid opens on the first of the month the
      // label already names. Otherwise it opens on whatever day-of-month happens
      // to be in `_selectedDate`, which reads as though that day were the period.
      initialDate: current,
      firstDate: DateTime(2020),
      // Today, not tomorrow. `showDatePicker` builds its grid from the calendar
      // *day* of `lastDate`, so the old `now.add(one day)` made tomorrow a
      // selectable cell — and tomorrow has no telemetry by definition, so that
      // cell could only ever resolve to the empty view. Same guard the dashboard
      // applies with its own `lastDate: today`.
      lastDate: today,
      // The picker's chrome is localised from this, not from the strings passed
      // in. Without it the day headers and month names follow the *device*
      // locale, which put Indonesian text inside this otherwise entirely
      // English screen. The dashboard hit exactly this and pinned it at
      // `_pickDateFromCalendar`; this dialog was the one that was missed.
      locale: const Locale('en', 'US'),
      // Honest about the day grid in monthly mode. `showDatePicker` has no
      // month-only mode (`DatePickerMode.year` still lands on a day), and the
      // month is what the view aggregates, so the day cell is a no-op there —
      // saying so beats letting the user hunt for which cell "is" the month.
      helpText: _monthly
          ? 'Select any day in the report month'
          : 'Select the report date',
      cancelText: 'Cancel',
      confirmText: 'Apply',
    );
    if (selected == null || !mounted) return;
    final next = canonicalPeriodDate(selected, monthly: _monthly);
    // Re-picking the period already shown is not a change. Guarding here rather
    // than comparing the raw `DateTime`s matters because `_selectedDate` starts
    // life as `DateTime.now()` and so carries a time-of-day that `==` would
    // never match.
    if (next == current) return;
    final windowChanged = periodWindowChanged(current, next);
    _touchedBucketNotifier.value = null;
    setState(() {
      _selectedDate = next;
    });
    if (windowChanged) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final buckets = bucketsForPeriod(
      buckets: data?.buckets ?? const <EnergyBucket>[],
      selectedDate: _selectedDate,
      monthly: _monthly,
    );
    final totals = totalsOf(buckets);
    final previousTotals = previousPeriodTotals(
      buckets: data?.buckets ?? const <EnergyBucket>[],
      selectedDate: _selectedDate,
      monthly: _monthly,
    );

    return Scaffold(
      appBar: AppBar(
        // English, like the rest of the app. It said "Energi Analytics", which
        // was a half-translation left in from 1.3.1 -- the screen around it reads
        // "Summary", "Energy per interval", "samples", "hours with data", and
        // the app's own acceptance criteria ask for an entirely English UI.
        title: const Text('Energy Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: _requestInFlight ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ErrorView(error: _error!, onRetry: _load)
            : RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                strokeWidth: 2.5,
                displacement: 48,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    AppSpacing.xxl,
                  ),
                  // Lazily built, in the same order and with the same content
                  // as the `children:` list this replaced. The list is only
                  // five deep, so the win is not the count: it is that the
                  // BarChart — up to 31 groups of two rods, plus two axis
                  // title builders per rod — is not constructed on the
                  // loading, error and empty paths, and not re-laid-out when
                  // the report is already scrolled past it. It rebuilt on every
                  // setState, which is every 5-minute refresh plus every
                  // period change plus every bucket touch.
                  itemCount: buckets.isEmpty ? 2 : 6,
                  itemBuilder: (context, index) => switch (index) {
                    0 => PeriodSelector(
                      monthly: _monthly,
                      selectedDate: _selectedDate,
                      onMonthlyChanged: (value) {
                        _touchedBucketNotifier.value = null;
                        setState(() => _monthly = value);
                      },
                      onPickPeriod: _pickPeriod,
                    ),
                    1 => const SizedBox(height: AppSpacing.md),
                    2 =>
                      buckets.isEmpty
                          ? EmptyPeriodView(data: data!)
                          : TotalsCard(
                              monthly: _monthly,
                              selectedDate: _selectedDate,
                              pvKwh: totals.pvKwh,
                              acKwh: totals.acKwh,
                              buckets: buckets,
                              previousTotals: previousTotals,
                            ),
                    3 =>
                      buckets.isEmpty
                          ? const SizedBox.shrink()
                          : ChartCard(
                              monthly: _monthly,
                              buckets: buckets,
                              touchedBucketNotifier: _touchedBucketNotifier,
                            ),
                    4 =>
                      buckets.isEmpty
                          ? const SizedBox.shrink()
                          : DataNote(data: data!),
                    _ =>
                      buckets.isEmpty
                          ? const SizedBox.shrink()
                          : ExportButton(
                              buckets: buckets,
                              selectedDate: _selectedDate,
                              monthly: _monthly,
                              sharingNotifier: _sharing,
                            ),
                  },
                ),
              ),
      ),
    );
  }
}
