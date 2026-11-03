import 'dart:math';

import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/user_db.dart';
import '../services/speaker.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum QuizType { meaning, pinyin, listening, cloze, measure }

class _QuizQuestion {
  final String promptTitle;
  final String promptMain;
  final String? promptSub;
  final String? audioZh;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _QuizQuestion({
    required this.promptTitle,
    required this.promptMain,
    this.promptSub,
    this.audioZh,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizScreen extends StatefulWidget {
  final QuizType type;
  final int? hskLevel;

  const QuizScreen({super.key, required this.type, this.hskLevel});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _loading = true;
  final List<_QuizQuestion> _questions = [];
  int _idx = 0;
  int? _selected;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _buildQuiz();
  }

  String get _modeTitle {
    switch (widget.type) {
      case QuizType.meaning:
        return 'Chọn nghĩa đúng';
      case QuizType.pinyin:
        return 'Chọn Pinyin đúng';
      case QuizType.listening:
        return 'Nghe âm đoán chữ';
      case QuizType.cloze:
        return 'Điền từ vào câu';
      case QuizType.measure:
        return 'Ghép lượng từ';
    }
  }

  Future<void> _buildQuiz() async {
    final rng = Random();
    final db = DictDb.instance;
    const totalQuestions = 10;

    if (widget.type == QuizType.measure) {
      final pool = await db.randomMeasureItems(limit: 40);
      final allMeasures = pool.map((e) => e.measure).toSet().toList();
      for (final item in pool.take(totalQuestions)) {
        final distractors = (List.of(allMeasures)..remove(item.measure))..shuffle(rng);
        if (distractors.length < 3) continue;
        final opts = [item.measure, ...distractors.take(3)]..shuffle(rng);
        _questions.add(_QuizQuestion(
          promptTitle: 'Chọn lượng từ phù hợp cho danh từ:',
          promptMain: item.word.simp,
          promptSub: '${item.word.pinyin} · ${item.word.shortMean}',
          audioZh: item.word.simp,
          options: opts,
          correctIndex: opts.indexOf(item.measure),
          explanation: 'Một ${item.word.simp} dùng lượng từ ${item.measure}',
        ));
      }
    } else if (widget.type == QuizType.cloze) {
      final items = await db.randomClozeItems(level: widget.hskLevel, limit: 15);
      final wordPool = await db.randomHskWords(level: widget.hskLevel, limit: 60);
      for (final item in items.take(totalQuestions)) {
        final masked = item.example.zh.replaceFirst(item.word.simp, '（ ___ ）');
        final distractors = wordPool
            .where((w) => w.id != item.word.id && w.simp != item.word.simp)
            .map((w) => '${w.simp} (${w.pinyin})')
            .toSet()
            .toList()
          ..shuffle(rng);
        if (distractors.length < 3) continue;
        final ans = '${item.word.simp} (${item.word.pinyin})';
        final opts = [ans, ...distractors.take(3)]..shuffle(rng);
        _questions.add(_QuizQuestion(
          promptTitle: 'Điền từ còn thiếu vào câu ví dụ:',
          promptMain: masked,
          promptSub: item.example.mean,
          audioZh: item.example.zh,
          options: opts,
          correctIndex: opts.indexOf(ans),
          explanation: '${item.example.zh}\n${item.example.pinyin}',
        ));
      }
    } else {
      final pool = await db.randomHskWords(level: widget.hskLevel, limit: 60);
      for (var i = 0; i < pool.length && _questions.length < totalQuestions; i++) {
        final w = pool[i];
        final others = pool.where((o) => o.id != w.id).toList()..shuffle(rng);
        if (others.length < 3) continue;

        if (widget.type == QuizType.meaning) {
          final opts = [w.shortMean, for (final o in others.take(3)) o.shortMean]
            ..shuffle(rng);
          _questions.add(_QuizQuestion(
            promptTitle: 'Nghĩa của từ này là gì?',
            promptMain: w.simp,
            promptSub: w.pinyin,
            audioZh: w.simp,
            options: opts,
            correctIndex: opts.indexOf(w.shortMean),
            explanation: '${w.simp} (${w.pinyin}): ${w.shortMean}',
          ));
        } else if (widget.type == QuizType.pinyin) {
          final othersPy = others
              .where((o) => o.pinyin != w.pinyin && o.pinyin.isNotEmpty)
              .take(3)
              .map((o) => o.pinyin)
              .toList();
          if (othersPy.length < 3) continue;
          final opts = [w.pinyin, ...othersPy]..shuffle(rng);
          _questions.add(_QuizQuestion(
            promptTitle: 'Chọn Pinyin đúng cho từ:',
            promptMain: w.simp,
            promptSub: w.shortMean,
            audioZh: w.simp,
            options: opts,
            correctIndex: opts.indexOf(w.pinyin),
            explanation: '${w.simp} đọc là ${w.pinyin}',
          ));
        } else if (widget.type == QuizType.listening) {
          final opts = [
            '${w.simp} — ${w.shortMean}',
            for (final o in others.take(3)) '${o.simp} — ${o.shortMean}'
          ]..shuffle(rng);
          _questions.add(_QuizQuestion(
            promptTitle: 'Nghe phát âm và chọn từ đúng:',
            promptMain: '🔊 Bấm để nghe',
            promptSub: 'Gợi ý Hán Việt: ${w.hanviet.isEmpty ? "—" : w.hanviet}',
            audioZh: w.simp,
            options: opts,
            correctIndex: opts.indexOf('${w.simp} — ${w.shortMean}'),
            explanation: '${w.simp} (${w.pinyin}): ${w.shortMean}',
          ));
        }
      }
    }

    if (mounted) {
      setState(() => _loading = false);
      if (_questions.isNotEmpty && widget.type == QuizType.listening) {
        final zh = _questions.first.audioZh;
        if (zh != null) Speaker.instance.speak(zh);
      }
    }
  }

  void _choose(int i) {
    if (_selected != null) return;
    final q = _questions[_idx];
    setState(() {
      _selected = i;
      if (i == q.correctIndex) _score++;
    });
    if (q.audioZh != null) {
      Speaker.instance.speak(q.audioZh!);
    }
  }

  Future<void> _next() async {
    if (_idx < _questions.length - 1) {
      setState(() {
        _idx++;
        _selected = null;
      });
      final q = _questions[_idx];
      if (widget.type == QuizType.listening && q.audioZh != null) {
        Speaker.instance.speak(q.audioZh!);
      }
    } else {
      await UserDb.instance.recordQuizRun(_modeTitle, _score, _questions.length);
      if (mounted) {
        setState(() => _idx = _questions.length);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modeTitle),
        actions: [
          if (!_loading && _idx < _questions.length)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_idx + 1}/${_questions.length}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Loading()
          : _questions.isEmpty
              ? const Center(child: Text('Không đủ câu hỏi cho chế độ này'))
              : _idx >= _questions.length
                  ? _summary()
                  : _questionView(),
    );
  }

  Widget _summary() {
    final pct = (_score * 100 / _questions.length).round();
    final color = pct >= 80
        ? AppColors.hint
        : pct >= 50
            ? AppColors.gold
            : AppColors.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 3),
              ),
              child: Text(
                '$_score/${_questions.length}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              pct >= 80
                  ? 'Xuất sắc!'
                  : pct >= 50
                      ? 'Khá tốt!'
                      : 'Cố gắng hơn nhé!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn trả lời đúng $pct% trong bài kiểm tra $_modeTitle.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _questions.clear();
                      _idx = 0;
                      _score = 0;
                      _selected = null;
                    });
                    _buildQuiz();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Làm đề mới'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Hoàn tất'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionView() {
    final q = _questions[_idx];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          LinearProgressIndicator(
            value: (_idx + 1) / _questions.length,
            color: AppColors.primary,
            backgroundColor: AppColors.surface2,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  q.promptTitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: q.audioZh == null
                      ? null
                      : () => Speaker.instance.speak(q.audioZh!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Text(
                      q.promptMain,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.type == QuizType.cloze ? 24 : 38,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (q.promptSub != null && q.promptSub!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    q.promptSub!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.gold, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < q.options.length; i++) _optionTile(i, q),
          if (_selected != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                q.explanation,
                style: const TextStyle(color: AppColors.gold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                    _idx < _questions.length - 1 ? 'Câu tiếp theo' : 'Xem kết quả'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionTile(int i, _QuizQuestion q) {
    final isSelected = _selected == i;
    final isCorrect = i == q.correctIndex;
    Color borderColor = Colors.white12;
    Color bgColor = AppColors.surface;

    if (_selected != null) {
      if (isCorrect) {
        borderColor = AppColors.hint;
        bgColor = AppColors.hint.withValues(alpha: 0.16);
      } else if (isSelected) {
        borderColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.16);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _choose(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surface2,
                child: Text(
                  String.fromCharCode(65 + i),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.options[i],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (_selected != null && isCorrect)
                const Icon(Icons.check_circle_rounded, color: AppColors.hint)
              else if (_selected != null && isSelected && !isCorrect)
                const Icon(Icons.cancel_rounded, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }
}
