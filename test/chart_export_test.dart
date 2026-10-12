import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/widgets/chart_export.dart';

/// The exported chart PNG.
///
/// **The size is read out of the PNG's IHDR, not back out of the constant.** A
/// test that asserts `kChartExportSize == Size(1920, 1080)` passes even if the
/// composition stops using the constant entirely — which is the failure this
/// exists for. The first version rasterised at `pixelRatio: 3` and shipped the
/// card's logical width, about 950 px on a phone, which the user reported as "the
/// data is not visible".
///
/// IHDR rather than `ui.instantiateImageCodec` because a codec in `flutter_test`
/// has no GPU behind it and the decode never completes.
void main() {
  late GlobalKey boundaryKey;

  Future<Uint8List> compose(WidgetTester tester, {double width = 317}) async {
    boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: RepaintBoundary(
                key: boundaryKey,
                child: CustomPaint(
                  painter: _BlockPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // **Inside `runAsync`, and that is not optional.** `toImage` and the PNG
    // encode are real asynchronous work on the engine's own event loop; the test
    // binding's fake async never lets them run, so awaiting them directly hangs
    // the file until the run times out. Every test here did that once.
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final data = await tester.runAsync(
      () => composeChartImage(
        boundary,
        title: 'PV',
        subtitle: 'Last 24 hours',
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      ),
    );
    expect(data, isNotNull, reason: 'the composition produced no PNG at all');
    return data!.buffer.asUint8List();
  }

  /// Width and height as written into the PNG's IHDR chunk.
  (int, int) ihdr(Uint8List png) {
    final view = ByteData.sublistView(png);
    return (view.getUint32(16), view.getUint32(20));
  }

  testWidgets('the exported PNG is 1920 x 1080 at a phone-sized card', (
    tester,
  ) async {
    expect(ihdr(await compose(tester)), (1920, 1080));
  });

  testWidgets('the size does not depend on how wide the card is', (
    tester,
  ) async {
    // **Both a narrow card and a very wide one, because the fit is a `min` over
    // two axes and only one of them binds at a time.** A card taller than it is
    // wide is limited by the height and letterboxes horizontally; a card wider
    // than 16:9 is limited by the width and letterboxes vertically. Asserting
    // one shape only would let the other silently become a different aspect
    // ratio — which is a bug that looks like nothing at all until a user gets
    // it.
    expect(ihdr(await compose(tester, width: 317)), (1920, 1080));
    expect(ihdr(await compose(tester, width: 1200)), (1920, 1080));
    expect(ihdr(await compose(tester, width: 90)), (1920, 1080));
  });
}

/// A deliberately loud painter, so "the file is the right size" and "the file is
/// the right picture" stay separate claims.
class _BlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2),
      Paint()..color = const Color(0xFFFF0000),
    );
  }

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) => false;
}
