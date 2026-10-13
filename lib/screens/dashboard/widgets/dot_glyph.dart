import 'package:flutter/material.dart';

import '../../../utils/solar_irradiance.dart';
import '../utils/design_tokens.dart';

/// The sky drawn as a dot matrix, in the style of the reference panel.
///
/// ## Why dots and not an icon font
///
/// Every other glyph on this panel is a Material icon, and those are outlines.
/// The reference is not — it is a grid of discrete lamps, and the dot is the
/// thing being drawn rather than the shape it happens to trace. A sun drawn as
/// `Icons.wb_sunny` would be a different picture, not a smaller one.
///
/// **The grid is 11 x 11 and it is not decoration.** The dot size follows the
/// cell, so a glyph is exactly as many lamps as its shape uses and a wider or
/// denser shape reads as *more* light rather than as a different icon. Resizing
/// the widget rescales the whole grid: the painter divides by the row count, so
/// there is no second number to keep in step.
///
/// ## Colour
///
/// **`AppSurfaces.onSurface`, not the accent.** Red is this panel's accent and it
/// is spent on severity — a breach, a section heading, a meter fill. A sky
/// glyph is neither. `SkyState`'s own text sits beside it in the same muted ink,
/// and matching them is what makes the two read as one cell.
class DotGlyph extends StatelessWidget {
  const DotGlyph(this.condition, {super.key, this.size = 22, this.color});

  final SkyCondition condition;

  /// The square edge of the drawn grid, in logical pixels.
  ///
  /// **The box is square and the grid is square, so nothing is letterboxed.**
  final double size;

  /// Overrides the default ink. Only for a caller painting on a known surface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      // **Semantics, and the label is the condition rather than the widget.**
      // A dot matrix is unreadable to a screen reader as a shape, and the word
      // is already on the row - but a screen reader walking the row would
      // otherwise announce an unlabelled image in the middle of it.
      child: Semantics(
        label: condition.label,
        image: true,
        child: CustomPaint(
          painter: _DotMatrixPainter(
            condition: condition,
            color: color ?? AppSurfaces.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  const _DotMatrixPainter({required this.condition, required this.color});

  final SkyCondition condition;
  final Color color;

  /// The grid, one string per row, `#` a lit lamp and `.` an unlit one.
  ///
  /// **Written out as art rather than generated.** A shape that cannot be read
  /// as art cannot be reviewed as art: the sun's rays, the moon's crescent and
  /// the cloud's stepped edge are all decisions someone has to look at, and a
  /// generator would hide every one of them behind a rule. Eleven rows of
  /// `#` and `.` is also the whole diff a later change needs.
  static const int _rows = 11;

  static List<String> _gridFor(SkyCondition condition) => switch (condition) {
    SkyCondition.clear => const [
      '....#.#....',
      '...#...#...',
      '..#..#..#..',
      '....###....',
      '...#####...',
      '#...###...#',
      '....###....',
      '..#..#..#..',
      '...#...#...',
      '....#.#....',
      '...........',
    ],
    // Sun behind a sheet: the top-left of the sun is still there.
    SkyCondition.partlyCloudy => const [
      '..#........',
      '..#...#....',
      '.....#.....',
      '....###....',
      '...#####...',
      '#...#####..',
      '..#########',
      '..#########',
      '..#########',
      '..#######..',
      '...........',
    ],
    SkyCondition.overcast => const [
      '...........',
      '...........',
      '...#####...',
      '..#######..',
      '.#########.',
      '###########',
      '###########',
      '.#########.',
      '...........',
      '...........',
      '...........',
    ],
    // Crescent plus two stars, because a plain disc would read as a full moon
    // and the sky here is past dusk.
    SkyCondition.night => const [
      '..###......',
      '.#####.....',
      '######.....',
      '######.....',
      '######.....',
      '.#####.....',
      '..###......',
      '...........',
      '.....#..#..',
      '....#...#..',
      '...........',
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _gridFor(condition);
    final cell = size.shortestSide / _rows;
    // **0.42 of the cell, and the number is the style.** A dot that fills its
    // cell reads as a solid blob and the gaps vanish; one that is much under
    // half reads as dust. 0.42 leaves a clear gutter between lamps at every
    // size, so the grid still looks like a grid at 22 dp and at 96.
    final radius = cell * 0.21;
    final paint = Paint()..color = color;
    for (var y = 0; y < _rows; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        if (row[x] != '#') continue;
        canvas.drawCircle(
          Offset((x + 0.5) * cell, (y + 0.5) * cell),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter old) =>
      old.condition != condition || old.color != color;
}