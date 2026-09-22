import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

import '../../../../core/source/chinese_search_dictionary.dart';

/// Locally matched candidates; typing never sends a search request.
class ChineseSearchSuggestions extends StatefulWidget {
  const ChineseSearchSuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.sourceId,
    required this.onSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? sourceId;
  final ValueChanged<String>? onSelected;

  @override
  State<ChineseSearchSuggestions> createState() =>
      _ChineseSearchSuggestionsState();
}

class _ChineseSearchSuggestionsState extends State<ChineseSearchSuggestions> {
  List<ChineseSearchEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await ChineseSearchDictionary.load();
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      // Explicit submission retains the dictionary error and retry flow.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.focusNode]),
    builder: (context, _) {
      final value = widget.controller.value;
      if (!widget.focusNode.hasFocus ||
          widget.sourceId == null ||
          (value.composing.isValid && !value.composing.isCollapsed)) {
        return const SizedBox.shrink();
      }
      final entries = ChineseSearchDictionary.suggest(
        _entries,
        value.text,
        widget.sourceId!,
      );
      if (entries.isEmpty) return const SizedBox.shrink();
      // Treat desktop mouse clicks on candidates as part of the text field.
      // Otherwise pointer-down unfocuses it and removes the chip before tap-up.
      return TextFieldTapRegion(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('中文候选 · 左右滑动，点击搜索'),
              const SizedBox(height: 4),
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    ...ScrollConfiguration.of(context).dragDevices,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(entry.label),
                            tooltip: entry.keywordFor(widget.sourceId!),
                            onPressed: widget.onSelected == null
                                ? null
                                : () => widget.onSelected!(
                                    entry.keywordFor(widget.sourceId!)!,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
