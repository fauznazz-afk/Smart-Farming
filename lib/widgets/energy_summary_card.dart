import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/color_helpers.dart';
import '../utils/design_tokens.dart';
import '../utils/pressable.dart';

/// Dua kartu accent yang di atas AppCard.
///
/// PV → `categoryColor(MetricCategory.pv)` = accent (#FCE570)
/// AC → `categoryColor(MetricCategory.ac)` = secondary (#8E99F3)
///
/// Perubahan utama berbanding dengan [energy_summary_card.dart] lama:
/// `solarColor` dan `loadColor` sebelumnya didapat dari `metricGraphic(index: 0)`
/// dan `strongMetricColor(index: 1)` — keduanya menurun dari satu seed yang sama,
/// sehingga keduanya selalu **sama warna** (bug yang pernah disembunyikan dan
/// kembali dengan kategori terpisah). Sekarang dua warna berbeda karena masing-masing
/// kategori memiliki hue sendiri.
class EnergySummaryCard extends StatelessWidget {
  const EnergySummaryCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EnergyTile(
            label: 'PV production',
            value: categoryColor(MetricCategory.pv),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _EnergyTile(
            label: 'AC usage',
            value: categoryColor(MetricCategory.ac),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

/// Satu baris nilai + label, berwarna sesuai kategori.
class _EnergyTile extends StatelessWidget {
  const _EnergyTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final Color value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.95,
      builder: (pressed) => AnimatedContainer(
        duration: AppMotion.press,
        curve: AppMotion.enter,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppSurfaces.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.fromBorderSide(AppBorders.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppType.labelUppercase.copyWith(color: AppPalette.onHue),
            ),
            const SizedBox(height: 6),
            Text(
              value == AppPalette.accent
                  ? '12.4 W'
                  : value == AppPalette.secondary
                      ? '8.7 W'
                      : '—',
              style: AppType.numeralLg.copyWith(color: value),
            ),
          ],
        ),
      ),
    );
  }
}