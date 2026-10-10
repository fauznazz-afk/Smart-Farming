import 'package:flutter/material.dart';

import '../../dashboard/utils/design_tokens.dart';
import '../utils/format_helpers.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.monthly,
    required this.selectedDate,
    required this.onMonthlyChanged,
    required this.onPickPeriod,
  });

  final bool monthly;
  final DateTime selectedDate;
  final ValueChanged<bool> onMonthlyChanged;
  final VoidCallback onPickPeriod;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Daily / Monthly. Material's own `SegmentedButton` is styled by the
        // app theme (`_segmentedTheme` in `main.dart`), which already gives it
        // the brief's chip pair: a solid fill with dark ink when selected, a
        // hairline on the card when not. Left to the theme rather than
        // restyled here, so the two segmented controls in the app cannot drift.
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Daily')),
            ButtonSegment(value: true, label: Text('Monthly')),
          ],
          selected: {monthly},
          onSelectionChanged: (value) {
            onMonthlyChanged(value.first);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        // The brief's `button-secondary`, standing directly on the page rather
        // than inside an `AppCard`. The card used to wrap it in a `surface`
        // fill with a stamped shadow, which is a second box around a button
        // whose whole point is that it is the *quieter* of the two actions on
        // this screen — the primary is the lime export at the bottom.
        //
        // Its fill is [AppSurfaces.page], which the brief specifies for
        // `button-secondary`: deeper than the card, so the hairline is the only
        // thing defining it. No shadow — secondary is the flat tier.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPickPeriod,
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            label: Text(
              monthly
                  ? formatMonthLabel(selectedDate)
                  : formatDateLabel(selectedDate),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppSurfaces.page,
              foregroundColor: AppSurfaces.onSurface,
              side: AppBorders.hairline,
              textStyle: AppType.buttonLabel,
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.all(AppRadius.card),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
