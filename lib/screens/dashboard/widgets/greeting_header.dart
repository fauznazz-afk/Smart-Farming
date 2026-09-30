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
    required this.isDark,
  });

  final String displayName;
  final bool isDark;

  static String greetingFor(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 15) return 'Good afternoon';
    if (now.hour < 18) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // The avatar was tinted with `white70`/`black54`, which is the exact pair
    // `color_helpers.dart` replaced: it is what fails 4.5:1 as a glyph and reads
    // as a grey smudge at 28 px inside the circle. The glyph now takes the
    // measured ordinary text colour, the fill is the real track surface rather
    // than a translucent grey, and the ring is a divider at a usable alpha.
    final glyph = appPrimaryText(isDark);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppSurfaces.track(isDark),
            border: Border.all(color: appDivider(isDark: isDark, opacity: 0.28)),
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: appPrimaryText(isDark),
                ),
              ),
              Text(
                '${dayNameFull(now.weekday)}, ${now.day} ${monthName(now.month)} ${now.year}',
                style: TextStyle(
                  fontSize: 13,
                  color: faintColor(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
