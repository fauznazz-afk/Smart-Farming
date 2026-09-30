import 'dart:async';

import 'package:flutter/material.dart';

import '../services/alarm_notification_service.dart';
import '../services/thingsboard_api.dart';
import '../theme/app_theme_controller.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';
import 'dashboard_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/liquid_glass.dart';

class LoginScreen extends StatefulWidget {
  final AppThemeController themeController;

  const LoginScreen({super.key, required this.themeController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ThingsBoardApi();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMsg;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final success = await _api.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (!mounted) return;

      if (success) {
        // Arm the background check with the fresh token. Without this the
        // alarms would only start working after the next app launch, which is
        // exactly the case a user who just signed in would notice.
        unawaited(AlarmNotificationService.sync(api: _api));
        Navigator.pushReplacement<void, void>(
          context,
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (context, animation, secondaryAnimation) =>
                DashboardScreen(
              api: _api,
              themeController: widget.themeController,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.035),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          ),
        );
      } else {
        setState(() => _errorMsg = 'Wrong username or password');
      }
    } catch (_) {
      setState(() => _errorMsg = 'Could not connect. Try again later.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolved through the controller rather than from
    // `Theme.of(context).brightness`, because a `Brightness` cannot distinguish
    // Dracula from the app's dark mode — both are published as
    // `ThemeMode.dark`. `resolveAppTheme` is the same free function the token
    // layer and `main.dart` use, so there is one answer and not three.
    final theme = resolveAppTheme(
      widget.themeController.option,
      Theme.of(context).brightness,
    );
    final isDark = theme.isDark;
    // `Colors.red` measured 3.33:1 as the 13dp text it is used for here, which
    // is a fail, and the wash behind it was a fixed `red @ 0.12` with no
    // relationship to the theme. `statusBad` is the measured value, pinned by
    // `test/color_helpers_test.dart` against the real card surface.
    //
    // `isDark`, and that is measured rather than assumed: the app's dark status
    // palette clears AA across the whole Dracula ramp, worst case 5.17:1 on the
    // chrome step. See the note on `statusOk`.
    final errorColor = statusBad(isDark);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        theme: theme,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: const BrandLogo(size: 100, showName: false),
                  ),
                  const SizedBox(height: 12),
                  // Was the only call site that passed `performanceMode: false`
                  // — the only place the blur ever actually ran — and it also
                  // restated `borderRadius: 20` on top of the same default. Both
                  // go: the fill is opaque and there is no `BackdropFilter` left
                  // to run, and `AppCard` owns its radius.
                  AppCard(
                    theme: theme,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'EnerGrow',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PLTS & Smart Farming Monitoring',
                          style: TextStyle(
                            fontSize: 13,
                            // Was `onSurface @ 0.60`, an unmeasured alpha
                            // blend — the same shape as the `black54` literals
                            // this pass removed elsewhere.
                            color: faintColor(isDark),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _usernameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Username / Email',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Image.asset(
                                'assets/user_icon.png',
                                width: 22,
                                height: 22,
                                color: Theme.of(context).colorScheme.onSurface,
                                colorBlendMode: BlendMode.srcIn,
                                semanticLabel: 'User',
                              ),
                            ),
                            // No local `OutlineInputBorder`: the theme's
                            // `inputDecorationTheme` (main.dart:82) already
                            // supplies an outlined border at `AppRadius.inset`
                            // with a `0x22` divider edge. This override also
                            // only set `border`, so it *removed* the theme's
                            // `enabledBorder` and `focusedBorder` for the
                            // focused state.
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          onSubmitted:
                              _loading ? null : (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_errorMsg != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            // `liveRegion` because this is the only way a
                            // failed login is reported. The error text appears
                            // without any focus change and without a SnackBar,
                            // so a screen-reader user pressing Login heard
                            // nothing and had no way to know why the form did
                            // not advance.
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.all(AppRadius.badge),
                                  // 0.08, not the 0.12 it used to be. The
                                  // wash is the same colour as the text sitting
                                  // on it, so every point of alpha is a point
                                  // of contrast: 0.12 measured 4.23:1 and 0.08
                                  // measures 4.51:1, which is the line.
                                  color: errorColor.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: errorColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: errorColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMsg!,
                                        style: TextStyle(
                                          color: errorColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.all(AppRadius.tile),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
