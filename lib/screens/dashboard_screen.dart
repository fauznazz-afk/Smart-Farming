import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/telemetry_export.dart';

import '../models/telemetry_model.dart';
import '../services/alarm_bridge.dart';
import '../services/alarm_notification_service.dart';
import '../services/app_update_service.dart';
import '../services/cctv_url.dart';
import '../services/connection_health_service.dart';
import '../services/thingsboard_api.dart';
import '../services/thingsboard_realtime_service.dart';
import '../services/widget_refresh.dart';
import '../utils/alarm_helpers.dart';
import '../utils/alarm_rules.dart';
import '../utils/app_log.dart';
import '../utils/app_update.dart';
import '../utils/ai_provider.dart';
import '../widgets/liquid_glass.dart';
import 'ai_chat_screen.dart';
import 'alarm_history_screen.dart';
import 'dashboard/charts/chart_data.dart';
import 'dashboard/utils/app_motion.dart';
import 'dashboard/utils/bound.dart';
import 'dashboard/utils/chart_gesture_lock.dart';
import 'dashboard/utils/color_helpers.dart';
import 'dashboard/utils/design_tokens.dart';
import 'dashboard/utils/energy_helpers.dart';
import 'dashboard/utils/history_range.dart';
import 'dashboard/utils/telemetry_helpers.dart';
import 'dashboard/widgets/banners.dart';
import 'dashboard/widgets/update_banner.dart';
import 'dashboard/widgets/chart_groups.dart';
import 'dashboard/widgets/power_sub_tabs.dart';
import 'dashboard/widgets/nav_bar.dart';
import 'dashboard/widgets/terminal_panel.dart';
import 'dashboard/pages/chart_sections.dart';
import 'dashboard/pages/detail_pages.dart';
import 'dashboard/pages/overview_page.dart';
import 'dashboard/state/alarms_mixin.dart';
import 'dashboard/state/preferences_mixin.dart';
import 'energy_report_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// The gap between two cards on the same page.
///
/// **A spacing value now, not a shadow-geometry one, and the number moved with
/// the design.** The gap used to be 20 because the ambient shadow needed that
/// much room to finish its falloff; with a tighter lift there is no falloff to
/// protect, only the footprint itself, which needs to clear the card below it.
/// 12 is the brief's `spacing.md` and leaves 8dp between one card's shadow and
/// the next card's top edge.
const double _cardGap = AppSpacing.md;

/// The gap between the docked nav bar's top edge and the last card.
///
/// **20, and the bar reserves nothing itself any more.** This used to be the
/// fix for an overlap: the bar was the Scaffold's `bottomNavigationBar` with
/// `extendBody: true`, so it painted *over* the page and the content had to
/// reserve the bar's height itself or the last line sat underneath it.
///
/// The bar is docked now, so `extendBody: false` and the Scaffold reserves the
/// slot. Adding the reservation here as well would leave the content that much
/// too high — the exact bug this number was introduced to stop, arriving from
/// the other direction. So the body asks for the gap alone.
///
/// **20 rather than something smaller.** The nav bar used to carry the same
/// raised shadow pair as every card, so its ambient half reached 20dp at one
/// sigma, and a gap below that let the shadow land on the last card. It is a
/// flat bar with no shadow now, so 20 is spacing rather than shadow clearance —
/// which is the same number for a different reason, and worth saying so the next
/// person does not "tidy" it back down on the strength of a stale comment.
const double _navBarClearance = 20;

/// Main monitoring dashboard: overview, PV, AC, battery, and CCTV tabs.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api});

  final ThingsBoardApi api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, DashboardAlarms, DashboardPreferences {
  // ── Navigation & lifecycle ───────────────────────────────────────────────────
  final _pageController = PageController();
  final ValueNotifier<int> _selectedPage = ValueNotifier(0);
  final ValueNotifier<double> _appBarBlurProgress = ValueNotifier(0);
  int _selectedIndex = 0;

  /// The page the user asked for, while the slide is running.
  ///
  /// **A slide crosses the pages in between, and the framework reports each
  /// one.** A jump from Overview to Fish passes the Power tab and the
  /// Hydroponics tab, and `onPageChanged` fires for both on the way. The
  /// bubble is on the page the user asked for, so those two are dropped
  /// rather than acted on — see [_onPageChanged].
  int? _targetPage;

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
  @override
  String? lastError;
  bool _isOfflineMode = false;
  DateTime? _cachedTelemetryTime;
  DateTime? _lastSuccessfulTelemetryAt;

  /// The WebSocket's view of the link, read by the poll floor and the wifi glyph.
  @override
  bool realtimeConnected = false;

  @override
  ThingsBoardApi get preferencesApi => widget.api;

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

  /// The 24h / 7d window the cost panel reports on.
  ///
  /// **Its toggle moved to the cost panel's own period label.** The control used
  /// to be the instrument panel's energy rows, which came off the Overview page
  /// when the glass cards replaced it — so the affordance followed the card that
  /// still has a window to change rather than being dropped.
  bool _weeklyEnergySummary = false;
  DateTime? _energyUpdatedAt;
  double _solarKwh = 0;
  double _loadKwh = 0;

  /// Whether a CSV is being fetched and built, so the action cannot be pressed
  /// twice and a second fetch cannot race the first one's share sheet.
  bool _exportingCsv = false;

  // ── Refresh & preferences ────────────────────────────────────────────────────
  // The preference fields and the poll timer live in
  // `dashboard/state/preferences_mixin.dart`.
  late final Listenable _connectionChromeListenable = Listenable.merge([
    _liveRevision,
    connectionHealth,
  ]);

  // ── Alerts ───────────────────────────────────────────────────────────────────
  // The alarm fields and methods live in `dashboard/state/alarms_mixin.dart`.

  // ── App update ───────────────────────────────────────────────────────────────
  /// The newest release found, or null. A `ValueNotifier` because the banner is
  /// the only thing that reads it and it arrives long after the first frame.
  final ValueNotifier<AppRelease?> _pendingUpdate = ValueNotifier(null);

  /// Dismissed for this session only.
  ///
  /// **Not persisted, on purpose.** The check itself is gated to once a day, so
  /// a user who taps LATER sees the banner again tomorrow - which is the point,
  /// because they still have the old build. Persisting the dismissal would mean
  /// the one time a release matters most is the time the banner had been
  /// silenced.
  bool _updateDismissed = false;

  // ── Misc ─────────────────────────────────────────────────────────────────────
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
  // the controller field are still there so a stored value is not silently
  // discarded; nothing on this screen reads it.
  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchAll();
    unawaited(_realtimeService.start());
    _fetchEnergyHistory();
    loadPreferences();
    loadDisplayName();
    // The screen is already on screen at this point, so the background check
    // has to stand down before its next tick rather than at the first resume
    // callback, which may not arrive for a while.
    unawaited(AlarmBridge.instance.setForeground(true));
    // **After everything above, and it does not gate anything.** The update
    // check is a request to a third party during startup; the dashboard has to
    // paint whether it answers or not, so this is deliberately not awaited
    // before `_fetchAll` and nothing waits on its result.
    unawaited(_checkForAppUpdate());
    // If the app was launched by tapping an alarm notification, navigate to the
    // alarm history screen so the user can see what fired.
    unawaited(_checkLaunchAlarm());
  }

  /// Asks whether a newer release exists, and publishes it if so.
  ///
  /// **One `try` around the whole thing, and the reason is the service's own
  /// contract**: `check` returns null for "up to date", "not due", "offline" and
  /// "the API changed shape" alike. Anything that escapes it is a bug rather
  /// than a condition, and a bug in an optional banner must not take the
  /// dashboard with it - so it is swallowed here, where it can be logged, rather
  /// than left to reach a `Future` nobody awaits.
  Future<void> _checkForAppUpdate() async {
    try {
      final release = await const AppUpdateService().check();
      if (release != null && mounted) _pendingUpdate.value = release;
    } catch (_) {
      // Nothing to report and nothing to retry; the next attempt is a day away.
    }
  }

  Future<void> _checkLaunchAlarm() async {
    final alarmId = await AlarmBridge.instance.launchAlarmId();
    if (alarmId != null && mounted) {
      Navigator.of(context)
          .push(appPageRoute<void>(page: const AlarmHistoryScreen()));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _selectedPage.dispose();
    _powerSubNotifier.dispose();
    _historyBusyNotifier.dispose();
    _appBarBlurProgress.dispose();
    _chartPointerActiveNotifier.dispose();
    _liveRevision.dispose();
    _batteryRevision.dispose();
    _pzemRevision.dispose();
    _sensorRevision.dispose();
    _fishRevision.dispose();
    _energyRevision.dispose();
    _chartRevision.dispose();
    alertMessages.dispose();
    _cctvKeepAlive.dispose();
    cancelRefreshTimer();
    // Nothing is evaluating alarms once this screen is gone, so the background
    // check has to be allowed to run again.
    unawaited(AlarmBridge.instance.setForeground(false));
    unawaited(_realtimeService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      restartRefreshTimer();
      // Tells the background check to stand down: the dashboard polls every ten
      // seconds and evaluates the same rules, so a background tick on top of that
      // is duplicate work against the same ThingsBoard instance.
      unawaited(AlarmBridge.instance.setForeground(true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      cancelRefreshTimer();
      unawaited(AlarmBridge.instance.setForeground(false));
    }
  }

  // ── Scroll-driven chrome ─────────────────────────────────────────────────────
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    // **The nav-bar collapse branch is gone.** There used to be a
    // `_downScrollDistance` accumulator that, past 12 px of downward scroll,
    // crossfaded all four destinations out and one enlarged icon in. The bar
    // keeps all four icons at all times now, so there is nothing for the
    // accumulator to measure — it and `_navCollapsed` were removed rather than
    // left at `false` forever, which is what a "temporarily disabled" branch
    // looks like six months later.
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

  // ── Telemetry fetching ───────────────────────────────────────────────────────
  @override
  Future<void> fetchAll() async {
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
          lastError != null ||
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
        widget.api
            .cacheTelemetrySnapshot({
              ThingsBoardApi.deviceBattery: results[0],
              ThingsBoardApi.devicePzem: results[1],
              ThingsBoardApi.deviceSensor: results[2],
              ThingsBoardApi.deviceFish: results[3],
            })
            // **After the write, and that ordering is the whole contract.** The
            // widget reads `cached_telemetry`, so a refresh that ran before the
            // write would redraw the previous tick's numbers and look like a
            // widget that updates one step behind - which is a harder bug to see
            // than one that does not update at all.
            .then((_) => const WidgetRefresh().refresh()),
      );
      _lastSuccessfulTelemetryAt = now;
      _loading = false;
      lastError = null;
      _isOfflineMode = false;
      connectionHealth.markSuccess(
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
      // above.** `evaluateEnergyAlerts` writes `activeAlertIds`, and
      // `SystemStatusStrip` reads its length inside a `Bound` whose token is
      // `_liveRevision` -- so the bump on the previous line rebuilt the strip with
      // the *previous* set. The count could then lag by up to a minute, until the
      // next telemetry difference or the once-a-minute `timestampChanged` bump.
      //
      // So: recompute first, then bump. Order matters and this is the only place
      // it is visible.
      final alertsBefore = activeAlertIds.length;
      evaluateEnergyAlerts();
      if (activeAlertIds.length != alertsBefore) {
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
      connectionHealth.markError(ConnectionTransport.rest, degraded: true);
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
      if (lastError != message || _loading) {
        final wasLoading = _loading;
        lastError = message;
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
    if (!mounted || realtimeConnected == connected) return;
    setState(() => realtimeConnected = connected);
    if (connected) {
      connectionHealth.markConnected(ConnectionTransport.webSocket);
    } else {
      connectionHealth.markDisconnected(ConnectionTransport.webSocket);
    }
    // The poll interval follows this state, so the timer has to be re-armed
    // when it changes -- in both directions. Without the second call the socket
    // could drop and the dashboard would keep the 60 s safety-net cadence for
    // the rest of the session, which is the exact case the short interval exists
    // for. Re-arming is cheap: it cancels a timer and makes another.
    restartRefreshTimer();
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
        wasLoading || lastError != null || !sameTelemetry(slot, updated);
    connectionHealth.markSuccess(
      ConnectionTransport.webSocket,
      latency: DateTime.now().difference(values.values.first.timestamp),
      updatedAt: latest,
    );
    _isOfflineMode = false;
    _lastSuccessfulTelemetryAt = DateTime.now();
    lastError = null;
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
    evaluateEnergyAlerts();
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
    await fetchAll();
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
  // `_setThresholds`, `evaluateEnergyAlerts`, `primeActiveAlerts` and
  // `_persistAlarm` live in `dashboard/state/alarms_mixin.dart`; see the note
  // there for why it is a mixin on this State rather than a service.
  /// The devices the rules read, in the shape the evaluator expects.
  ///
  /// A device missing from this list cannot raise anything at all: the evaluator
  /// skips any rule whose device has no reading, because a device that was never
  /// read is not the same as a device that stopped reporting. The fish device is
  /// here so that `stale_fish` and `offline_fish` can actually fire.
  @override
  List<AlarmReading> get alarmReadings => [
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

  @override
  ThingsBoardApi get alarmApi => widget.api;

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
    // **Only `current` is kept.** The instrument panel's `PREV_SOLAR` /
    // `PREV_LOAD` rows were the only readers of the previous period, and they
    // went with it — the 7-day sheet reports a week of days rather than one
    // week-versus-last-week delta, which is the same comparison expressed as
    // seven readable rows instead of two.
    _solarKwh = energyComparison(
      history: _energyHistory,
      key: 'power_dc',
      weekly: _weeklyEnergySummary,
    ).current;
    _loadKwh = energyComparison(
      history: _energyHistory,
      key: 'power_ac',
      weekly: _weeklyEnergySummary,
    ).current;
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
  /// The status strip's battery cell is a shortcut to the battery readings, which
  /// are a view inside the Power tab rather than a tab. Both halves have to
  /// happen, and the order matters: selecting the sub-view first means the page
  /// builds with the right content already in place instead of flashing PV.
  ///
  /// **Its caller is now the hero's SOC cell** rather than a row in the
  /// instrument panel that came off this page. "How full is the pack" is the
  /// question that cell answers, so the affordance is the thing being asked about
  /// — the same reason it was the right target when the panel owned it.
  void _openBatteryFromStrip() {
    final batteryIndex = kPowerSubTabs.indexWhere(
      (tab) => tab.prefix == 'battery',
    );
    if (batteryIndex != _powerSubNotifier.value) {
      _powerSubNotifier.value = batteryIndex;
    }
    if (_selectedIndex != 1) {
      unawaited(_showPage(1));
    }
    // Fetched by prefix, and the prefix is the battery sub-view. The switch
    // above applies the selection before it moves the page, so
    // `_reloadHistoryForCurrentPage` would resolve to the same prefix — but
    // naming it keeps the request tied to the sub-view the user was sent to
    // rather than to the tab they were on.
    _historyLoaded.remove('battery');
    unawaited(_fetchHistoryFor('battery'));
  }

  /// Moves the dashboard to a page, and the nav bar's bubble with it.
  ///
  /// **The selection is applied before the page moves, and that is what makes
  /// the two arrive together.** The bubble is drawn from `_selectedIndex`, and
  /// `_onPageChanged` only fires once the new page is halfway across — so the
  /// bubble used to start moving halfway through the content's own animation,
  /// and the two landed apart. Applying the selection first starts both on the
  /// same frame.
  ///
  /// **One clock for both, and it is [AppMotionTab].** The bubble was already
  /// on it; the page slide is the half that moved. Two halves of one gesture
  /// that run on two clocks read as two gestures.
  ///
  /// **A swipe still moves the bubble late, and that is the framework's
  /// order, not this one's.** `onPageChanged` fires when the new page becomes
  /// the current one, which is halfway through the drag; the bubble follows
  /// the finger's release from there. A tap — the gesture the clock is for —
  /// moves both at once.
  Future<void> _showPage(int index) async {
    _selectedIndex = index;
    _selectedPage.value = index;
    _targetPage = index;
    await _pageController.animateToPage(
      index,
      duration: AppMotionTab.duration,
      curve: AppMotionTab.curve,
    );
    // **Only clear the target if it is still this one.** A second tap starts a
    // second slide, and the first slide's future completes the moment it is
    // cancelled — which would clear the second one's target and let the pages
    // it passes take the bubble with them.
    if (_targetPage == index) _targetPage = null;
  }

  void _selectPage(int index) {
    if (_selectedPage.value == index) return;
    unawaited(_showPage(index));
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
    // Also for the Overview's period summary, which is not a page and so not
    // covered by `_reloadHistoryForCurrentPage` — that reads `_selectedIndex`,
    // and the Overview's index is 0, which resolves to no prefix at all.
    _loadSummaryHistory();
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
    // Same reason as in `_selectDate`: the Overview is not a page, so
    // `_reloadHistoryForCurrentPage` resolves to no prefix and the summary would
    // never get its greenhouse and fish history.
    _loadSummaryHistory();
  }

  void _reloadHistoryForCurrentPage() {
    final prefix = _prefixForPage(_selectedIndex);
    if (prefix != null) unawaited(_fetchHistoryFor(prefix));
  }

  // ── Screen routing ───────────────────────────────────────────────────────────
  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      appPageRoute<void>(page: const LoginScreen()),
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
      appPageRoute<bool>(page: SettingsScreen(onLogout: _logout)),
    );
    if (changed == true) {
      loadPreferences();
    }
  }

  void _openAlarmHistory() {
    Navigator.push(
      context,
      appPageRoute<void>(page: const AlarmHistoryScreen()),
    );
  }

  void _openEnergyReport() {
    Navigator.push(
      context,
      appPageRoute<void>(page: EnergyReportScreen(api: widget.api)),
    );
  }

  /// The snapshot the AI assistant is allowed to answer from.
  ///
  /// Built here rather than inside the chat screen because the live values are
  /// this screen's state, and the whole point of the layering rule in AGENTS.md
  /// is that a widget receives its data instead of reaching into a screen.
  ///
  /// **This is a method, not a field, because the snapshot has to be current.**
  /// It used to be evaluated once and handed to `AiChatScreen` as a `String`, so
  /// the assistant answered from whatever the readings were when the screen was
  /// opened — a question asked ten minutes later reasoned about ten-minute-old
  /// numbers. `AiChatScreen.telemetrySummary` takes a builder now and calls it per
  /// request.
  ///
  /// **Everything the app knows goes in, not the four devices it used to send.**
  /// The slice was live values for four devices, two totals and seven days of
  /// three power keys; the assistant therefore could not answer anything about
  /// alarms, thresholds, the tariff, the array's size, how fresh a reading was, or
  /// any key outside a hardcoded whitelist. All of those are here now, and the
  /// formatting is `ai_provider.dart`'s job.
  String _aiTelemetrySummary() {
    final now = DateTime.now();
    return buildTelemetrySummaryWithHistory(
      devices: {
        'battery': _battery?.latestValues ?? const {},
        'pzem meter': _pzem?.latestValues ?? const {},
        'environment sensor': _sensor?.latestValues ?? const {},
        'fish tank sensor': _fish?.latestValues ?? const {},
      },
      totals: {'solar_kwh_today': _solarKwh, 'load_kwh_today': _loadKwh},
      history: _history,
      deviceNotes: {
        if (_battery != null) 'battery': _freshness(_battery!.lastUpdate, now),
        if (_pzem != null) 'pzem meter': _freshness(_pzem!.lastUpdate, now),
        if (_sensor != null)
          'environment sensor': _freshness(_sensor!.lastUpdate, now),
        if (_fish != null)
          'fish tank sensor': _freshness(_fish!.lastUpdate, now),
      },
      // The same evaluator the banner and the background module use, so the
      // assistant cannot describe a condition the app is not showing.
      activeAlarms: alertMessages.value,
      thresholds: _aiThresholds(),
      installation: _aiInstallation(),
      derived: _aiDerived(),
    );
  }

  /// "3 min ago", for a device's last reading.
  ///
  /// `--` when the device has never reported: "0 min ago" would be a claim about
  /// a reading that does not exist.
  String _freshness(DateTime? lastUpdate, DateTime now) {
    if (lastUpdate == null) return 'no reading yet';
    final minutes = now.difference(lastUpdate).inMinutes;
    if (minutes < 1) return 'updated just now';
    if (minutes < 60) return 'updated $minutes min ago';
    final hours = minutes ~/ 60;
    return 'updated $hours h ago';
  }

  /// The user's alarm thresholds, as `label -> "value unit"`.
  ///
  /// Only the ones that are actually set: a null limit is not a threshold, and
  /// printing it as one would tell the assistant a rule exists that does not.
  Map<String, String> _aiThresholds() {
    final t = thresholds;
    String c(double? value, String unit) =>
        value == null ? '' : '${slotNumber(value, decimals: 1)} $unit';
    return {
      if (t.tempMin != null || t.tempMax != null)
        'air temperature': '${c(t.tempMin, '')} to ${c(t.tempMax, '°C')}'
            .trim(),
      if (t.humidityMin != null || t.humidityMax != null)
        'humidity': '${c(t.humidityMin, '')} to ${c(t.humidityMax, '%')}'
            .trim(),
      if (t.tdsMin != null) 'tds minimum': c(t.tdsMin, 'ppm'),
      if (t.tdsMax != null) 'tds maximum': c(t.tdsMax, 'ppm'),
      'battery low': '${slotNumber(t.lowSoc, decimals: 0)} %',
      if (t.fishPhMin != null || t.fishPhMax != null)
        'fish pH': '${c(t.fishPhMin, '')} to ${c(t.fishPhMax, '')}'.trim(),
      if (t.fishTempMin != null || t.fishTempMax != null)
        'fish temperature':
            '${c(t.fishTempMin, '')} to ${c(t.fishTempMax, '°C')}'.trim(),
      if (t.fishTurbidityMax != null)
        'turbidity max': c(t.fishTurbidityMax, 'NTU'),
      'silent device warning': '${t.staleMinutes} min',
      'device offline': '${t.offlineMinutes} min',
    };
  }

  /// The installation's own numbers — the two the user typed into Settings.
  ///
  /// Neither is an alarm threshold and neither raises a notification, which is why
  /// they are separate from [_aiThresholds]: an assistant told the tariff is a
  /// threshold would answer "your tariff is breached".
  Map<String, String> _aiInstallation() {
    final target = dailyProductionTargetKwh;
    return {
      if (pvInstalledWp != null)
        'array nameplate': '${slotNumber(pvInstalledWp, decimals: 0)} Wp',
      if (electricityTariffPerKwh != null)
        'electricity tariff':
            '${slotNumber(electricityTariffPerKwh, decimals: 0)} per kWh',
      if (target != null && target > 0)
        'daily production target': '${slotNumber(target, decimals: 1)} kWh',
    };
  }

  /// Figures the assistant would otherwise have to be told how to compute.
  ///
  /// Each one is a number the page is already deriving somewhere, so the answer
  /// and the screen cannot disagree about it. Kept short deliberately: anything
  /// the model can read straight off `devices` does not belong here.
  Map<String, String> _aiDerived() {
    // The highest PV output in the window the chart already holds. A running max
    // in a widget would be a max since launch, which for something labelled
    // "Peak" is a claim that silently stops being true.
    final peak = pvPeakWatts(
      _history['power_dc'] ?? const <TelemetryPoint>[],
      livePower: _pzem?.latestValues['power_dc'],
    );
    // The cost panel's own function, so the assistant cannot price a period the
    // app would refuse to price — an unset tariff is "the user has not told us",
    // not zero.
    final money = moneyForPeriod(
      solarKwh: _solarKwh,
      loadKwh: _loadKwh,
      tariffPerKwh: electricityTariffPerKwh,
    );
    return {
      if (peak != null) 'peak PV today': '${slotNumber(peak, decimals: 0)} W',
      'net energy today (solar minus load)':
          '${slotNumber(_solarKwh - _loadKwh, decimals: 2)} kWh',
      if (pvInstalledWp != null && pvInstalledWp! > 0)
        'specific yield today':
            '${(_solarKwh * 1000 / pvInstalledWp!).toStringAsFixed(2)} kWh/kWp',
      // A zero denominator is omitted rather than printed as infinity: no load
      // today is a fact worth leaving out, not a percentage worth inventing.
      if (_loadKwh > 0)
        'self-sufficiency today':
            '${((_solarKwh / _loadKwh) * 100).clamp(0, 999).toStringAsFixed(0)} %',
      if (money != null)
        'load cost today': '${slotNumber(money.loadCost, decimals: 0)} rupiah',
      if (money != null)
        'solar value today':
            '${slotNumber(money.solarValue, decimals: 0)} rupiah',
      if (money != null)
        'balance today (solar value minus load cost)':
            '${slotNumber(money.balance, decimals: 0)} rupiah',
    };
  }

  void _openAiAssistant() {
    Navigator.push(
      context,
      appPageRoute<void>(
        page: AiChatScreen(
          telemetrySummary: _aiTelemetrySummary,
          openSettings: _openSettings,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // **One palette, resolved statically.** `AppSurfaces` / `AppPalette` are
    // read through getters at build time, so a widget never has to infer a mode
    // from `Theme.of(context)` and cannot disagree with its neighbours about
    // which ramp is live.
    return Scaffold(
      extendBodyBehindAppBar: true,
      // **The page colour, not transparent — and this is the strip under the nav
      // bar.**
      //
      // The Scaffold's rect covers the whole screen, but its *body* slot stops at
      // the nav bar, and `AppBackground` paints only the body. So the strip below
      // the bar — the `SafeArea`'s bottom padding, the system gesture inset — was
      // painted by nothing at all.
      //
      // The settings screen has always been right on this: it leaves
      // `backgroundColor` unset, so it takes `scaffoldBackgroundColor`, which is
      // `AppSurfaces.page` and opaque. That is the whole difference, and this is
      // now the same one line.
      backgroundColor: AppSurfaces.page,
      appBar: _buildAppBar(),
      body: AppBackground(child: _buildBody()),
      // **False, and it was `true` while the bar was a floating capsule.**
      //
      // `extendBody: true` lets the body paint all the way to the screen's
      // bottom edge so an overlay bar can sit over the content. That is the
      // right trade for a floating object and the wrong one for a docked bar:
      // nothing covers the strip below it, so the last row of the Overview panel
      // showed through under the bar and through the gesture inset as well.
      //
      // The reservation in `glassNavBarReservedHeight` still applies. It was
      // written for the overlay case, where the body had to reserve the space
      // itself; with `extendBody: false` the `Scaffold` reserves the bar's slot
      // as well, so the two now overlap rather than cover for each other.
      extendBody: false,
      // **Floating, but over the bottom nav bar — not the content.**
      // `endFloat` places the FAB in the bottom nav bar's space, which is
      // reserved by the Scaffold (extendBody: false). The scrollable body ends
      // at the nav bar, so the FAB never overlaps a reading. This is the
      // standard Material "floating over bottom bar" position.
      floatingActionButton: FloatingActionButton(
        onPressed: _openAiAssistant,
        tooltip: 'Ask the assistant',
        backgroundColor: AppPalette.error,
        foregroundColor: AppPalette.onHue,
        child: const Icon(Icons.auto_awesome),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // The app-bar icon stays for discoverability; the FAB is the "floating"
      // one the user asked for. Both open the same screen.
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _selectedPage,
        builder: (context, _, _) =>
            GlassNavBar(selectedIndex: _selectedIndex, onSelect: _selectPage),
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
          // scroll. **The sweep's first stop, not the flat page.** The bar is
          // transparent over the body, so what is behind it is the *top* of the
          // gradient, and reading the flat page instead would leave a visible
          // band of a slightly different shade under the bar the moment the two
          // diverged.
          final baseColor = AppGlass.pageGradient.first;
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
      // Wordmark only. Every button that used to live here has a home that is
      // either on the page itself or in the hero card: reload is the page's own
      // pull-to-refresh, alarm history is the hero's bell, settings is the
      // hero's menu, CSV export is the hero's download. Four duplicates of
      // things the user can already see, on the one surface present on all tabs.
      //
      // **The token, and the ink comes from the bar.** The literal style had no
      // colour, so the title took the bar's foreground, which is not the page
      // ink this bar actually needs. The colour is `AppGlass.pageInkStrong`, from
      // the theme's `AppBarTheme`.
      title: const Text('EnerGrow', style: AppType.appBarTitle),
      actions: const <Widget>[],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (lastError != null && _battery == null) {
      return TelemetryErrorView(message: lastError!, onRetry: fetchAll);
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
    // **A page the slide passed is not a page the user is on.**
    //
    // The framework reports the page the scroll position has rounded to, so
    // a jump from Overview to Fish reports the Power tab and then the
    // Hydroponics tab on the way past. The bubble is already on the page the
    // user asked for, and the history for a page nobody is going to look at is
    // a request nobody needs — so a page change that is not the target is
    // dropped rather than acted on.
    if (_targetPage != null && index != _targetPage) return;
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
      () => _statusStripWithUpdate(showAlerts: index == 0),
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
              // The bottom padding reserves space so the floating AI assistant button
              // and the bottom nav bar do not cover the last card or row when scrolled to bottom.
              // 56 (FAB) + 16 (gap) + _navBarClearance (20) = 92.
              _navBarClearance + 72,
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
    displayName,
    // **The connection flag, and this was the gap that froze the Live/Polling
    // indicator on two tabs.**
    //
    // `ChartSectionHeader` reads `realtimeConnected` and paints a wifi glyph
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
    realtimeConnected,
    // The thresholds belong here. Bound only rebuilds when the listenable fires or
    // this token changes, and _loadPreferences changes the thresholds with a plain
    // setState — so without this, saving a new limit left the environment grid
    // captioning its old range and the status strip judging against the old
    // low-SOC threshold, until the next telemetry change happened to rescue it.
    thresholds,
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
    // **The 24H / 7D toggle, and it was the gap that froze the energy rows.**
    //
    // `_overviewPanel` reads `_weeklyEnergySummary` at the `ENERGY (24H)` /
    // `(7D)` section heading and switches which rows it draws. That field is
    // only ever written by `_setWeeklyEnergySummary`, which bumps
    // `_energyRevision` — a notifier this subtree is *not* bound to. The panel
    // is bound to `_liveRevision`, which only the telemetry poll touches, so
    // tapping the toggle changed nothing on screen until the next ten-second
    // poll happened to land. Found by the dead-code audit's `_visualToken`
    // sweep, which is the direction that check is good at: a value read by a
    // builder that no entry accounts for.
    _weeklyEnergySummary,
    // **The selected date and range, because the Overview's period summary reads
    // them.** `_selectDate` and `_pickDateFromCalendar` change all three in a
    // plain `setState`, which rebuilds this screen but not a `Bound` whose token
    // is unchanged — and `Bound` keeps its cached child in exactly that case.
    // The history fetch that follows bumps `_chartRevision`, so without this the
    // panel would update only when the network happened to answer: the numbers
    // would be right and the *heading* would still name the previous day, and
    // there is no exception to notice. The chart pages read the same state, so
    // this is not a token added for one widget.
    _selectedRangeStart,
    _selectedRangeEnd,
    // **The palette's brightness, kept in the token even though the app is
    // dark-only.** `AppSurfaces` and `AppPalette` are static getters resolved at
    // build time, so a `Bound` whose builder closes over them must rebuild when
    // the palette changes. Today that never happens; the entry stays so a future
    // ramp cannot reintroduce the frozen-palette bug where every panel kept its
    // cached child and painted the old colours until the next poll.
    AppTheme.brightness,
  );

  /// Binds a polling-driven subtree to one listenable and one token.
  ///
  /// The theme is part of the token because it is part of what every card inside
  /// reads, and this is the mechanism `AGENTS.md` warns about: a `Bound` whose
  /// builder closes over new data without a matching token change is silently
  /// dropped.
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
      final failed = lastError != null;
      final offline = _isOfflineMode;
      final alerts = alertMessages.value;
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
          health: connectionHealth.health,
          lastSuccessfulAt: _lastSuccessfulTelemetryAt,
          errorMessage: lastError,
          visible: true,
          onRetry: fetchAll,
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
              onRetry: fetchAll,
            ),
          ),
        );
      }
      if (showAlerts) {
        return _bindRevision(
          alertMessages,
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
          health: connectionHealth.health,
          lastSuccessfulAt: _lastSuccessfulTelemetryAt,
          errorMessage: null,
          visible: true,
          onRetry: fetchAll,
        );
      }
      return const SizedBox.shrink();
    });
  }

  /// The status strip, with the update banner above it when one is pending.
  ///
  /// **Stacked rather than merged into the status strip's precedence**, and the
  /// reason is that the two answer different questions. The strip is "is my data
  /// trustworthy" and it takes strict precedence because a wrong number is worse
  /// than a missing one. An available update is neither; folding it into that
  /// chain would mean hiding it behind an unrelated stale-device warning, and a
  /// banner that only appears when everything else is fine is a banner most
  /// users never see.
  ///
  /// Its own `Bound` on `_pendingUpdate` rather than a read of the notifier
  /// inside `_statusStripBuilder`: the strip is rebuilt by
  /// `_connectionChromeListenable` and `_liveRevision`, neither of which the
  /// update touches, so reading it there would mean the banner only appeared on
  /// the next poll.
  Widget _statusStripWithUpdate({required bool showAlerts}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Bound(
          listenable: _pendingUpdate,
          token: _pendingUpdate.value?.version ?? '',
          builder: () => UpdateBannerSwitcher(
            release: _pendingUpdate.value,
            visible: _pendingUpdate.value != null && !_updateDismissed,
            onDismiss: () => _updateDismissed = true,
          ),
        ),
        _statusStripBuilder(showAlerts: showAlerts),
      ],
    );
  }

  /// Feeds the same readings the rule engine uses, so the banner and the alarms
  /// can never disagree about which devices stopped reporting.
  List<String> _staleDeviceNames() => staleDeviceNames(
    readings: alarmReadings,
    staleMinutes: staleTelemetryMinutes,
  );

  // ── Overview page ────────────────────────────────────────────────────────────
  List<Widget Function()> _overviewPage() => overviewPage(_overviewInputs);

  OverviewInputs get _overviewInputs => OverviewInputs(
    displayName: displayName,
    battery: _battery,
    pzem: _pzem,
    sensor: _sensor,
    history: _history,
    energyHistory: _energyHistory,
    selectedDate: _selectedDate,
    rangeStart: _selectedRangeStart,
    rangeEnd: _selectedRangeEnd,
    stripDays: _stripDays,
    activeAlerts: activeAlertIds,
    exportingCsv: _exportingCsv,
    solarKwh: _solarKwh,
    loadKwh: _loadKwh,
    energyLoading: _energyLoading,
    energyError: _energyError,
    weeklyEnergySummary: _weeklyEnergySummary,
    dailyProductionTargetKwh: dailyProductionTargetKwh,
    electricityTariffPerKwh: electricityTariffPerKwh,
    pvInstalledWp: pvInstalledWp,
    thresholds: thresholds,
    bindRevision: _bindRevision,
    liveRevision: _liveRevision,
    energyRevision: _energyRevision,
    chartRevision: _chartRevision,
    onPickDate: _pickDateFromCalendar,
    onOpenAlarmHistory: _openAlarmHistory,
    onExportCsv: _exportCsv,
    onOpenSettings: _openSettings,
    onOpenBattery: _openBatteryFromStrip,
    onOpenEnergyReport: _openEnergyReport,
    onSelectDate: _selectDate,
    onTogglePeriod: _setWeeklyEnergySummary,
    loadSummaryHistory: _loadSummaryHistory,
    summarySettled:
        _historyLoaded.contains('env') ||
        _historyLoadFailed.contains('env') ||
        _historyLoaded.contains('fish') ||
        _historyLoadFailed.contains('fish'),
  );

  /// The glass hero: the site's name, today's date, the sun glyph, the array's
  /// live output, and the three figures that qualify it.
  ///
  /// **The hero is PV output, and that is the same call `OverviewPanel` makes**,
  /// with the same trade-off recorded there: at midnight it reads zero, and the
  /// array's own status is on the panel below. What changed is the presentation —
  /// this is the reference's hero card with telemetry in it, so the biggest
  /// number on the page is the one the panels exist to produce.
  ///
  /// The stat row is AC load, battery flow and state of charge: the three numbers
  /// that answer "where is the power going", which is the question the hero's own
  /// figure cannot.
  // anyone who re-adds a section, and removing them would have taken their tests
  // with them.

  /// Fetches the greenhouse and fish-tank history the period summary needs.
  ///
  /// **Both go through the ordinary `_fetchHistoryFor`, so the summary and the
  /// Environment and Fish charts read the same history map and cannot
  /// disagree.** A separate request into a separate field would be two copies of
  /// the same series with no compiler check between them — the shape
  /// `chart_groups.dart` exists to end.
  ///
  /// It also means navigating to those pages afterwards costs nothing, because
  /// the data is already in hand and only the page's own poll was missing.
  ///
  /// Not called on startup: the initial selection is today, so the panel is not
  /// on screen and the request would be for nothing.
  void _loadSummaryHistory() {
    final isSummaryPeriod =
        _selectedRangeStart != null ||
        startOfDay(_selectedDate) != startOfDay(DateTime.now());
    if (!isSummaryPeriod) return;
    for (final prefix in const ['env', 'fish']) {
      unawaited(_fetchHistoryFor(prefix));
    }
  }

  // ── CSV export ───────────────────────────────────────────────────────────────
  /// Fetches every telemetry key for the selected window and shares a CSV.
  ///
  /// The fetching and the file itself live in `utils/telemetry_export.dart`,
  /// which owns the two reasons the export does not dump what is on screen.
  /// What stays here is the `_exportingCsv` guard and the snackbar.
  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final csv = await buildTelemetryCsvForWindow(
        widget.api,
        selectedDate: _selectedDate,
        rangeStart: _selectedRangeStart,
        rangeEnd: _selectedRangeEnd,
      );
      if (!mounted) return;
      if (csv == null) {
        _showExportNote('Nothing was recorded in this period.');
        return;
      }
      await shareTelemetryCsv(
        csv,
        describeHistoryRange(
          selectedDate: _selectedDate,
          rangeStart: _selectedRangeStart,
          rangeEnd: _selectedRangeEnd,
          now: DateTime.now(),
        ),
      );
    } catch (error) {
      if (mounted) _showExportNote('Could not export: $error');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  void _showExportNote(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            powerSelector(sub, _selectPowerSub),
            const SizedBox(height: 12),
            // The page builders hand back lazily-invoked closures so the outer
            // ListView only realises visible items. Inside this one Column they
            // are invoked instead, which costs nothing measurable: the expensive
            // child is the chart, and that is a `Bound` whose child is cached and
            // only rebuilt when the chart revision actually bumps.
            // The switcher is keyed on `sub`, so a tap cross-fades the two
            // sub-views while the selector above it stays put. It is fed the
            // already-invoked closures, not the closures, because a list of
            // functions has no identity AnimatedSwitcher can key on.
            AnimatedSwitcher(
              duration: AppMotion.state,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              // The default centres both children; a page has to keep its top
              // edge, so the outgoing view fades where it stood.
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[...previousChildren, ?currentChild],
              ),
              child: Column(
                key: ValueKey<int>(sub),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: switch (sub) {
                  0 => _pvPage(),
                  1 => _acPage(),
                  _ => _batteryPage(),
                }.map((make) => make()).toList(),
              ),
            ),
          ],
        ),
      ),
    ];
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
    () => detailHeader('PV Status', Icons.wb_sunny, MetricCategory.pv),
    () => _bindRevision(
      _pzemRevision,
      () => detailTelemetryCard(_pzem, const [
        MetricDef('voltage_dc', 'Voltage DC', 'V', Icons.bolt),
        MetricDef('current_dc', 'Current DC', 'A', Icons.swap_horiz),
        MetricDef('power_dc', 'Power DC', 'W', Icons.wb_sunny),
        MetricDef('energy_dc', 'Energy', 'kWh', Icons.bar_chart),
      ], staleTelemetryMinutes),
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
    () => detailHeader('AC Status', Icons.power, MetricCategory.ac),
    () => _bindRevision(
      _pzemRevision,
      () => detailTelemetryCard(_pzem, const [
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
      ], staleTelemetryMinutes),
    ),
    // `_chartSections`, for the reason on the PV page: the hand-written
    // `.single` is what threw `Bad state: Too many elements` when the electrical
    // pages were split into one group per unit.
    ..._chartSectionThunks('ac'),
  ];

  List<Widget Function()> _batteryPage() => [
    () => detailHeader('Battery Status', Icons.battery_charging_full, MetricCategory.battery),
    () => _bindRevision(
      _batteryRevision,
      () => detailTelemetryCard(_battery, const [
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
      ], staleTelemetryMinutes),
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
      () => detailHeader('Hydroponics', Icons.eco, MetricCategory.environment),
      // The camera comes first, above the readings.
      //
      // It was last because this page had no chart, so the grid was the whole
      // page and the camera was the thing underneath it. With four charts now
      // below, a camera at the bottom meant scrolling past every reading and
      // every plot to reach the one control that is not a number -- and the
      // thing you want to check most often is the thing furthest from the top.
      // Hydroponics is tab 2 of the four in `AppDestination` order.
      () => cameraPanel(
        keepAlive: _cctvKeepAlive,
        streamUrl: cctvUrl,
        selectedIndex: _selectedIndex,
        pageIndex: 2,
      ),
      () => const SizedBox(height: _cardGap),
      () => _bindRevision(_sensorRevision, () => environmentGrid(sensor: _sensor, thresholds: thresholds, staleMinutes: staleTelemetryMinutes)),
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
      () => detailHeader('Fish Tank', Icons.set_meal, MetricCategory.water),
      // Camera first, for the same reason as the greenhouse: it is the one
      // control on the page that is not a number, so it belongs where the eye
      // lands rather than below three charts.
      () => cameraPanel(
        keepAlive: _cctvKeepAlive,
        streamUrl: cctvUrlFish,
        selectedIndex: _selectedIndex,
        pageIndex: 3,
      ),
      () => const SizedBox(height: 8),
      () => _bindRevision(_fishRevision, () => fishGrid(fish: _fish, thresholds: thresholds, staleMinutes: staleTelemetryMinutes)),
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

  /// Everything the chart builders read, gathered once per call.
  ChartSectionInputs get _chartInputs => ChartSectionInputs(
    history: _history,
    spots: _chartSpots,
    stats: _chartStats,
    boundsCache: _chartBounds,
    loading: _chartLoading,
    loadFailedPrefixes: _historyLoadFailed,
    selectedDate: _selectedDate,
    rangeStart: _selectedRangeStart,
    rangeEnd: _selectedRangeEnd,
    realtimeConnected: realtimeConnected,
    busyNotifier: _historyBusyNotifier,
    requestInFlight: _historyRequestInFlight,
    onPointerActive: _setChartPointerActive,
    bindRevision: _bindRevision,
    revision: _chartRevision,
  );

  List<Widget Function()> _chartSectionThunks(String prefix) =>
      chartSectionThunks(_chartInputs, prefix);

  List<Widget> _chartSections(String prefix) =>
      chartSections(_chartInputs, prefix);
}
