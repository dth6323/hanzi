import 'dart:async';

import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/text_utils.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pronunciation_sheet.dart';
import 'practice_screen.dart';

class SentencePracticeScreen extends StatefulWidget {
  final int? initialHsk;
  const SentencePracticeScreen({super.key, this.initialHsk});

  @override
  State<SentencePracticeScreen> createState() => _SentencePracticeScreenState();
}

class _SentencePracticeScreenState extends State<SentencePracticeScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int? _selectedHsk;
  bool _loading = true;
  List<Example> _sentences = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedHsk = widget.initialHsk;
    _fetchSentences();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSentences() async {
    setState(() => _loading = true);
    List<Example> items;
    if (_query.isNotEmpty) {
      items = await DictDb.instance.searchExamples(_query, limit: 50);
    } else if (_selectedHsk != null) {
      items = await DictDb.instance.examplesByHsk(_selectedHsk!, limit: 50);
    } else {
      items = await DictDb.instance.recommendedExamples(limit: 40);
    }
    if (mounted) {
      setState(() {
        _sentences = items;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = val.trim();
      if (q != _query) {
        _query = q;
        _fetchSentences();
      }
    });
  }

  void _selectHsk(int? hsk) {
    if (_selectedHsk == hsk && _query.isEmpty) return;
    setState(() {
      _selectedHsk = hsk;
      _query = '';
      _searchCtrl.clear();
    });
    _fetchSentences();
  }

  void _openPractice(Example ex) {
    final chars = cjkCharsOrdered(ex.zh);
    if (chars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có chữ Hán trong câu này')),
      );
      return;
    }
    Navigator.push(
      context,
      appRoute((_) => PracticeScreen(
            chars: chars,
            title: 'Luyện viết câu',
            example: ex,
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện viết theo câu ví dụ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới danh sách',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSentences,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm câu theo chữ Hán, pinyin hoặc nghĩa…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _query = '';
                          _fetchSentences();
                        },
                      )
                    : null,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Gợi ý'),
                  selected: _selectedHsk == null && _query.isEmpty,
                  onSelected: (_) => _selectHsk(null),
                ),
                const SizedBox(width: 8),
                for (var lv = 1; lv <= 6; lv++) ...[
                  FilterChip(
                    label: Text('HSK $lv'),
                    selected: _selectedHsk == lv && _query.isEmpty,
                    onSelected: (_) => _selectHsk(lv),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Loading()
                : _sentences.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_off_rounded,
                                size: 56, color: AppColors.muted),
                            const SizedBox(height: 12),
                            const Text(
                              'Không tìm thấy câu ví dụ phù hợp',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _sentences.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _sentenceTile(_sentences[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sentenceTile(Example ex) {
    final chars = cjkCharsOrdered(ex.zh);
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ex.zh,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                SpeakButton(ex.zh, size: 20),
              ],
            ),
            if (ex.pinyin.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ex.pinyin,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (ex.mean.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                ex.mean,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    '${chars.length} chữ Hán',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.mic_none_rounded, size: 16),
                  label: const Text('Luyện nói'),
                  onPressed: () => showPronunciationSheet(
                    context,
                    zh: ex.zh,
                    pinyin: ex.pinyin,
                    mean: ex.mean,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.draw_rounded, size: 16),
                  label: const Text(
                    'Luyện viết',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _openPractice(ex),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
