import 'package:flutter/material.dart';

import '../../../utils/alarm_rules.dart';
import '../utils/design_tokens.dart';
import 'terminal_panel.dart';

// Gradient dark-mode skin for the environment and fish panels, local to this
// file so the shared token layer stays untouched.
const Color _glassFill = Color(0x0FFFFFFF);
const Color _glassBorder = Color(0x1FFFFFFF);
const Color _valueGradientStart = Color(0xFF00D97E);
const Color _valueGradientEnd = Color(0xFF00D97E);
const double _glassRadius = 26;

/// A cyan-to-violet wash over a value figure. `BlendMode.srcIn` keeps the
/// glyphs, so this paints the type rather than a box behind it.
class _GradientValue extends StatelessWidget {
  const _GradientValue({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_valueGradientStart, _valueGradientEnd],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// One reading in a [MetricGrid]: which telemetry key, what to call it, and
/// whether anything is watching it.
class MetricSpec {
  const MetricSpec(
    this.key,
    this.label,
    this.unit,
    this.icon, {
    this.metric,
    this.decimals = 1,
  });

  final String key;
  final String label;
  final String unit;
  final IconData icon;
  final String? metric;
  final int decimals;
}

/// How a spec's configured range is captioned under its value.
typedef LimitLabelBuilder = String? Function(MetricSpec spec);

/// A titled table of readings, used for the greenhouse sensors and for the fish
/// tank. One [TerminalPanel], one [TerminalRow] per spec.
///
/// ## Why it is no longer a grid of tiles
///
/// This was `columns` side-by-side [AppCard]s, each with an icon, a value and a
/// caption. On a phone that is four or five boxes inside a box, and the
/// comparison the layout promised — two readings of the same kind next to each
/// other — is one the reader was never making, because a `temp_dht` and a `lux`
/// have nothing to be compared against. It was also the last part of the
/// dashboard still in the old card vocabulary after the Overview became a
/// panel, so the two grids and the Overview page read as three different apps.
///
/// **One spec per row is the fix, and [columns] did nothing for it.** The
/// column count was chosen so a row would not end half empty, which was a
/// property of the tile grid and not of the data. It is still a constructor
/// parameter because `dashboard_screen.dart` passes it and callers should not
/// have to change to get the new look, but it no longer decides anything: the
/// rows are ordered and dense, which is what makes this a readout.
///
/// ## The label is now a slot name
///
/// `AMBIENT_T`, `PV_TEMP`, `TURBIDITY` — abbreviated, underscored, monospace,
/// the same vocabulary as `PV_OUT` and `BAT_SOC` on the Overview panel. `key`
/// and `metric` are untouched: those are the ThingsBoard telemetry keys and the
/// alarm-rule names, and the two are deliberately different.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.title,
    required this.specs,
    required this.values,
    this.columns = 3,
    this.thresholds,
    this.limitLabelFor,
    this.staleMinutes = 10,
    this.lastUpdate,
    this.showGridColors = true,
  });

  final String title;
  final List<MetricSpec> specs;
  final Map<String, double>? values;

  /// Retained for call-site compatibility only. It no longer affects layout —
  /// see the class doc comment.
  final int columns;
  final AlarmThresholds? thresholds;
  final int staleMinutes;
  final DateTime? lastUpdate;
  final LimitLabelBuilder? limitLabelFor;
  final bool showGridColors;

  @override
  Widget build(BuildContext context) {
    final verdicts = _Verdicts.of(
      values,
      thresholds,
      lastUpdate,
      staleMinutes,
      specs,
    );
    final breached = specs.where((spec) => verdicts.isBreached(spec)).length;

    return Container(
      decoration: BoxDecoration(
        color: _glassFill,
        borderRadius: BorderRadius.circular(_glassRadius),
        border: Border.all(color: _glassBorder),
      ),
      child: TerminalPanel(
        // **Its own title, not `TerminalPanel`'s `'Overview'` default.**
        // `MetricGrid` draws the Environment and Water Quality panels as well as
        // anything else, and the default was still in force at this call site —
        // so every one of them was announced to a screen reader as "Overview".
        // The parameter was made a parameter precisely so this could stop
        // happening, and then nobody passed it.
        semanticLabel: title,
        header: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              // **Cyan, not red.** Red on this panel means one thing only:
              // `TerminalRow.alert` and `TerminalTag(alert: true)` — a reading
              // out of bounds. A red section heading put the alarm colour on a
              // block that was working, so the one genuinely breached value had
              // to compete with its own title for the eye. The accent is the
              // panel's mark for structure.
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.slotKey.copyWith(
                    color: AppSurfaces.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              // **Say nothing when nothing is wrong.** Both tags below are a
              // verdict on the data, so the healthy case draws nothing at all
              // rather than a green "all normal" badge occupying the space a real
              // breach needs.
              if (verdicts.isStale)
                TerminalTag(text: 'Stale data', alert: false)
              else if (breached > 0 && showGridColors)
                TerminalTag(text: '$breached out of range', alert: true),
            ],
          ),
        ),
        children: [
          // **One clock for the whole grid, one fade per row.** The rows used to
          // appear as a block; the panel now assembles itself top to bottom. It
          // is a single controller with an interval per row rather than a
          // controller each, so five rows cost one ticker and not five, and the
          // stagger is capped so a long fish grid does not take twice as long as
          // a short environment one to become readable.
          _GridEntrance(
            // The spec count is the animation's shape. A rebuild that changes it
            // is a different grid, and re-keying it is what lets the entrance run
            // again for that grid without replaying on every poll.
            key: ValueKey(specs.length),
            rowCount: specs.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < specs.length; i++) ...[
                  _SpecRow(
                    spec: specs[i],
                    value: values?[specs[i].key],
                    breached: verdicts.isBreached(specs[i]),
                    limit: limitLabelFor?.call(specs[i]),
                    meterFraction: _meterFraction(specs[i]),
                    showGridColors: showGridColors,
                  ),
                  if (i < specs.length - 1) const TerminalRule(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Where a reading sits inside its configured range, or null for no bar.
  ///
  /// **A meter needs both ends of the scale.** [AlarmThresholds] leaves a bound
  /// null on purpose — turbidity has a maximum and no minimum — and a bar drawn
  /// against one end is not a position, it is a decoration that reads as
  /// "nearly empty" or "nearly full" for a value that has nowhere to sit. So a
  /// one-sided limit gets the caption only, and the reading still says whether
  /// it is inside the limit it has.
  ///
  /// A zero-width range is the same problem: no reading can be inside it, so
  /// the fraction would divide by zero and clamp to a bar that is either empty
  /// or full regardless of the value.
  double? _meterFraction(MetricSpec spec) {
    final metric = spec.metric;
    final value = metric == null ? null : values?[metric];
    if (metric == null || value == null || thresholds == null) return null;
    final min = thresholds!.minFor(metric);
    final max = thresholds!.maxFor(metric);
    if (min == null || max == null || max <= min) return null;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }
}

/// Fades the grid's rows in, top to bottom, on the **first mount only**.
///
/// **One controller for the whole grid.** A controller per row would be five
/// tickers for one gesture, and the stagger is what makes the order read as
/// assembly rather than as noise. Rows are driven by a single interval each,
/// so the last one starts at [_kGridStaggerStep] × (rows - 1) and no row can
/// outlive `AppMotion.container`.
///
/// **A poll must not replay it.** The dashboard rebuilds this grid every ten
/// seconds; `initState` starts the animation once and nothing restarts it.
/// The key is the spec count, so the entrance runs again only when a
/// genuinely different grid is drawn.
///
/// **Reduce-motion wins.** `MediaQuery.disableAnimationsOf` is the platform's
/// own setting; when it is set the rows are simply present.
class _GridEntrance extends StatefulWidget {
  const _GridEntrance({super.key, required this.rowCount, required this.child});

  final int rowCount;
  final Widget child;

  @override
  State<_GridEntrance> createState() => _GridEntranceState();
}

class _GridEntranceState extends State<_GridEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// One 0..1 curve per row, or null where the row is simply present.
  late final List<Animation<double>?> _rows;

  /// How far apart two consecutive rows start.
  ///
  /// `shortcut:` a fixed 60 ms step, correct for the 3-5 rows this grid ever
  /// holds; upgrade to a step derived from `AppMotion.container / rows` if a
  /// grid starts carrying more than about five.
  static const Duration _step = Duration(milliseconds: 60);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.container,
      vsync: this,
    );
    final shown = widget.rowCount.clamp(0, _kMaxStaggeredRows);
    final span =
        1.0 -
        (shown <= 1
            ? 0.0
            : (shown - 1) *
                  _step.inMilliseconds /
                  AppMotion.container.inMilliseconds);
    _rows = <Animation<double>?>[
      for (var i = 0; i < widget.rowCount; i++)
        i < shown
            ? CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  (i *
                          _step.inMilliseconds /
                          AppMotion.container.inMilliseconds)
                      .clamp(0.0, 1.0),
                  ((i *
                              _step.inMilliseconds /
                              AppMotion.container.inMilliseconds) +
                          span)
                      .clamp(0.0, 1.0),
                  curve: AppMotion.enter,
                ),
              )
            : null,
    ];
    _controller.forward();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      if (row is CurvedAnimation) row.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final children = (widget.child as Column).children;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < children.length; i++)
          _rows.length > i / 2 && _rows[i ~/ 2] != null && i.isEven
              ? FadeTransition(
                  opacity: _rows[i ~/ 2]!,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(_rows[i ~/ 2]!),
                    child: children[i],
                  ),
                )
              : children[i],
      ],
    );
  }
}

/// How many rows may be staggered at all. Past this the remaining rows are
/// simply present, so a long list cannot grow the entrance without bound.
const int _kMaxStaggeredRows = 5;

/// One spec: the row, and the range bar under it when there is a range.
class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.spec,
    required this.value,
    required this.breached,
    required this.limit,
    required this.meterFraction,
    required this.showGridColors,
  });

  final MetricSpec spec;
  final double? value;

  /// The reading is outside its configured range.
  final bool breached;

  final String? limit;

  /// null when there is no two-ended range to plot — see [_meterFraction].
  final double? meterFraction;

  final bool showGridColors;

  @override
  Widget build(BuildContext context) {
    // **The alert colour is gated on `showGridColors`, and the caption is
    // not.** The reading and the configured limit are facts; the red is the
    // user's chosen severity, and Settings switches it off. Gating both would
    // make a breached reading look identical to an unwatched one.
    final alert = breached && showGridColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // **No `valueStyle`**: these rows take `AppType.slotValue`, 24 sp, the
        // same figure the Power page's card draws. That is what the user asked
        // for and it is the default here, so there is nothing to write.
        //
        // A reading long enough to need shrinking still shrinks, the same way
        // Power's does, because the value sits in a `FittedBox(scaleDown)` in
        // `TerminalRow`. That was tried as an argument here and reverted: naming
        // `slotValueSmall` for the whole grid made every reading 12 sp, which is
        // the opposite of the request.
        _GradientValue(
          child: TerminalRow(
            label: spec.label,
            value: slotNumber(value, decimals: spec.decimals),
            unit: spec.unit.isEmpty ? null : spec.unit,
            alert: alert,
            // `slotNumber` right-trims trailing zeros, which is what a tabular
            // column wants: the device reported a whole number, so the column
            // says so and every row is the same width.
            divider: false,
          ),
        ),
        if (meterFraction != null)
          TerminalMeter(
            fraction: meterFraction!,
            alert: alert,
            leftCaption: limit,
            rightCaption: value == null
                // **`spec.decimals`, not the `slotNumber` default of 1.** The
                // cell above already formats the same reading at the spec's own
                // precision, so a spec that declares fewer digits printed two
                // different numbers for one value inside one cell — `TURBIDITY`
                // declares 0 because the sensor is good to a few percent, and
                // drew `2396` above a caption reading `2396.5`. The spec is the
                // one place that decides how precise a quantity is shown;
                // reading the default here quietly made a second one.
                ? null
                : slotNumber(value, decimals: spec.decimals),
          )
        else if (limit != null)
          // One-sided limit: the caption is the range, and it stays muted rather
          // than turning red because the bar it would have sat under is absent.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              // `kTerminalGapAbove`, not 0 — this caption stands exactly where
              // `TerminalMeter`'s own caption stands, so it has to be given the
              // same top gap or the cell shifts 4 dp depending on whether the
              // spec happened to have a bar.
              kTerminalGapAbove,
              AppSpacing.cardPadding,
              AppSpacing.md,
            ),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_valueGradientStart, _valueGradientEnd],
              ).createShader(bounds),
              child: Text(
                limit!,
                // `slotKey`, not `slotMicro`. This caption sits on the same line
                // the meter's own captions use, and at 10 sp against a 24 sp
                // figure it read as a footnote to the row above rather than as
                // the range the reading is being judged against. A breach keeps
                // the status red; the gradient is the accent for a reading.
                style: AppType.slotKey.copyWith(
                  color: alert ? AppPalette.statusBad : AppSurfaces.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Whether each monitored reading sits inside its configured range.
class _Verdicts {
  const _Verdicts(this.breached, this.isStale);

  final Map<String, bool> breached;
  final bool isStale;

  static _Verdicts of(
    Map<String, double>? values,
    AlarmThresholds? thresholds,
    DateTime? lastUpdate,
    int staleMinutes,
    List<MetricSpec> specs,
  ) {
    final result = <String, bool>{};
    if (values != null && thresholds != null) {
      for (final spec in specs) {
        final metric = spec.metric;
        final value = metric == null ? null : values[metric];
        if (metric == null || value == null) continue;
        final min = thresholds.minFor(metric);
        final max = thresholds.maxFor(metric);
        result[metric] =
            (min != null && value < min) || (max != null && value > max);
      }
    }
    final stale =
        lastUpdate == null ||
        DateTime.now().difference(lastUpdate).inMinutes > staleMinutes;
    return _Verdicts(result, stale);
  }

  bool isBreached(MetricSpec spec) => verdictFor(spec) == false;

  bool? verdictFor(MetricSpec spec) {
    final metric = spec.metric;
    if (metric == null) return null;
    final out = breached[metric];
    if (out == null) return null;
    return !out;
  }
}
