import 'dart:convert';
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/energy_report_service.dart';
import '../services/thingsboard_api.dart';
import '../widgets/liquid_glass.dart';

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
  bool _sharing = false;
  bool _requestInFlight = false;
  int? _touchedBucketIndex;
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
    setState(() {
      _selectedDate = selected;
      _touchedBucketIndex = null;
    });
    if (monthChanged) await _load();
  }

  List<EnergyBucket> _periodBuckets() {
    final buckets = _data?.buckets ?? const <EnergyBucket>[];
    if (!_monthly) {
      return buckets
          .where(
            (item) =>
                item.hour.year == _selectedDate.year &&
                item.hour.month == _selectedDate.month &&
                item.hour.day == _selectedDate.day,
          )
          .toList(growable: false);
    }
    final byDay = <DateTime, EnergyBucket>{};
    for (final item in buckets) {
      if (item.hour.year != _selectedDate.year ||
          item.hour.month != _selectedDate.month) {
        continue;
      }
      final day = DateTime(item.hour.year, item.hour.month, item.hour.day);
      final old = byDay[day];
      byDay[day] = EnergyBucket(
        hour: day,
        pvKwh: (old?.pvKwh ?? 0) + item.pvKwh,
        acKwh: (old?.acKwh ?? 0) + item.acKwh,
        sampleCount: (old?.sampleCount ?? 0) + item.sampleCount,
      );
    }
    return byDay.values.toList()..sort((a, b) => a.hour.compareTo(b.hour));
  }

  (double, double)? _previousPeriodTotals() {
    final source = _data?.buckets;
    if (source == null) return null;
    final previousStart = _monthly
        ? DateTime(_selectedDate.year, _selectedDate.month - 1, 1)
        : DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day - 1,
          );
    final previous = source.where(
      (item) => _monthly
          ? item.hour.year == previousStart.year &&
                item.hour.month == previousStart.month
          : item.hour.year == previousStart.year &&
                item.hour.month == previousStart.month &&
                item.hour.day == previousStart.day,
    );
    if (previous.isEmpty) return null;
    return (
      previous.fold<double>(0, (sum, item) => sum + item.pvKwh),
      previous.fold<double>(0, (sum, item) => sum + item.acKwh),
    );
  }

  Future<void> _shareReport(List<EnergyBucket> buckets) async {
    if (_sharing || buckets.isEmpty) return;
    setState(() => _sharing = true);
    try {
      final csv = _buildCsv(buckets);
      final filename =
          'laporan_energi_${_selectedDate.year}_${_selectedDate.month.toString().padLeft(2, '0')}${_monthly ? '' : '_${_selectedDate.day.toString().padLeft(2, '0')}'}'
          '.csv';
      await SharePlus.instance.share(
        ShareParams(
          title: 'Laporan energi EnerGrow',
          subject: 'Laporan energi EnerGrow',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csv)),
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [filename],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Laporan gagal diekspor: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _buildCsv(List<EnergyBucket> buckets) {
    final rows = <List<String>>[
      ['Laporan Energi EnerGrow'],
      [
        'Periode',
        _monthly ? _monthLabel(_selectedDate) : _dateLabel(_selectedDate),
      ],
      ['Sumber', 'ThingsBoard PZEM time-series'],
      [
        'Metode',
        'Rata-rata daya per jam dikali durasi interval; interval tanpa data tidak diestimasi',
      ],
      [],
      [
        _monthly ? 'Tanggal' : 'Jam',
        'Jumlah sampel',
        'Produksi PV (kWh)',
        'Pemakaian AC (kWh)',
      ],
      for (final bucket in buckets)
        [
          _monthly ? _dateLabel(bucket.hour) : _hourLabel(bucket.hour),
          '${bucket.sampleCount}',
          bucket.pvKwh.toStringAsFixed(2),
          bucket.acKwh.toStringAsFixed(2),
        ],
      [
        'TOTAL',
        '${buckets.fold<int>(0, (sum, item) => sum + item.sampleCount)}',
        buckets
            .fold<double>(0, (sum, item) => sum + item.pvKwh)
            .toStringAsFixed(2),
        buckets
            .fold<double>(0, (sum, item) => sum + item.acKwh)
            .toStringAsFixed(2),
      ],
    ];
    return '\uFEFF${rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n')}\r\n';
  }

  String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _hourLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:00';

  String _monthLabel(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.year}';

  static const _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _data;
    final buckets = _periodBuckets();
    final pvKwh = buckets.fold<double>(0, (sum, item) => sum + item.pvKwh);
    final acKwh = buckets.fold<double>(0, (sum, item) => sum + item.acKwh);
    final previousTotals = _previousPeriodTotals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan energi'),
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
            ? _errorView(isDark)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _periodSelector(isDark),
                    const SizedBox(height: 12),
                    if (buckets.isEmpty)
                      _emptyPeriod(data!, isDark)
                    else ...[
                      _totalsCard(
                        isDark,
                        pvKwh,
                        acKwh,
                        buckets,
                        previousTotals,
                      ),
                      const SizedBox(height: 12),
                      _chartCard(isDark, buckets),
                      const SizedBox(height: 12),
                      _dataNote(isDark, data!),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _sharing
                            ? null
                            : () => _shareReport(buckets),
                        icon: _sharing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_download_outlined),
                        label: Text(
                          _sharing ? 'Menyiapkan CSV…' : 'Ekspor laporan CSV',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _periodSelector(bool isDark) => Column(
    children: [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Harian')),
          ButtonSegment(value: true, label: Text('Bulanan')),
        ],
        selected: {_monthly},
        onSelectionChanged: (value) => setState(() {
          _monthly = value.first;
          _touchedBucketIndex = null;
        }),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _pickPeriod,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(
          _monthly ? _monthLabel(_selectedDate) : _dateLabel(_selectedDate),
        ),
      ),
    ],
  );

  Widget _totalsCard(
    bool isDark,
    double pvKwh,
    double acKwh,
    List<EnergyBucket> buckets,
    (double, double)? previousTotals,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthly
                ? 'Ringkasan ${_monthLabel(_selectedDate)}'
                : 'Ringkasan ${_dateLabel(_selectedDate)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _totalMetric(
                isDark,
                'Produksi PV',
                pvKwh,
                previousTotals?.$1,
                const Color(0xFFFFC857),
                Icons.wb_sunny_outlined,
              ),
              const SizedBox(width: 10),
              _totalMetric(
                isDark,
                'Pemakaian AC',
                acKwh,
                previousTotals?.$2,
                const Color(0xFF69B7FF),
                Icons.electrical_services_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${buckets.fold<int>(0, (sum, item) => sum + item.sampleCount)} sampel • ${buckets.length} ${_monthly ? 'hari' : 'jam'} dengan data',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _totalMetric(
    bool isDark,
    String label,
    double value,
    double? previous,
    Color color,
    IconData icon,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            '${value.toStringAsFixed(2)} kWh',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _comparisonLabel(value, previous),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    ),
  );

  String _comparisonLabel(double current, double? previous) {
    if (previous == null) return 'Belum ada data pembanding';
    if (previous <= 0) return 'Periode sebelumnya: 0 kWh';
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Sama dengan periode sebelumnya';
    return '${change > 0 ? '+' : ''}$change% dari periode sebelumnya';
  }

  Widget _chartCard(bool isDark, List<EnergyBucket> buckets) {
    final selectedIndex = (_touchedBucketIndex ?? 0)
        .clamp(0, buckets.length - 1)
        .toInt();
    final selectedBucket = buckets[selectedIndex];
    final chartWidth = (buckets.length * (_monthly ? 18 : 22)).toDouble();
    final maxValue = buckets.fold<double>(
      0,
      (max, item) => mathMax(max, mathMax(item.pvKwh, item.acKwh)),
    );
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.25;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Energi per interval',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _monthly
                          ? _dateLabel(selectedBucket.hour)
                          : _hourLabel(selectedBucket.hour),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _legendValue(
                    'PV',
                    selectedBucket.pvKwh,
                    const Color(0xFFFFC857),
                  ),
                  const SizedBox(width: 12),
                  _legendValue(
                    'AC',
                    selectedBucket.acKwh,
                    const Color(0xFF69B7FF),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth < 300 ? 300 : chartWidth,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      minY: 0,
                      barGroups: [
                        for (var i = 0; i < buckets.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 2,
                            barRods: [
                              BarChartRodData(
                                toY: buckets[i].pvKwh,
                                color: const Color(0xFFFFC857),
                                width: _monthly ? 6 : 8,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              BarChartRodData(
                                toY: buckets[i].acKwh,
                                color: const Color(0xFF69B7FF),
                                width: _monthly ? 6 : 8,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                      ],
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchExtraThreshold: const EdgeInsets.symmetric(
                          vertical: 44,
                          horizontal: 10,
                        ),
                        handleBuiltInTouches: false,
                        touchCallback: (_, response) {
                          final index = response?.spot?.touchedBarGroupIndex;
                          if (index != null &&
                              index >= 0 &&
                              index < buckets.length &&
                              index != _touchedBucketIndex) {
                            setState(() => _touchedBucketIndex = index);
                          }
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            interval: maxY / 4,
                            getTitlesWidget: (value, _) => Text(
                              value.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: _monthly ? 5 : 4,
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= buckets.length) {
                                return const SizedBox.shrink();
                              }
                              final date = buckets[index].hour;
                              final text = _monthly
                                  ? '${date.day}'
                                  : date.hour.toString().padLeft(2, '0');
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (buckets.length > 1)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Interval sebelumnya',
                    onPressed: selectedIndex == 0
                        ? null
                        : () => setState(
                            () => _touchedBucketIndex = selectedIndex - 1,
                          ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: (buckets.length - 1).toDouble(),
                      divisions: buckets.length - 1,
                      value: selectedIndex.toDouble(),
                      label: _monthly
                          ? _dateLabel(selectedBucket.hour)
                          : _hourLabel(selectedBucket.hour),
                      onChanged: (value) =>
                          setState(() => _touchedBucketIndex = value.round()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Interval berikutnya',
                    onPressed: selectedIndex >= buckets.length - 1
                        ? null
                        : () => setState(
                            () => _touchedBucketIndex = selectedIndex + 1,
                          ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend('PV', const Color(0xFFFFC857)),
                const SizedBox(width: 20),
                _legend('AC', const Color(0xFF69B7FF)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _legendValue(String label, double value, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        '$label ${value.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _dataNote(bool isDark, EnergyReportData data) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sumber & perhitungan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'ThingsBoard · PZEM · ${data.sampleCount} agregat daya per jam',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            'Energi per jam dihitung dari rata-rata Power DC/AC (W) yang tersimpan di time-series database. Data disegarkan otomatis setiap 5 menit.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyPeriod(EnergyReportData data, bool isDark) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Belum ada data untuk periode ini',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Data ThingsBoard mencakup ${_dateLabel(data.firstSample)} hingga ${_dateLabel(data.lastSample)}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ],
      ),
    ),
  );

  Widget _errorView(bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
          const SizedBox(height: 8),
          Text(
            'Pastikan perangkat PZEM mengirim telemetry dan akun ThingsBoard memiliki akses histori perangkat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    ),
  );
}

double mathMax(double a, double b) => a > b ? a : b;
