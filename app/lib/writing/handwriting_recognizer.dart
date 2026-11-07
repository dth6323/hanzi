import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import 'stroke_matcher.dart';

class HandwritingCandidate {
  final String char;
  final String pinyin;
  final String hanviet;
  final double distance;

  const HandwritingCandidate({
    required this.char,
    required this.pinyin,
    required this.hanviet,
    required this.distance,
  });
}

class HandwritingRecognizer {
  const HandwritingRecognizer();

  /// Converts screen strokes to character space (1024 box, y up) and recognizes candidates.
  Future<List<HandwritingCandidate>> recognize({
    required List<List<Offset>> rawStrokes,
    required Size canvasSize,
    int limit = 12,
  }) async {
    if (rawStrokes.isEmpty || canvasSize.width <= 0) return const [];

    final k = canvasSize.width / 1024;
    final convertedStrokes = <List<Pt>>[];

    for (final stroke in rawStrokes) {
      if (stroke.length < 2) continue;
      final pts = stroke
          .map((o) => Pt(o.dx / k, 900 - o.dy / k))
          .toList();
      convertedStrokes.add(pts);
    }

    if (convertedStrokes.isEmpty) return const [];

    final results = await DictDb.instance.recognizeHandwriting(
      convertedStrokes,
      limit: limit,
    );

    return results
        .map((r) => HandwritingCandidate(
              char: r.char,
              pinyin: r.pinyin,
              hanviet: r.hanviet,
              distance: r.distance,
            ))
        .toList();
  }
}
