import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/alarm_bridge.dart';

/// Live status of the background alarm check, plus the two things that can stop
/// it working.
///
/// This exists because the failure mode is invisible by construction. A dropped
/// alarm looks exactly like "nothing to report", so every previous session spent
/// guessing whether a quiet phone meant a quiet greenhouse or a check that never
/// ran. Everything the module knows is read back here instead.
class BackgroundStatusSection extends StatefulWidget {
  const BackgroundStatusSection({super.key});

  @override
  State<BackgroundStatusSection> createState() => _BackgroundStatusSectionState();
}

class _BackgroundStatusSectionState extends State<BackgroundStatusSection> {
  AlarmBridgeStatus? _status;
  bool _loading = true;
  bool _checking = false;
  bool _exempt = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final status = await AlarmBridge.instance.status();
    final exempt = await AlarmBridge.instance.isExemptFromBatteryOptimisations();
    if (!mounted) return;
    setState(() {
      _status = status;
      _exempt = exempt;
      _loading = false;
      _error = AlarmBridge.instance.lastError;
    });
  }

  Future<void> _requestExemption() async {
    final opened = await AlarmBridge.instance.requestIgnoreBatteryOptimizations();
    if (!mounted) return;
    // The user decides on a system screen, so the answer is only known once they
    // come back. Re-read rather than assume either outcome.
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open the settings manually: Settings > Apps > EnerGrow',
          ),
        ),
      );
    }
    await _refresh();
  }

  Future<void> _checkNow() async {
    // Guarded in the UI as well as natively. The native side drops an overlapping
    // run, but that would leave the button looking broken, and a user who taps
    // repeatedly should not queue three authenticated checks either way.
    if (_checking) return;
    setState(() => _checking = true);
    await AlarmBridge.instance.checkNow();
    if (!mounted) return;
    // The check runs on a native thread, so give it a moment before reading the
    // result back rather than showing the previous run's outcome.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _checking = false);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final unsupported = AlarmBridge.instance.isUnavailable;

    // SettingsScreen already wraps every section in a SectionCard built from the
    // section descriptor, so this returns content only.
    if (unsupported) {
      return const Text(
        'This platform has no native background alarm module, so alarms are '
        'only reported while the app is open.',
      );
    }

    final scheduled = status?.scheduled ?? false;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            'Scheduled',
            _loading && status == null
                ? '…'
                : scheduled
                ? 'Every ${status!.intervalMinutes} min'
                : 'Not armed',
            ok: scheduled,
          ),
          _row(
            'Credentials stored',
            status?.hasCredentials == true ? 'Yes' : 'No',
            ok: status?.hasCredentials == true,
          ),
          _row(
            'Last check',
            _describeAge(status?.lastCheckAt),
            ok: status != null && status.lastCheckAt.millisecondsSinceEpoch > 0,
          ),
          _row(
            'Last outcome',
            status?.lastOutcome.isNotEmpty == true
                ? status!.lastOutcome
                : '—',
            ok: status?.lastOutcome == 'ok, no alarms',
            plain: true,
          ),
          _row(
            'Battery optimisation',
            _exempt ? 'Exempt' : 'Active',
            ok: _exempt,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 10),
          // A Wrap, not a Row. "Check now" and "Battery settings" side by side with
          // their icons are wider than the card on a narrow phone, and the second
          // button only appears when the app is NOT exempt — so the overflow only
          // shows up for exactly the user who has something to fix. A Row with
          // neither child flexible overflows by a few pixels and Flutter draws the
          // striped error box over the buttons. Wrapping lets the second button drop
          // to its own line instead, which also reads better next to the hint text.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _checking ? null : _checkNow,
                icon: _checking
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_checking ? 'Checking…' : 'Check now'),
              ),
              if (!_exempt)
                OutlinedButton.icon(
                  onPressed: _requestExemption,
                  icon: const Icon(Icons.battery_saver, size: 18),
                  label: const Text('Battery settings'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _exempt
                ? 'Android may still delay a check, but the app is not being '
                      'put to sleep.'
                : 'Without this, Android can put EnerGrow to sleep and stop '
                      'delivering the background check entirely.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
    );
  }

  Widget _row(
    String label,
    String value, {
    required bool ok,
    bool plain = false,
  }) {
    final color = ok
        ? const Color(0xFF35A968)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 150, plus a fixed 10 px gap before the value. "Battery optimisation"
          // is a couple of pixels wider than 150, so the label ran straight into
          // its value and the row read "Battery optimisationActive". Widening the
          // column alone would not have fixed it: the next label to exceed the
          // width would collide the same way. The gap is unconditional, so a
          // label that exactly fills its column still cannot touch the value.
          //
          // A label too long for the column wraps to a second line rather than
          // being clipped, which is why crossAxisAlignment is start.
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: plain ? null : color,
                fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A relative age, or a dash when no check has ever run.
  ///
  /// "Never" is itself a diagnosis here: it means the check has not executed at
  /// all since the configuration was pushed, which is the case that needs
  /// attention, as opposed to an old result that is merely stale.
  String _describeAge(DateTime? at) {
    if (at == null || at.millisecondsSinceEpoch == 0) return 'Never';
    final age = DateTime.now().difference(at);
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) return '${age.inHours} h ago';
    return '${age.inDays} d ago';
  }
}
