import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/widgets/formatted_markdown_text.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('FormattedMarkdownText', () {
    testWidgets('renders bold text properly', (tester) async {
      await tester.pumpWidget(wrap(
        const FormattedMarkdownText(text: 'Daya saat ini **1250 W** stabil.'),
      ));

      expect(find.textContaining('1250 W'), findsOneWidget);

      final richText = tester.widget<RichText>(find.byType(RichText));
      final textSpan = richText.text as TextSpan;

      bool foundBold = false;
      textSpan.visitChildren((span) {
        if (span is TextSpan && span.text == '1250 W' && span.style?.fontWeight == FontWeight.w800) {
          foundBold = true;
          return false;
        }
        return true;
      });
      expect(foundBold, isTrue);
    });

    testWidgets('renders list bullet items', (tester) async {
      await tester.pumpWidget(wrap(
        const FormattedMarkdownText(text: '- Item 1\n- Item 2'),
      ));

      expect(find.textContaining('Item 1'), findsOneWidget);
      expect(find.textContaining('Item 2'), findsOneWidget);
    });

    testWidgets('renders code block correctly', (tester) async {
      await tester.pumpWidget(wrap(
        const FormattedMarkdownText(text: '```\npower = 100\n```'),
      ));

      expect(find.text('power = 100'), findsOneWidget);
    });
  });
}
