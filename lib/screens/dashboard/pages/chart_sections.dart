import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/telemetry_model.dart';
import '../charts/chart_data.dart';
import '../widgets/chart_card.dart';
import '../widgets/chart_carousel.dart';
import '../utils/design_tokens.dart';
import '../widgets/chart_groups.dart';

/// The gap above a chart section header, which is a different job from the
/// card gap.
///
/// Larger than the card gap because a header belongs to what follows it, and it
/// needs the previous card's shadow to have finished before the label lands. It
/// also carries more text than a card boundary does, so a bare 20dp made the
/// header look attached to the card above it.
const double kChartHeaderGap = 28;

/// Everything a page's charts read from the dashboard's state, passed in once
/// so the builders below do not close over a `State`.
class ChartSectionInputs {
  const ChartSectionInputs({
    required this.history,
    required this.spots,
    required this.stats,
    required this.boundsCache,
    required this.loading,
    required this.loadFailedPrefixes,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.realtimeConnected,
    required this.busyNotifier,
    required this.requestInFlight,
    required this.onPointerActive,
    required this.bindRevision,
    required this.revision,
  });

  final Map<String, List<TelemetryPoint>> history;
  final Map<String, List<FlSpot>> spots;
  final Map<String, SeriesStats?> stats;
  final Map<String, ChartBounds> boundsCache;
  final bool loading;
  final Set<String> loadFailedPrefixes;
  final DateTime selectedDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final bool realtimeConnected;

  /// Bumped when a history request starts or finishes, so the header can show
  /// that it is updating. The set itself changing is not observable.
  final ValueListenable<int> busyNotifier;
  final Set<String> requestInFlight;
  final ValueChanged<bool> onPointerActive;

  /// Binds a polling-driven subtree to [revision] and the dashboard's visual
  /// token. Passed as a function because the token lives on the screen.
  final Widget Function(Listenable listenable, Widget Function() builder)
  bindRevision;
  final Listenable revision;
}

/// One header plus one card per group a prefix declares, as built widgets.
List<Widget> chartSections(ChartSectionInputs inputs, String prefix) => [
  for (final build in chartSectionThunks(inputs, prefix)) build(),
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
List<Widget Function()> chartSectionThunks(
  ChartSectionInputs inputs,
  String prefix,
) {
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
      () => const SizedBox(height: kChartHeaderGap),
      () => _header(inputs, groups.single.title, prefix),
      () => const SizedBox(height: 8),
      () => inputs.bindRevision(
        inputs.revision,
        () => _card(inputs, prefix, groups.single),
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
    () => const SizedBox(height: kChartHeaderGap),
    // The page name, not the chart name, because in a carousel the chart name
    // moves and this does not. The indicator below the plot carries it.
    () => _header(inputs, title, prefix),
    () => const SizedBox(height: 8),
    // One `Bound` around the whole carousel rather than one per page. The pages
    // are a fixed list and they move together, and a `Bound` per page would let
    // four boundaries rebuild because one of them changed.
    () => inputs.bindRevision(
      inputs.revision,
      () => ChartCarousel(
        itemCount: groups.length,
        height: tallest,
        // The dashboard's own pager gate, reused. Two horizontal pagers are
        // nested here and without this the outer one takes every swipe — the
        // first build swiped from the Temperature chart to the Fish Tank tab.
        onPointerActive: inputs.onPointerActive,
        inset: kDashboardPageMargin,
        labelBuilder: (i) => groups[i].title,
        itemBuilder: (context, i) => _card(inputs, prefix, groups[i]),
      ),
    ),
  ];
}

Widget _header(ChartSectionInputs inputs, String title, String prefix) {
  // A notifier rather than reading the set directly: adding or removing a
  // prefix from the in-flight set mutates a plain Set, which rebuilds nothing.
  return ValueListenableBuilder<int>(
    valueListenable: inputs.busyNotifier,
    builder: (context, _, _) => ChartSectionHeader(
      title: title,
      selectedDate: inputs.selectedDate,
      rangeStart: inputs.rangeStart,
      rangeEnd: inputs.rangeEnd,
      realtimeConnected: inputs.realtimeConnected,
      refreshing: inputs.requestInFlight.contains(prefix),
    ),
  );
}

Widget _card(ChartSectionInputs inputs, String prefix, ChartGroup group) {
  return TelemetryChartCard(
    prefix: prefix,
    group: group,
    points: inputs.history,
    spots: inputs.spots,
    stats: inputs.stats,
    boundsCache: inputs.boundsCache,
    loading: inputs.loading,
    loadFailed: !inputs.loading && inputs.loadFailedPrefixes.contains(prefix),
    selectedDate: inputs.selectedDate,
    rangeStart: inputs.rangeStart,
    rangeEnd: inputs.rangeEnd,
    onPointerActive: inputs.onPointerActive,
  );
}
