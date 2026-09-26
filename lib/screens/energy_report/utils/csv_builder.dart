import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/energy_report_service.dart';
import 'format_helpers.dart';

/// Builds a CSV string from energy buckets.
String buildEnergyCsv({
  required List<EnergyBucket> buckets,
  required DateTime selectedDate,
  required bool monthly,
}) {
  final rows = <List<String>>[
    ['Laporan Energi EnerGrow'],
    [
      'Periode',
      monthly ? formatMonthLabel(selectedDate) : formatDateLabel(selectedDate),
    ],
    ['Sumber', 'ThingsBoard PZEM time-series'],
    [
      'Metode',
      'Rata-rata daya per jam dikali durasi interval; interval tanpa data tidak diestimasi',
    ],
    [],
    [
      monthly ? 'Tanggal' : 'Jam',
      'Jumlah sampel',
      'Produksi PV (kWh)',
      'Pemakaian AC (kWh)',
    ],
    for (final bucket in buckets)
      [
        monthly ? formatDateLabel(bucket.hour) : formatHourLabel(bucket.hour),
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
  return '\uFEFF${rows.map((row) => row.map(escapeCsv).join(',')).join('\r\n')}\r\n';
}

/// Generates a filename for the energy report CSV.
String generateEnergyCsvFilename({
  required DateTime selectedDate,
  required bool monthly,
}) {
  return 'laporan_energi_${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}${monthly ? '' : '_${selectedDate.day.toString().padLeft(2, '0')}'}' 
      '.csv';
}

/// Shares the energy report as a CSV file.
Future<void> shareEnergyReport({
  required BuildContext context,
  required List<EnergyBucket> buckets,
  required DateTime selectedDate,
  required bool monthly,
  required ValueNotifier<bool> sharingNotifier,
}) async {
  if (sharingNotifier.value || buckets.isEmpty) return;
  sharingNotifier.value = true;
  try {
    final csv = buildEnergyCsv(
      buckets: buckets,
      selectedDate: selectedDate,
      monthly: monthly,
    );
    final filename = generateEnergyCsvFilename(
      selectedDate: selectedDate,
      monthly: monthly,
    );
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laporan gagal diekspor: $error')),
      );
    }
  } finally {
    if (context.mounted) sharingNotifier.value = false;
  }
}