import 'package:flutter/material.dart';

import '../data/user_db.dart';
import '../services/speaker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pronunciation_sheet.dart';
import 'word_screen.dart';

class FlashcardScreen extends StatefulWidget {
  final List<SrsCard> cards;
  final String title;

  const FlashcardScreen({
    super.key,
    required this.cards,
    this.title = 'Ôn tập Flashcard (SRS)',
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late final List<SrsCard> _queue = List.of(widget.cards);
  int _index = 0;
  bool _revealed = false;
  int _reviewedCount = 0;

  SrsCard get _cur => _queue[_index];

  Future<void> _rate(int grade) async {
    final updated = _cur.review(grade);
    await UserDb.instance.saveSrsCard(updated);
    if (!mounted) return;
    setState(() {
      _reviewedCount++;
      if (grade == 0) {
        // Re-queue forgotten card at the end of the session
        _queue.add(updated);
      }
      if (_index < _queue.length - 1) {
        _index++;
        _revealed = false;
      } else {
        _index = _queue.length; // Finished
      }
    });
  }

  String _nextIntervalLabel(int grade) {
    final preview = _cur.review(grade);
    if (grade == 0) return '10 phút';
    return '${preview.intervalDays} ngày';
  }

  @override
  Widget build(BuildContext context) {
    final done = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!done)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_index + 1}/${_queue.length}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
      body: done ? _doneView() : _cardView(),
    );
  }

  Widget _doneView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded,
                size: 72, color: AppColors.gold),
            const SizedBox(height: 16),
            const Text(
              'Hoàn thành phiên ôn tập!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã ôn $_reviewedCount lượt thẻ.\nLịch lặp lại ngắt quãng (SM-2) đã được cập nhật.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardView() {
    final c = _cur;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _index / _queue.length,
              color: AppColors.primary,
              backgroundColor: AppColors.surface2,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_revealed) {
                    setState(() => _revealed = true);
                    Speaker.instance.speak(c.simp);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _revealed
                          ? AppColors.gold.withValues(alpha: 0.45)
                          : Colors.white12,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        c.simp,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_revealed) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c.pinyin,
                              style: const TextStyle(
                                fontSize: 24,
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SpeakButton(c.simp, size: 26),
                            IconButton(
                              icon: const Icon(Icons.mic_rounded,
                                  color: AppColors.primary),
                              tooltip: 'Chấm phát âm',
                              onPressed: () => showPronunciationSheet(
                                context,
                                zh: c.simp,
                                pinyin: c.pinyin,
                                mean: c.mean,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        Text(
                          c.mean,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            appRoute((_) => WordScreen(wordId: c.wordId)),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Xem chi tiết từ & ví dụ'),
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        const Icon(Icons.touch_app_rounded,
                            color: AppColors.muted, size: 32),
                        const SizedBox(height: 8),
                        const Text(
                          'Chạm vào thẻ để lật xem Pinyin & Nghĩa',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!_revealed)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _revealed = true);
                    Speaker.instance.speak(c.simp);
                  },
                  child: const Text('Lật thẻ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              )
            else
              Row(
                children: [
                  _gradeBtn(0, 'Quên', AppColors.error),
                  const SizedBox(width: 8),
                  _gradeBtn(1, 'Khó', const Color(0xFFE8914A)),
                  const SizedBox(width: 8),
                  _gradeBtn(2, 'Tốt', AppColors.gold),
                  const SizedBox(width: 8),
                  _gradeBtn(3, 'Dễ', AppColors.hint),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _gradeBtn(int grade, String label, Color color) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _rate(grade),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _nextIntervalLabel(grade),
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
