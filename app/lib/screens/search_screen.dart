import 'dart:async';

import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ocr_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Word>? _results;
  List<Map<String, Object?>> _history = [];
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await UserDb.instance.history();
    if (mounted) setState(() => _history = h);
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(v));
  }

  Future<void> _run(String v) async {
    final seq = ++_seq;
    if (v.trim().isEmpty) {
      setState(() => _results = null);
      _loadHistory();
      return;
    }
    final r = await DictDb.instance.search(v);
    if (mounted && seq == _seq) setState(() => _results = r);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(children: [
                const Text('汉',
                    style: TextStyle(
                        fontSize: 30,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                const Text('Từ điển Trung – Việt',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 0.8),
                  ),
                  child: const Text('v1.0.0',
                      style: TextStyle(fontSize: 11, color: AppColors.gold, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                key: const Key('search_input'),
                controller: _ctrl,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Chữ Hán, pinyin, Hán Việt hoặc nghĩa…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ctrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            _run('');
                          },
                        ),
                      IconButton(
                        tooltip: 'Quét ảnh / Chụp màn hình OCR',
                        icon: const Icon(Icons.document_scanner_rounded,
                            color: AppColors.gold),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            appRoute((_) => const OcrScreen()),
                          );
                          _loadHistory();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final r = _results;
    if (r == null) {
      if (_history.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Thử gõ: 你好 · nihao · hảo · xin chào',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Row(children: [
            const Expanded(child: SectionTitle('Tra gần đây')),
            TextButton(
                onPressed: () async {
                  await UserDb.instance.clearHistory();
                  _loadHistory();
                },
                child: const Text('Xoá')),
          ]),
          for (final h in _history)
            WordTile(
                id: h['word_id'] as int,
                simp: h['simp'] as String,
                pinyin: (h['pinyin'] as String?) ?? '',
                mean: (h['mean'] as String?) ?? ''),
        ],
      );
    }
    if (r.isEmpty) {
      return const Center(
          child: Text('Không tìm thấy kết quả',
              style: TextStyle(color: AppColors.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: r.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) => WordTile.fromWord(r[i]),
    );
  }
}
