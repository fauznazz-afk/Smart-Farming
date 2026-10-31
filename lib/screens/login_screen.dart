import 'dart:async';

import 'package:flutter/material.dart';

import '../services/alarm_notification_service.dart';
import '../services/thingsboard_api.dart';
import 'dashboard/utils/app_motion.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';
import 'dashboard_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/liquid_glass.dart';

/// Flat dark green, with no gradient. Three identical stops so every call
/// site that paints this `LinearGradient` renders flat.
const _pageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0B1F14),
    Color(0xFF0B1F14),
    Color(0xFF0B1F14),
  ],
);

/// The one accent: flat, so the button reads as a single fill rather than a
/// second gradient on a page that has none.
const _buttonGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF00D97E), Color(0xFF00D97E)],
);

const _violet = Color(0xFF00D97E);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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

  /// **This class had no `dispose()` at all.**
  ///
  /// Both controllers are created here and handed to a `TextField`, which does
  /// not own them and does not dispose them. Each sign-in builds a fresh
  /// `LoginScreen` — `pushReplacement` after a successful login and
  /// `pushAndRemoveUntil(..., (_) => false)` on logout — so two
  /// `TextEditingController`s, each a `ChangeNotifier` holding an editable value
  /// and a selection, were abandoned per attempt.
  ///
  /// Small, and invisible, and the same shape as every other resource leak this
  /// file's siblings were audited for.
  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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
        // **The app's one transition, not a second one.** This screen had its
        // own `PageRouteBuilder` and every other push in the app was a
        // `MaterialPageRoute`, so the app had two different answers to "what
        // happens when I press this" — and the sign-in, the one transition the
        // user sees first, was the one that belonged to nobody else.
        Navigator.pushReplacement<void, void>(
          context,
          appPageRoute<void>(page: DashboardScreen(api: _api)),
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

  InputDecoration _fieldDecoration({
    required String label,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    const hairline = Color(0x1FFFFFFF);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppGlass.glassInkFaint),
      filled: true,
      fillColor: AppGlass.glassFill,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFF00D97E).withValues(alpha: 0.7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1F14),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: _pageGradient)),
          ),
          // Two soft glows. `IgnorePointer` so they never eat a tap.
          Positioned(
            top: -120,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _violet.withValues(alpha: 0.45),
                      _violet.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -110,
            child: IgnorePointer(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D97E).withValues(alpha: 0.22),
                      const Color(0xFF00D97E).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: const BrandLogo(size: 100, showName: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppGlass.glassFill,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppGlass.glassBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              'EnerGrow',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'PLTS & SMART FARMING MONITORING',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.6,
                                color: AppGlass.glassInkFaint,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sectionGap),
                          TextField(
                            controller: _usernameCtrl,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                            decoration: _fieldDecoration(
                              label: 'Username / Email',
                              // Same 48dp box the password field's default icon
                              // occupies: a 24dp glyph in a 12dp pad.
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Image.asset(
                                  'assets/user_icon.png',
                                  width: 24,
                                  height: 24,
                                  color: AppGlass.glassInkFaint,
                                  colorBlendMode: BlendMode.srcIn,
                                  semanticLabel: 'User',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted:
                                _loading ? null : (_) => _handleLogin(),
                            decoration: _fieldDecoration(
                              label: 'Password',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppGlass.glassInkFaint,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppGlass.glassInkFaint,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sectionGap),
                          if (_errorMsg != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                liveRegion: true,
                                child: AppBadge(
                                  color: statusBad,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMsg!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Pill button, gradient fill, glow shadow in the accent.
                          // The shadow is painted by the `DecoratedBox` behind
                          // the button rather than `elevation`, because Material
                          // maps elevation through `kElevationToShadow` and
                          // cannot carry a hue.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00D97E,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                  gradient: _buttonGradient,
                                ),
                                child: TextButton(
                                  onPressed: _loading ? null : _handleLogin,
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: AppPalette.onHue,
                                    disabledForegroundColor: AppPalette.onHue
                                        .withValues(alpha: 0.7),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF121212),
                                          ),
                                        )
                                      : const Text('Login'),
                                ),
                              ),
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
        ],
      ),
    );
  }
}
