import 'package:eyesense/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Renders the subset of Markdown used by the bundled legal documents.
///
/// A general Markdown package is deliberately avoided: the documents are ours,
/// so the grammar is known and bounded, and what matters here is the semantics
/// a screen reader receives. Headings are announced as headings so TalkBack's
/// heading navigation can jump between sections, and tables are flattened into
/// labelled rows rather than presented as a grid, because a pipe table read
/// cell-by-cell is unintelligible aloud.
class LegalMarkdown extends StatelessWidget {
  final String source;

  const LegalMarkdown({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _parse(source, context),
    );
  }

  static List<Widget> _parse(String source, BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.eyeColors;
    final widgets = <Widget>[];
    final lines = source.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();

      if (line.trim().isEmpty) continue;

      if (line.trim() == '---') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: colors.border, height: 1),
        ));
        continue;
      }

      if (line.startsWith('|')) {
        final rows = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          rows.add(lines[i].trim());
          i++;
        }
        i--;
        widgets.addAll(_table(rows, context));
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final style = switch (level) {
          1 => text.headlineMedium,
          2 => text.titleLarge,
          3 => text.titleMedium?.copyWith(color: colors.accent),
          _ => text.titleSmall,
        };
        widgets.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 0 : 28, bottom: 12),
          child: Semantics(
            header: true,
            child: Text(heading.group(2)!, style: style),
          ),
        ));
        continue;
      }

      if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(left: BorderSide(color: colors.accent, width: 4)),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(AppTheme.radiusMedium),
            ),
          ),
          child: Text.rich(_inline(line.substring(2), text.bodyLarge, colors)),
        ));
        continue;
      }

      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Decorative: the list item is already announced as one node, so
              // the glyph must not be read out as part of the sentence.
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Text('\u2022', style: text.bodyLarge?.copyWith(color: colors.accent)),
                ),
              ),
              Expanded(
                child: Text.rich(_inline(bullet.group(1)!, text.bodyLarge, colors)),
              ),
            ],
          ),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text.rich(_inline(line, text.bodyLarge, colors)),
      ));
    }

    return widgets;
  }

  /// Flattens a pipe table into one labelled block per row.
  ///
  /// Every cell is paired with its column heading, so a listener hears
  /// "Read Text. What happens to the image: captured, analysed on your
  /// device..." instead of a stream of delimiters.
  static List<Widget> _table(List<String> rows, BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.eyeColors;

    List<String> cells(String row) => row
        .split('|')
        .map((cell) => cell.trim())
        .toList()
      ..removeWhere((cell) => cell.isEmpty);

    if (rows.isEmpty) return const [];
    final headers = cells(rows.first);
    final body = rows
        .skip(1)
        .where((row) => !RegExp(r'^\|[\s:\-|]+\|?$').hasMatch(row))
        .map(cells)
        .where((row) => row.isNotEmpty)
        .toList();

    return [
      for (final row in body)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                _inline(row.first, text.titleSmall?.copyWith(color: colors.accent), colors),
              ),
              for (var c = 1; c < row.length; c++) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: [
                    if (c < headers.length)
                      TextSpan(
                        text: '${headers[c]}: ',
                        style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                      ),
                    _inline(row[c], text.bodyLarge, colors),
                  ]),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  /// Handles `**bold**`, `` `code` `` and `[label](target)`.
  ///
  /// Link targets are dropped rather than spoken: the documents always write a
  /// human-readable label, and reading a full URL aloud is noise.
  static TextSpan _inline(String raw, TextStyle? base, EyeSenseColors colors) {
    final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|\[(.+?)\]\((.+?)\)');
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(raw)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: raw.substring(cursor, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(color: colors.accent, fontFamily: 'monospace'),
        ));
      } else {
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(color: colors.accent, decoration: TextDecoration.underline),
        ));
      }
      cursor = match.end;
    }

    if (cursor < raw.length) spans.add(TextSpan(text: raw.substring(cursor)));
    return TextSpan(style: base, children: spans);
  }
}
