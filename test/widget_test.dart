import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plts_monitoring/widgets/brand_logo.dart';

void main() {
  testWidgets('brand logo renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLogo(size: 64))),
    );
    expect(find.byType(BrandLogo), findsOneWidget);
  });
}