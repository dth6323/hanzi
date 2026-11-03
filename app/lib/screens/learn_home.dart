import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class LearnHome extends StatelessWidget {
  const LearnHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Học & Kiểm tra',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.text,
            unselectedLabelColor: AppColors.muted,
            tabs: [
              Tab(text: 'HSK'),
              Tab(text: 'Chủ đề'),
              Tab(text: 'Ngữ pháp'),
              Tab(text: 'Kiểm tra'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _HskTab(),
                _TopicTab(),
                _GrammarTab(),
                _QuizTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

void _openWords(BuildContext context, String title, Future<List<Word>> f) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _WordListScreen(title: title, future: f)));
}

class _WordListScreen extends StatelessWidget {
  final String title;
  final Future<List<Word>> future;
  const _WordListScreen({required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Word>>(
      future: future,
      builder: (context, s) {
        final words = s.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (words != null && words.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final subset = words.take(30).toList();
                    await UserDb.instance.importWordsToSrs(subset.map((w) => (
                          id: w.id,
                          simp: w.simp,
                          pinyin: w.pinyin,
                          mean: w.shortMean,
                        )));
                    final cards = subset
                        .map((w) => SrsCard(
                              wordId: w.id,
                              simp: w.simp,
                              pinyin: w.pinyin,
                              mean: w.shortMean,
                              reps: 0,
                              intervalDays: 0,
                              ease: 2.5,
                              dueMs: 0,
                              lastReviewMs: 0,
                            ))
                        .toList();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FlashcardScreen(cards: cards, title: title),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.style_rounded,
                      color: AppColors.gold, size: 18),
                  label: const Text('Flashcard',
                      style: TextStyle(color: AppColors.gold)),
                ),
            ],
          ),
          body: words == null
              ? const Loading()
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: words.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (_, i) => WordTile.fromWord(words[i]),
                ),
        );
      },
    );
  }
}

class _HskTab extends StatelessWidget {
  const _HskTab();
  static const _counts = [506, 750, 953, 972, 1059, 1123, 5601];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final lv = i + 1;
        final color = AppColors.hskColor(lv);
        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text('$lv',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ),
            title: Text(lv == 7 ? 'HSK 7–9' : 'HSK $lv',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_counts[i]} từ vựng'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Kiểm tra nhanh HSK $lv',
                  icon: const Icon(Icons.quiz_outlined, color: AppColors.gold),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          QuizScreen(type: QuizType.meaning, hskLevel: lv),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => _openWords(context, 'Từ vựng HSK $lv',
                DictDb.instance.wordsByHsk(lv)),
          ),
        );
      },
    );
  }
}

class _TopicTab extends StatelessWidget {
  const _TopicTab();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Topic>>(
      future: DictDb.instance.topics(),
      builder: (_, s) {
        if (!s.hasData) return const Loading();
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8),
          itemCount: s.data!.length,
          itemBuilder: (_, i) {
            final t = s.data![i];
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openWords(
                  context, t.name, DictDb.instance.wordsByTopic(t.id)),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('${t.count} từ',
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GrammarTab extends StatelessWidget {
  const _GrammarTab();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: DictDb.instance.grammarLevels(),
      builder: (_, s) {
        if (!s.hasData) return const Loading();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final lv in s.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_rounded,
                        color: AppColors.gold),
                    title: Text(lv,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => _GrammarList(level: lv))),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GrammarList extends StatelessWidget {
  final String level;
  const _GrammarList({required this.level});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ngữ pháp $level')),
      body: FutureBuilder<List<Grammar>>(
        future: DictDb.instance.grammarByLevel(level),
        builder: (_, s) {
          if (!s.hasData) return const Loading();
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: s.data!.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final g = s.data![i];
              return ListTile(
                title: Text(g.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: g.keywords.isEmpty
                    ? null
                    : Text(g.keywords,
                        style: const TextStyle(color: AppColors.gold)),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _GrammarDetail(g))),
              );
            },
          );
        },
      ),
    );
  }
}

class _GrammarDetail extends StatelessWidget {
  final Grammar g;
  const _GrammarDetail(this.g);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(g.level)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(g.title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          if (g.useFor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(g.useFor,
                  style: const TextStyle(color: AppColors.muted)),
            ),
          const SizedBox(height: 16),
          for (final p in g.body)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(p,
                  style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: p.startsWith('Cấu trúc')
                          ? AppColors.gold
                          : AppColors.text,
                      fontWeight: p.startsWith('Cấu trúc') ||
                              p.endsWith(':')
                          ? FontWeight.w700
                          : FontWeight.normal)),
            ),
        ],
      ),
    );
  }
}

class _QuizTab extends StatefulWidget {
  const _QuizTab();
  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab> {
  int? _hsk = 1;
  List<Map<String, Object?>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await UserDb.instance.quizRuns();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _startQuiz(QuizType t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(type: t, hskLevel: _hsk),
      ),
    );
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Chọn cấp độ HSK',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: _hsk == null,
              onSelected: (_) => setState(() => _hsk = null),
            ),
            for (var lv = 1; lv <= 6; lv++)
              ChoiceChip(
                label: Text('HSK $lv'),
                selected: _hsk == lv,
                onSelected: (_) => setState(() => _hsk = lv),
              ),
          ],
        ),
        const SectionTitle('Chế độ kiểm tra (10 câu)'),
        _modeCard(
          icon: Icons.translate_rounded,
          title: 'Chọn nghĩa đúng',
          subtitle: 'Nhìn chữ Hán & Pinyin, chọn nghĩa tiếng Việt',
          color: AppColors.primary,
          onTap: () => _startQuiz(QuizType.meaning),
        ),
        const SizedBox(height: 10),
        _modeCard(
          icon: Icons.record_voice_over_rounded,
          title: 'Chọn Pinyin & Thanh điệu',
          subtitle: 'Kiểm tra khả năng nhớ phiên âm và thanh điệu chuẩn',
          color: AppColors.gold,
          onTap: () => _startQuiz(QuizType.pinyin),
        ),
        const SizedBox(height: 10),
        _modeCard(
          icon: Icons.headphones_rounded,
          title: 'Nghe âm đoán chữ',
          subtitle: 'Nghe phát âm tiếng Trung và chọn từ tương ứng',
          color: const Color(0xFF3E9BD6),
          onTap: () => _startQuiz(QuizType.listening),
        ),
        const SizedBox(height: 10),
        _modeCard(
          icon: Icons.short_text_rounded,
          title: 'Điền từ vào câu ví dụ',
          subtitle: 'Đọc câu khuyết từ trong ngữ cảnh thực tế',
          color: AppColors.hint,
          onTap: () => _startQuiz(QuizType.cloze),
        ),
        const SizedBox(height: 10),
        _modeCard(
          icon: Icons.category_rounded,
          title: 'Ghép lượng từ',
          subtitle: 'Chọn lượng từ (个, 本, 张, 条…) đi kèm danh từ',
          color: const Color(0xFFD06BC4),
          onTap: () => _startQuiz(QuizType.measure),
        ),
        if (_history.isNotEmpty) ...[
          const SectionTitle('Kết quả gần đây'),
          for (final r in _history.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.emoji_events_rounded,
                      color: AppColors.gold),
                  title: Text(r['mode'] as String),
                  trailing: Text(
                    '${r['score']}/${r['total']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
