import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../writing/hanzi_canvas.dart';
import '../writing/stroke_matcher.dart';

/// Stroke-by-stroke writing practice over a list of characters.
class PracticeScreen extends StatefulWidget {
  final List<String> chars;
  final String? title;
  const PracticeScreen({super.key, required this.chars, this.title});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _canvas = GlobalKey<HanziCanvasState>();
  final List<HanChar> _chars = [];
  bool _loading = true;
  bool _canvasTouching = false;
  int _index = 0;
  WriteMode _mode = WriteMode.trace;
  String _feedback = '';
  Color _feedbackColor = AppColors.muted;
  int? _score;
  final Map<String, int> _attemptsMap = {};
  final Map<String, int> _sessionMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final c in widget.chars) {
      final hc = await DictDb.instance.char(c);
      if (hc != null && hc.canWrite) {
        _chars.add(hc);
        final st = await UserDb.instance.charWritingStat(c);
        _attemptsMap[c] = st.attempts;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  HanChar get _cur => _chars[_index];

  void _onStroke(int i, StrokeResult r) {
    setState(() {
      if (r.ok) {
        _feedback = 'Đúng nét ${i + 1}/${_cur.strokes.length}';
        _feedbackColor = AppColors.hint;
      } else {
        _feedback = r.reason ?? 'Chưa đúng, thử lại';
        _feedbackColor = AppColors.error;
      }
    });
  }

  Future<void> _onComplete(int mistakes) async {
    final score = writingScore(mistakes, _cur.strokes.length);
    await UserDb.instance.recordWriting(_cur.char, mistakes, score);
    setState(() {
      _score = score;
      _attemptsMap[_cur.char] = (_attemptsMap[_cur.char] ?? 0) + 1;
      _sessionMap[_cur.char] = (_sessionMap[_cur.char] ?? 0) + 1;
      final totalDone = _attemptsMap[_cur.char]!;
      _feedback = mistakes == 0
          ? 'Hoàn hảo! (Lần viết thứ $totalDone)'
          : 'Hoàn thành lần thứ $totalDone · sai $mistakes nét';
      _feedbackColor = AppColors.gold;
    });
  }

  void _go(int delta) {
    final n = (_index + delta).clamp(0, _chars.length - 1);
    setState(() {
      _index = n;
      _score = null;
      _feedback = '';
    });
    _canvas.currentState?.reset();
  }

  void _setMode(WriteMode m) {
    setState(() {
      _mode = m;
      _score = null;
      _feedback = m == WriteMode.watch ? 'Quan sát thứ tự nét' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Luyện viết'),
        actions: [
          if (!_loading && _chars.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1}/${_chars.length}',
                    style: const TextStyle(color: AppColors.muted)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Loading()
          : _chars.isEmpty
              ? const Center(child: Text('Không có dữ liệu nét cho các chữ này'))
              : _body(),
    );
  }

  Widget _body() {
    final c = _cur;
    final showInfo = _mode != WriteMode.recall || _score != null;
    return SafeArea(
      child: ListView(
        physics: _canvasTouching
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SegmentedButton<WriteMode>(
            segments: const [
              ButtonSegment(
                  value: WriteMode.watch,
                  icon: Icon(Icons.play_circle_outline_rounded),
                  label: Text('Xem')),
              ButtonSegment(
                  value: WriteMode.trace,
                  icon: Icon(Icons.gesture_rounded),
                  label: Text('Tô theo')),
              ButtonSegment(
                  value: WriteMode.recall,
                  icon: Icon(Icons.psychology_rounded),
                  label: Text('Viết nhớ')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showInfo)
                Text(c.char,
                    style: const TextStyle(fontSize: 28, color: AppColors.text)),
              const SizedBox(width: 10),
              Text(c.pinyin,
                  style: const TextStyle(
                      fontSize: 22,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600)),
              SpeakButton(c.char),
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Đã viết: ${_attemptsMap[c.char] ?? 0} lần'
                  '${(_sessionMap[c.char] ?? 0) > 0 ? " (hôm nay +${_sessionMap[c.char]})" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          if (c.hanviet.isNotEmpty || c.meanings.isNotEmpty)
            Text(
              [
                if (c.hanviet.isNotEmpty) c.hanviet.toUpperCase(),
                if (c.meanings.isNotEmpty) c.meanings.first.items.take(2).join(', '),
              ].join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          if (_chars.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _chars.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final active = i == _index;
                  final ch = _chars[i].char;
                  final cnt = _attemptsMap[ch] ?? 0;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _go(i - _index),
                    child: Container(
                      width: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? AppColors.gold : Colors.white10,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              ch,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    active ? FontWeight.w800 : FontWeight.w500,
                                color: active ? Colors.white : AppColors.text,
                              ),
                            ),
                          ),
                          if (cnt > 0)
                            Positioned(
                              right: 3,
                              top: 2,
                              child: Text(
                                '${cnt}x',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white70
                                      : AppColors.gold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    if (!_canvasTouching) setState(() => _canvasTouching = true);
                  },
                  onPointerUp: (_) {
                    if (_canvasTouching) setState(() => _canvasTouching = false);
                  },
                  onPointerCancel: (_) {
                    if (_canvasTouching) setState(() => _canvasTouching = false);
                  },
                  child: HanziCanvas(
                    key: _canvas,
                    char: c,
                    mode: _mode,
                    onStroke: _onStroke,
                    onComplete: _onComplete,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _feedback,
              key: ValueKey(_feedback),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _feedbackColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (_score != null) ...[
            const SizedBox(height: 8),
            Center(child: _ScoreBadge(_score!)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filledTonal(
                tooltip: 'Chữ trước',
                onPressed: _index > 0 ? () => _go(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Gợi ý nét',
                onPressed: _mode == WriteMode.watch
                    ? null
                    : () => _canvas.currentState?.showHint(),
                icon: const Icon(Icons.lightbulb_outline_rounded),
              ),
              IconButton.filledTonal(
                tooltip: _mode == WriteMode.watch ? 'Xem lại' : 'Viết lại',
                onPressed: () {
                  setState(() {
                    _score = null;
                    _feedback = '';
                  });
                  if (_mode == WriteMode.watch) {
                    _canvas.currentState?.animate();
                  } else {
                    _canvas.currentState?.reset();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton.filled(
                tooltip: 'Chữ tiếp',
                onPressed:
                    _index < _chars.length - 1 ? () => _go(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge(this.score);
  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? AppColors.hint
        : score >= 60
            ? AppColors.gold
            : AppColors.error;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text('$score điểm',
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
