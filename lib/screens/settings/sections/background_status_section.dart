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
          Row(
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
              const SizedBox(width: 10),
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
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
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
