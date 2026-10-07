import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/color_helpers.dart';
import 'package:plts_monitoring/screens/dashboard/utils/design_tokens.dart';
import 'package:plts_monitoring/theme/app_theme_controller.dart';

/// WCAG contrast ratio between two opaque colours.
double ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Skeuo is the one theme in the app that came from a brief rather than from a
/// measurement, and a near-black page is exactly the case where an assumption
/// about contrast is most likely to be wrong — every text colour is *further*
/// from its background than on any other page, which helps AA and makes a
/// mistake in the other direction easy to miss.
void main() {
  const skeuo = AppTheme.skeuo;

  group('skeuo is a dark theme on every axis', () {
    // Every `isDark` branch in the app decides caption and status colours from
    // this one boolean, so a theme that reported `false` would be drawing the
    // light text palette on a near-black page.
    test('isDark and brightness', () {
      expect(skeuo.isDark, isTrue);
      expect(skeuo.brightness, Brightness.dark);
    });

    test('it carries its own accent, so the Settings seed cannot override it', () {
      expect(skeuo.usesPresetAccent, isTrue);
      expect(presetAccent(skeuo), skeuoAccent);
      expect(presetAccent(skeuo), isNot(draculaAccent),
          reason: 'the predicate is shared with Dracula, so only the switch can '
              'keep the two presets apart');
    });

    test('every preset theme gets its own accent, and no other does', () {
      for (final theme in AppTheme.values) {
        final accent = presetAccent(theme);
        if (theme.usesPresetAccent) {
          expect(accent, isNotNull, reason: '${theme.name} is a preset');
        } else {
          expect(accent, isNull, reason: '${theme.name} uses the user seed');
        }
      }
    });
  });

  group('skeuo text clears AA on its own surfaces', () {
    final page = AppSurfaces.page(skeuo);
    final texts = <String, Color>{
      'faintColor': faintColor(true),
      'statusOk': statusOk(true),
      'statusWarn': statusWarn(true),
      'statusBad': statusBad(true),
      'statusAlert': statusAlert(true),
      'accent': skeuoAccent,
      'signal': skeuoSignal,
      'body': const Color(0xFFFFFFFF),
    };

    for (final entry in {
      'page': page,
      'card': AppSurfaces.card(skeuo),
      'chrome': AppSurfaces.chrome(skeuo),
      'input': AppSurfaces.input(skeuo),
      'tooltip': AppSurfaces.tooltip(skeuo),
    }.entries) {
      for (final text in texts.entries) {
        test('${text.key} on ${entry.key}', () {
          expect(
            ratio(entry.value, text.value),
            greaterThanOrEqualTo(4.5),
            reason: 'skeuo carries no measurement, so this is the first one',
          );
        });
      }
    }
  });

  test('the brief\'s own hex values are the ones that ship', () {
    // The brief's `background #0A0A0C` and `surface #38383C`. `surface` becomes
    // `chrome`, not the card: a card's fill is the page everywhere in this app,
    // and `design_tokens_test.dart` pins that.
    expect(AppSurfaces.page(skeuo), const Color(0xFF0A0A0C));
    expect(AppSurfaces.chrome(skeuo), const Color(0xFF38383C));
    expect(skeuoAccent, const Color(0xFFF59E0B));
    expect(skeuoSignal, const Color(0xFFC4F042));
    expect(AppSurfaces.card(skeuo), AppSurfaces.page(skeuo));
  });

  test('skeuo is distinguishable from every other theme by its page', () {
    // `appThemeOf` resolves a pushed screen by searching `AppTheme.values` for
    // one whose page equals the published `scaffoldBackgroundColor`. Two themes
    // sharing a page would make that search ambiguous and the wrong one would
    // win silently, which is the failure the search was written to avoid.
    final pages = <Color, List<String>>{};
    for (final theme in AppTheme.values) {
      pages.putIfAbsent(AppSurfaces.page(theme), () => []).add(theme.name);
    }
    for (final entry in pages.entries) {
      expect(entry.value, hasLength(1),
          reason: 'page ${entry.key} is shared by ${entry.value.join(" and ")}, '
              'so appThemeOf cannot tell them apart');
    }
  });

  test('the option round-trips through storage', () {
    expect(ThemeOption.fromStored('skeuo'), ThemeOption.skeuo);
    expect(ThemeOption.skeuo.stored, 'skeuo');
    expect(ThemeOption.skeuo.themeMode, ThemeMode.dark);
    expect(
      resolveAppTheme(ThemeOption.skeuo, Brightness.light),
      AppTheme.skeuo,
      reason: 'a preset must not depend on the system brightness',
    );
  });
}
