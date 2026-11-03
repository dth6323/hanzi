import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/speaker.dart';
import '../services/speech_scorer.dart';
import '../theme.dart';

/// Opens a bottom sheet where the learner listens to [zh] and records their
/// own pronunciation for syllable-by-syllable tone & phoneme grading.
void showPronunciationSheet(BuildContext context,
    {required String zh, required String pinyin, String? mean}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PronunciationSheet(zh: zh, pinyin: pinyin, mean: mean),
  );
}

class PronunciationSheet extends StatefulWidget {
  final String zh;
  final String pinyin;
  final String? mean;

  const PronunciationSheet({
    super.key,
    required this.zh,
    required this.pinyin,
    this.mean,
  });

  @override
  State<PronunciationSheet> createState() => _PronunciationSheetState();
}

class _PronunciationSheetState extends State<PronunciationSheet> {
  bool _listening = false;
  String? _error;
  PronunciationEvaluation? _eval;
  final _manualCtrl = TextEditingController();
  bool _showManual = false;

  Future<void> _toggleListen() async {
    if (_listening) {
      await SpeechScorer.instance.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _error = null;
    });
    try {
      final transcript = await SpeechScorer.instance.listen();
      if (!mounted) return;
      final res = await SpeechScorer.instance.evaluate(
        expectedZh: widget.zh,
        expectedPinyin: widget.pinyin,
        transcript: transcript,
      );
      if (mounted) {
        setState(() {
          _listening = false;
          _eval = res;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = e.message ?? 'Thiết bị chưa hỗ trợ nhận diện giọng nói offline';
          _showManual = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = 'Không thể thu âm: $e';
          _showManual = true;
        });
      }
    }
  }

  Future<void> _gradeManual(String text) async {
    final res = await SpeechScorer.instance.evaluate(
      expectedZh: widget.zh,
      expectedPinyin: widget.pinyin,
      transcript: text,
    );
    if (mounted) setState(() => _eval = res);
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    if (_listening) SpeechScorer.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Luyện nói & Chấm phát âm',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (_eval == null) ...[
            Text(
              widget.zh,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.pinyin,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            _buildColoredSyllables(_eval!),
          if (widget.mean != null && widget.mean!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.mean!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
          const SizedBox(height: 18),
          if (_eval != null) ...[
            _buildScoreBanner(_eval!),
            const SizedBox(height: 14),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gold, fontSize: 13),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => Speaker.instance.speak(widget.zh),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Nghe mẫu'),
              ),
              GestureDetector(
                onTap: _toggleListen,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? AppColors.error : AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? AppColors.error : AppColors.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: _listening ? 24 : 12,
                        spreadRadius: _listening ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _listening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Speaker.instance.speak(widget.zh, slow: true),
                icon: const Icon(Icons.slow_motion_video_rounded),
                label: const Text('Nghe chậm'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _listening
                ? 'Đang nghe giọng đọc tiếng Trung của bạn… Bấm để dừng'
                : 'Bấm biểu tượng Micro và đọc to câu/từ trên',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (_showManual) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _manualCtrl,
              decoration: InputDecoration(
                hintText: 'Hoặc dùng phím giọng nói trên bàn phím gõ chữ Hán vào đây…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.gold),
                  onPressed: () => _gradeManual(_manualCtrl.text),
                ),
              ),
              onSubmitted: _gradeManual,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColoredSyllables(PronunciationEvaluation ev) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final s in ev.syllables)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.char,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: _colorFor(s.match),
                ),
              ),
              Text(
                s.expectedPinyin,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _colorFor(s.match),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Color _colorFor(ToneMatch m) {
    switch (m) {
      case ToneMatch.exact:
        return AppColors.hint;
      case ToneMatch.wrongTone:
        return AppColors.gold;
      case ToneMatch.wrong:
        return AppColors.error;
    }
  }

  Widget _buildScoreBanner(PronunciationEvaluation ev) {
    final color = ev.score >= 85
        ? AppColors.hint
        : ev.score >= 60
            ? AppColors.gold
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${ev.score} / 100 điểm',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (ev.transcript.isNotEmpty) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Nhận diện: “${ev.transcript}”',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ev.feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.hint, label: 'Chuẩn'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.gold, label: 'Lệch thanh'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.error, label: 'Chưa đúng'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      );
}
