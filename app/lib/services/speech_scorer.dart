import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/dict_db.dart';
import '../data/text_utils.dart';
import 'speech_web_stub.dart'
    if (dart.library.html) 'speech_web_impl.dart';

enum ToneMatch { exact, wrongTone, wrong }

class SyllableScore {
  final String char;
  final String expectedPinyin;
  final String? spokenPinyin;
  final ToneMatch match;

  const SyllableScore({
    required this.char,
    required this.expectedPinyin,
    this.spokenPinyin,
    required this.match,
  });
}

class PronunciationEvaluation {
  final String transcript;
  final int score; // 0-100
  final List<SyllableScore> syllables;
  final String feedback;

  const PronunciationEvaluation({
    required this.transcript,
    required this.score,
    required this.syllables,
    required this.feedback,
  });
}

/// Native bridge to Android SpeechRecognizer / iOS SFSpeechRecognizer (zh-CN)
/// and offline syllable-by-syllable pronunciation evaluator.
class SpeechScorer {
  SpeechScorer._();
  static final SpeechScorer instance = SpeechScorer._();

  static const _channel = MethodChannel('com.hadz.hanzi_app/speech');

  Future<bool> isAvailable() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts native zh-CN speech recognition and resolves with the recognized text.
  Future<String> listen() async {
    if (kIsWeb) {
      final webFut = webListenSpeech();
      if (webFut != null) return await webFut;
    }
    final text = await _channel.invokeMethod<String>('listen');
    return (text ?? '').trim();
  }

  Future<void> stop() async {
    if (kIsWeb) {
      webStopSpeech();
      return;
    }
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Evaluates spoken Chinese [transcript] against target [expectedZh] and [expectedPinyin].
  Future<PronunciationEvaluation> evaluate({
    required String expectedZh,
    required String expectedPinyin,
    required String transcript,
  }) async {
    final targetChars = cjkChars(expectedZh);
    final expTokens = _splitPinyin(expectedPinyin, targetChars.length);

    final spokenChars = cjkChars(transcript);
    final spokenReadings = <List<String>>[];
    for (final sc in spokenChars) {
      final hc = await DictDb.instance.char(sc);
      if (hc != null && hc.pinyin.isNotEmpty) {
        spokenReadings.add(
          hc.pinyin
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty)
              .toList(),
        );
      } else {
        spokenReadings.add([sc.toLowerCase()]);
      }
    }

    return gradeTokens(
      targetChars: targetChars,
      expectedPinyin: expTokens,
      spokenChars: spokenChars,
      spokenReadings: spokenReadings,
      rawTranscript: transcript,
    );
  }

  /// Pure grading helper (also used in unit tests without DB).
  static PronunciationEvaluation gradeTokens({
    required List<String> targetChars,
    required List<String> expectedPinyin,
    required List<String> spokenChars,
    required List<List<String>> spokenReadings,
    required String rawTranscript,
  }) {
    if (targetChars.isEmpty) {
      return PronunciationEvaluation(
        transcript: rawTranscript,
        score: 0,
        syllables: const [],
        feedback: 'Không có chữ Hán để chấm',
      );
    }
    if (spokenChars.isEmpty && rawTranscript.trim().isEmpty) {
      return PronunciationEvaluation(
        transcript: '',
        score: 0,
        syllables: [
          for (var i = 0; i < targetChars.length; i++)
            SyllableScore(
              char: targetChars[i],
              expectedPinyin: i < expectedPinyin.length ? expectedPinyin[i] : '',
              match: ToneMatch.wrong,
            ),
        ],
        feedback: 'Chưa nghe rõ giọng đọc, hãy nói to và rõ hơn',
      );
    }

    final syllables = <SyllableScore>[];
    var totalPoints = 0.0;

    for (var i = 0; i < targetChars.length; i++) {
      final ch = targetChars[i];
      final expPy = (i < expectedPinyin.length ? expectedPinyin[i] : '').toLowerCase();
      final expBase = removeDiacritics(expPy).replaceAll(RegExp(r'[^a-z]'), '');

      ToneMatch bestMatch = ToneMatch.wrong;
      String? matchedPy;

      // Search in a window around index i
      final start = (i - 1).clamp(0, spokenChars.length);
      final end = (i + 2).clamp(0, spokenChars.length);
      for (var j = start; j < end; j++) {
        if (spokenChars[j] == ch) {
          bestMatch = ToneMatch.exact;
          matchedPy = expPy;
          break;
        }
        for (final r in spokenReadings[j]) {
          final rBase = removeDiacritics(r).replaceAll(RegExp(r'[^a-z]'), '');
          if (r == expPy && expPy.isNotEmpty) {
            bestMatch = ToneMatch.exact;
            matchedPy = r;
            break;
          } else if (rBase == expBase && expBase.isNotEmpty && bestMatch != ToneMatch.exact) {
            bestMatch = ToneMatch.wrongTone;
            matchedPy = r;
          }
        }
        if (bestMatch == ToneMatch.exact) break;
      }

      if (bestMatch == ToneMatch.exact) {
        totalPoints += 1.0;
      } else if (bestMatch == ToneMatch.wrongTone) {
        totalPoints += 0.65;
      }

      syllables.add(SyllableScore(
        char: ch,
        expectedPinyin: expPy,
        spokenPinyin: matchedPy,
        match: bestMatch,
      ));
    }

    final score = ((totalPoints / targetChars.length) * 100).round().clamp(0, 100);
    final String feedback;
    if (score >= 90) {
      feedback = 'Phát âm rất chuẩn! Tiếp tục phát huy nhé.';
    } else if (score >= 65) {
      feedback = 'Khá tốt! Chú ý thanh điệu ở các âm màu vàng.';
    } else {
      feedback = 'Cần luyện thêm các âm màu đỏ. Hãy nghe mẫu chậm rồi đọc lại.';
    }

    return PronunciationEvaluation(
      transcript: rawTranscript,
      score: score,
      syllables: syllables,
      feedback: feedback,
    );
  }

  static List<String> _splitPinyin(String pinyin, int count) {
    final cleaned = pinyin
        .replaceAll('\u200b', ' ')
        .replaceAll(RegExp(r'[，。！？、“”‘’,.!?;:]'), ' ')
        .trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length == count) return parts;
    return parts;
  }
}
