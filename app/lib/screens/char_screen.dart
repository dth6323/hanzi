import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../writing/hanzi_canvas.dart';
import 'practice_screen.dart';

class CharScreen extends StatefulWidget {
  final String char;
  const CharScreen({super.key, required this.char});
  @override
  State<CharScreen> createState() => _CharScreenState();
}

class _CharScreenState extends State<CharScreen> {
  late final Future<_CharData?> _future = _load();
  final _canvas = GlobalKey<HanziCanvasState>();

  Future<_CharData?> _load() async {
    final db = DictDb.instance;
    final c = await db.char(widget.char);
    if (c == null) return null;
    final results = await Future.wait([
      db.wordsContainingChar(widget.char),
      c.radical != null && c.radical!.isNotEmpty
          ? db.charsByRadical(c.radical!, exclude: c.char)
          : Future.value(<HanChar>[]),
    ]);
    return _CharData(
      c,
      results[0] as List<Word>,
      results[1] as List<HanChar>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(title: Text('Chữ ${widget.char}')),
          body: Stack(
            children: [
              FutureBuilder<_CharData?>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Loading();
                  }
                  final d = snap.data;
                  if (d == null) {
                    return const Center(child: Text('Chưa có dữ liệu chữ này'));
                  }
                  final c = d.char;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    children: [
                      if (c.canWrite) ...[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Container(
                              decoration: BoxDecoration(
                                  color: AppColors.paper,
                                  borderRadius: BorderRadius.circular(16)),
                              child: HanziCanvas(
                                  key: _canvas, char: c, mode: WriteMode.watch),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('Xem lại nét'),
                              onPressed: () => _canvas.currentState?.animate(),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              icon: const Icon(Icons.draw_rounded),
                              label: const Text('Luyện viết'),
                              onPressed: () => Navigator.push(context,
                                  appRoute((_) => PracticeScreen(chars: [c.char]))),
                            ),
                          ],
                        ),
                      ] else
                        Center(
                            child: Text(c.char,
                                style: const TextStyle(fontSize: 120))),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.pinyin,
                              style: const TextStyle(
                                  fontSize: 22,
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600)),
                          SpeakButton(c.char),
                        ],
                      ),
                      const SectionTitle('Thông tin'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(children: [
                            _row('Hán Việt', c.hanviet),
                            _row('Bộ thủ', c.radical),
                            _row('Số nét', c.strokeCount?.toString()),
                            _row('Lục thư', c.liushu),
                            _row('Cấu tạo', c.ids),
                            _row('Thành phần', c.components.join('  ')),
                            _row('Thứ tự nét', c.strokeNames),
                            _row('Độ phổ biến', c.popular),
                          ]),
                        ),
                      ),
                      if (c.meanings.isNotEmpty) ...[
                        const SectionTitle('Nghĩa Hán Việt'),
                        for (final m in c.meanings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                title: Text(m.reading,
                                    style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(m.items.join(' · ')),
                              ),
                            ),
                          ),
                      ],
                      if (c.components.isNotEmpty) ...[
                        const SectionTitle('Chữ thành phần'),
                        Wrap(spacing: 8, children: [
                          for (final comp in c.components)
                            ActionChip(
                              label: Text(comp, style: const TextStyle(fontSize: 20)),
                              onPressed: () => Navigator.push(
                                  context, appRoute((_) => CharScreen(char: comp))),
                            ),
                        ]),
                      ],
                      if (d.words.isNotEmpty) ...[
                        SectionTitle('Từ chứa chữ ${c.char}'),
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < d.words.length; i++) ...[
                                if (i > 0) const Divider(height: 1, indent: 16),
                                WordTile.fromWord(d.words[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (d.sameRadical.isNotEmpty) ...[
                        SectionTitle('Chữ cùng bộ ${c.radical}'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final rc in d.sameRadical)
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.push(
                                    context, appRoute((_) => CharScreen(char: rc.char))),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.paper,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(rc.char,
                                          style: const TextStyle(
                                              fontSize: 28, color: AppColors.ink)),
                                      Text(rc.pinyin,
                                          style: const TextStyle(
                                              fontSize: 9, color: AppColors.userInk)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 28,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -150) {
                      Navigator.maybePop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(k, style: const TextStyle(color: AppColors.muted))),
        Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _CharData {
  final HanChar char;
  final List<Word> words;
  final List<HanChar> sameRadical;
  _CharData(this.char, this.words, this.sameRadical);
}
