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
  const padY = 16.0;
  const gap = 4.0;

  final width = boundary.size.width;

  // **Measured with the real styles, not guessed heights.** A fixed header
  // height is how a caption ends up half-drawn at a 2x system font scale — the
  // text grows and the band does not, so the export looks fine at 1.0 and is
  // cropped at 2.0. Same trap as the date strip's day-name probe.
  final titlePainter = TextPainter(
    text: TextSpan(
      text: title,
      // The token's own style, unmodified: the caption stands in for the section
      // header, and stretching its line height to make room would make the
      // exported file differ from the screen it came from.
      style: AppType.numeralLg.copyWith(color: AppSurfaces.onSurface),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
  )..layout(maxWidth: width - padX * 2);

  final subtitlePainter = TextPainter(
    text: TextSpan(
      text: subtitle,
      style: AppType.labelMicro.copyWith(color: AppSurfaces.onSurfaceVariant),
    ),
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 2,
  )..layout(maxWidth: width - padX * 2);

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
  final titleBottom = padY + titleInk;
  final headerHeight = titleBottom + gap + subtitleInk + padY;
  final logical = Size(width, headerHeight + boundary.size.height);

  // **The capture ratio is the fit factor, not a round 3.** That makes the
  // source raster one output pixel per pixel — the alternative is capturing at
  // device scale and then upscaling it into the canvas, which ships a blurred
  // file that is nominally 1920 wide.
  final fit = math.min(
    kChartExportSize.width / logical.width,
    kChartExportSize.height / logical.height,
  );
  final captureRatio = fit < 1 ? 1.0 : fit;

  final chart = await boundary.toImage(pixelRatio: captureRatio);
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & kChartExportSize,
      Paint()..color = AppSurfaces.page,
    );
    canvas.scale(fit);
    canvas.translate(
      (kChartExportSize.width / fit - logical.width) / 2,
      (kChartExportSize.height / fit - logical.height) / 2,
    );
    // **Below the caption, not at the origin.** The card's own first row is the
    // legend; pasted at `Offset.zero` it printed straight through the title.
    canvas.drawImage(chart, Offset(0, headerHeight), Paint());
    titlePainter.paint(canvas, const Offset(padX, padY));
    subtitlePainter.paint(canvas, Offset(padX, titleBottom + gap));
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
