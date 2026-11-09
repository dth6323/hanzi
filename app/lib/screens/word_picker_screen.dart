import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/text_utils.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WordPickerScreen extends StatefulWidget {
  final String title;
  final Future<List<Word>> future;
  const WordPickerScreen({super.key, required this.title, required this.future});

  @override
  State<WordPickerScreen> createState() => _WordPickerScreenState();
}

class _WordPickerScreenState extends State<WordPickerScreen> {
  final Set<int> _selectedIds = {};
  String _filter = '';

  List<String> _extractChars(List<Word> words) {
    final seen = <String>{};
    final out = <String>[];
    for (final w in words) {
      if (_selectedIds.contains(w.id)) {
        for (final c in cjkChars(w.simp)) {
          if (seen.add(c)) out.add(c);
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Word>>(
      future: widget.future,
      builder: (context, snap) {
        final all = snap.data;
        final filtered = all == null
            ? const <Word>[]
            : _filter.isEmpty
                ? all
                : all
                    .where((w) =>
                        w.simp.contains(_filter) ||
                        w.pinyin.toLowerCase().contains(_filter) ||
                        w.shortMean.toLowerCase().contains(_filter))
                    .toList();
        final chars = all == null ? const <String>[] : _extractChars(all);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              if (all != null && all.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length >= 20) {
                        _selectedIds.clear();
                      } else {
                        for (final w in filtered.take(20)) {
                          _selectedIds.add(w.id);
                        }
                      }
                    });
                  },
                  child: Text(
                      _selectedIds.length >= 20 ? 'Bỏ chọn' : '+20 từ đầu'),
                ),
            ],
          ),
          body: all == null
              ? const Loading()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        onChanged: (v) =>
                            setState(() => _filter = v.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Lọc nhanh trong danh sách…',
                          prefixIcon: Icon(Icons.filter_list_rounded),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          final w = filtered[i];
                          final checked = _selectedIds.contains(w.id);
                          return CheckboxListTile(
                            value: checked,
                            activeColor: AppColors.primary,
                            onChanged: (_) {
                              setState(() {
                                if (checked) {
                                  _selectedIds.remove(w.id);
                                } else {
                                  _selectedIds.add(w.id);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                Text(w.simp,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(w.pinyin,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.gold, fontSize: 14)),
                                ),
                              ],
                            ),
                            subtitle: Text(w.shortMean,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                            secondary: IconButton(
                              tooltip: 'Luyện ngay từ này',
                              icon: const Icon(Icons.draw_rounded,
                                  color: AppColors.gold),
                              onPressed: () =>
                                  Navigator.pop(context, cjkChars(w.simp)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: chars.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, chars),
                      icon: const Icon(Icons.draw_rounded),
                      label: Text(
                        'Luyện viết ${_selectedIds.length} từ đã chọn (${chars.length} chữ Hán)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
