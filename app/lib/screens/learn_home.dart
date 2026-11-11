import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'grammar_screen.dart';
import 'quiz_screen.dart';
import 'word_list_screen.dart';

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
      context, appRoute((_) => WordListScreen(title: title, future: f)));
}

class _HskTab extends StatefulWidget {
  const _HskTab();
  @override
  State<_HskTab> createState() => _HskTabState();
}

class _HskTabState extends State<_HskTab>
    with AutomaticKeepAliveClientMixin {
  Map<int, int>? _counts;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    DictDb.instance.hskCounts().then((c) {
      if (mounted) setState(() => _counts = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final lv = i + 1;
        final color = AppColors.hskColor(lv);
        final count = _counts?[lv];
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
            subtitle: Text(count == null ? '…' : '$count từ vựng'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Kiểm tra nhanh HSK $lv',
                  icon: const Icon(Icons.quiz_outlined, color: AppColors.gold),
                  onPressed: () => Navigator.push(
                    context,
                    appRoute((_) =>
                        QuizScreen(type: QuizType.meaning, hskLevel: lv)),
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

class _TopicTab extends StatefulWidget {
  const _TopicTab();
  @override
  State<_TopicTab> createState() => _TopicTabState();
}

class _TopicTabState extends State<_TopicTab>
    with AutomaticKeepAliveClientMixin {
  late final Future<List<Topic>> _future = DictDb.instance.topics();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Topic>>(
      future: _future,
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

class _GrammarTab extends StatefulWidget {
  const _GrammarTab();
  @override
  State<_GrammarTab> createState() => _GrammarTabState();
}

class _GrammarTabState extends State<_GrammarTab>
    with AutomaticKeepAliveClientMixin {
  late final Future<List<String>> _future = DictDb.instance.grammarLevels();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<String>>(
      future: _future,
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
                        context, appRoute((_) => GrammarListScreen(level: lv))),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuizTab extends StatefulWidget {
  const _QuizTab();
  @override
  State<_QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<_QuizTab>
    with AutomaticKeepAliveClientMixin {
  int? _hsk = 1;
  List<Map<String, Object?>> _history = [];

  @override
  bool get wantKeepAlive => true;

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
      appRoute((_) => QuizScreen(type: t, hskLevel: _hsk)),
    );
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
