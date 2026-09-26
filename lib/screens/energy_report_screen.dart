import 'dart:async';

import 'package:flutter/material.dart';

import '../services/energy_report_service.dart';
import '../services/thingsboard_api.dart';
import '../widgets/liquid_glass.dart';
import 'energy_report/utils/period_buckets.dart';
import 'energy_report/widgets/period_selector.dart';
import 'energy_report/widgets/totals_card.dart';
import 'energy_report/widgets/chart_card.dart';
import 'energy_report/widgets/data_note.dart';
import 'energy_report/widgets/empty_and_error_views.dart';
import 'energy_report/widgets/export_button.dart';

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
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: _monthly ? 'Pilih bulan laporan' : 'Pilih tanggal laporan',
    );
    if (selected == null) return;
    final monthChanged =
        selected.year != _selectedDate.year ||
        selected.month != _selectedDate.month;
    _touchedBucketNotifier.value = null;
    setState(() {
      _selectedDate = selected;
    });
    if (monthChanged) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        title: const Text('Energi Analytics'),
        actions: [
          IconButton(
            tooltip: 'Segarkan laporan',
            onPressed: _requestInFlight ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AmbientBackground(
        isDark: isDark,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ErrorView(isDark: isDark, error: _error!, onRetry: _load)
            : RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                strokeWidth: 2.5,
                displacement: 48,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    PeriodSelector(
                      monthly: _monthly,
                      selectedDate: _selectedDate,
                      onMonthlyChanged: (value) {
                        _touchedBucketNotifier.value = null;
                        setState(() => _monthly = value);
                      },
                      onPickPeriod: _pickPeriod,
                    ),
                    const SizedBox(height: 12),
                    if (buckets.isEmpty)
                      EmptyPeriodView(isDark: isDark, data: data!)
                    else ...[
                      TotalsCard(
                        isDark: isDark,
                        monthly: _monthly,
                        selectedDate: _selectedDate,
                        pvKwh: totals.pvKwh,
                        acKwh: totals.acKwh,
                        buckets: buckets,
                        previousTotals: previousTotals,
                      ),
                      const SizedBox(height: 12),
                      ChartCard(
                        isDark: isDark,
                        monthly: _monthly,
                        buckets: buckets,
                        touchedBucketNotifier: _touchedBucketNotifier,
                      ),
                      const SizedBox(height: 12),
                      DataNote(isDark: isDark, data: data!),
                      const SizedBox(height: 12),
                      ExportButton(
                        isDark: isDark,
                        sharing: _sharing.value,
                        buckets: buckets,
                        selectedDate: _selectedDate,
                        monthly: _monthly,
                        sharingNotifier: _sharing,
                        onShare: () {},
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
