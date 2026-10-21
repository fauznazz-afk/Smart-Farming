import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:share_plus/share_plus.dart';

import '../utils/design_tokens.dart';

/// Exports a chart card as a PNG and hands it to the platform share sheet.
///
/// **The caption is drawn onto the image rather than screenshotted, and that is
/// the whole point of the function.** The card's own subtree carries the legend,
/// the plot and the per-series statistics, but the two things that make the
/// image *legible later* — what the chart is, and which range it covers — live
/// outside it: the title is in `ChartSectionHeader`, one widget above, and the
/// range only exists as the `semanticLabel` string. A file saved from the plot
/// alone is seven unlabelled lines, which is what makes this worth the extra
/// thirty lines rather than `RepaintBoundary.toImage()` on its own.
///
/// **Composition is a header strip, not a screenshot of the screen.** Drawing a
/// caption band in the page colour and pasting the card's own pixels under it
/// keeps the export a function of one widget: no window capture, no second
/// boundary, and nothing to keep in step if a page grows another card.
///
/// **Share sheet rather than "save to gallery".** `SharePlus` is already a
/// dependency, it needs no storage permission, and its sheet offers Files, Drive
/// and the gallery's own share target. Writing into `MediaStore` would mean a
/// permissions request and a scoped-storage path for no capability the sheet
/// does not already have.
///
/// `shortcut:` the canvas is a fixed [kChartExportSize] and the image is handed
/// over as bytes, so a very large chart is bounded only by memory. If a future
/// chart outgrows that, stream to a file in the app's own directory instead of
/// `XFile.fromData`.
Future<void> exportChartImage(
  BuildContext context,
  GlobalKey boundaryKey, {
  required String title,
  required String subtitle,
  required String fileName,
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return;

  final data = await composeChartImage(
    boundary,
    title: title,
    subtitle: subtitle,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  );
  if (data == null) return;

  await SharePlus.instance.share(
    ShareParams(
      title: title,
      subject: '$title — $subtitle',
      files: [
        XFile.fromData(Uint8List.view(data.buffer), mimeType: 'image/png'),
      ],
      fileNameOverrides: [fileName],
    ),
  );
}

/// The exported PNG's size, in pixels.
///
/// **A constant rather than a ratio, and this is the second version of that
/// decision.** The first rasterised at `pixelRatio: 3` and shipped whatever the
/// card's logical width happened to be — about 950 px on a 360 dp phone. It
/// rendered correctly and was useless: opened in a viewer, seven series across
/// that width are one pixel each and the axis labels do not read. The user's was
/// "the data is not visible".
///
/// 1920 x 1080 is the smallest size a picture of this kind survives being put
/// into a gallery, a document or a chat. Exported PNG bytes, so nothing about
/// the source is resampled on the way out.
/// **A chart card is portrait and 16:9 is not, so most of the canvas is
/// letterbox.** A card is roughly 343 x 472, which is 1.38 tall for every 1 wide;
/// fitted into 1920 x 1080 that leaves about 570 px of page colour down each
/// side. The caption is drawn inside that margin rather than above the card, so
/// the left edge of the file lines up with the left edge of the card and the
/// empty space reads as a margin instead of as a crop.
const Size kChartExportSize = Size(1920, 1080);

/// Renders [boundary] plus a drawn caption into a [kChartExportSize] PNG.
///
/// **Split out from [exportChartImage] so the size can be asserted.** Sharing is
/// a platform channel and cannot run in a test, so the claim "the file is 1920 x
/// 1080" had no check at all until the composition stood on its own — the same
/// reason `glassNavBarReservedHeightFor` exists without a `BuildContext`.
///
/// **The card is fitted and centred rather than stretched.** A chart is a plot
/// with a Y axis; stretching one to a fixed aspect ratio changes what its
/// heights mean. Letterboxing on the page colour costs a margin and keeps the
/// proportions the user was reading.
Future<ByteData?> composeChartImage(
  RenderRepaintBoundary boundary, {
  required String title,
  required String subtitle,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) async {
  const padX = 16.0;
  const gap = 4.0;

  final width = boundary.size.width;

  // **Height-driven, with a reserved gutter for the caption.** The card is
  // portrait and the canvas is not, so centring it leaves the width half empty -
  // the file was mostly page colour. Filling the height and putting the caption
  // in the leftover width uses all 1920 px.
  //
  // The width term reserves [captionGutterMin] rather than taking the whole
  // remainder, which is what keeps a card that is *not* portrait from pushing
  // the caption off the canvas: it letterboxes vertically instead, and the
  // composition below needs no second branch.
  const captionGutterMin = 220.0;
  final fit = math.min(
    (kChartExportSize.width - captionGutterMin) / width,
    kChartExportSize.height / boundary.size.height,
  );
  final captionGutterPixels = kChartExportSize.width - width * fit;

  // **Measured with the real styles, not guessed heights.** A fixed header
  // height is how a caption ends up half-drawn at a 2x system font scale — the
  // text grows and the band does not, so the export looks fine at 1.0 and is
  // cropped at 2.0. Same trap as the date strip's day-name probe.
  //
  // **Laid out against the gutter, not against the card.** The caption is drawn
  // in the margin to the card's left, so `width - padX * 2` is the wrong budget
  // twice over: it is wider than the space the caption actually has, and it is
  // wider than the gutter once the card is wide. This is that space.
  final captionLogicalWidth = math.max(
    80.0,
    captionGutterPixels / (fit < 1 ? 1.0 : fit) - padX * 2,
  );

  final titlePainter = TextPainter(
    text: TextSpan(
      text: title,
      // The token's own style, unmodified: the caption stands in for the section
      // header, and stretching its line height to make room would make the
      // exported file differ from the screen it came from.
      //
      // **Page ink, because the caption sits on the page-coloured margin.** The
      // canvas is painted `AppSurfaces.page` and `AppSurfaces.onSurface` is
      // *card* ink — navy in both ramps since the cards went near-white — which
      // measured **1.22:1** on that canvas in the dark ramp.
      style: AppType.numeralLg.copyWith(color: AppGlass.pageInkStrong),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
  )..layout(maxWidth: captionLogicalWidth);

  final subtitlePainter = TextPainter(
    text: TextSpan(
      text: subtitle,
      // The soft page ink, because the subtitle is a caption and the soft ink is
      // the caption weight: **7.32:1** on the dark sweep's top stop and
      // **8.28:1** on the flat dark page, **8.02:1** on the light page.
      style: AppType.labelMicro.copyWith(color: AppGlass.pageInkSoft),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
  )..layout(maxWidth: captionLogicalWidth);

  // **Ink extents, not `TextPainter.height`.** `height` is the laid-out line box,
  // which for a display weight is *shorter* than the glyphs inside it, so it
  // under-reports the space the caption occupies. Measured on the device, the
  // export read "PVVoltage" — the title painted straight through the legend.
  // `LineMetrics.ascent`/`descent` are the ink's own top and bottom.
  final titleInk = titlePainter.computeLineMetrics().fold<double>(
    0,
    (sum, line) => sum + line.ascent.abs() + line.descent,
  );
  final subtitleInk = subtitlePainter.computeLineMetrics().fold<double>(
    0,
    (sum, line) => sum + line.ascent.abs() + line.descent,
  );

  // **The capture ratio is the fit factor, not a round 3.** That makes the
  // source raster one output pixel per pixel — the alternative is capturing at
  // device scale and then upscaling it into the canvas, which ships a blurred
  // file that is nominally 1920 wide.
  final captureRatio = fit < 1 ? 1.0 : fit;

  final chart = await boundary.toImage(pixelRatio: captureRatio);

  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & kChartExportSize,
      Paint()..color = AppSurfaces.page,
    );

    // **Landscape: the card fills the height on the right and the caption takes
    // the margin on the left.** The card is portrait — about 343 x 472 on a
    // phone — and the canvas is 16:9, so centring it left roughly 570 px of
    // page colour down each side and a caption band above it. The user's read was
    // "make it wide", and the honest reading of that is that the frame was not
    // being used: the file was mostly empty.
    //
    // Putting the caption in that margin rather than above the card is what makes
    // the space read as a margin instead of as a crop, and it buys back the band
    // the plot was losing. The card's own aspect is untouched — a chart's
    // proportions carry its Y axis, and stretching one changes what its heights
    // mean.
    final captionGutter = captionGutterPixels;

    canvas.save();
    canvas.scale(fit);
    canvas.translate(captionGutter / fit, 0);

    // **`drawImageRect`, not `drawImage`, and this is the bug that made the card
    // come out cropped.** `drawImage` paints the image at its own *pixel*
    // dimensions in the current coordinate space; it does not take a size. The
    // canvas here is already scaled by `fit`, and the raster is already
    // `captureRatio` times the logical size, so `drawImage` drew it
    // `fit * captureRatio` times too big: the card ran off the right edge of the
    // 1920 px canvas and the bottom of the plot was cut mid-axis.
    canvas.drawImageRect(
      chart,
      Rect.fromLTWH(0, 0, chart.width.toDouble(), chart.height.toDouble()),
      Rect.fromLTWH(0, 0, width, boundary.size.height),
      Paint(),
    );

    // **The caption is painted in the same scaled space as the card, but on the
    // other side of the gutter — and those are two separate claims that were
    // confused for one.** Drawn unscaled, a 24 sp title sat in a 1134 px margin
    // at 1:1 while everything beside it was 2.3x larger: two words of caption in
    // the corner of a near-empty page, too small to read. Drawn inside the
    // card's translated space, it came out scaled correctly and sitting *on* the
    // axis labels, because the translate had already moved the origin to the
    // card's left edge. So: same `scale`, no `translate`.
    canvas.save();
    canvas.scale(fit);
    final captionTop =
        (boundary.size.height - (titleInk + gap + subtitleInk)) / 2;
    titlePainter.paint(canvas, Offset(padX, captionTop));
    subtitlePainter.paint(canvas, Offset(padX, captionTop + titleInk + gap));
    canvas.restore();

    titlePainter.dispose();
    subtitlePainter.dispose();

    final composed = await recorder.endRecording().toImage(
      kChartExportSize.width.round(),
      kChartExportSize.height.round(),
    );
    final data = await composed.toByteData(format: ui.ImageByteFormat.png);
    composed.dispose();
    return data;
  } finally {
    chart.dispose();
  }
}
