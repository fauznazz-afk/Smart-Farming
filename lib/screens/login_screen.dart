import 'dart:async';

import 'package:flutter/material.dart';

import '../services/alarm_notification_service.dart';
import '../services/thingsboard_api.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';
import 'dashboard_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/liquid_glass.dart';

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
        Navigator.pushReplacement<void, void>(
          context,
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (context, animation, secondaryAnimation) =>
                DashboardScreen(
              api: _api,
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: const BrandLogo(size: 100, showName: false),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'EnerGrow',
                            textAlign: TextAlign.center,
                            style: AppType.headlineMd,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PLTS & Smart Farming Monitoring',
                          style: AppType.bodySm.copyWith(color: faintColor),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
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
                                        style: AppType.bodySm,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _loading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              foregroundColor: AppPalette.onHue,
                              textStyle: AppType.labelUppercase,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.all(AppRadius.pill),
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
