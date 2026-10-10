import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_keys.dart';
import '../models/telemetry_model.dart';
import '../services/alarm_bridge.dart';
import '../services/alarm_history_service.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_settings.dart';
import '../services/cctv_url.dart';
import '../services/connection_health_service.dart';
import '../services/energy_forecast_service.dart';
import '../services/thingsboard_api.dart';
import '../services/thingsboard_realtime_service.dart';
import '../utils/alarm_helpers.dart';
import '../utils/alarm_rules.dart';
import '../utils/app_log.dart';
import '../utils/poll_interval.dart';
import '../widgets/energy_summary_card.dart';
import '../widgets/liquid_glass.dart';
import 'alarm_history_screen.dart';
import 'cctv_screen.dart';
import 'dashboard/charts/chart_data.dart';
import 'dashboard/utils/bound.dart';
import 'dashboard/utils/chart_gesture_lock.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';
import 'dashboard/utils/energy_helpers.dart';
import 'dashboard/utils/history_range.dart';
import 'dashboard/utils/telemetry_helpers.dart';
import 'dashboard/widgets/banners.dart';
import 'dashboard/widgets/chart_carousel.dart';
import 'dashboard/widgets/chart_card.dart';
import 'dashboard/widgets/chart_groups.dart';
import 'dashboard/widgets/date_strip.dart';
import 'dashboard/widgets/power_sub_tabs.dart';
import 'dashboard/widgets/system_status_strip.dart';
import 'dashboard/widgets/metric_grid.dart';
import 'dashboard/widgets/metric_specs.dart';
import 'dashboard/widgets/greeting_header.dart';
import 'dashboard/widgets/live_power_card.dart';
import 'dashboard/widgets/nav_bar.dart';
import 'dashboard/widgets/telemetry_card.dart';
import 'energy_report_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Horizontal margin of a dashboard page: how far every card sits from the left
/// and right edge of the display.
///
/// It is a local constant and not a token in `design_tokens.dart` only because
/// the shadow arithmetic below is a property of `AppElevation.raised`, and that
/// file belongs to the surface work rather than to this screen. If the numbers
/// there change, this one has to be re-derived rather than nudged.
///
/// 16dp fitted the *contact* shadow and clipped the ambient half of the same
/// shadow against the screen edge. `AppElevation.raised` is a contact shadow at
/// offset 3 / blur 6 and an ambient one at offset 9 / blur 22, and Flutter paints
/// a box shadow as a mask blur of sigma = blurRadius / 2 translated by the
/// offset. So the ambient reaches:
///
///  * `9 + 11 = 20dp` at one sigma, still about 60% of its 0x40 peak — this is
///    the part that actually draws the edge, and 16dp cut it in half.
///  * `9 + 22 = 31dp` at two sigma, about 13% of peak, which is a couple of
///    levels of alpha over the page and cannot be seen.
///
/// 24dp shows the whole visible core with 4dp to spare and still clips only the
/// invisible tail. 32dp would show the tail too and costs 16dp of chart plot on a
/// 381dp-wide viewport, which is a bad trade for 3% alpha.
///
/// The cost is 16dp of width per side: on this device a card goes from 349dp to
/// 333dp, so every two-column metric cell loses 8dp. That is the one thing here
/// that cannot be checked without the device.
/// The dashboard's horizontal page margin, in logical pixels.
///
/// **Public so a test can read it rather than restate it.** Every page is a
/// `ListView` whose padding is this value on each side, so a card on screen is
/// `screenWidth - 2 * kDashboardPageMargin` dp wide. `test/widget_text_helpers.dart`
/// needs that number to measure a card at the width it really has, and a test
/// that copied the literal would be a copy — the failure mode `FEATURE.md`
/// records twice already, where a list of surface hex values in
/// `color_helpers_test.dart` drifted from the fills it claimed to measure and
/// three colours sat under AA with the suite green.
///
/// 16, not 24: the brief's `spacing.gutter`. It is also the carousel's bleed on
/// each side, which is why it is written as the token rather than as a second
/// number — one value, one meaning.
const double kDashboardPageMargin = AppSpacing.gutter;

/// The gap between two cards on the same page.
///
/// **A spacing value now, not a shadow-geometry one, and the number moved with
/// the design.** The gap used to be 20 because the *soft* ambient shadow needed
/// that much room to finish its falloff; with the brief's hard `4px 4px 0`
/// displacement there is no falloff to protect, only a 4px footprint that needs
/// to clear the card below it. 12 is the brief's `spacing.md` and leaves 8dp
/// between one card's shadow and the next card's top edge.
const double _cardGap = AppSpacing.md;

/// The gap above a chart section header, which is a different job from [\_cardGap].
///
/// Larger than the card gap because a header belongs to what follows it, and it
/// needs the previous card's shadow to have finished before the label lands. It
/// also carries more text than a card boundary does, so a bare 20dp made the
/// header look attached to the card above it.
const double _chartHeaderGap = 28;

/// The gap between the floating nav bar's top edge and the last card.
///
/// **This is the fix for the overlap, and the `76` it replaced was not a
/// smaller version of the same number — it was an unrelated one.** The bar is
/// the Scaffold's `bottomNavigationBar` with `extendBody: true`, so it is drawn
/// *over* the page and the scrolling content has to reserve the space itself.
/// The reserve was `MediaQuery.paddingOf(context).bottom + 76`, and the `76`
/// was written when the bar was full-width; nothing tied it to the 52 the bar
/// draws, so on the device the last line of the Energy analytics card sat under
/// the pill with no way to scroll clear of it.
///
/// The reservation is now `glassNavBarReservedHeight(context)` — the bar's own
/// height plus its own safe-area floor, from `nav_bar.dart` — and this gap on
/// top of it.
///
/// **20 rather than something smaller, for the same reason [\_cardGap] is 20.**
/// The nav bar carries the same `AppElevation.raised` pair as every card, so its
/// ambient half reaches 20dp at 1 sigma. A gap below that lets the bar's shadow
/// land on the last card, which is the same "there is something wrong here" look
/// a clipped card shadow produces — so the content would be *uncovered* and still
/// read as covered.
///
/// The `MediaQuery` is read from the State's context, which is above the
/// `Scaffold`, and that matters: with `extendBody: true` the `Scaffold` republishes
/// `padding.bottom` inside the body as the bar's height, so reading it from below
/// would count the bar twice.
const double _navBarClearance = 20;

/// Main monitoring dashboard: overview, PV, AC, battery, and CCTV tabs.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api});

  final ThingsBoardApi api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // ── Navigation & lifecycle ───────────────────────────────────────────────────
  final _pageController = PageController();
  final ValueNotifier<int> _selectedPage = ValueNotifier(0);
  final ValueNotifier<bool> _navCollapsed = ValueNotifier(false);
  final ValueNotifier<double> _appBarBlurProgress = ValueNotifier(0);
  double _downScrollDistance = 0;
  int _selectedIndex = 0;

  /// Which of PV / AC / Battery the Power tab is showing.
  ///
  /// A notifier rather than plain state so that selecting a sub-view rebuilds only
  /// the Power page. See `_powerPage` for the measurement that motivated it.
  final ValueNotifier<int> _powerSubNotifier = ValueNotifier(0);

  // ── Telemetry ────────────────────────────────────────────────────────────────
  DeviceTelemetry? _battery;
  DeviceTelemetry? _pzem;
  DeviceTelemetry? _sensor;
  DeviceTelemetry? _fish;
  bool _loading = true;
  bool _telemetryRequestInFlight = false;

  /// Completed when the in-flight `_fetchAll` finishes.
  ///
  /// The bool above answers "is one running?" and this answers "when does the
  /// running one end?", which is what a deliberate user gesture needs. Without it
  /// pull-to-refresh could only either skip the fetch or fire a second one
  /// concurrently, and the first of those is a lie told to the user's finger.
  Completer<void>? _telemetryInFlight;
  String? _error;
  bool _isOfflineMode = false;
  DateTime? _cachedTelemetryTime;
  DateTime? _lastSuccessfulTelemetryAt;
  bool _realtimeConnected = false;
  late final ThingsBoardRealtimeService _realtimeService =
      ThingsBoardRealtimeService(
        api: widget.api,
        onTelemetry: _handleRealtimeTelemetry,
        onConnectionChanged: _handleRealtimeConnection,
      );

  // ── History & charts ─────────────────────────────────────────────────────────
  final Map<String, List<TelemetryPoint>> _history = {};
  final Map<String, List<FlSpot>> _chartSpots = {};
  final Map<String, SeriesStats?> _chartStats = {};
  final Map<String, ChartBounds> _chartBounds = {};
  bool _chartLoading = true;
  final _historyRequestInFlight = <String>{};

  /// Per-prefix counterpart to [_telemetryInFlight].
  final _historyInFlight = <String, Completer<void>>{};

  /// Prefixes whose last history request ended in an exception.
  ///
  /// The chart needs this to tell a failed request apart from a quiet day.
  /// _fetchHistoryFor catches every error and substitutes an empty map, so
  /// without a separate record both arrive as the same empty list and the user is
  /// told the greenhouse produced nothing.
  final _historyLoadFailed = <String>{};

  /// Bumped when a history request starts or finishes, so the chart header can
  /// show that it is updating. The set itself changing is not observable.
  final ValueNotifier<int> _historyBusyNotifier = ValueNotifier(0);
  final _historyRequestDate = <String, String>{};
  final _historyPendingRefresh = <String>{};
  final _historyLoaded = <String>{};

  // ── Date selection ───────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedRangeStart;
  DateTime? _selectedRangeEnd;

  // ── Energy summary ───────────────────────────────────────────────────────────
  final Map<String, List<TelemetryPoint>> _energyHistory = {};
  bool _energyLoading = true;
  bool _energyRequestInFlight = false;

  /// Completed when the in-flight energy fetch finishes. See [_telemetryInFlight].
  ///
  /// This one was missing while its two siblings had it, and the consequence
  /// was that pull-to-refresh on Overview did nothing at all: Overview is
  /// _selectedIndex == 0, where _prefixForPage(0) is null, so the energy fetch
  /// is the only thing the gesture has to do -- and it returned at the guard above
  /// while the spinner still dismissed. The card's numbers then stayed up to
  /// fifteen minutes old with nothing saying so.
  Completer<void>? _energyInFlight;
  String? _energyError;
  bool _weeklyEnergySummary = false;
  DateTime? _energyUpdatedAt;
  double _solarKwh = 0;
  double _previousSolarKwh = 0;
  double _loadKwh = 0;
  double _previousLoadKwh = 0;
  double? _dailyProductionTargetKwh;
  static const _energyForecastService = EnergyForecastService();

  // ── Refresh & preferences ────────────────────────────────────────────────────
  bool _autoRefresh = true;
  int _refreshSeconds = 10;
  Timer? _refreshTimer;
  final _connectionHealth = ConnectionHealthService();
  late final Listenable _connectionChromeListenable = Listenable.merge([
    _liveRevision,
    _connectionHealth,
  ]);

  // ── Alerts ───────────────────────────────────────────────────────────────────
  final _alarmHistoryService = AlarmHistoryService();
  final ValueNotifier<List<String>> _alertMessages = ValueNotifier(const []);

  /// Alarms currently raised, and the subset of them already reported.
  ///
  /// Seeded from the native alarm module so an alarm the background check
  /// already notified about is not notified about again here, and published
  /// back to it so the reverse also holds.
  Set<String> _activeAlertIds = {};

  /// Thresholds for every alert rule, resolved from settings in one place.
  ///
  /// Replaces eight separate fields whose defaults were previously repeated in
  /// the settings controller, the dashboard and the background service, which is
  /// how the same setting came to default to different values in different
  /// readers.
  AlarmThresholds _thresholds = AlarmThresholds.defaults;

  /// The rule list, rebuilt only when the thresholds change.
  ///
  /// This was a getter, so every read rebuilt the whole list from scratch —
  /// roughly fifteen `AlarmRule` objects plus nine short-lived helper instances.
  /// `_evaluateEnergyAlerts` reads it on every telemetry frame the socket
  /// delivers, and does so *before* its own `if (!changed) return` bail-out, so
  /// the common case of nothing having changed still paid for a fresh rule list.
  /// The thresholds only move in `_setThresholds`, which is the only writer.
  late List<AlarmRule> _alarmRules = buildAlarmRules(_thresholds);

  void _setThresholds(AlarmThresholds value) {
    if (identical(value, _thresholds)) return;
    _thresholds = value;
    _alarmRules = buildAlarmRules(value);
  }

  int get _staleTelemetryMinutes => _thresholds.staleMinutes;

  // ── Misc ─────────────────────────────────────────────────────────────────────
  String _displayName = '';
  String _cctvUrl = defaultAllowedCctvUrl;
  String _cctvUrlFish = defaultAllowedFishCctvUrl;
  final ValueNotifier<int> _cctvKeepAlive = ValueNotifier(0);
  final ValueNotifier<int> _liveRevision = ValueNotifier(0);
  // One counter per ThingsBoard device, for the cards that read exactly one
  // device each.
  //
  // `_liveRevision` has to stay wide: the status strip, both banners and the hero
  // card read state spread across all four devices, so any change has to reach
  // them. But the PV/AC/Battery cards and the two `MetricGrid`s read one device
  // and nothing else, and the socket delivers frames two or three times a second,
  // so a frame from the BMS was rebuilding a greenhouse card that could not have
  // drawn anything different. Each counter below is bumped only when its own
  // device's values differ, by the same `sameTelemetry` test the wide path
  // already uses, so a device that publishes unchanged values now costs nothing.
  //
  // Safe to be narrower because each consumer's builder reads only the device
  // named here; the theme, seed colour, performance mode and alarm thresholds it
  // also reads are already part of `_visualToken`, which rebuilds it on change.
  final ValueNotifier<int> _batteryRevision = ValueNotifier(0);
  final ValueNotifier<int> _pzemRevision = ValueNotifier(0);
  final ValueNotifier<int> _sensorRevision = ValueNotifier(0);
  final ValueNotifier<int> _fishRevision = ValueNotifier(0);
  final ValueNotifier<int> _energyRevision = ValueNotifier(0);
  final ValueNotifier<int> _chartRevision = ValueNotifier(0);
  final ValueNotifier<bool> _chartPointerActiveNotifier = ValueNotifier(false);

  // The Performance setting used to be threaded through every card here and was
  // part of `_visualToken`. It gated a `BackdropFilter` that no longer exists:
  // surfaces are opaque, so a card has nothing to frost. The preference key and
  // the controller field are still there, because the Appearance section still
  // offers the switch and a stored value should not be silently discarded; the
  // switch itself is being relabelled to match what it now does, which is
  // nothing on this screen.
  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAll();
    unawaited(_realtimeService.start());
    _fetchEnergyHistory();
    _loadPreferences();
    _loadDisplayName();
    // The screen is already on screen at this point, so the background check
    // has to stand down before its next tick rather than at the first resume
    // callback, which may not arrive for a while.
    unawaited(AlarmBridge.instance.setForeground(true));
    // If the app was launched by tapping an alarm notification, navigate to the
    // alarm history screen so the user can see what fired.
    unawaited(_checkLaunchAlarm());
  }

  Future<void> _checkLaunchAlarm() async {
    final alarmId = await AlarmBridge.instance.launchAlarmId();
    if (alarmId != null && mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AlarmHistoryScreen()));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _selectedPage.dispose();
    _powerSubNotifier.dispose();
    _historyBusyNotifier.dispose();
    _navCollapsed.dispose();
    _appBarBlurProgress.dispose();
    _chartPointerActiveNotifier.dispose();
    _liveRevision.dispose();
    _batteryRevision.dispose();
    _pzemRevision.dispose();
    _sensorRevision.dispose();
    _fishRevision.dispose();
    _energyRevision.dispose();
    _chartRevision.dispose();
    _alertMessages.dispose();
    _cctvKeepAlive.dispose();
    _refreshTimer?.cancel();
    // Nothing is evaluating alarms once this screen is gone, so the background
    // check has to be allowed to run again.
    unawaited(AlarmBridge.instance.setForeground(false));
    unawaited(_realtimeService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartRefreshTimer();
      // Tells the background check to stand down: the dashboard polls every ten
      // seconds and evaluates the same rules, so a background tick on top of that
      // is duplicate work against the same ThingsBoard instance.
      unawaited(AlarmBridge.instance.setForeground(true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
      unawaited(AlarmBridge.instance.setForeground(false));
    }
  }

  // ── Scroll-driven chrome ─────────────────────────────────────────────────────
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        _downScrollDistance = 0;
      } else if (notification.direction == ScrollDirection.forward) {
        _downScrollDistance = 0;
        _navCollapsed.value = false;
      } else if (notification.metrics.pixels <= 0) {
        _downScrollDistance = 0;
        _navCollapsed.value = false;
      }
    } else if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != null &&
        notification.scrollDelta! > 0) {
      _downScrollDistance += notification.scrollDelta!;
      if (_downScrollDistance >= 12 && !_navCollapsed.value) {
        _navCollapsed.value = true;
      }
    }
    final progress = ((notification.metrics.pixels - 4) / 44)
        .clamp(0.0, 1.0)
        .toDouble();
    if (progress == 0.0 || progress == 1.0) {
      if (_appBarBlurProgress.value != progress) {
        _appBarBlurProgress.value = progress;
      }
    } else if ((progress - _appBarBlurProgress.value).abs() >= 0.015) {
      _appBarBlurProgress.value = progress;
    }
    return false;
  }

  // ── Preferences ──────────────────────────────────────────────────────────────
  Future<void> _loadDisplayName() async {
    final name = await widget.api.fetchDisplayName();
    if (mounted) setState(() => _displayName = name);
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final cctvUrl = await loadCctvUrl();
    if (!mounted) return;
    final fishCctvUrl = await loadFishCctvUrl();
    if (!mounted) return;
    final thresholds = readAlarmThresholds(preferences);
    setState(() {
      _autoRefresh = preferences.getBool(SettingsKeys.autoRefresh) ?? true;
      _refreshSeconds = preferences.getInt(SettingsKeys.refreshSeconds) ?? 10;
      _setThresholds(thresholds);
      _dailyProductionTargetKwh = _readDouble(
        preferences,
        SettingsKeys.dailyProductionTargetKwh,
      );
      _cctvUrl = cctvUrl;
      _cctvUrlFish = fishCctvUrl;
    });
    _restartRefreshTimer();
    // Must precede the first evaluation, otherwise every alarm looks new to a
    // fresh process and gets announced again on top of the background's.
    await _primeActiveAlerts();
    if (!mounted) return;
    _evaluateEnergyAlerts();
    // The background check evaluates the same rules, so it has to be told when
    // the thresholds change. A threshold raised above the current SOC would
    // otherwise keep notifying from the background for up to a quarter of an
    // hour after the user turned it off.
    unawaited(AlarmNotificationService.sync(api: widget.api));
  }

  static double? _readDouble(SharedPreferences preferences, String key) =>
      double.tryParse(preferences.getString(key) ?? '');

  void _restartRefreshTimer() {
    _refreshTimer?.cancel();
    if (!_autoRefresh) {
      _connectionHealth.markDisconnected(ConnectionTransport.polling);
      return;
    }
    _connectionHealth.markConnected(ConnectionTransport.polling);
    // **The interval depends on whether the WebSocket is carrying telemetry.**
    //
    // It did not, and the line was plainly `Duration(seconds: _refreshSeconds)`.
    // The WebSocket pushes every value into these slots the moment it arrives --
    // see `_handleRealtimeTelemetry` -- so a 10 s REST re-read is fetching values
    // the screen already has, and does it for three devices for as long as the
    // app stays open.
    //
    // The floor is 60 s and the poll still runs, because the socket sends no
    // ping and a dead-but-open connection is only noticed by a re-read. The
    // reasoning and the arithmetic are in `utils/poll_interval.dart`.
    final interval = effectivePollIntervalSeconds(
      requestedSeconds: _refreshSeconds,
      realtimeConnected: _realtimeConnected,
    );
    _refreshTimer = Timer.periodic(Duration(seconds: interval), (_) async {
      final started = DateTime.now();
      await _fetchAll();
      if (_error == null) {
        _connectionHealth.markSuccess(
          ConnectionTransport.polling,
          latency: DateTime.now().difference(started),
        );
      } else {
        _connectionHealth.markError(
          ConnectionTransport.polling,
          degraded: true,
        );
      }
    });
  }

  // ── Telemetry fetching ───────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    if (_telemetryRequestInFlight) return;
    _telemetryRequestInFlight = true;
    final flight = Completer<void>();
    _telemetryInFlight = flight;
    final started = DateTime.now();
    // No `markConnecting(ConnectionTransport.rest)` here, deliberately.
    //
    // It fired a real `notifyListeners()` on every single poll, because
    // `connecting != connected` and the following `markSuccess` produced no
    // notification of its own: the status went to `connected` and stayed there.
    // The strip rebuilds its banner switcher to draw that, and none of its four
    // branches render a connecting state. Nothing else reads the status either —
    // `statusMessage` only reaches the screen through a banner that is showing a
    // fetch failure or a stale device, and both of those override the label; the
    // in-flight state is `_telemetryRequestInFlight` above, not this.
    try {
      final results = await Future.wait([
        widget.api.fetchBatteryData(),
        widget.api.fetchPzemData(),
        widget.api.fetchSensorData(),
        widget.api.fetchFishData(),
      ]);
      if (!mounted) return;
      final now = DateTime.now();
      final wasLoading = _loading;
      // Per device rather than one `changed`, because each card is now rebuilt by
      // the counter for the device it reads. A tick that moved the BMS and
      // nothing else must not announce itself to the greenhouse grid.
      final batteryChanged = !sameTelemetry(_battery, results[0]);
      final pzemChanged = !sameTelemetry(_pzem, results[1]);
      final sensorChanged = !sameTelemetry(_sensor, results[2]);
      final fishChanged = !sameTelemetry(_fish, results[3]);
      final changed =
          _loading ||
          _error != null ||
          batteryChanged ||
          pzemChanged ||
          sensorChanged ||
          fishChanged;
      final timestampChanged =
          _lastSuccessfulTelemetryAt == null ||
          now.difference(_lastSuccessfulTelemetryAt!).inMinutes >= 1;
      _battery = results[0];
      _pzem = results[1];
      _sensor = results[2];
      _fish = results[3];
      // One merged cache write for the whole tick, and not awaited.
      //
      // This used to happen per device inside each fetch, so one poll meant four
      // concurrent read-modify-write cycles against the same key: each read the
      // same snapshot and each wrote only its own device, so three of the four
      // buckets were discarded by whichever write landed last. Measured on the
      // test device at 32-77 ms per write, all of it on the poll's critical path
      // because `Future.wait` could not complete until the slowest write finished.
      //
      // Fire-and-forget because it is a best-effort offline fallback: the values
      // are already in memory and on screen, and nothing should wait on storage.
      unawaited(
        widget.api.cacheTelemetrySnapshot({
          ThingsBoardApi.deviceBattery: results[0],
          ThingsBoardApi.devicePzem: results[1],
          ThingsBoardApi.deviceSensor: results[2],
          ThingsBoardApi.deviceFish: results[3],
        }),
      );
      _lastSuccessfulTelemetryAt = now;
      _loading = false;
      _error = null;
      _isOfflineMode = false;
      _connectionHealth.markSuccess(
        ConnectionTransport.rest,
        latency: DateTime.now().difference(started),
        updatedAt: now,
      );
      _notifyLive(wasLoading: wasLoading, changed: changed || timestampChanged);
      _notifyDeviceRevisions(
        battery: batteryChanged,
        pzem: pzemChanged,
        sensor: sensorChanged,
        fish: fishChanged,
        // Once a minute, whichever device moved.
        //
        // `MetricGrid` decides its own "Stale data" tag at build time, from
        // `DateTime.now()` against that device's `lastUpdate`, so a grid that is
        // never rebuilt goes on claiming freshness for a sensor that has died.
        // The wide counter used to hide that by rebuilding it several times a
        // second as a side effect; a per-minute bump to four small widgets does
        // the same job without the cost.
        all: timestampChanged,
      );
      // **The alarm set is recomputed here, which is *after* every notifier bump
      // above.** `_evaluateEnergyAlerts` writes `_activeAlertIds`, and
      // `SystemStatusStrip` reads its length inside a `Bound` whose token is
      // `_liveRevision` -- so the bump on the previous line rebuilt the strip with
      // the *previous* set. The count could then lag by up to a minute, until the
      // next telemetry difference or the once-a-minute `timestampChanged` bump.
      //
      // So: recompute first, then bump. Order matters and this is the only place
      // it is visible.
      final alertsBefore = _activeAlertIds.length;
      _evaluateEnergyAlerts();
      if (_activeAlertIds.length != alertsBefore) {
        // `_liveRevision` directly rather than `_notifyLive`, which returns early
        // when `changed` is false and so could not express "nothing about the
        // telemetry moved, but the alarm set did".
        if (mounted) _liveRevision.value++;
      }
      final lastEnergyUpdate = _energyUpdatedAt;
      if (lastEnergyUpdate == null ||
          DateTime.now().difference(lastEnergyUpdate).inMinutes >= 15) {
        unawaited(_fetchEnergyHistory());
      }
    } catch (error) {
      _connectionHealth.markError(ConnectionTransport.rest, degraded: true);
      if (!mounted) return;
      if (error.toString().contains('Token expired')) {
        // Same as an explicit logout: the session is over, so the background
        // check has to stop too.
        unawaited(AlarmNotificationService.disable());
        await widget.api.logout();
        if (!mounted) return;
        _goToLogin();
        return;
      }
      await _applyOfflineFallback();
      final message = error.toString();
      if (_error != message || _loading) {
        final wasLoading = _loading;
        _error = message;
        _loading = false;
        _notifyLive(
          wasLoading: wasLoading,
          changed: wasLoading || _battery == null,
        );
      }
    } finally {
      _telemetryRequestInFlight = false;
      _telemetryInFlight = null;
      if (!flight.isCompleted) flight.complete();
    }
  }

  /// Rebuilds either via setState (first paint) or via a cheap notifier bump.
  void _notifyLive({required bool wasLoading, required bool changed}) {
    if (!changed) return;
    if (wasLoading) {
      if (mounted) setState(() {});
    } else {
      _liveRevision.value++;
    }
  }

  /// Announces a telemetry change to the one card per device that reads it.
  ///
  /// Each flag is the result of `sameTelemetry` for that device alone, so a card
  /// is only ever rebuilt for a difference it could actually draw. [all] bumps
  /// all four at once, for the once-a-minute refresh described at the call site.
  ///
  /// Called on the first paint as well, where `_notifyLive` only calls
  /// `setState`. That is not redundant: `Bound` caches its child, and its
  /// `didUpdateWidget` does not re-run the builder when the listenable and the
  /// token are both unchanged, so a plain `setState` leaves any `Bound` that was
  /// built before the data arrived still showing no data.
  void _notifyDeviceRevisions({
    bool battery = false,
    bool pzem = false,
    bool sensor = false,
    bool fish = false,
    bool all = false,
  }) {
    if (all || battery) _batteryRevision.value++;
    if (all || pzem) _pzemRevision.value++;
    if (all || sensor) _sensorRevision.value++;
    if (all || fish) _fishRevision.value++;
  }

  /// Falls back to cached telemetry when every live device fetch failed.
  Future<void> _applyOfflineFallback() async {
    if (_battery != null || _pzem != null || _sensor != null) {
      _isOfflineMode = true;
      return;
    }
    final cached = await widget.api.loadCachedTelemetry();
    final cacheTime = await widget.api.getCachedTelemetryTime();
    if (cached == null || !mounted) return;
    final split = splitCachedTelemetry(cached.latestValues);
    _isOfflineMode = true;
    _cachedTelemetryTime = cacheTime;
    _battery = DeviceTelemetry(
      latestValues: split.battery,
      lastUpdate: cached.lastUpdate,
    );
    _pzem = DeviceTelemetry(
      latestValues: split.pzem,
      lastUpdate: cached.lastUpdate,
    );
    _sensor = DeviceTelemetry(
      latestValues: split.sensor,
      lastUpdate: cached.lastUpdate,
    );
    _fish = DeviceTelemetry(
      latestValues: split.fish,
      lastUpdate: cached.lastUpdate,
    );
    // The four slots were just filled from cache where they were null, so each
    // card needs its rebuild. `_fetchAll` may only `setState` on this path.
    _notifyDeviceRevisions(all: true);
  }

  void _handleRealtimeConnection(bool connected) {
    if (!mounted || _realtimeConnected == connected) return;
    setState(() => _realtimeConnected = connected);
    if (connected) {
      _connectionHealth.markConnected(ConnectionTransport.webSocket);
    } else {
      _connectionHealth.markDisconnected(ConnectionTransport.webSocket);
    }
    // The poll interval follows this state, so the timer has to be re-armed
    // when it changes -- in both directions. Without the second call the socket
    // could drop and the dashboard would keep the 60 s safety-net cadence for
    // the rest of the session, which is the exact case the short interval exists
    // for. Re-arming is cheap: it cancels a timer and makes another.
    _restartRefreshTimer();
  }

  void _handleRealtimeTelemetry(
    String deviceId,
    Map<String, TelemetryPoint> values,
  ) {
    if (!mounted || values.isEmpty) return;
    final slot = switch (deviceId) {
      ThingsBoardApi.deviceBattery => _battery,
      ThingsBoardApi.devicePzem => _pzem,
      ThingsBoardApi.deviceSensor => _sensor,
      ThingsBoardApi.deviceFish => _fish,
      _ => null,
    };
    if (slot == null && !_isKnownDevice(deviceId)) return;

    final mergedValues = <String, double>{
      ...?slot?.latestValues,
      for (final entry in values.entries) entry.key: entry.value.value,
    };
    var latest = slot?.lastUpdate;
    for (final point in values.values) {
      if (latest == null || point.timestamp.isAfter(latest)) {
        latest = point.timestamp;
      }
    }
    final updated = DeviceTelemetry(
      latestValues: mergedValues,
      lastUpdate: latest,
    );
    switch (deviceId) {
      case ThingsBoardApi.deviceBattery:
        _battery = updated;
      case ThingsBoardApi.devicePzem:
        _pzem = updated;
      case ThingsBoardApi.deviceSensor:
        _sensor = updated;
      case ThingsBoardApi.deviceFish:
        _fish = updated;
    }

    final wasLoading = _loading;
    // Gate the rebuild on the values actually differing, exactly as the poll path
    // does. This used to pass `changed: true` unconditionally, which meant every
    // telemetry frame the socket delivered announced itself as a change: the PZEM
    // and the BMS publish around 1 Hz each, so the revision counter went up two or
    // three times a second, roughly thirty times more often than the ten-second
    // poll it was designed around, and every Bound in the tree rebuilt with it.
    //
    // The socket can also deliver a frame whose values are identical to what is
    // already on screen, which is the common case for a device that reports on a
    // slow cycle. Those frames used to be indistinguishable from real changes.
    final changed =
        wasLoading || _error != null || !sameTelemetry(slot, updated);
    _connectionHealth.markSuccess(
      ConnectionTransport.webSocket,
      latency: DateTime.now().difference(values.values.first.timestamp),
      updatedAt: latest,
    );
    _isOfflineMode = false;
    _lastSuccessfulTelemetryAt = DateTime.now();
    _error = null;
    _loading = false;
    _notifyLive(wasLoading: wasLoading, changed: changed);
    // One frame, one device, one card. The same `sameTelemetry` gate above
    // decides it, so a frame whose values are already on screen rebuilds
    // nothing at all now, not the whole tree.
    switch (deviceId) {
      case ThingsBoardApi.deviceBattery:
        _notifyDeviceRevisions(battery: changed);
      case ThingsBoardApi.devicePzem:
        _notifyDeviceRevisions(pzem: changed);
      case ThingsBoardApi.deviceSensor:
        _notifyDeviceRevisions(sensor: changed);
      case ThingsBoardApi.deviceFish:
        _notifyDeviceRevisions(fish: changed);
    }
    _evaluateEnergyAlerts();
  }

  static bool _isKnownDevice(String deviceId) =>
      deviceId == ThingsBoardApi.deviceBattery ||
      deviceId == ThingsBoardApi.devicePzem ||
      deviceId == ThingsBoardApi.deviceSensor ||
      deviceId == ThingsBoardApi.deviceFish;

  /// Pull-to-refresh, which has to outrank the poll.
  ///
  /// [RefreshIndicator] dismisses itself as soon as this future completes, so a
  /// future that returns without having fetched anything is a lie told to the
  /// user's finger. Both entry points here bail out unconditionally when their
  /// request is already in flight -- `_fetchAll` on `_telemetryRequestInFlight`,
  /// `_fetchHistoryFor` on `_historyRequestInFlight` -- so pulling while the
  /// 10-second poll was mid-tick refetched nothing and still ended the spinner.
  ///
  /// The fix is not to remove either guard: they exist so the poll cannot stack
  /// requests on top of each other, which is a real problem on a slow link. It is
  /// to wait for the in-flight request to finish and then do one more, so the
  /// gesture always results in a fetch that happened after the finger lifted.
  Future<void> _refreshCurrentPage() async {
    // A poll that is already running is *about* to deliver the same data, so
    // waiting for it and then issuing one more is not duplicated work in the
    // common case -- it is one extra request, once, on a deliberate gesture.
    if (_telemetryRequestInFlight) {
      await _telemetryInFlight?.future;
    }
    await _fetchAll();
    if (_selectedIndex == 0) {
      if (_energyRequestInFlight) {
        await _energyInFlight?.future;
      }
      await _fetchEnergyHistory();
    }
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix == null) return;
    _historyLoaded.remove(prefix);
    if (_historyRequestInFlight.contains(prefix)) {
      await _historyInFlight[prefix]?.future;
    }
    await _fetchHistoryFor(prefix);
  }

  // ── Alerts ───────────────────────────────────────────────────────────────────
  void _evaluateEnergyAlerts() {
    final now = DateTime.now();
    final signals = evaluateAlarmRules(
      rules: _alarmRules,
      readings: _alarmReadings,
      now: now,
    );
    final alerts = {for (final signal in signals) signal.id: signal.message};

    final newSignals = newlyActiveSignals(
      signals: signals,
      alreadyActive: _activeAlertIds,
    );
    final nextMessages = signals.map((signal) => signal.message).toList();
    final changed =
        alerts.length != _activeAlertIds.length ||
        !alerts.keys.every(_activeAlertIds.contains) ||
        !sameStrings(nextMessages, _alertMessages.value);
    if (!changed) return;
    _activeAlertIds = alerts.keys.toSet();
    _alertMessages.value = nextMessages;
    unawaited(AlarmBridge.instance.setActiveAlerts(_activeAlertIds));

    // Nothing is announced until the background module's active set has been
    // read. Before that read completes every alarm looks new, because a fresh
    // process starts with an empty set, and the first evaluation would report
    // alarms the background had already reported. The banner still updates, so
    // the user sees the state immediately either way.
    if (_activeAlertsPrimed && newSignals.isNotEmpty) {
      for (final signal in newSignals) {
        _persistAlarm(signal, now);
      }
    }
    // No SnackBar here, deliberately. The same messages already render in
    // `EnergyAlertBanner` at the top of the list, above the greeting, so the
    // SnackBar was the same sentence twice — once where the user was already
    // looking and once over the bottom of the screen, where it covered the
    // energy card and the navigation bar. Worse, it re-fired on every message
    // change rather than on every new alarm, so a reading drifting in and out
    // of range popped a bar every few seconds while the banner just sat there.
    // The banner is persistent, non-modal, and does not obscure content; that
    // is the right shape for a condition that is still true.
  }

  /// The devices the rules read, in the shape the evaluator expects.
  ///
  /// A device missing from this list cannot raise anything at all: the evaluator
  /// skips any rule whose device has no reading, because a device that was never
  /// read is not the same as a device that stopped reporting. The fish device is
  /// here so that `stale_fish` and `offline_fish` can actually fire.
  List<AlarmReading> get _alarmReadings => [
    if (_battery != null)
      AlarmReading(
        device: AlarmDevice.battery,
        values: _battery!.latestValues,
        lastUpdate: _battery!.lastUpdate,
      ),
    if (_pzem != null)
      AlarmReading(
        device: AlarmDevice.pzem,
        values: _pzem!.latestValues,
        lastUpdate: _pzem!.lastUpdate,
      ),
    if (_sensor != null)
      AlarmReading(
        device: AlarmDevice.sensor,
        values: _sensor!.latestValues,
        lastUpdate: _sensor!.lastUpdate,
      ),
    if (_fish != null)
      AlarmReading(
        device: AlarmDevice.fish,
        values: _fish!.latestValues,
        lastUpdate: _fish!.lastUpdate,
      ),
  ];

  /// Whether the background module's active set has been read yet.
  bool _activeAlertsPrimed = false;

  /// Reads the set of alarms the background check has already reported.
  ///
  /// Awaited during startup, before anything is allowed to announce an alarm.
  /// Doing it lazily inside the evaluation was the earlier mistake: the read is
  /// asynchronous, so the first evaluation always saw an empty set and reported
  /// alarms that the background had already reported, which is exactly the
  /// duplicate the shared set exists to prevent.
  Future<void> _primeActiveAlerts() async {
    if (_activeAlertsPrimed) return;
    _activeAlertsPrimed = true;
    final background = await AlarmBridge.instance.activeAlerts();
    if (!mounted || background.isEmpty) return;
    _activeAlertIds = {..._activeAlertIds, ...background};
  }

  void _persistAlarm(AlarmSignal signal, DateTime now) {
    unawaited(
      _alarmHistoryService.addAlarm(
        AlarmRecord(
          id: '${now.millisecondsSinceEpoch}_${signal.id}',
          timestamp: now,
          type: signal.type,
          severity: signal.severity,
          message: signal.message,
          value: signal.value,
        ),
      ),
    );
    unawaited(
      AlarmNotificationService.notifyAlarm(
        id: signal.id,
        title: signal.isCritical
            ? 'EnerGrow: Critical alarm'
            : 'EnerGrow: Warning alarm',
        message: signal.message,
        critical: signal.isCritical,
      ),
    );
  }

  // ── Energy summary ───────────────────────────────────────────────────────────
  Future<void> _fetchEnergyHistory() async {
    if (_energyRequestInFlight) return;
    _energyRequestInFlight = true;
    final energyFlight = Completer<void>();
    _energyInFlight = energyFlight;
    if (mounted && _energyHistory.isEmpty) {
      _energyLoading = true;
      _notifyEnergy();
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      final histories = await widget.api.fetchHistoryForKeys(
        ThingsBoardApi.devicePzem,
        const ['power_dc', 'power_ac'],
        start: today.subtract(const Duration(days: 13, minutes: 15)),
        end: now,
        intervalMs: 30 * 60 * 1000,
        limit: 1500,
      );
      if (!mounted) return;
      final hasHistory = histories.values.any((points) => points.isNotEmpty);
      _energyHistory
        ..clear()
        ..addAll({
          for (final entry in histories.entries)
            entry.key: List<TelemetryPoint>.of(entry.value)
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        });
      _updateMemoizedEnergy();
      _energyLoading = false;
      _energyError = hasHistory
          ? null
          : 'ThingsBoard has no power_dc/power_ac history in the last 14 days.';
      _energyUpdatedAt = now;
      _notifyEnergy();
    } catch (error) {
      if (!mounted) return;
      // Compiled out in release by `appLog`; the user-visible failure is the
      // `_energyError` set on the next line, which is unchanged either way.
      appLog(() => 'Energy summary history request failed: $error');
      _energyLoading = false;
      _energyError = 'Power history could not be loaded. Pull down to retry.';
      _notifyEnergy();
    } finally {
      _energyRequestInFlight = false;
      _energyInFlight = null;
      if (!energyFlight.isCompleted) energyFlight.complete();
    }
  }

  void _setWeeklyEnergySummary(bool weekly) {
    if (_weeklyEnergySummary == weekly) return;
    _weeklyEnergySummary = weekly;
    _updateMemoizedEnergy();
    _notifyEnergy();
  }

  void _notifyEnergy() {
    if (mounted) _energyRevision.value++;
  }

  void _notifyCharts() {
    if (mounted) _chartRevision.value++;
  }

  void _updateMemoizedEnergy() {
    final solar = energyComparison(
      history: _energyHistory,
      key: 'power_dc',
      weekly: _weeklyEnergySummary,
    );
    final load = energyComparison(
      history: _energyHistory,
      key: 'power_ac',
      weekly: _weeklyEnergySummary,
    );
    _solarKwh = solar.current;
    _previousSolarKwh = solar.previous;
    _loadKwh = load.current;
    _previousLoadKwh = load.previous;
  }

  // ── Per-page history ─────────────────────────────────────────────────────────
  Future<void> _fetchHistoryFor(String prefix) async {
    final now = DateTime.now();
    final rangeStart = _selectedRangeStart ?? startOfDay(_selectedDate);
    final selectionKey = historySelectionKey(
      rangeStart: rangeStart,
      rangeEnd: _selectedRangeEnd,
    );
    // Always refetch, even when this view's data is already in hand.
    //
    // This used to return early on a cache hit, on the reasoning that a switch
    // should be instant. It is, but the numbers it showed were whatever was there
    // when that view was last opened, which for "Last 24 hours" on a live system
    // is not what anyone means by looking at it again.
    //
    // Refreshing unconditionally does not make the switch feel slower, because
    // nothing waits: `_chartLoading` is only raised when this prefix has no data at
    // all, so the already-loaded chart stays on screen and the fresh series
    // replaces it when the request lands. Stale-while-revalidate, not a spinner.
    if (_historyRequestInFlight.contains(prefix)) {
      if (_historyRequestDate[prefix] != selectionKey) {
        _historyPendingRefresh.add(prefix);
      }
      return;
    }
    _historyRequestInFlight.add(prefix);
    final historyFlight = Completer<void>();
    _historyInFlight[prefix] = historyFlight;
    _historyRequestDate[prefix] = selectionKey;
    _historyBusyNotifier.value++;
    if (mounted && !_historyLoaded.contains(prefix)) {
      _chartLoading = true;
      _notifyCharts();
    }

    final window = historyWindowFor(
      prefix: prefix,
      rangeStart: rangeStart,
      rangeEnd: _selectedRangeEnd,
      now: now,
    );
    Map<String, List<TelemetryPoint>> histories;
    var requestFailed = false;
    try {
      histories = await widget.api.fetchHistoryForKeys(
        window.deviceId,
        window.keys,
        start: window.start,
        end: window.end,
        intervalMs: window.intervalMs,
      );
    } catch (_) {
      // An exception is not an empty range. Record it so the chart can say
      // so, and clear it on the next attempt so a recovered prefix does not
      // keep warning.
      _historyLoadFailed.add(prefix);
      requestFailed = true;
      histories = const {};
    }
    if (!requestFailed) {
      _historyLoadFailed.remove(prefix);
    }

    // Drop the result if the user changed the selection while it was loading.
    final currentKey = historySelectionKey(
      rangeStart: _selectedRangeStart ?? startOfDay(_selectedDate),
      rangeEnd: _selectedRangeEnd,
    );
    if (mounted && currentKey == selectionKey) {
      _storeHistory(prefix, window.keys, histories);
      _chartLoading = false;
      _notifyCharts();
    }
    await _releaseHistoryRequest(prefix, historyFlight);

    // **The page check comes first, and that order was the bug.**
    //
    // `_historyPendingRefresh` is registered when a request is asked for while one
    // is already in flight, which is what a second date tap does. It means "when
    // this request lands, go again for the current selection".
    //
    // `remove` was evaluated first, so the flag was cleared unconditionally. A
    // prefix registered as pending while the user was on page A, who then swipes
    // to page B before the in-flight request returns, had its pending-refresh
    // request discarded -- the chart for A silently kept the old date range, and
    // nothing would re-fetch it until the user touched the date again.
    //
    // Leaving the flag set instead is correct in that case: when the user comes
    // back to A, the next request for A consumes it. That is the whole point of a
    // pending flag.
    if (_historyPendingRefresh.contains(prefix) &&
        _prefixForPage(_selectedIndex) == prefix) {
      _historyPendingRefresh.remove(prefix);
      unawaited(_fetchHistoryFor(prefix));
    }
  }

  /// Releases the in-flight bookkeeping for one history request.
  ///
  /// Called from `_fetchHistoryFor` at the end of its straight-line section, and
  /// it exists as a method for one reason: the first version of this was a
  /// comment describing a `finally` that **did not exist**, which is worse than no
  /// comment at all -- it told the next reader the invariant was already
  /// guaranteed. It was not reachable then either, since the only statements
  /// between are pure arithmetic and a total `switch`. But it was three lines away
  /// from being reachable, and the cost of that is a hung spinner.
  ///
  /// `await` is deliberate even though the body never awaits anything: putting the
  /// call at the tail of `_fetchHistoryFor` means it runs after the release, so a
  /// future `try` around the *rest* of that method would still be correct.
  Future<void> _releaseHistoryRequest(
    String prefix,
    Completer<void> flight,
  ) async {
    _historyRequestInFlight.remove(prefix);
    _historyRequestDate.remove(prefix);
    _historyInFlight.remove(prefix);
    if (!flight.isCompleted) flight.complete();
    // Guarded, unlike the rest. `_fetchHistoryFor` is awaited by nobody --
    // `unawaited` at the poll and at `_reloadHistoryForCurrentPage` -- so a
    // `notifyListeners()` on a disposed notifier surfaces as an unhandled async
    // error and a red screen in debug, and is silent in release.
    //
    // The screen really can be torn down mid-request: `_logout` and the
    // token-expired branch both use
    // `pushAndRemoveUntil(..., (_) => false)`, which disposes this `State`
    // immediately while the HTTP call is still outstanding.
    if (!mounted) return;
    _historyBusyNotifier.value++;
  }

  /// Files a history response under the keys the chart looks them up by.
  ///
  /// The maps are keyed by the bare telemetry key now, not by
  /// `'${prefix}_$metric'`. That composed name was the other half of the old
  /// fixed-trio assumption: the chart derived its lookup key from a prefix and
  /// a suffix index while this derived its storage key from a prefix and a
  /// literal, and the only reason they ever agreed was that both lists had
  /// exactly three entries in the same order.
  void _storeHistory(
    String prefix,
    HistoryKeys keys,
    Map<String, List<TelemetryPoint>> histories,
  ) {
    for (final key in keys) {
      final points = histories[key] ?? [];
      _history[key] = points;
      _chartSpots[key] = processSpots(points);
      _chartStats[key] = SeriesStats.fromPoints(points);
    }
    // Every group on this page, not just the prefix: the greenhouse draws four
    // cards off one fetch, and each has its own memoised bounds.
    for (final group in chartGroupsForPrefix(prefix)) {
      _chartBounds.remove('$prefix/${group.title}');
    }
    _historyLoaded.add(prefix);
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  // PV, AC and Battery share one tab, selected by a segmented control inside the
  // page rather than by three tabs of their own.
  //
  // The reason is arithmetic, and it is not close. Material 2 documents 80 dp as
  // the minimum width of a bottom-navigation destination in portrait, and this
  // phone is 380 dp wide, so a six-tab bar needed 480 dp — a hundred dp short of
  // fitting, and "Hydroponics" measured 62 dp in a 60 dp slot at the smallest
  // type size Material has. Material 3 states the limit and the symptom together:
  // "the elements may collide and there likely won't be enough space for
  // translated text."
  //
  // Four tabs need 320 dp, which fits with 60 dp to spare, and leaves one slot
  // free for a seventh destination later. The grouping is also the honest one:
  // PV, AC and Battery are three views of a single electrical system, all of it
  // from the PZEM and BMS devices, whereas Hydroponics and Fish are separate
  // subsystems that fail differently. Material asks for destinations "of equal
  // importance", and six peers was never the right description of what this app
  // has — it is a cluster of three plus an overview plus two singletons.
  //
  // Hydroponics and Fish deliberately have no prefix: they have no history chart.
  // TelemetryChartCard plots voltage/current/power under the names
  // `${prefix}_voltage`, `${prefix}_current` and `${prefix}_power`, so pH and
  // turbidity cannot be charted without generalising that widget. A null prefix
  // also means no history request is fired for those pages.
  //
  // Which page's history this is, and which of its devices to read.
  //
  // The Power page's answer depends on the sub-tab the user has selected inside
  // it, so this cannot be a plain lookup. Four callers depend on it agreeing with
  // what is actually on screen: the history fetch, pull-to-refresh, the
  // date-change reload and the pending-refresh check.
  //
  // The greenhouse and the fish tank were absent here until now, which is why
  // neither had a chart: a null prefix means no history request, and a missing
  // request means there is nothing to plot. They have prefixes, and
  // `historyDeviceForPrefix` sends each to its own device.
  String? _prefixForPage(int index) => switch (index) {
    1 => kPowerSubTabs[_powerSubNotifier.value].prefix,
    2 => 'env',
    3 => 'fish',
    _ => null,
  };

  /// The status strip's battery cell is a shortcut to the battery readings, which
  /// are now a view inside the Power tab rather than a tab. Both halves have to
  /// happen, and the order matters: selecting the sub-view first means the page
  /// builds with the right content already in place instead of flashing PV.
  void _openBatteryFromStrip() {
    final batteryIndex = kPowerSubTabs.indexWhere(
      (tab) => tab.prefix == 'battery',
    );
    if (batteryIndex != _powerSubNotifier.value) {
      _powerSubNotifier.value = batteryIndex;
    }
    if (_selectedIndex != 1) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
      );
    }
    // Fetched by prefix rather than through _reloadHistoryForCurrentPage, which
    // reads _selectedIndex — and that is only updated by onPageChanged once the
    // animation above has finished. Relying on it here would fetch whatever page
    // the user was on, not the one they were sent to.
    _historyLoaded.remove('battery');
    unawaited(_fetchHistoryFor('battery'));
  }

  void _selectPage(int index) {
    if (_selectedPage.value == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
    );
  }

  void _setChartPointerActive(bool active) {
    if (_chartPointerActiveNotifier.value == active) return;
    _chartPointerActiveNotifier.value = active;
  }

  // ── Date selection ───────────────────────────────────────────────────────────
  List<DateTime> get _stripDays {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  void _clearHistoryCache() {
    _historyLoaded.clear();
    _chartBounds.clear();
    _chartSpots.clear();
    _chartStats.clear();
  }

  void _selectDate(DateTime date) {
    final picked = startOfDay(date);
    // **The early return only checked `_selectedDate`, and that made today's chip
    // dead while a range was active.**
    //
    // The reachable sequence: open the range picker and press Apply without
    // touching anything. `initialDateRange` is today-to-today when nothing is
    // selected, so a range is committed and `_selectedDate` becomes today. But
    // `DateStripChip.isSelected` is `rangeStart == null && sameDay(...)`, so with
    // a range active *no chip is lit*. Tap today's chip: the guard below sees
    // `picked == _selectedDate`, returns early, and the range is never cleared --
    // so a chip that looks selectable ignores the tap, the strip stays unlit, and
    // there is no other way back to a single day except reopening the picker.
    //
    // So the early return now also requires that no range is active. When one is,
    // the tap clears it, which is what tapping any other chip already did.
    final hasRange = _selectedRangeStart != null;
    if (!hasRange && picked == startOfDay(_selectedDate)) return;
    setState(() {
      _selectedDate = date;
      _selectedRangeStart = null;
      _selectedRangeEnd = null;
      _clearHistoryCache();
    });
    _reloadHistoryForCurrentPage();
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final today = startOfDay(now);
    final firstDate = today.subtract(const Duration(days: 90));
    DateTime clamp(DateTime value) => value.isBefore(firstDate)
        ? firstDate
        : value.isAfter(today)
        ? today
        : value;
    final initialStart = clamp(
      startOfDay(_selectedRangeStart ?? _selectedDate),
    );
    final initialEnd = clamp(startOfDay(_selectedRangeEnd ?? _selectedDate));
    final safeEnd = initialEnd.isBefore(initialStart)
        ? initialStart
        : initialEnd;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: safeEnd),
      firstDate: firstDate,
      lastDate: today,
      // The picker's own chrome is localised from this, not from the strings
      // passed in. Leaving it on Indonesian meant the day headers and month
      // names stayed Indonesian inside an otherwise English dialog, which was
      // the last Indonesian surface in the app.
      locale: const Locale('en', 'US'),
      helpText: 'Select a telemetry date range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = startOfDay(picked.start);
      _selectedRangeStart = startOfDay(picked.start);
      _selectedRangeEnd = startOfDay(picked.end);
      _clearHistoryCache();
    });
    _reloadHistoryForCurrentPage();
  }

  void _reloadHistoryForCurrentPage() {
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
  }

  // ── Screen routing ───────────────────────────────────────────────────────────
  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    // Stop the background check before the session goes away. Otherwise the
    // native side keeps its own copy of the token and polls with it after the
    // user has signed out.
    unawaited(AlarmNotificationService.disable());
    await widget.api.logout();
    // Clear the CCTV URL so the next user on this device does not inherit
    // the previous user's stream URL.
    await clearCctvUrl();
    if (!mounted) return;
    _goToLogin();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(onLogout: _logout)),
    );
    if (changed == true) {
      _loadPreferences();
    }
  }

  void _openAlarmHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlarmHistoryScreen()),
    );
  }

  void _openEnergyReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EnergyReportScreen(api: widget.api)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // **The single resolution every card in this frame agrees on.**
    //
    // It used to be `Theme.of(context).brightness == Brightness.dark`, which was
    // exact for the two themes that existed and stopped being exact when Dracula
    // landed: Dracula is published as `ThemeMode.dark`, so the brightness reads
    // the same as the app's own dark mode and cannot tell them apart. Going
    // through [resolveAppTheme] with the controller's stored option is what
    // recovers the third value.
    //
    // It is resolved *here*, once, and threaded down as a parameter. That is the
    // documented reason the parameter exists: a `MaterialApp` publishes one
    // `ThemeData` for the whole subtree, so a widget that inferred its own mode
    // could disagree with its neighbours and produce a frame that is half Dracula
    // and half the app's dark mode. `AppCard.theme` and `DateStripChip.theme`
    // are required rather than optional for exactly the same reason.
    //
    // With a single dark theme, the resolution is gone and every card simply
    // reads the same token file.
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: AppBackground(child: _buildBody()),
      extendBody: true,
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _selectedPage,
        builder: (context, _, _) => GlassNavBar(
          selectedIndex: _selectedIndex,
          collapsed: _navCollapsed,
          onSelect: _selectPage,
          onExpand: () => _navCollapsed.value = false,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      flexibleSpace: ValueListenableBuilder<double>(
        valueListenable: _appBarBlurProgress,
        builder: (context, progress, _) {
          if (progress == 0) return const SizedBox.expand();
          // The scrim has to match the page it fades in over, or the app bar
          // shows as a slightly different shade of the same colour once you
          // scroll. These were the old scaffold hexes; the page moved.
          final baseColor = AppSurfaces.page;
          return DecoratedBox(
            decoration: BoxDecoration(
              // Opaque, and that is a fix. This was `0.86 * progress`, so 14% of
              // whatever was scrolled under the app bar showed through, and on
              // the device the greeting -- 17sp bold -- stayed plainly legible
              // through the title. A 17sp bold glyph is not a texture to be
              // ghosted; it is text, and text behind a title is text nobody can
              // read. The ramp still fades in over the first 48px, it just
              // arrives at fully opaque rather than at 86%.
              color: baseColor.withValues(alpha: progress),
              border: Border(
                bottom: BorderSide(
                  // The hairline at low alpha rather than `Colors.white` at
                  // 8%: the brief has one border colour and it is already a
                  // near-black grey, so the scrim line has to be that colour
                  // fading rather than a second white one.
                  color: AppSurfaces.border.withValues(alpha: progress),
                ),
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
      leading: IconButton(
        tooltip: 'Reload data',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _loading ? null : _fetchAll,
      ),
      title: const Text(
        'EnerGrow',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        // No date-range button here, and that is the user's call.
        //
        // It was added in this release to fix a real gap -- the range picker had
        // become unreachable -- and the reasoning was that the app bar is the one
        // place on screen on all four tabs. It sat between the "EnerGrow" wordmark
        // and the history icon, and the user read it as clutter next to the logo.
        //
        // The gap is therefore back, and honestly: `DateStrip` on Overview is the
        // only route to a custom range again, so on Power, Hydroponics and Fish
        // the date cannot be changed without going back to Overview. That was the
        // state before this release and it is a worse experience than a slightly
        // crowded app bar.
        //
        // Recording it rather than quietly reverting, because the reasoning for
        // putting it here was sound and the reason for taking it out is that it
        // looked wrong in the one place the user looks at first. If the range
        // control is wanted back, the app bar is still the only chrome shared by
        // all four tabs -- but it should be a single control that also carries the
        // current date, not an icon that duplicates what the date strip says.
        IconButton(
          tooltip: 'Alarm History',
          icon: const Icon(Icons.history_outlined),
          onPressed: _openAlarmHistory,
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _battery == null) {
      return TelemetryErrorView(message: _error!, onRetry: _fetchAll);
    }
    // No ValueListenableBuilder here any more. The physics reads the pointer flag
    // at gesture time, so touching a chart no longer rebuilds the PageView — and
    // because the chart fills most of the PV, AC and Battery pages, that rebuild
    // used to fire twice for nearly every scroll on those pages.
    return PageView.builder(
      controller: _pageController,
      physics: ChartGestureLockPhysics(
        basePhysics: const PageScrollPhysics(),
        isLocked: () => _chartPointerActiveNotifier.value,
      ),
      itemCount: 4,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) => _buildPage(index),
    );
  }

  void _onPageChanged(int index) {
    _selectedIndex = index;
    _selectedPage.value = index;
    final prefix = _prefixForPage(index);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
    // Entering the Power tab warms all three of its sub-views.
    //
    // The symptom this fixes: switching between PV, AC and Battery left the
    // incoming card showing the previous fetch's numbers for as long as the
    // request took, which on a slow ThingsBoard is a second or two. It read as the
    // card being stuck rather than as a refresh, because nothing on screen said
    // anything was happening. There are only three views, so fetching all of them
    // on entry costs three requests once and makes every later switch land on data
    // that is already there. Each switch still refreshes in the background, so this
    // changes when the data arrives, not whether it is current.
    if (index == 1) _warmPowerSubViews();
  }

  void _warmPowerSubViews() {
    for (final tab in kPowerSubTabs) {
      unawaited(_fetchHistoryFor(tab.prefix));
    }
  }

  Widget _buildPage(int index) {
    // One status strip, not three. They used to stack, and a phone in offline
    // mode showed a green "polling active" line directly above an orange
    // "offline" line, which is two opposite claims about the same connection
    // stacked on top of each other before any content appeared.
    //
    // The alarm banner is Overview-only. A threshold breach is a fact about the
    // greenhouse, not about the page being looked at, so repeating it above the
    // PV, AC, Battery, Hydroponics and Fish pages pushed lines the user had
    // already read above the content they opened a tab to see. It still reaches
    // them where it matters: a notification, and the alarm count in the status
    // strip, which is present on every page.
    //
    // Connection state is different and stays everywhere, because a page of
    // numbers that cannot be trusted needs to say so wherever it is displayed.
    final items = <Widget Function()>[
      () => _statusStripBuilder(showAlerts: index == 0),
      ..._pageContentFor(index),
    ];
    return RepaintBoundary(
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surface,
          strokeWidth: 2.5,
          displacement: 58,
          edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
          onRefresh: _refreshCurrentPage,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              kDashboardPageMargin,
              MediaQuery.paddingOf(context).top + kToolbarHeight - 6,
              kDashboardPageMargin,
              // The bar's real height plus [_navBarClearance], not a literal.
              // See that constant for why this was the wrong number before.
              glassNavBarReservedHeight(context) + _navBarClearance,
            ),
            itemCount: items.length,
            itemBuilder: (context, itemIndex) => items[itemIndex](),
          ),
        ),
      ),
    );
  }

  List<Widget Function()> _pageContentFor(int index) {
    // The `_ =>` arm renders Overview, so a page index added to the PageView
    // without an arm here shows the Overview page twice with no error anywhere.
    return switch (index) {
      1 => _powerPage(),
      2 => _hydroponicsPage(),
      3 => _fishPage(),
      _ => _overviewPage(),
    };
  }

  // ── Banners ──────────────────────────────────────────────────────────────────
  Object get _visualToken => Object.hash(
    _selectedDate,
    _displayName,
    // **The connection flag, and this was the gap that froze the Live/Polling
    // indicator on two tabs.**
    //
    // `ChartSectionHeader` reads `_realtimeConnected` and paints a wifi glyph
    // with the word "Live" or "Polling" from it. That flag changes only via
    // `setState` in `_handleRealtimeConnection` -- it is not a notifier, and
    // `_chartRevision` is not bumped by it. So on any tab whose charts were bound
    // with a token that omitted it, a connection change rebuilt the page and
    // `Bound` kept its cached child: same listenable, same token, closure never
    // re-invoked.
    //
    // Hydroponics and Fish were the two that omitted it, because they declared
    // their own `Bound(listenable: _chartRevision, token: theme)` instead of
    // going through `_bindRevision` like PV, AC and Battery did. Eight chart
    // headers were frozen at whatever they last showed, and only corrected on a
    // page switch, a date change or a pull-to-refresh. The other three tabs were
    // correct, so the same field behaved differently either side of a page
    // boundary -- which is the worst shape a bug of this kind can have, because
    // it looks like the pages are just different.
    //
    // Both halves are fixed: the flag is in the token, and the two tabs use
    // `_bindRevision` so there is no third way to declare a bound subtree.
    //
    // `AGENTS.md` records this as the `Bound` failure mode to expect, and it is
    // worth being precise about the shape: a token is unenforced by the compiler,
    // so a builder that reads a new piece of state and does not also add it to the
    // token fails *silently*. Nothing here throws.
    _realtimeConnected,
    // The thresholds belong here. Bound only rebuilds when the listenable fires or
    // this token changes, and _loadPreferences changes the thresholds with a plain
    // setState — so without this, saving a new limit left the environment grid
    // captioning its old range and the status strip judging against the old
    // low-SOC threshold, until the next telemetry change happened to rescue it.
    _thresholds,
    // Which power sub-view is selected. PV, AC and Battery are three closure
    // lists spliced into the same Column, so their Bound widgets sit at the same
    // tree position and reuse each other's State. Bound keeps its cached child
    // when the token is unchanged, so without this the symptom was: tapping AC
    // then PV left the AC card and the AC chart on screen under the "PV Status"
    // header until the next revision bump — up to ten seconds for the telemetry
    // card, because that is the poll interval. The header is a plain widget and
    // updated immediately, which made the stale card below it read as the wrong
    // page rather than as a slow refresh.
    _powerSubNotifier.value,
  );

  /// Binds a polling-driven subtree to one listenable and one token.
  ///
  /// The theme is part of the token because it is part of what every card inside
  /// reads, and this is the mechanism `AGENTS.md` warns about: a `Bound` whose
  /// builder closes over new data without a matching token change is silently
  /// dropped. It was a `bool` here before, which meant dark and Dracula hashed
  /// the same and switching between them would not have rebuilt anything; the
  /// enum makes the two distinct, which is the whole reason the token type
  /// changed with it.
  Widget _bindRevision(Listenable listenable, Widget Function() builder) {
    return Bound(listenable: listenable, token: _visualToken, builder: builder);
  }

  /// One status line for everything the user needs to know about liveness.
  ///
  /// Replaces three stacked banners with strict precedence: a fetch failure
  /// beats offline mode, which beats an active alarm, which beats stale devices.
  /// Only the most important thing is ever shown, so the strip cannot contradict
  /// itself and does not push the page content off screen.
  Widget _statusStripBuilder({required bool showAlerts}) {
    return _bindRevision(_connectionChromeListenable, () {
      final failed = _error != null;
      final offline = _isOfflineMode;
      final alerts = _alertMessages.value;
      final stale = _staleDeviceNames();

      // Each branch is wrapped in a BannerSwitcher rather than returned
      // conditionally, so a banner that goes away collapses instead of
      // vanishing in one frame. The alert banner is the case that matters
      // most: a reading returning to range used to drop the whole Overview
      // down a card-height with no transition, which reads as a glitch.
      if (failed) {
        return ConnectionStatusBannerSwitcher(
          failed: true,
          staleNames: stale,
          health: _connectionHealth.health,
          lastSuccessfulAt: _lastSuccessfulTelemetryAt,
          errorMessage: _error,
          visible: true,
          onRetry: _fetchAll,
        );
      }
      if (offline) {
        return _bindRevision(
          _liveRevision,
          () => BannerSwitcher(
            visible: true,
            identity: 'offline:${_cachedTelemetryTime ?? ''}',
            bottomSpacing: 8,
            builder: () => OfflineBanner(
              cacheTime: _cachedTelemetryTime,
              onRetry: _fetchAll,
            ),
          ),
        );
      }
      if (showAlerts) {
        return _bindRevision(
          _alertMessages,
          () => BannerSwitcher(
            visible: alerts.isNotEmpty,
            // The identity is the set of messages, so a *change* of alarm
            // cross-fades the text rather than only resizing the box.
            identity: alerts.join('|'),
            builder: () => EnergyAlertBanner(messages: alerts),
          ),
        );
      }
      if (stale.isNotEmpty) {
        return ConnectionStatusBannerSwitcher(
          failed: false,
          staleNames: stale,
          health: _connectionHealth.health,
          lastSuccessfulAt: _lastSuccessfulTelemetryAt,
          errorMessage: null,
          visible: true,
          onRetry: _fetchAll,
        );
      }
      return const SizedBox.shrink();
    });
  }

  /// Feeds the same readings the rule engine uses, so the banner and the alarms
  /// can never disagree about which devices stopped reporting.
  List<String> _staleDeviceNames() => staleDeviceNames(
    readings: _alarmReadings,
    staleMinutes: _staleTelemetryMinutes,
  );

  // ── Overview page ────────────────────────────────────────────────────────────
  List<Widget Function()> _overviewPage() {
    return [
      () => GreetingHeader(displayName: _displayName),
      () => const SizedBox(height: 8),
      () => _dateStrip(),
      () => const SizedBox(height: 8),
      () => _bindRevision(_liveRevision, () => _heroCard()),
      () => const SizedBox(height: 8),
      () => _bindRevision(_energyRevision, () => _energySummaryCard()),
      () => const SizedBox(height: 8),
      () => _bindRevision(_liveRevision, () => _dualCards()),
      // The environment grid used to sit here. It moved to the Hydroponics page,
      // where it belongs with the camera looking at the same greenhouse, and
      // Overview is now only what the power system is doing. The readings did not
      // change and the limits did not change, so the alarms are unaffected.
    ];
  }

  Widget _dateStrip() {
    return DateStrip(
      days: _stripDays,
      selectedDate: _selectedDate,
      rangeStart: _selectedRangeStart,
      rangeEnd: _selectedRangeEnd,
      onSelectDate: _selectDate,
      onPickRange: _pickDateFromCalendar,
    );
  }

  Widget _heroCard() {
    return LivePowerCard(
      pvPower: _pzem?.latestValues['power_dc'],
      acPower: _pzem?.latestValues['power_ac'],
      // Read from the BMS's own `power` key, not multiplied out from voltage and
      // current. The device reports all three, and deriving it produced two
      // separate wrong answers: the product collapses to 0 whenever current reads
      // 0.00 A, which the BMS does report while idle, and it drifts from the
      // reported figure whenever the pack is not at its nominal voltage.
      //
      // Passed through raw, sign and all, so the figure matches the Battery page
      // one tab away. Negating it here to make the hero read "Charging 12 W" was
      // tried and reverted: two screens reporting different numbers for one
      // measurement is worse than an odd-looking minus, because the reader has to
      // work out that a minus became a plus.
      //
      // Which sign means which direction is decided by the observed state-of-charge
      // trend, not by this comment, and it has been opposite twice on two BMSes.
      // `batteryChargeState` owns it and is pinned by a test; see
      // `lib/utils/battery_sign.dart`. `energy_forecast_service.dart` documents the
      // same vendor disagreement behind a warning to use `.abs()` where only the
      // magnitude matters.
      batteryPower: _battery?.latestValues['power'],
      soc: _battery?.latestValues['soc'],
      pzemStale: _pzem?.isStale(minutes: _staleTelemetryMinutes) ?? true,
      pzemAgeLabel: _pzem?.ageLabel,
    );
  }

  Widget _energySummaryCard() {
    return EnergySummaryCard(
      weekly: _weeklyEnergySummary,
      loading: _energyLoading,
      hasData:
          (_energyHistory['power_dc']?.isNotEmpty ?? false) ||
          (_energyHistory['power_ac']?.isNotEmpty ?? false),
      errorMessage: _energyError,
      solarKwh: _solarKwh,
      previousSolarKwh: _previousSolarKwh,
      loadKwh: _loadKwh,
      previousLoadKwh: _previousLoadKwh,
      forecast: _energyForecastService.calculate(
        history: _energyHistory,
        latest: {...?_battery?.latestValues, ...?_pzem?.latestValues},
        dailyProductionTargetKwh: _dailyProductionTargetKwh,
        referenceDate: DateTime.now(),
      ),
      onRangeChanged: _setWeeklyEnergySummary,
      onOpenReport: _openEnergyReport,
    );
  }

  Widget _dualCards() {
    return SystemStatusStrip(
      lowSocThreshold: _thresholds.lowSoc,
      activeAlerts: _activeAlertIds.length,
      // **No `?? 0.0` anywhere in here, and that is the fix.** These records used
      // to be `double` and an absent device was filled in with a zero, so a
      // never-reporting BMS rendered as a red `0%` beside `min 20%` and a meter
      // that had not spoken rendered as a red `Unstable 0 V - 0 Hz`. Both
      // verdicts fail on zero, so absence became a fault. `SystemStatusStrip`
      // renders a null as `--` and `not reporting` in ordinary text, which is
      // the same answer `LivePowerCard` and `MetricGrid` already give on this
      // page. The record's own doc comment carries the longer version.
      battery: (
        soc: _battery?.latestValues['soc'],
        voltage: _battery?.latestValues['voltage'],
        current: _battery?.latestValues['current'],
        // The same key the hero card reads, so the two cannot disagree about
        // which way the pack is moving.
        power: _battery?.latestValues['power'],
      ),
      ac: (
        voltage: _pzem?.latestValues['voltage_ac'],
        current: _pzem?.latestValues['current_ac'],
        power: _pzem?.latestValues['power_ac'],
        frequency: _pzem?.latestValues['frequency_ac'],
      ),
      onOpenBattery: _openBatteryFromStrip,
    );
  }

  Widget _environmentGrid() {
    return MetricGrid(
      title: 'Environment',
      specs: kEnvironmentSpecs,
      values: _sensor?.latestValues,
      thresholds: _thresholds,
      limitLabelFor: (spec) => environmentLimitLabel(spec, _thresholds),
      staleMinutes: _staleTelemetryMinutes,
      lastUpdate: _sensor?.lastUpdate,
      // The alerts toggle governs the grid's warning colours too, not just the
      // background rules — a limit the user switched off must stop colouring the
      // page, or Settings and the dashboard contradict each other.
      showGridColors: _thresholds.environmentAlerts,
    );
  }

  Widget _fishGrid() {
    return MetricGrid(
      title: 'Water Quality',
      specs: kFishSpecs,
      values: _fish?.latestValues,
      thresholds: _thresholds,
      limitLabelFor: (spec) => environmentLimitLabel(spec, _thresholds),
      showGridColors: _thresholds.fishAlerts,
      // The readings still get the stale tag, so a dead sensor cannot present a
      // page of plausible numbers as current.
      staleMinutes: _staleTelemetryMinutes,
      lastUpdate: _fish?.lastUpdate,
      // Two columns, so four readings land as 2 + 2. Three would leave the fourth
      // stranded beside a gap.
      columns: 2,
    );
  }

  // ── Detail pages ─────────────────────────────────────────────────────────────
  // ── Power page ───────────────────────────────────────────────────────────────
  /// PV, AC and Battery behind one tab, chosen with a segmented control.
  ///
  /// The selector is a `ValueListenableBuilder` over [_powerSubNotifier] rather
  /// than screen `setState`, and that is the whole reason the switch feels
  /// immediate. Measured on the device: a screen-level `setState` here cost
  /// 14-20 ms to the next frame against an 8.33 ms budget at 120 Hz, because
  /// rebuilding the screen repaints `AmbientBackground` and the blurred app bar
  /// and re-runs every cached page's closure list — none of which have anything to
  /// do with which sub-view is selected. Same pattern the nav bar already uses for
  /// [_selectedPage].
  List<Widget Function()> _powerPage() {
    return [
      () => ValueListenableBuilder<int>(
        valueListenable: _powerSubNotifier,
        builder: (context, sub, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _powerSelector(sub),
            const SizedBox(height: 12),
            // The page builders hand back lazily-invoked closures so the outer
            // ListView only realises visible items. Inside this one Column they
            // are invoked instead, which costs nothing measurable: the expensive
            // child is the chart, and that is a `Bound` whose child is cached and
            // only rebuilt when the chart revision actually bumps.
            ...switch (sub) {
              0 => _pvPage(),
              1 => _acPage(),
              _ => _batteryPage(),
            }.map((make) => make()),
          ],
        ),
      ),
    ];
  }

  Widget _powerSelector(int selected) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: [
          for (final tab in kPowerSubTabs)
            ButtonSegment<int>(
              value: kPowerSubTabs.indexOf(tab),
              icon: Icon(tab.icon, size: 16),
              label: Text(tab.label),
            ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => _selectPowerSub(selection.first),
      ),
    );
  }

  void _selectPowerSub(int index) {
    if (index == _powerSubNotifier.value) return;
    _powerSubNotifier.value = index;
    // No cache invalidation. An earlier version removed the incoming prefix from
    // `_historyLoaded` to force a refetch, which had the opposite of the intended
    // effect: every tap re-requested the history and blanked the chart while it was
    // in flight. `_fetchHistoryFor` returns early when it already holds this
    // selection's data, and a date change still clears everything.
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix == null) return;
    unawaited(_fetchHistoryFor(prefix));
  }

  List<Widget Function()> _pvPage() => [
    () => GlassPageHeader(
      title: 'PV Status',
      icon: Icons.wb_sunny,
      accent: categoryColor(MetricCategory.pv),
    ),
    () => const SizedBox(height: _cardGap),
    () => _bindRevision(
      _pzemRevision,
      () => _telemetryCard(_pzem, const [
        MetricDef('voltage_dc', 'Voltage DC', 'V', Icons.bolt),
        MetricDef('current_dc', 'Current DC', 'A', Icons.swap_horiz),
        MetricDef('power_dc', 'Power DC', 'W', Icons.wb_sunny),
        MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
      ]),
    ),
    // **Through `_chartSectionThunks`, which iterates the groups.** This used to
    // hand-write a header and one
    // `_chartCard('pv', chartGroupsForPrefix('pv').single, theme)`.
    //
    // **That `.single` was a landmine, and it is worth recording how it was found
    // because the failure mode was invisible.** An experiment split the electrical
    // pages into one chart group per unit — see the note on
    // `chartGroupsForPrefix` — and the three `.single` calls immediately threw
    // `Bad state: Too many elements` on the first frame.
    //
    // In a **release** build that was a blank page: no stripe, no log line, no
    // crash dialog. `flutter analyze` was clean, `flutter test` was fully green,
    // and the release APK built without complaint, because nothing in the suite
    // constructs a dashboard page and release mode strips Dart error reporting.
    // The page painted as one flat grey card, since the `Bound` that had already
    // thrown kept its empty child. It took a **profile** build on the emulator to
    // read the actual `Bad state` out of logcat.
    //
    // So the third way of declaring a page's charts is gone. There is one
    // implementation, it iterates, and a page with two groups is now simply a page
    // with two groups. Nothing about the current layout changes: each of the three
    // electrical pages still declares exactly one group, and `_chartHeaderGap`
    // moves inside the shared path where the other two pages were missing it.
    ..._chartSectionThunks('pv'),
  ];

  List<Widget Function()> _acPage() => [
    () => GlassPageHeader(
      title: 'AC Status',
      icon: Icons.power,
      accent: categoryColor(MetricCategory.ac),
    ),
    () => const SizedBox(height: _cardGap),
    () => _bindRevision(
      _pzemRevision,
      () => _telemetryCard(_pzem, const [
        MetricDef('voltage_ac', 'Voltage AC', 'V', Icons.bolt),
        MetricDef('current_ac', 'Current AC', 'A', Icons.swap_horiz),
        MetricDef('power_ac', 'Power AC', 'W', Icons.power, decimals: 1),
        MetricDef(
          'frequency_ac',
          'Frequency',
          'Hz',
          Icons.graphic_eq,
          decimals: 1,
        ),
        MetricDef('energy_ac', 'Energy', 'kWh', Icons.bar_chart),
        MetricDef('pf_ac', 'Power Factor', '', Icons.electric_meter),
      ]),
    ),
    // `_chartSections`, for the reason on the PV page: the hand-written
    // `.single` is what threw `Bad state: Too many elements` when the electrical
    // pages were split into one group per unit.
    ..._chartSectionThunks('ac'),
  ];

  List<Widget Function()> _batteryPage() => [
    () => GlassPageHeader(
      title: 'Battery Status',
      icon: Icons.battery_charging_full,
      accent: categoryColor(MetricCategory.battery),
    ),
    () => const SizedBox(height: _cardGap),
    () => _bindRevision(
      _batteryRevision,
      () => _telemetryCard(_battery, const [
        MetricDef('voltage', 'Voltage', 'V', Icons.bolt),
        MetricDef('current', 'Current', 'A', Icons.swap_horiz),
        MetricDef('power', 'Power', 'W', Icons.bolt_outlined, decimals: 1),
        MetricDef(
          'soc',
          'State of Charge',
          '%',
          Icons.battery_charging_full,
          decimals: 0,
        ),
        MetricDef('cycles', 'Cycles', '', Icons.refresh, decimals: 0),
        MetricDef(
          'remain_capacity_ah',
          'Remaining Capacity',
          'Ah',
          Icons.battery_3_bar,
          decimals: 1,
        ),
        // The full capacity was already being fetched and displayed nowhere.
        // A remaining charge with no reference to the original size is just a
        // number, so the pack size goes next to it.
        MetricDef(
          'full_capacity_ah',
          'Full Capacity',
          'Ah',
          Icons.battery_full,
          decimals: 0,
        ),
      ]),
    ),
    // `_chartSections`, for the reason on the PV page.
    ..._chartSectionThunks('battery'),
  ];

  // ── Hydroponics page ──────────────────────────────────────────────────────────
  /// The greenhouse sensors, their history, and the camera that was previously a
  /// tab of its own.
  ///
  /// The charts came after generalising `TelemetryChartCard` off its fixed
  /// voltage/current/power series, which is the work this page was waiting on.
  /// Four cards rather than one, because lux, per cent and parts per million do
  /// not share an axis with each other; only the two temperature sensors do, and
  /// putting those two together is the point -- the gap between the air and the
  /// panel is the reading.
  ///
  /// The history request is shared: all four groups come from one fetch of the
  /// greenhouse device, keyed by the same list the charts look up.
  List<Widget Function()> _hydroponicsPage() {
    return [
      () => GlassPageHeader(
        title: 'Hydroponics',
        icon: Icons.eco,
        accent: categoryColor(MetricCategory.environment),
      ),
      () => const SizedBox(height: _cardGap),
      // The camera comes first, above the readings.
      //
      // It was last because this page had no chart, so the grid was the whole
      // page and the camera was the thing underneath it. With four charts now
      // below, a camera at the bottom meant scrolling past every reading and
      // every plot to reach the one control that is not a number -- and the
      // thing you want to check most often is the thing furthest from the top.
      () => Bound(
        listenable: _cctvKeepAlive,
        token: '$_cctvUrl|$_selectedIndex',
        builder: () => CctvScreen(
          streamUrl: _cctvUrl,
          // Hydroponics is tab 2 of the four in `AppDestination` order. The
          // flag has to know, because this panel is inside an `IndexedStack`
          // and is therefore mounted on every tab; see `isVisible`.
          isVisible: _selectedIndex == 2,
        ),
      ),
      () => const SizedBox(height: 8),
      () => _bindRevision(_sensorRevision, () => _environmentGrid()),
      // One `Bound` around all four cards rather than four around four: the
      // groups are a fixed list, so they move together, and four boundaries
      // would let three cards rebuild for a bounds change on the fourth.
      //
      // Through `_bindRevision`, like PV, AC and Battery. A bare
      // `Bound(listenable: _chartRevision, token: theme)` is what left the
      // Live/Polling indicator frozen on this page -- see the note on
      // `_visualToken`. There is deliberately no third way to declare one of these.
      () => _bindRevision(
        _chartRevision,
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _chartSections('env'),
        ),
      ),
    ];
  }

  // ── Fish page ─────────────────────────────────────────────────────────────────
  /// Water quality for the fish tank, its history, and the second camera.
  ///
  /// The metric list mirrors ThingsBoardApi.fishKeys exactly. `turbidity_keruh`
  /// and `turbidity_voltage` are intentionally not here: the first is a boolean
  /// the numeric parser would flatten to a confident 0, the second is the
  /// sensor's own supply rail.
  List<Widget Function()> _fishPage() {
    return [
      () => GlassPageHeader(
        title: 'Fish Tank',
        icon: Icons.set_meal,
        accent: categoryColor(MetricCategory.water),
      ),
      () => const SizedBox(height: _cardGap),
      // Camera first, for the same reason as the greenhouse: it is the one
      // control on the page that is not a number, so it belongs where the eye
      // lands rather than below three charts.
      () => Bound(
        listenable: _cctvKeepAlive,
        token: '$_cctvUrlFish|$_selectedIndex',
        builder: () =>
            CctvScreen(streamUrl: _cctvUrlFish, isVisible: _selectedIndex == 3),
      ),
      () => const SizedBox(height: 8),
      () => _bindRevision(_fishRevision, () => _fishGrid()),
      // Same reason as the greenhouse charts above.
      () => _bindRevision(
        _chartRevision,
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _chartSections('fish'),
        ),
      ),
    ];
  }

  Widget _telemetryCard(DeviceTelemetry? data, List<MetricDef> metrics) {
    return TelemetryCard(
      data: data,
      metrics: metrics,
      staleMinutes: _staleTelemetryMinutes,
    );
  }

  Widget _chartSectionHeader(String title, String prefix) {
    // A notifier rather than reading the set directly: adding or removing a prefix
    // from `_historyRequestInFlight` mutates a plain Set, which rebuilds nothing.
    return ValueListenableBuilder<int>(
      valueListenable: _historyBusyNotifier,
      builder: (context, _, _) => ChartSectionHeader(
        title: title,
        selectedDate: _selectedDate,
        rangeStart: _selectedRangeStart,
        rangeEnd: _selectedRangeEnd,
        realtimeConnected: _realtimeConnected,
        refreshing: _historyRequestInFlight.contains(prefix),
      ),
    );
  }

  Widget _chartCard(String prefix, ChartGroup group) {
    return TelemetryChartCard(
      prefix: prefix,
      group: group,
      points: _history,
      spots: _chartSpots,
      stats: _chartStats,
      boundsCache: _chartBounds,
      loading: _chartLoading,
      loadFailed: !_chartLoading && _historyLoadFailed.contains(prefix),
      selectedDate: _selectedDate,
      rangeStart: _selectedRangeStart,
      rangeEnd: _selectedRangeEnd,
      onPointerActive: _setChartPointerActive,
    );
  }

  /// One header plus one card per group a prefix declares.
  ///
  /// **More than one group becomes a carousel rather than a stack.** The
  /// greenhouse declares four and the fish tank three, and stacked they meant
  /// scrolling past three plots to reach the fourth on a phone, every time. The
  /// electrical pages declare one each and keep the plain layout -- a carousel
  /// holding a single chart cannot be swiped and only looks like it should.
  ///
  /// The header, the date-range picker and the Live indicator stay outside the
  /// carousel because they describe the page rather than the plot; only the plot
  /// moves. The dots below it are load-bearing rather than decorative, and the
  /// reason is that a carousel with no position indicator is indistinguishable
  /// from a chart the user has finished with.
  List<Widget> _chartSections(String prefix) => [
    for (final build in _chartSectionThunks(prefix)) build(),
  ];

  /// One thunk per section, for a page's charts.
  ///
  /// The thunks rather than the widgets because every page's item list is
  /// `List<Widget Function()>`, and because the card is the thing `Bound` has to
  /// be able to defer. Building the list twice -- once as thunks for the three
  /// electrical pages and once as widgets for the other two -- is how the
  /// electrical pages ended up with their own hand-written chart wiring, and that
  /// wiring is what threw `Bad state: Too many elements` when the groups were
  /// split. There is now one implementation of "a page's charts".
  List<Widget Function()> _chartSectionThunks(String prefix) {
    final title = chartPageTitle(prefix);
    if (title == null) return const [];
    final groups = chartGroupsForPrefix(prefix);
    if (groups.isEmpty) return const [];

    // One group: the header and the card, exactly as this always rendered.
    //
    // **The single-group path is not a special case for tidiness.** The header
    // names the chart, so on a one-chart page the header must name that chart,
    // which is `groups.single.title` and not the page name. Collapsing the two
    // would rename "PV" to "Power" on the PV tab.
    if (groups.length == 1) {
      return [
        () => const SizedBox(height: _chartHeaderGap),
        () => _chartSectionHeader(groups.single.title, prefix),
        () => const SizedBox(height: 8),
        () => _bindRevision(
          _chartRevision,
          () => _chartCard(prefix, groups.single),
        ),
      ];
    }

    // The tallest card in the set sizes the slot. Every card already declares
    // its own height, so this is a maximum over declared values rather than a
    // number chosen here -- which is why the carousel costs no vertical
    // accuracy: each card still paints into the height it asked for.
    final tallest = groups
        .map((g) => g.height ?? 400.0)
        .reduce((a, b) => a > b ? a : b);

    return [
      () => const SizedBox(height: _chartHeaderGap),
      // The page name, not the chart name, because in a carousel the chart name
      // moves and this does not. The indicator below the plot carries it.
      () => _chartSectionHeader(title, prefix),
      () => const SizedBox(height: 8),
      // One `Bound` around the whole carousel rather than one per page. The
      // pages are a fixed list and they move together, and a `Bound` per page
      // would let four boundaries rebuild because one of them changed.
      () => _bindRevision(
        _chartRevision,
        () => ChartCarousel(
          itemCount: groups.length,
          height: tallest,
          // The dashboard's own pager gate, reused. Two horizontal pagers are
          // nested here and without this the outer one takes every swipe — the
          // first build swiped from the Temperature chart to the Fish Tank tab.
          onPointerActive: _setChartPointerActive,
          inset: kDashboardPageMargin,
          labelBuilder: (i) => groups[i].title,
          itemBuilder: (context, i) => _chartCard(prefix, groups[i]),
        ),
      ),
    ];
  }
}
