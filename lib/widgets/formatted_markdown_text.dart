import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../screens/dashboard/utils/design_tokens.dart';

/// Lightweight markdown-like text parser for AI assistant responses.
///
/// Supports:
/// - Bold (`**text**` or `__text__`)
/// - Italic (`*text*` or `_text_`)
/// - Inline code (`` `code` ``)
/// - Bulleted lists (`- item` or `* item`)
/// - Numbered lists (`1. item`)
/// - Section headers (`### Header` or `## Header` or `# Header`)
/// - Code blocks (` ```language ... ``` `)
class FormattedMarkdownText extends StatelessWidget {
  const FormattedMarkdownText({
    super.key,
    required this.text,
    this.baseStyle,
    this.isUser = false,
  });

  final String text;
  final TextStyle? baseStyle;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = baseStyle ?? AppType.bodyMd;
    final lines = text.split('\n');
    final widgets = <Widget>[];

    var inCodeBlock = false;
    final codeBlockLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_buildCodeBlock(codeBlockLines.join('\n')));
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headers
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            trimmed.substring(4),
            style: AppType.labelUppercase.copyWith(
              color: AppPalette.error,
              letterSpacing: 0.5,
            ),
          ),
        ));
        continue;
      }
      if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final content = trimmed.startsWith('## ')
            ? trimmed.substring(3)
            : trimmed.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            content,
            style: AppType.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
        continue;
      }

      // Unordered list
      final bulletMatch = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 8),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isUser ? AppSurfaces.onSurface : AppPalette.error,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text.rich(
                  _parseInlineSpans(bulletMatch.group(1)!, defaultStyle),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Numbered list
      final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: Text(
                  '${numMatch.group(1)}.',
                  style: defaultStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isUser ? AppSurfaces.onSurface : AppPalette.error,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  _parseInlineSpans(numMatch.group(2)!, defaultStyle),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // Normal paragraph line
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text.rich(_parseInlineSpans(line, defaultStyle)),
      ));
    }

    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeBlockLines.join('\n')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppSurfaces.page,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: AppBorders.hairlineBorder,
      ),
      child: SelectableText(
        code,
        style: AppType.bodySm.copyWith(
          fontFamily: AppType.mono,
          color: AppSurfaces.onSurface,
        ),
      ),
    );
  }

  TextSpan _parseInlineSpans(String raw, TextStyle base) {
    final spans = <InlineSpan>[];

    // Regex matches: block math $$...$$, inline math $...$, inline code `code`, bold **text**, italic *text*
    final inlineRegex = RegExp(
      r'\$\$([^$]+)\$\$|\$([^$]+)\$|`([^`]+)`|\*\*([^*]+)\*\*|\*([^*]+)\*',
    );

    var currentIndex = 0;
    for (final match in inlineRegex.allMatches(raw)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: raw.substring(currentIndex, match.start),
          style: base,
        ));
      }

      final blockMath = match.group(1);
      final inlineMath = match.group(2);
      final code = match.group(3);
      final bold = match.group(4);
      final italic = match.group(5);

      if (blockMath != null) {
        // Block math - render as centered math widget
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Math.tex(
                blockMath,
                textStyle: base.copyWith(fontSize: (base.fontSize ?? 13) * 1.1),
              ),
            ),
          ),
        ));
      } else if (inlineMath != null) {
        // Inline math - render inline
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            inlineMath,
            textStyle: base.copyWith(fontSize: (base.fontSize ?? 13) * 0.95),
          ),
        ));
      } else if (code != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppSurfaces.surfaceMuted,
              borderRadius: BorderRadius.circular(4),
              border: AppBorders.hairlineBorder,
            ),
            child: Text(
              code,
              style: AppType.bodySm.copyWith(
                fontFamily: AppType.mono,
                fontSize: (base.fontSize ?? 13) * 0.9,
              ),
            ),
          ),
        ));
      } else if (bold != null) {
        spans.add(TextSpan(
          text: bold,
          style: base.copyWith(
            fontWeight: FontWeight.w800,
            color: isUser ? AppSurfaces.onSurface : null,
          ),
        ));
      } else if (italic != null) {
        spans.add(TextSpan(
          text: italic,
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      }

      currentIndex = match.end;
    }

    if (currentIndex < raw.length) {
      spans.add(TextSpan(
        text: raw.substring(currentIndex),
        style: base,
      ));
    }

    return TextSpan(children: spans);
  }
}
