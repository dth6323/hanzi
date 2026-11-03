import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/text_utils.dart';
import '../data/user_db.dart';
import '../theme.dart';
import 'practice_screen.dart';

class WritingHome extends StatefulWidget {
  const WritingHome({super.key});
  @override
  State<WritingHome> createState() => _WritingHomeState();
}

class _WritingHomeState extends State<WritingHome> {
  final _ctrl = TextEditingController();
  List<Map<String, Object?>> _stats = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await UserDb.instance.writingStats();
    if (mounted) setState(() => _stats = s);
  }

  Future<void> _open(List<String> chars, {String? title}) async {
    if (chars.isEmpty) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PracticeScreen(chars: chars, title: title)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final weak = _stats.where((s) => (s['best'] as int) < 70).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text('Luyện viết',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Viết theo thứ tự nét, chấm điểm từng nét',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('practice_input'),
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'Nhập chữ muốn luyện, VD: 你好中国',
              prefixIcon: const Icon(Icons.edit_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: AppColors.primary),
                onPressed: () => _open(cjkChars(_ctrl.text)),
              ),
            ),
            onSubmitted: (v) => _open(cjkChars(v)),
          ),
          if (weak.isNotEmpty) ...[
            const SectionTitle('Cần ôn lại'),
            _charStrip(weak.map((s) => s['char'] as String).toList(),
                title: 'Ôn chữ viết yếu'),
          ],
          const SectionTitle('Chữ theo cấp HSK'),
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
            _charStrip(_stats.take(30).map((s) => s['char'] as String).toList(),
                scores: {
                  for (final s in _stats) s['char'] as String: s['best'] as int
                }),
          ],
        ],
      ),
    );
  }

  Widget _hskCard(int lv) {
    final color = AppColors.hskColor(lv);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final chars = await DictDb.instance.charsForHsk(lv);
        _open(chars, title: 'Chữ HSK $lv');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.08)],
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
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _charStrip(List<String> chars,
      {String? title, Map<String, int>? scores}) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chars.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = chars[i];
          final sc = scores?[c];
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
                if (sc != null)
                  Positioned(
                    right: 4,
                    bottom: 2,
                    child: Text('$sc',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: sc >= 70 ? AppColors.hint : AppColors.error)),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
