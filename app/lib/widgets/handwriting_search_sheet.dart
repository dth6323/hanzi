import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../writing/handwriting_recognizer.dart';

/// Shows the handwriting search modal bottom sheet.
Future<String?> showHandwritingSearchSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const HandwritingSearchSheet(),
  );
}

class HandwritingSearchSheet extends StatefulWidget {
  const HandwritingSearchSheet({super.key});

  @override
  State<HandwritingSearchSheet> createState() => _HandwritingSearchSheetState();
}

class _HandwritingSearchSheetState extends State<HandwritingSearchSheet> {
  final _recognizer = const HandwritingRecognizer();
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  List<HandwritingCandidate> _candidates = [];
  bool _isRecognizing = false;
  Timer? _debounce;
  final StringBuffer _composedQuery = StringBuffer();

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _currentStroke?.add(d.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails d, Size canvasSize) {
    if (_currentStroke != null && _currentStroke!.length >= 2) {
      _strokes.add(List.from(_currentStroke!));
    }
    setState(() {
      _currentStroke = null;
    });
    _triggerRecognition(canvasSize);
  }

  void _triggerRecognition(Size canvasSize) {
    _debounce?.cancel();
    if (_strokes.isEmpty) {
      setState(() {
        _candidates = [];
        _isRecognizing = false;
      });
      return;
    }

    setState(() => _isRecognizing = true);
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      final results = await _recognizer.recognize(
        rawStrokes: _strokes,
        canvasSize: canvasSize,
        limit: 12,
      );
      if (mounted) {
        setState(() {
          _candidates = results;
          _isRecognizing = false;
        });
      }
    });
  }

  void _undo(Size canvasSize) {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      _triggerRecognition(canvasSize);
    }
  }

  void _clearCanvas() {
    _debounce?.cancel();
    setState(() {
      _strokes.clear();
      _currentStroke = null;
      _candidates = [];
      _isRecognizing = false;
    });
  }

  void _pickCandidate(HandwritingCandidate c) {
    setState(() {
      _composedQuery.write(c.char);
      _clearCanvas();
    });
  }

  void _finishSearch([String? text]) {
    final query = text ?? _composedQuery.toString().trim();
    if (query.isNotEmpty) {
      Navigator.of(context).pop(query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = (mq.size.width - 40).clamp(240.0, 320.0);
    final canvasSize = Size(size, size);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, mq.viewInsets.bottom + 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                const Icon(Icons.draw_rounded, color: AppColors.gold, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Nhận dạng chữ viết tay',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_composedQuery.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: Text('Tìm: $_composedQuery'),
                    onPressed: () => _finishSearch(),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Candidate Bar
            Container(
              height: 60,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: _strokes.isEmpty && _candidates.isEmpty
                  ? Center(
                      child: Text(
                        _composedQuery.isNotEmpty
                            ? 'Đã chọn: $_composedQuery · Viết tiếp chữ tiếp theo'
                            : 'Vẽ chữ Hán vào khung bên dưới để nhận dạng',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : _isRecognizing && _candidates.isEmpty
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _candidates.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final c = _candidates[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                if (_composedQuery.isEmpty) {
                                  // Direct single character search
                                  _finishSearch(c.char);
                                } else {
                                  _pickCandidate(c);
                                }
                              },
                              onLongPress: () => _pickCandidate(c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? AppColors.primary.withValues(alpha: 0.25)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: i == 0
                                        ? AppColors.gold.withValues(alpha: 0.6)
                                        : Colors.white10,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      c.char,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: i == 0
                                            ? AppColors.gold
                                            : AppColors.text,
                                      ),
                                    ),
                                    Text(
                                      c.pinyin.isNotEmpty
                                          ? c.pinyin
                                          : (c.hanviet.isNotEmpty
                                              ? c.hanviet
                                              : ''),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 14),

            // Canvas Box with Tian Zi Ge / Rice Grid
            Center(
              child: Container(
                width: canvasSize.width,
                height: canvasSize.height,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: (d) => _onPanEnd(d, canvasSize),
                    child: CustomPaint(
                      size: canvasSize,
                      painter: _HandwritingPainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Toolbar under Canvas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _strokes.isEmpty ? null : () => _undo(canvasSize),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Hoàn tác'),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Số nét: ${_strokes.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _strokes.isEmpty ? null : _clearCanvas,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Xoá bảng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HandwritingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;

  _HandwritingPainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw traditional Chinese Rice Grid (米字格)
    final gridPaint = Paint()
      ..color = const Color(0xFFD32F2F).withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = const Color(0xFFD32F2F).withValues(alpha: 0.18)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Outer border
    canvas.drawRect(Offset.zero & size, gridPaint);

    // Cross lines
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), dashPaint);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), dashPaint);

    // Diagonal lines
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), dashPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), dashPaint);

    // 2. Draw user strokes with dark ink
    final inkPaint = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 3.25, inkPaint..style = PaintingStyle.fill);
        inkPaint.style = PaintingStyle.stroke;
      } else {
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, inkPaint);
      }
    }

    if (currentStroke != null && currentStroke!.isNotEmpty) {
      if (currentStroke!.length == 1) {
        canvas.drawCircle(currentStroke!.first, 3.25, inkPaint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(currentStroke!.first.dx, currentStroke!.first.dy);
        for (var i = 1; i < currentStroke!.length; i++) {
          path.lineTo(currentStroke![i].dx, currentStroke![i].dy);
        }
        canvas.drawPath(path, inkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HandwritingPainter oldDelegate) => true;
}
