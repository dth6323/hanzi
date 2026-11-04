import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../data/models.dart';
import '../theme.dart';
import 'stroke_matcher.dart';

enum WriteMode { watch, trace, recall }

/// A custom pan recognizer that eagerly wins the gesture arena immediately on
/// pointer-down so vertical strokes (e.g. "nét sổ thẳng") never get stolen
/// by parent scrollables like ListView.
class _ImmediatePanGestureRecognizer extends PanGestureRecognizer {
  _ImmediatePanGestureRecognizer() : super(debugOwner: 'HanziCanvas');

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Draws a character from Make Me a Hanzi data and lets the user
/// animate it or write it stroke by stroke with feedback.
class HanziCanvas extends StatefulWidget {
  final HanChar char;
  final WriteMode mode;
  final void Function(int mistakes)? onComplete;
  final void Function(int stroke, StrokeResult result)? onStroke;

  const HanziCanvas({
    super.key,
    required this.char,
    required this.mode,
    this.onComplete,
    this.onStroke,
  });

  @override
  State<HanziCanvas> createState() => HanziCanvasState();
}

class HanziCanvasState extends State<HanziCanvas>
    with TickerProviderStateMixin {
  late List<Path> _paths;
  late List<List<Pt>> _medians;

  int _done = 0; // strokes completed
  int _mistakes = 0;
  int _strokeMistakes = 0;
  final List<Offset> _user = [];
  int? _hint; // stroke index currently hinted
  bool _wrongFlash = false;

  late final AnimationController _anim = AnimationController(vsync: this);
  late final AnimationController _hintAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  int _animStroke = -1;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _load();
    _anim.addListener(() => setState(() {}));
    _hintAnim.addListener(() => setState(() {}));
    if (widget.mode == WriteMode.watch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => animate());
    }
  }

  @override
  void didUpdateWidget(covariant HanziCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.char.char != widget.char.char || oldWidget.mode != widget.mode) {
      _load();
      reset();
      if (widget.mode == WriteMode.watch) animate();
    }
  }

  void _load() {
    _paths = widget.char.strokes.map(parseSvgPathData).toList();
    _medians = widget.char.medians
        .map((s) => s.map((p) => Pt(p[0], p[1])).toList())
        .toList();
  }

  @override
  void dispose() {
    _anim.dispose();
    _hintAnim.dispose();
    super.dispose();
  }

  int get strokeCount => _paths.length;
  int get done => _done;
  int get mistakes => _mistakes;

  void reset() {
    _animating = false;
    _anim.stop();
    _hintAnim.stop();
    setState(() {
      _done = 0;
      _mistakes = 0;
      _strokeMistakes = 0;
      _user.clear();
      _hint = null;
      _animStroke = -1;
    });
  }

  /// Plays the stroke-order animation.
  Future<void> animate() async {
    reset();
    _animating = true;
    for (var i = 0; i < _paths.length; i++) {
      if (!_animating || !mounted) return;
      final len = pathLength(_medians[i]);
      _anim.duration =
          Duration(milliseconds: (350 + len * 0.6).clamp(350, 1100).toInt());
      setState(() => _animStroke = i);
      await _anim.forward(from: 0);
      if (!_animating || !mounted) return;
      setState(() => _done = i + 1);
      await Future.delayed(const Duration(milliseconds: 180));
    }
    _animating = false;
    if (mounted) setState(() => _animStroke = -1);
  }

  void showHint() {
    if (_done >= _paths.length) return;
    setState(() => _hint = _done);
    _hintAnim.forward(from: 0).then((_) {
      if (mounted) setState(() => _hint = null);
    });
  }

  // --- coordinate helpers -------------------------------------------------

  double _scale(Size s) => s.width / 1024;

  Pt _toChar(Offset o, double k) => Pt(o.dx / k, 900 - o.dy / k);

  // --- input --------------------------------------------------------------

  bool get _interactive =>
      widget.mode != WriteMode.watch && _done < _paths.length && !_animating;

  void _onPanStart(DragStartDetails d) {
    if (!_interactive) return;
    setState(() {
      _user
        ..clear()
        ..add(d.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_interactive) return;
    setState(() => _user.add(d.localPosition));
  }

  void _onPanEnd(Size size) {
    if (!_interactive || _user.isEmpty) return;
    final k = _scale(size);
    final pts = _user.map((o) => _toChar(o, k)).toList();
    final res = matchStroke(pts, _medians[_done]);
    if (res.reason == 'Nét quá ngắn' && pathLength(pts) < 25) {
      setState(_user.clear); // accidental tap
      return;
    }
    widget.onStroke?.call(_done, res);
    if (res.ok) {
      setState(() {
        _user.clear();
        _done++;
        _strokeMistakes = 0;
        _hint = null;
      });
      if (_done == _paths.length) widget.onComplete?.call(_mistakes);
    } else {
      setState(() {
        _mistakes++;
        _strokeMistakes++;
        _wrongFlash = true;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _wrongFlash = false;
            _user.clear();
          });
        }
      });
      if (_strokeMistakes >= 3) showHint();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxWidth);
        return RawGestureDetector(
          gestures: {
            _ImmediatePanGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                _ImmediatePanGestureRecognizer>(
              () => _ImmediatePanGestureRecognizer(),
              (_ImmediatePanGestureRecognizer instance) {
                instance
                  ..onStart = _onPanStart
                  ..onUpdate = _onPanUpdate
                  ..onEnd = (_) => _onPanEnd(size);
              },
            ),
          },
          child: CustomPaint(
            size: size,
            painter: _HanziPainter(
              paths: _paths,
              medians: _medians,
              done: _done,
              showOutline: widget.mode != WriteMode.recall ||
                  _done == _paths.length,
              user: List.of(_user),
              wrong: _wrongFlash,
              animStroke: _animStroke,
              animT: _anim.value,
              hint: _hint,
              hintT: _hintAnim.value,
            ),
          ),
        );
      }),
    );
  }
}

class _HanziPainter extends CustomPainter {
  final List<Path> paths;
  final List<List<Pt>> medians;
  final int done;
  final bool showOutline;
  final List<Offset> user;
  final bool wrong;
  final int animStroke;
  final double animT;
  final int? hint;
  final double hintT;

  _HanziPainter({
    required this.paths,
    required this.medians,
    required this.done,
    required this.showOutline,
    required this.user,
    required this.wrong,
    required this.animStroke,
    required this.animT,
    required this.hint,
    required this.hintT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 1024;
    _grid(canvas, size);

    final m = Float64List.fromList([
      k, 0, 0, 0, //
      0, -k, 0, 0, //
      0, 0, 1, 0, //
      0, 900 * k, 0, 1,
    ]);
    final screen = paths.map((p) => p.transform(m)).toList();

    final outline = Paint()..color = AppColors.outline;
    final ink = Paint()..color = AppColors.ink;

    for (var i = 0; i < screen.length; i++) {
      if (i < done) {
        canvas.drawPath(screen[i], ink);
      } else if (showOutline) {
        canvas.drawPath(screen[i], outline);
      }
    }

    // Stroke-order animation: reveal along the median, clipped to stroke.
    if (animStroke >= 0 && animStroke < screen.length && animStroke >= done) {
      _reveal(canvas, screen[animStroke], medians[animStroke], k, animT,
          AppColors.accent);
    }

    // Hint: flash the expected stroke.
    if (hint != null && hint! < screen.length) {
      final t = hintT;
      _reveal(canvas, screen[hint!], medians[hint!], k, (t * 1.6).clamp(0, 1),
          AppColors.hint.withValues(alpha: 1 - (t - 0.6).clamp(0, 0.4) * 2.5));
    }

    // Current user stroke.
    if (user.length > 1) {
      final p = Path()..moveTo(user.first.dx, user.first.dy);
      for (final o in user.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = wrong ? AppColors.error : AppColors.userInk
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.045,
      );
    }
  }

  void _reveal(Canvas canvas, Path stroke, List<Pt> median, double k,
      double t, Color color) {
    if (median.length < 2) return;
    final mp = Path()..moveTo(median.first.x * k, (900 - median.first.y) * k);
    for (final p in median.skip(1)) {
      mp.lineTo(p.x * k, (900 - p.y) * k);
    }
    canvas.save();
    canvas.clipPath(stroke);
    for (final metric in mp.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * t),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 220 * k,
      );
    }
    canvas.restore();
  }

  void _grid(Canvas canvas, Size s) {
    final border = Paint()
      ..color = AppColors.gridStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(16)),
        border);
    final dash = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;
    void dashed(Offset a, Offset b) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
      canvas.drawPath(
          dashPath(path, dashArray: CircularIntervalList([6.0, 6.0])),
          dash..style = PaintingStyle.stroke);
    }

    dashed(Offset(s.width / 2, 0), Offset(s.width / 2, s.height));
    dashed(Offset(0, s.height / 2), Offset(s.width, s.height / 2));
    dashed(Offset.zero, Offset(s.width, s.height));
    dashed(Offset(s.width, 0), Offset(0, s.height));
  }

  @override
  bool shouldRepaint(covariant _HanziPainter old) => true;
}
