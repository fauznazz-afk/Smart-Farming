import '../../../widgets/liquid_glass.dart';
import '../utils/color_helpers.dart';
import 'package:flutter/material.dart';

import '../utils/date_helpers.dart';
import '../utils/design_tokens.dart';

/// Time-of-day greeting with the signed-in user's name and today's date.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.displayName,
  });

  final String displayName;

  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 15) return 'Good afternoon';
    if (now.hour < 18) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final glyph = appPrimaryText;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppSurfaces.track,
            border: Border.all(
              color: AppSurfaces.border,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/user_icon.png',
              fit: BoxFit.contain,
              color: glyph,
              colorBlendMode: BlendMode.srcIn,
              semanticLabel: 'User profile',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greetingFor(now)}${displayName.isNotEmpty ? ', $displayName!' : '!'}',
                style: AppType.numeralLg.copyWith(color: appPrimaryText),
              ),
              Text(
                '${dayNameFull(now.weekday)}, ${now.day} ${monthName(now.month)} ${now.year}',
                style: AppType.labelMicro.copyWith(color: faintColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}