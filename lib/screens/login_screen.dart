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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: const BrandLogo(size: 100, showName: false),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // `card-padding`, 16, not 24. The brief has one card inset and
                  // this was a second one.
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Not `const`: the ink is a brightness-aware getter.
                        //
                        // **Card ink, explicitly — and this was page ink.** This
                        // word is inside the `AppCard`, so the ink on it is the
                        // card's own token, not the page's.
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'EnerGrow',
                            textAlign: TextAlign.center,
                            // `headline-lg`, the brief's "uppercase card title"
                            // slot at 24/900. It was `headline-md`, which is the
                            // *sub*-headline — and this is the screen's defining
                            // line.
                            style: AppType.headlineLg.copyWith(
                              color: AppSurfaces.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'PLTS & Smart Farming Monitoring',
                          // The brief's metadata line: uppercase, wide-tracked,
                          // secondary ink. It was a lowercase 12px body line,
                          // which is the brief's slot for *paragraphs*, and this
                          // is a strapline.
                          style: AppType.labelUppercase.copyWith(
                            color: faintColor,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        TextField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                          decoration: InputDecoration(
                            labelText: 'Username / Email',
                            // Same 48dp box the password field's default icon
                            // occupies: a 24dp glyph in a 12dp pad. The username
                            // glyph used to be a 22dp asset in a 13dp pad, so
                            // the two fields' left icons sat at different sizes
                            // and offsets - visible as the user icon reading
                            // smaller and nudged right of the lock below it.
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Image.asset(
                                'assets/user_icon.png',
                                width: 24,
                                height: 24,
                                color: Theme.of(context).colorScheme.onSurface,
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
                          onSubmitted: _loading ? null : (_) => _handleLogin(),
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
                                    const Icon(Icons.error_outline, size: 16),
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
                        // The brief's `button-primary`, and the tinted lift is
                        // what makes it the one electric object on the page.
                        // Painted by the `DecoratedBox` behind the button rather
                        // than by `FilledButton`'s own `elevation`, because
                        // Material maps elevation through `kElevationToShadow`
                        // and cannot carry a hue. The shadow is the accent, so it
                        // reads as part of the fill rather than as a grey halo.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.all(AppRadius.card),
                            boxShadow: AppShadows.stampedIn(AppPalette.error),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed: _loading ? null : _handleLogin,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.error,
                                foregroundColor: AppPalette.onHue,
                                disabledBackgroundColor: AppPalette.error,
                                disabledForegroundColor: AppPalette.onHue,
                                textStyle: AppType.buttonLabel,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.all(AppRadius.card),
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
