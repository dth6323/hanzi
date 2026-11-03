import 'dart:async';

import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/text_utils.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';

class WritingHome extends StatefulWidget {
  const WritingHome({super.key});
  @override
  State<WritingHome> createState() => _WritingHomeState();
}

class _WritingHomeState extends State<WritingHome> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Word>? _searchResults;
  final List<Word> _selectedWords = [];
  List<Map<String, Object?>> _stats = [];
  List<Map<String, Object?>> _favs = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = await UserDb.instance.writingStats();
    final f = await UserDb.instance.favorites();
    if (mounted) {
      setState(() {
        _stats = s;
        _favs = f;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final res = await DictDb.instance.search(v, limit: 20);
      if (mounted) setState(() => _searchResults = res);
    });
  }

  void _toggleWord(Word w) {
    setState(() {
      final idx = _selectedWords.indexWhere((e) => e.id == w.id);
      if (idx >= 0) {
        _selectedWords.removeAt(idx);
      } else {
        _selectedWords.add(w);
      }
    });
  }

  List<String> get _selectedChars {
    final seen = <String>{};
    final out = <String>[];
    for (final w in _selectedWords) {
      for (final c in cjkChars(w.simp)) {
        if (seen.add(c)) out.add(c);
      }
    }
    return out;
  }

  Future<void> _open(List<String> chars, {String? title}) async {
    if (chars.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PracticeScreen(chars: chars, title: title),
      ),
    );
    _refresh();
  }

  Future<void> _openWordSelector({
    required String title,
    required Future<List<Word>> future,
  }) async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _WordPickerScreen(title: title, future: future),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      _open(picked, title: title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weak = _stats.where((s) => (s['best'] as int) < 70).toList();
    final selChars = _selectedChars;
    final totalAttempts = _stats.fold<int>(
        0, (sum, s) => sum + ((s['attempts'] as int?) ?? 0));
    final masteredChars =
        _stats.where((s) => ((s['best'] as int?) ?? 0) >= 85).length;

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, selChars.isNotEmpty ? 96 : 24),
            children: [
              const Text('Luyện viết',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Tìm và chọn các từ vựng muốn luyện viết theo thứ tự nét',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(
                        '$totalAttempts', 'Tổng lần đã viết ✍️', AppColors.gold),
                    _statItem('${_stats.length}', 'Số chữ đã tập',
                        AppColors.primary),
                    _statItem(
                        '$masteredChars', 'Viết đẹp (≥85đ)', AppColors.hint),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('practice_input'),
                controller: _ctrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm từ để chọn (chữ Hán, pinyin, nghĩa) hoặc gõ chữ…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ctrl.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                      if (hasCjk(_ctrl.text))
                        IconButton(
                          tooltip: 'Luyện ngay chữ vừa gõ',
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.primary),
                          onPressed: () => _open(cjkChars(_ctrl.text)),
                        ),
                    ],
                  ),
                ),
                onSubmitted: (v) {
                  if (hasCjk(v)) _open(cjkChars(v));
                },
              ),
              if (_selectedWords.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in _selectedWords)
                      InputChip(
                        label: Text('${w.simp} (${w.pinyin})'),
                        selected: true,
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.25),
                        onDeleted: () => _toggleWord(w),
                      ),
                    TextButton(
                      onPressed: () => setState(_selectedWords.clear),
                      child: const Text('Xoá chọn'),
                    ),
                  ],
                ),
              ],
              if (_searchResults != null) ...[
                const SectionTitle('Bấm chọn các từ để đưa vào danh sách luyện'),
                if (_searchResults!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Không tìm thấy từ phù hợp',
                        style: TextStyle(color: AppColors.muted)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < _searchResults!.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          _selectableWordTile(_searchResults![i]),
                        ],
                      ],
                    ),
                  ),
              ],
              if (_favs.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(child: SectionTitle('Từ trong Sổ tay')),
                    TextButton.icon(
                      onPressed: () {
                        final chars = <String>[];
                        final seen = <String>{};
                        for (final f in _favs) {
                          for (final c in cjkChars((f['simp'] as String?) ?? '')) {
                            if (seen.add(c)) chars.add(c);
                          }
                        }
                        _open(chars, title: 'Luyện viết Sổ tay');
                      },
                      icon: const Icon(Icons.draw_rounded, size: 16),
                      label: const Text('Luyện tất cả'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _favs.take(20))
                      FilterChip(
                        label: Text(
                            '${f['simp']} (${(f['pinyin'] as String?) ?? ''})'),
                        selected: _selectedWords
                            .any((w) => w.id == (f['word_id'] as int)),
                        onSelected: (_) => _toggleWord(Word(
                          id: f['word_id'] as int,
                          simp: (f['simp'] as String?) ?? '',
                          trad: '',
                          pinyin: (f['pinyin'] as String?) ?? '',
                          hanviet: '',
                          shortMean: (f['mean'] as String?) ?? '',
                        )),
                      ),
                  ],
                ),
              ],
              if (weak.isNotEmpty) ...[
                const SectionTitle('Cần ôn lại'),
                _charStrip(weak.map((s) => s['char'] as String).toList(),
                    title: 'Ôn chữ viết yếu'),
              ],
              const SectionTitle('Chọn từ theo cấp HSK'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  for (var lv = 1; lv <= 6; lv++) _hskCard(lv),
                ],
              ),
              if (_stats.isNotEmpty) ...[
                const SectionTitle('Đã luyện gần đây'),
                _charStrip(
                  _stats.take(30).map((s) => s['char'] as String).toList(),
                  scores: {
                    for (final s in _stats)
                      s['char'] as String: s['best'] as int
                  },
                  attempts: {
                    for (final s in _stats)
                      s['char'] as String: (s['attempts'] as int?) ?? 1
                  },
                ),
              ],
            ],
          ),
          if (selChars.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _open(
                  selChars,
                  title:
                      'Luyện ${_selectedWords.length} từ (${selChars.length} chữ)',
                ),
                icon: const Icon(Icons.draw_rounded),
                label: Text(
                  'Bắt đầu luyện ${_selectedWords.length} từ (${selChars.length} chữ Hán)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectableWordTile(Word w) {
    final checked = _selectedWords.any((e) => e.id == w.id);
    return CheckboxListTile(
      value: checked,
      activeColor: AppColors.primary,
      onChanged: (_) => _toggleWord(w),
      title: Row(
        children: [
          Text(w.simp,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(w.pinyin,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.gold, fontSize: 14)),
          ),
        ],
      ),
      subtitle: Text(w.shortMean,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      secondary: IconButton(
        tooltip: 'Luyện riêng từ này',
        icon: const Icon(Icons.play_arrow_rounded, color: AppColors.gold),
        onPressed: () => _open(cjkChars(w.simp), title: w.simp),
      ),
    );
  }

  Widget _hskCard(int lv) {
    final color = AppColors.hskColor(lv);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openWordSelector(
        title: 'Chọn từ HSK $lv để luyện viết',
        future: DictDb.instance.wordsByHsk(lv),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.08)
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('HSK',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            Text('$lv',
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const Text('Chọn từ',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String val, String label, Color color) => Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      );

  Widget _charStrip(
    List<String> chars, {
    String? title,
    Map<String, int>? scores,
    Map<String, int>? attempts,
  }) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chars.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = chars[i];
          final sc = scores?[c];
          final att = attempts?[c];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => title != null
                ? _open(chars.sublist(i) + chars.sublist(0, i), title: title)
                : _open([c]),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(14)),
              child: Stack(children: [
                Center(
                    child: Text(c,
                        style: const TextStyle(
                            fontSize: 32, color: AppColors.ink))),
                if (att != null && att > 0)
                  Positioned(
                    left: 5,
                    top: 3,
                    child: Text('${att}x',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.userInk)),
                  ),
                if (sc != null)
                  Positioned(
                    right: 4,
                    bottom: 2,
                    child: Text('$scđ',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color:
                                sc >= 70 ? AppColors.hint : AppColors.error)),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _WordPickerScreen extends StatefulWidget {
  final String title;
  final Future<List<Word>> future;
  const _WordPickerScreen({required this.title, required this.future});

  @override
  State<_WordPickerScreen> createState() => _WordPickerScreenState();
}

class _WordPickerScreenState extends State<_WordPickerScreen> {
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
