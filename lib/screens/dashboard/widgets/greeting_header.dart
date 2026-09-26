import 'package:flutter/material.dart';

import '../utils/date_helpers.dart';

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
    if (now.hour < 12) return 'Selamat Pagi';
    if (now.hour < 15) return 'Selamat Siang';
    if (now.hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final primary = isDark ? Colors.white70 : Colors.black54;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary.withValues(alpha: 0.18),
            border: Border.all(color: primary.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/user_icon.png',
              fit: BoxFit.contain,
              color: primary,
              colorBlendMode: BlendMode.srcIn,
              semanticLabel: 'Profil pengguna',
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
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${dayNameFull(now.weekday)}, ${now.day} ${monthName(now.month)} ${now.year}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
