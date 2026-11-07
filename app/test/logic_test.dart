import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanzi_app/data/text_utils.dart';
import 'package:hanzi_app/data/user_db.dart';
import 'package:hanzi_app/services/speech_scorer.dart';
import 'package:hanzi_app/writing/stroke_matcher.dart';

/// Medians for 好 taken from the bundled DB (via sqlite3 CLI if available).
List<List<Pt>>? _medians(String char) {
  try {
    final r = Process.runSync('sqlite3',
        ['-init', '/dev/null', '-list', '-noheader', 'assets/db/vi_full.db',
          "select medians from chars where char='$char'"]);
    final list = jsonDecode((r.stdout as String).trim()) as List;
    return list
        .map((s) => (s as List)
            .map((p) => Pt((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList())
        .toList();
  } catch (_) {
    return null;
  }
}

void main() {
  test('removeDiacritics', () {
    expect(removeDiacritics('xin chào đẹp'), 'xin chao dep');
    expect(removeDiacritics('nǐ hǎo lǜ'), 'ni hao lv');
  });

  test('cjkChars', () {
    expect(cjkChars('你好, 你们'), ['你', '好', '们']);
    expect(cjkCharsOrdered('谢谢大家！'), ['谢', '谢', '大', '家']);
    expect(hasCjk('hao'), isFalse);
  });

  group('matchStroke', () {
    final meds = _medians('好');

    test('exact median matches every stroke', () {
      if (meds == null) return;
      for (final m in meds) {
        expect(matchStroke(m, m).ok, isTrue);
      }
    });

    test('slightly wobbly stroke still matches', () {
      if (meds == null) return;
      for (final m in meds) {
        final wobbly = [
          for (var i = 0; i < m.length; i++)
            Pt(m[i].x + (i.isEven ? 30 : -30), m[i].y + 25)
        ];
        expect(matchStroke(wobbly, m).ok, isTrue);
      }
    });

    test('reversed stroke is rejected', () {
      if (meds == null) return;
      final m = meds[2]; // horizontal stroke
      expect(matchStroke(m.reversed.toList(), m).ok, isFalse);
    });

    test('drawing a different stroke is rejected', () {
      if (meds == null) return;
      expect(matchStroke(meds[5], meds[0]).ok, isFalse);
    });
  });

  test('writingScore', () {
    expect(writingScore(0, 6), 100);
    expect(writingScore(3, 6), 75);
    expect(writingScore(100, 6), 0);
  });

  group('SRS SM-2 scheduling', () {
    test('increases interval on good/easy and resets on again', () {
      const card0 = SrsCard(
        wordId: 1,
        simp: '你好',
        pinyin: 'nǐ hǎo',
        mean: 'xin chào',
        reps: 0,
        intervalDays: 0,
        ease: 2.5,
        dueMs: 0,
        lastReviewMs: 0,
      );
      final c1 = card0.review(2, nowMs: 1000); // Good -> 1 day
      expect(c1.reps, 1);
      expect(c1.intervalDays, 1);

      final c2 = c1.review(2, nowMs: 2000); // Good -> 3 days
      expect(c2.reps, 2);
      expect(c2.intervalDays, 3);

      final c3 = c2.review(3, nowMs: 3000); // Easy -> >3 days
      expect(c3.intervalDays, greaterThan(3));
      expect(c3.ease, greaterThan(2.5));

      final reset = c3.review(0, nowMs: 4000); // Again -> reset
      expect(reset.reps, 0);
      expect(reset.intervalDays, 0);
    });
  });

  group('SpeechScorer.gradeTokens', () {
    test('scores exact match 100 and tone mismatch partially', () {
      final exact = SpeechScorer.gradeTokens(
        targetChars: ['你', '好'],
        expectedPinyin: ['nǐ', 'hǎo'],
        spokenChars: ['你', '好'],
        spokenReadings: [
          ['nǐ'],
          ['hǎo'],
        ],
        rawTranscript: '你好',
      );
      expect(exact.score, 100);
      expect(exact.syllables.every((s) => s.match == ToneMatch.exact), isTrue);

      final wrongTone = SpeechScorer.gradeTokens(
        targetChars: ['你', '好'],
        expectedPinyin: ['nǐ', 'hǎo'],
        spokenChars: ['泥', '号'],
        spokenReadings: [
          ['ní'],
          ['hào'],
        ],
        rawTranscript: '泥号',
      );
      expect(wrongTone.score, 65);
      expect(
          wrongTone.syllables.every((s) => s.match == ToneMatch.wrongTone),
          isTrue);
    });
  });

  test('handwriting recognition stroke preprocessing', () {
    final meds = _medians('好');
    if (meds == null) return;
    expect(meds.length, 6);
    final r0 = resample(meds[0], 12);
    expect(r0.length, 12);
  });
}
