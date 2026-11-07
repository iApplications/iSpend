import 'package:flutter/material.dart';

import '../../expenses/data/expense_model.dart';
import '../data/tag_rules.dart';

/// Chips for an expense's tags, a field to add more, and suggestions taken
/// from the user's own history (matched on-device, nothing is sent anywhere).
class TagEditor extends StatefulWidget {
  const TagEditor({
    required this.tags,
    required this.controller,
    required this.history,
    required this.merchant,
    required this.onChanged,
    super.key,
  });

  final List<String> tags;

  /// Owned by the parent so a tag typed but not yet added is still saved.
  final TextEditingController controller;
  final List<Expense> history;

  /// The merchant typed so far; tags used with it before are suggested first.
  final String merchant;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  List<String> get _known => [
    for (final entry in tagUsage(widget.history)) entry.key,
  ];

  /// Adds every comma-separated tag in [text]; tags that do not fit stay out.
  void _add(String text) {
    final next = normalizeTags([
      ...widget.tags,
      ...text.split(','),
    ], known: _known);
    widget.controller.clear();
    if (next.length != widget.tags.length ||
        !next.every(widget.tags.contains)) {
      widget.onChanged(next);
    }
  }

  void _remove(String tag) =>
      widget.onChanged([...widget.tags.where((t) => t != tag)]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = widget.tags.length >= maxTagsPerExpense;
    final suggestions = full
        ? const <String>[]
        : suggestTags(
            history: widget.history,
            merchant: widget.merchant,
            selected: widget.tags,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          enabled: !full,
          textInputAction: TextInputAction.done,
          maxLength: maxTagLength * 4,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          decoration: InputDecoration(
            labelText: 'Tags',
            hintText: full
                ? 'Up to $maxTagsPerExpense tags'
                : 'Add a tag, then press done',
            prefixIcon: const Icon(Icons.sell_outlined),
            suffixIcon: IconButton(
              tooltip: 'Add tag',
              icon: const Icon(Icons.add),
              onPressed: full ? null : () => _add(widget.controller.text),
            ),
          ),
          onSubmitted: _add,
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => _remove(tag),
                  deleteButtonTooltipMessage: 'Remove $tag',
                ),
            ],
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Suggestions', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in suggestions)
                ActionChip(label: Text(tag), onPressed: () => _add(tag)),
            ],
          ),
        ],
      ],
    );
  }
}
