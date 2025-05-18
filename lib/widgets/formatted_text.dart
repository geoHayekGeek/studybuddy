import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class FormattedText extends StatelessWidget {
  final String content;
  final TextStyle? defaultStyle;

  const FormattedText({
    super.key,
    required this.content,
    this.defaultStyle,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: defaultStyle ?? Theme.of(context).textTheme.bodyMedium,
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        code: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        blockquote: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
      builders: {
        'code': CodeElementBuilder(),
      },
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceAll('language-', '');
    final code = element.textContent;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (language != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                language.toUpperCase(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}