import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// One label/value pair in the hero's translucent stat card.
///
/// A plain value object rather than a widget parameter set, so a screen can
/// build the list as data and the card stays the only place that decides how
/// three of them are drawn.
class GlassHeroStat {
  const GlassHeroStat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;

  /// Makes this cell a route rather than a reading.
  ///
  /// **Only the cell that names a whole view takes one.** The SOC figure is the
  /// hero's cell for the battery, and tapping it is the same question the value
  /// answers, so the affordance sits on the thing being asked about rather than
  /// on a chevron nobody notices.
  final VoidCallback? onTap;
}

/// The gradient card at the top of the dashboard.
///
/// It is the only surface in the app that is *not* a card or the page: the whole
/// card is one deep blue gradient carrying four rows of white ink and
/// translucent white fills, so it separates from the flat dark page by hue
/// rather than by a tonal step.
///
/// Everything translucent here sits on that gradient, so it needs white ink at
/// three strengths and white fill at three strengths — which is why it owns its
/// own ink ramp instead of reading the card's. The figure is baseline-aligned
/// against its unit and uses tabular figures so a value that refreshes every ten
/// seconds does not jitter the layout.
class GlassHeroCard extends StatelessWidget {
  const GlassHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.figure,
    required this.unit,
    required this.conditionLabel,
    required this.highLabel,
    required this.highValue,
    required this.lowLabel,
    required this.lowValue,
    required this.stats,
    this.trailingActions = const <Widget>[],
    this.footer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String figure;
  final String unit;
  final String conditionLabel;
  final String highLabel;
  final String highValue;
  final String lowLabel;
  final String lowValue;
  final List<GlassHeroStat> stats;

  /// Round buttons for the top-right corner, normally two. Spacing between
  /// them is the card's job so callers cannot forget it.
  final List<Widget> trailingActions;

  /// Content below the stat row, inside the card.
  ///
  /// **The date strip lives here rather than in a row of its own.** It was a
  /// separate block under the card with a header row holding nothing but its own
  /// calendar button, which read as an empty strip and put two horizontally
  /// unrelated rows a few dp apart. As a slot the dates belong to the surface
  /// that is already describing "now", and the trigger is one of the card's own
  /// actions.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    for (var i = 0; i < trailingActions.length; i++) {
      if (i > 0) actions.add(const SizedBox(width: 8));
      actions.add(trailingActions[i]);
    }

    final statCells = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        statCells.add(
          Container(
            width: 1,
            color: AppGlass.divider,
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),
        );
      }
      statCells.add(Expanded(child: _StatCell(stat: stats[i])));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppGlass.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppGlass.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppType.headlineLg.copyWith(
                        color: AppGlass.inkStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppType.bodySm.copyWith(color: AppGlass.inkSoft),
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 88, color: AppGlass.inkStrong),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            figure,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.figureHero.copyWith(
                              color: AppGlass.inkStrong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: AppType.figureUnit.copyWith(
                            color: AppGlass.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conditionLabel,
                      style: AppType.bodyLg.copyWith(color: AppGlass.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniPill(label: highLabel, value: highValue, up: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniPill(label: lowLabel, value: lowValue, up: false),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppGlass.fillSoft,
              borderRadius: BorderRadius.circular(AppRadius.stat),
            ),
            child: Row(children: statCells),
          ),
          if (footer != null) ...[
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: AppGlass.divider),
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// A circular translucent button for the hero's top-right corner.
///
/// The transparent [Material] is required, not decoration: the hero's Container
/// paints over the ink layer of any Material above it, so without it the splash
/// is invisible and the button feels dead.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.tooltip,
    this.fill,
    this.ink,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Draws the small dot that says an alert exists, without turning the button
  /// into a status badge.
  final bool badge;

  /// Long-press hint. The calendar button is the one action whose icon does not
  /// say what it acts on, so it gets the strip's own description of the current
  /// selection.
  final String? tooltip;

  /// The disc and its glyph, for a button that stands on the **page** rather
  /// than on the hero.
  ///
  /// **The defaults are hero-only and that is the reason these exist.** A 20%
  /// white wash with a white glyph is legible over the hero and nothing else:
  /// the wash has no body against the page. A page button therefore wants the
  /// card fill with card ink — `AppSurfaces.surface` /
  /// `AppSurfaces.onSurface` — which is the pairing that clears AA on the card.
  final Color? fill;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 40,
      height: 40,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Stack(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fill ?? AppGlass.fill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: ink ?? AppGlass.inkStrong),
              ),
              if (badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppGlass.arrowUp,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// The high/low pill. Its arrow is the only place in the hero where a colour
/// means a direction rather than a reading.
class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.value, required this.up});

  final String label;
  final String value;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppGlass.fill,
        borderRadius: BorderRadius.circular(AppRadius.tilePill),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              '$label: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodyMd.copyWith(color: AppGlass.ink),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            up ? Icons.north_east_rounded : Icons.south_east_rounded,
            size: 14,
            color: up ? AppGlass.arrowUp : AppGlass.arrowDown,
          ),
        ],
      ),
    );
  }
}

/// One column of the stat card: a quiet caption over a strong figure.
class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final GlassHeroStat stat;

  @override
  Widget build(BuildContext context) {
    // **Ink, not fill.** The cell sits inside a translucent wash on the hero
    // gradient, so a filled ripple would paint a solid chip over the glass and
    // break the one surface the card is made of.
    final cell = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.labelMicro.copyWith(color: AppGlass.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.numeralMd.copyWith(
            color: AppGlass.inkStrong,
          ),
        ),
      ],
    );

    if (stat.onTap == null) return cell;
    return Semantics(
      button: true,
      label: '${stat.label} ${stat.value}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: stat.onTap, child: cell),
      ),
    );
  }
}
