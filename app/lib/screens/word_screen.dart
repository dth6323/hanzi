import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/text_utils.dart';
import '../data/user_db.dart';
import '../services/speaker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pronunciation_sheet.dart';
import 'char_screen.dart';

class WordScreen extends StatefulWidget {
  final int wordId;
  const WordScreen({super.key, required this.wordId});
  @override
  State<WordScreen> createState() => _WordScreenState();
}

class _WordData {
  final Word word;
  final List<Sense> senses;
  final Map<String, List<String>> rel;
  final List<Note> notes;
  _WordData(this.word, this.senses, this.rel, this.notes);
}

class _WordScreenState extends State<WordScreen> {
  late final Future<_WordData?> _future = _load();
  bool _fav = false;

  Future<_WordData?> _load() async {
    final db = DictDb.instance;
    final w = await db.word(widget.wordId);
    if (w == null) return null;
    final res = await Future.wait([
      db.senses(w.id),
      db.relations(w.id),
      db.notes(w.id),
    ]);
    _fav = await UserDb.instance.isFavorite(w.id);
    UserDb.instance.addHistory(w.id, w.simp, w.pinyin, w.shortMean);
    return _WordData(w, res[0] as List<Sense>,
        res[1] as Map<String, List<String>>, res[2] as List<Note>);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: FutureBuilder<_WordData?>(
          future: _future,
          builder: (context, snap) {
            final d = snap.data;
            return Scaffold(
              backgroundColor: AppColors.bg,
              appBar: AppBar(
                actions: [
                  if (d != null)
                    IconButton(
                      icon: Icon(_fav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: _fav ? AppColors.gold : null),
                      onPressed: () async {
                        await UserDb.instance.setFavorite(d.word.id, d.word.simp,
                            d.word.pinyin, d.word.shortMean, !_fav);
                        setState(() => _fav = !_fav);
                      },
                    ),
                ],
              ),
              body: Stack(
                children: [
                  snap.connectionState != ConnectionState.done
                      ? const Loading()
                      : d == null
                          ? const Center(child: Text('Không tìm thấy từ'))
                          : _content(d),
                  // Vuốt từ mép phải sang trái để quay lại (cho thói quen ngón cái tay phải)
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
            );
          },
        ),
      ),
    );
  }

  Widget _content(_WordData d) {
    final w = d.word;
    final chars = cjkChars(w.simp);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _header(w),
        if (chars.isNotEmpty) ...[
          const SectionTitle('Chữ Hán · luyện viết'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in chars)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CharScreen(char: c))),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(c,
                        style: const TextStyle(
                            fontSize: 34, color: AppColors.ink)),
                  ),
                ),
            ],
          ),
        ],
        const SectionTitle('Nghĩa'),
        for (var i = 0; i < d.senses.length; i++) _sense(i + 1, d.senses[i]),
        for (final n in d.notes) _note(n),
        for (final kind in const ['measure', 'compound', 'syno', 'anto'])
          if (d.rel[kind]?.isNotEmpty ?? false) ...[
            SectionTitle(relLabels[kind]!),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in d.rel[kind]!.take(40))
                  ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 16)),
                    onPressed: kind == 'measure'
                        ? null
                        : () async {
                            final target =
                                await DictDb.instance.wordBySimp(t);
                            if (target != null && mounted) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          WordScreen(wordId: target.id)));
                            }
                          },
                  ),
              ],
            ),
          ],
      ],
    );
  }

  Widget _header(Word w) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A1F1A), Color(0xFF1D1A18)],
          ),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(w.simp,
                      style: const TextStyle(
                          fontSize: 54,
                          height: 1.1,
                          fontWeight: FontWeight.w500)),
                ),
                if (w.tradIfDifferent != null) ...[
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('〔${w.tradIfDifferent}〕',
                        style: const TextStyle(
                            fontSize: 22, color: AppColors.muted)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(w.pinyin,
                    style: const TextStyle(
                        fontSize: 22,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600)),
              ),
              SpeakButton(w.simp, size: 26),
              SpeakButton(w.simp, size: 24, slow: true),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 24,
                color: AppColors.primary,
                tooltip: 'Luyện phát âm',
                icon: const Icon(Icons.mic_rounded),
                onPressed: () => showPronunciationSheet(
                  context,
                  zh: w.simp,
                  pinyin: w.pinyin,
                  mean: w.shortMean,
                ),
              ),
            ]),
            Wrap(spacing: 8, children: [
              if (w.hanviet.isNotEmpty)
                Text('Hán Việt: ${w.hanviet}',
                    style: const TextStyle(color: AppColors.muted)),
              if (w.hsk != null) HskBadge(w.hsk!),
            ]),
          ],
        ),
      );

  Widget _sense(int idx, Sense s) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text('$idx',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.kind != null && s.kind!.isNotEmpty)
                          Text(posLabels[s.kind] ?? s.kind!,
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        Text(s.gloss,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        if (s.explain != null && s.explain!.isNotEmpty)
                          Text(s.explain!,
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ]),
                for (final e in s.examples) ExampleView(e),
              ],
            ),
          ),
        ),
      );

  Widget _note(Note n) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Card(
          color: AppColors.surface2,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                  n.kind == 'compare'
                      ? Icons.compare_arrows_rounded
                      : Icons.account_tree_rounded,
                  color: AppColors.gold),
              title: Text(n.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.body, style: const TextStyle(height: 1.5)),
                for (final e in n.examples) ExampleView(e),
              ],
            ),
          ),
        ),
      );
}

class ExampleView extends StatelessWidget {
  final Example e;
  const ExampleView(this.e, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Speaker.instance.speak(e.zh),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 34, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.zh, style: const TextStyle(fontSize: 17)),
                    if (e.pinyin.isNotEmpty)
                      Text(e.pinyin,
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 13)),
                    if (e.mean.isNotEmpty)
                      Text(e.mean,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              SpeakButton(e.zh, size: 20),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 19,
                color: AppColors.primary,
                tooltip: 'Luyện nói câu này',
                icon: const Icon(Icons.mic_none_rounded),
                onPressed: () => showPronunciationSheet(
                  context,
                  zh: e.zh,
                  pinyin: e.pinyin,
                  mean: e.mean,
                ),
              ),
            ],
          ),
        ),
      );
}
