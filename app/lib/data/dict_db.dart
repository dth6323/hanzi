import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_bridge.dart';
import 'models.dart';
import 'text_utils.dart';
import '../writing/stroke_matcher.dart';

/// Read-only access to the bundled dictionary (assets/db/vi_full.db).
class DictDb {
  DictDb._();
  static final DictDb instance = DictDb._();

  static const _assetPath = 'assets/db/vi_full.db';
  static const _fileName = 'vi_full.db';
  // Bump when the bundled DB changes so the copy is refreshed.
  static const _dbVersion = '2026-10-31';

  late Database _db;

  Future<void> init({void Function(String)? onStatus}) async {
    if (useHttpBridge) {
      _db = await appDbFactory.openDatabase(
        _fileName,
        options: OpenDatabaseOptions(readOnly: true),
      );
      return;
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    final marker = File('$path.version');
    final needsCopy = !File(path).existsSync() ||
        !marker.existsSync() ||
        marker.readAsStringSync() != _dbVersion;
    if (needsCopy) {
      onStatus?.call('Đang chuẩn bị dữ liệu từ điển (chỉ lần đầu)…');
      await Directory(dir).create(recursive: true);
      final data = await rootBundle.load(_assetPath);
      await File(path).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      marker.writeAsStringSync(_dbVersion);
    }
    _db = await openDatabase(path, readOnly: true);
  }

  static const _wordCols =
      'id, simp, trad, pinyin, hanviet, hsk, rank, short_mean';

  // ---------------- Search ----------------

  Future<List<Word>> search(String raw, {int limit = 60}) async {
    final q = raw.trim();
    if (q.isEmpty) return [];
    if (hasCjk(q)) {
      final rows = await _db.rawQuery(
        'SELECT $_wordCols FROM words '
        'WHERE simp LIKE ? OR trad LIKE ? '
        'ORDER BY (simp = ? OR trad = ?) DESC, length(simp), rank '
        'LIMIT ?',
        ['$q%', '$q%', q, q, limit],
      );
      final list = rows.map(Word.fromRow).toList();
      if (list.length < 10 && q.length > 1) {
        // Fallback: words containing the query anywhere.
        final more = await _db.rawQuery(
          'SELECT $_wordCols FROM words WHERE simp LIKE ? '
          'ORDER BY rank LIMIT ?',
          ['%$q%', limit],
        );
        _mergeInto(list, more.map(Word.fromRow));
      }
      return list;
    }

    final plain = removeDiacritics(q.toLowerCase());
    final key = plain.replaceAll(RegExp(r'[^a-z]'), '');
    final spaced = plain.replaceAll(RegExp(r'\s+'), ' ');
    final result = <Word>[];

    if (key.isNotEmpty) {
      final py = await _db.rawQuery(
        'SELECT $_wordCols FROM words WHERE pinyin_key LIKE ? '
        'ORDER BY (pinyin_key = ?) DESC, rank LIMIT 30',
        ['$key%', key],
      );
      _mergeInto(result, py.map(Word.fromRow));
    }
    final hv = await _db.rawQuery(
      'SELECT $_wordCols FROM words WHERE hanviet_key LIKE ? '
      'ORDER BY (hanviet_key = ?) DESC, rank LIMIT 20',
      ['$spaced%', spaced],
    );
    _mergeInto(result, hv.map(Word.fromRow));

    final tokens = spaced
        .split(' ')
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll('"', ''))
        .toList();
    if (tokens.isNotEmpty) {
      final match = '"${tokens.join(' ')}"';
      try {
        final fts = await _db.rawQuery(
          'SELECT $_wordCols FROM words WHERE id IN '
          '(SELECT rowid FROM mean_fts WHERE mean_fts MATCH ? LIMIT 400) '
          'ORDER BY rank IS NULL, rank LIMIT 30',
          [match],
        );
        _mergeInto(result, fts.map(Word.fromRow));
      } catch (_) {
        // Fallback when SQLite engine (e.g. sql.js WASM) wasn't compiled with FTS5
        final phrase = tokens.join(' ');
        final likeRows = await _db.rawQuery(
          'SELECT $_wordCols FROM words WHERE id IN '
          '(SELECT id FROM mean_fts_content WHERE c0 LIKE ? LIMIT 300) '
          'ORDER BY rank IS NULL, rank LIMIT 30',
          ['%$phrase%'],
        );
        _mergeInto(result, likeRows.map(Word.fromRow));
      }
    }
    return result.take(limit).toList();
  }

  void _mergeInto(List<Word> target, Iterable<Word> src) {
    final ids = target.map((w) => w.id).toSet();
    for (final w in src) {
      if (ids.add(w.id)) target.add(w);
    }
  }

  // ---------------- Word detail ----------------

  Future<Word?> word(int id) async {
    final r = await _db
        .rawQuery('SELECT $_wordCols FROM words WHERE id = ?', [id]);
    return r.isEmpty ? null : Word.fromRow(r.first);
  }

  Future<Word?> wordBySimp(String simp) async {
    final r = await _db.rawQuery(
        'SELECT $_wordCols FROM words WHERE simp = ? ORDER BY rank LIMIT 1',
        [simp]);
    return r.isEmpty ? null : Word.fromRow(r.first);
  }

  /// Segments a Chinese paragraph/sentence into known dictionary words
  /// using Maximum Forward Matching (up to 4 chars per word).
  Future<List<Word>> segmentChineseText(String text) async {
    final chars = cjkChars(text);
    if (chars.isEmpty) return const [];
    final joined = chars.join();

    // Collect all candidate substrings of length 1..4
    final candidates = <String>{};
    for (var i = 0; i < joined.length; i++) {
      for (var len = 1; len <= 4 && i + len <= joined.length; len++) {
        candidates.add(joined.substring(i, i + len));
      }
    }
    if (candidates.isEmpty) return const [];

    final list = candidates.toList();
    final map = <String, Word>{};
    // Query in chunks of 150 to stay well within SQLite parameter limits
    for (var start = 0; start < list.length; start += 150) {
      final chunk = list.skip(start).take(150).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT $_wordCols FROM words '
        'WHERE simp IN ($placeholders) OR trad IN ($placeholders) '
        'ORDER BY rank IS NULL, rank ASC',
        [...chunk, ...chunk],
      );
      for (final r in rows) {
        final w = Word.fromRow(r);
        map.putIfAbsent(w.simp, () => w);
        if (w.trad.isNotEmpty) map.putIfAbsent(w.trad, () => w);
      }
    }

    // Greedy Maximum Forward Matching
    final out = <Word>[];
    final seenIds = <int>{};
    var i = 0;
    while (i < joined.length) {
      Word? matched;
      var step = 1;
      for (var len = 4; len >= 1; len--) {
        if (i + len > joined.length) continue;
        final sub = joined.substring(i, i + len);
        final w = map[sub];
        if (w != null) {
          matched = w;
          step = len;
          break;
        }
      }
      if (matched != null && seenIds.add(matched.id)) {
        out.add(matched);
      }
      i += step;
    }
    return out;
  }

  Future<List<Sense>> senses(int wordId) async {
    final rows = await _db.rawQuery(
        'SELECT id, kind, gloss, explain FROM senses WHERE word_id = ? '
        'ORDER BY sort',
        [wordId]);
    final out = <Sense>[];
    for (final r in rows) {
      final ex = await _db.rawQuery(
        'SELECT e.id, e.zh, e.pinyin, e.mean FROM sense_examples se '
        'JOIN examples e ON e.id = se.example_id '
        'WHERE se.sense_id = ? ORDER BY se.sort LIMIT 6',
        [r['id']],
      );
      out.add(Sense(
        kind: r['kind'] as String?,
        gloss: r['gloss'] as String,
        explain: r['explain'] as String?,
        examples: ex.map(Example.fromRow).toList(),
      ));
    }
    return out;
  }

  Future<Map<String, List<String>>> relations(int wordId) async {
    final rows = await _db.rawQuery(
        'SELECT kind, target, extra FROM word_rel WHERE word_id = ? '
        'ORDER BY kind, sort',
        [wordId]);
    final map = <String, List<String>>{};
    for (final r in rows) {
      final kind = r['kind'] as String;
      var target = r['target'] as String;
      final extra = r['extra'] as String?;
      if (kind == 'measure' && extra != null && extra.isNotEmpty) {
        target = '$target  ($extra)';
      }
      map.putIfAbsent(kind, () => []).add(target);
    }
    return map;
  }

  Future<List<Note>> notes(int wordId) async {
    final rows = await _db.rawQuery(
        'SELECT kind, title, body, examples FROM notes WHERE word_id = ?',
        [wordId]);
    final out = <Note>[];
    for (final r in rows) {
      var examples = <Example>[];
      final ids = (jsonDecode((r['examples'] as String?) ?? '[]') as List)
          .cast<num>()
          .map((e) => e.toInt())
          .toList();
      if (ids.isNotEmpty) {
        final ex = await _db.rawQuery(
            'SELECT id, zh, pinyin, mean FROM examples WHERE id IN '
            '(${List.filled(ids.length, '?').join(',')})',
            ids);
        examples = ex.map(Example.fromRow).toList();
      }
      out.add(Note(
        kind: r['kind'] as String,
        title: r['title'] as String,
        body: (r['body'] as String?) ?? '',
        examples: examples,
      ));
    }
    return out;
  }

  // ---------------- Characters ----------------

  Future<HanChar?> char(String c) async {
    final r = await _db.rawQuery('SELECT * FROM chars WHERE char = ?', [c]);
    return r.isEmpty ? null : HanChar.fromRow(r.first);
  }

  /// Characters with stroke data, ordered by how common they are.
  Future<List<String>> charsForHsk(int level) async {
    final rows = await _db.rawQuery(
        'SELECT simp FROM words WHERE hsk = ? AND length(simp) = 1 '
        'ORDER BY rank',
        [level]);
    return rows.map((r) => r['simp'] as String).toList();
  }

  // ---------------- Browsing ----------------

  Future<List<Word>> wordsByHsk(int level) async {
    final rows = await _db.rawQuery(
        'SELECT $_wordCols FROM words WHERE hsk = ? ORDER BY rank', [level]);
    return rows.map(Word.fromRow).toList();
  }

  Future<List<Topic>> topics() async {
    final rows = await _db.rawQuery(
        'SELECT t.id, t.name, COUNT(wt.word_id) AS n FROM topics t '
        'JOIN word_topics wt ON wt.topic_id = t.id '
        'GROUP BY t.id ORDER BY t.name');
    return rows
        .map((r) => Topic(r['id'] as int, r['name'] as String, r['n'] as int))
        .toList();
  }

  Future<List<Word>> wordsByTopic(int topicId) async {
    final rows = await _db.rawQuery(
        'SELECT w.id, w.simp, w.trad, w.pinyin, w.hanviet, w.hsk, w.rank, '
        'w.short_mean FROM word_topics wt JOIN words w ON w.id = wt.word_id '
        'WHERE wt.topic_id = ? ORDER BY w.rank IS NULL, w.rank',
        [topicId]);
    return rows.map(Word.fromRow).toList();
  }

  Future<List<String>> grammarLevels() async {
    final rows = await _db.rawQuery(
        'SELECT level FROM grammar GROUP BY level ORDER BY MIN(id)');
    return rows.map((r) => (r['level'] as String?) ?? '').toList();
  }

  Future<List<Grammar>> grammarByLevel(String level) async {
    final rows = await _db.rawQuery(
        'SELECT * FROM grammar WHERE level = ? ORDER BY id', [level]);
    return rows.map(Grammar.fromRow).toList();
  }

  // ---------------- Quiz question pools ----------------

  Future<List<Word>> randomHskWords({int? level, int limit = 60}) async {
    if (level != null) {
      final rows = await _db.rawQuery(
        'SELECT $_wordCols FROM words WHERE hsk = ? AND short_mean != "" '
        'ORDER BY RANDOM() LIMIT ?',
        [level, limit],
      );
      return rows.map(Word.fromRow).toList();
    }
    final rows = await _db.rawQuery(
      'SELECT $_wordCols FROM words WHERE hsk IS NOT NULL AND short_mean != "" '
      'ORDER BY RANDOM() LIMIT ?',
      [limit],
    );
    return rows.map(Word.fromRow).toList();
  }

  /// Fetches random words that have a measure word relation.
  Future<List<({Word word, String measure})>> randomMeasureItems(
      {int limit = 20}) async {
    final rows = await _db.rawQuery(
      'SELECT w.id, w.simp, w.trad, w.pinyin, w.hanviet, w.hsk, w.rank, '
      'w.short_mean, r.target, r.extra '
      'FROM word_rel r JOIN words w ON w.id = r.word_id '
      'WHERE r.kind = "measure" AND length(w.simp) BETWEEN 1 AND 3 '
      'ORDER BY RANDOM() LIMIT ?',
      [limit],
    );
    return rows.map((r) {
      final firstMeasure = (r['target'] as String).split(',').first.trim();
      final firstPy = ((r['extra'] as String?) ?? '').split(',').first.trim();
      final label = firstPy.isNotEmpty ? '$firstMeasure ($firstPy)' : firstMeasure;
      return (word: Word.fromRow(r), measure: label);
    }).toList();
  }

  /// Fetches example sentences containing a target HSK word for cloze tests.
  Future<List<({Word word, Example example})>> randomClozeItems(
      {int? level, int limit = 20}) async {
    final words = await randomHskWords(level: level, limit: limit * 2);
    final out = <({Word word, Example example})>[];
    for (final w in words) {
      if (out.length >= limit) break;
      final rows = await _db.rawQuery(
        'SELECT e.id, e.zh, e.pinyin, e.mean '
        'FROM senses s JOIN sense_examples se ON se.sense_id = s.id '
        'JOIN examples e ON e.id = se.example_id '
        'WHERE s.word_id = ? AND e.zh LIKE ? AND length(e.zh) BETWEEN 4 AND 28 '
        'LIMIT 1',
        [w.id, '%${w.simp}%'],
      );
      if (rows.isNotEmpty) {
        final ex = Example.fromRow(rows.first);
        if (ex.zh != w.simp && ex.mean.isNotEmpty) {
          out.add((word: w, example: ex));
        }
      }
    }
    return out;
  }

  /// Example sentences filtered by HSK level (via word senses).
  Future<List<Example>> examplesByHsk(int hsk, {int limit = 40}) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT e.id, e.zh, e.pinyin, e.mean '
      'FROM examples e '
      'JOIN sense_examples se ON se.example_id = e.id '
      'JOIN senses s ON s.id = se.sense_id '
      'WHERE s.hsk = ? AND length(e.zh) BETWEEN 4 AND 28 '
      'LIMIT ?',
      [hsk, limit],
    );
    return rows.map(Example.fromRow).toList();
  }

  /// Search example sentences by Chinese characters, pinyin, or Vietnamese meaning.
  Future<List<Example>> searchExamples(String query, {int limit = 40}) async {
    final q = '%${query.trim()}%';
    final rows = await _db.rawQuery(
      'SELECT id, zh, pinyin, mean FROM examples '
      'WHERE (zh LIKE ? OR mean LIKE ? OR pinyin LIKE ?) AND length(zh) BETWEEN 3 AND 35 '
      'LIMIT ?',
      [q, q, q, limit],
    );
    return rows.map(Example.fromRow).toList();
  }

  /// Curated example sentences suitable for writing practice across elementary HSK levels.
  Future<List<Example>> recommendedExamples({int limit = 30}) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT e.id, e.zh, e.pinyin, e.mean '
      'FROM examples e '
      'JOIN sense_examples se ON se.example_id = e.id '
      'JOIN senses s ON s.id = se.sense_id '
      'WHERE s.hsk BETWEEN 1 AND 4 AND length(e.zh) BETWEEN 4 AND 22 '
      'LIMIT ?',
      [limit],
    );
    return rows.map(Example.fromRow).toList();
  }

  /// Recognizes a handwritten character from user-drawn stroke points in 1024 character space.
  Future<List<({String char, String pinyin, String hanviet, double distance})>>
      recognizeHandwriting(List<List<Pt>> strokes, {int limit = 12}) async {
    if (strokes.isEmpty) return const [];
    final k = strokes.length;
    final minK = (k - 1).clamp(1, 40);
    final maxK = k + 1;

    final rows = await _db.rawQuery(
      'SELECT char, pinyin, hanviet, stroke_count, popular, medians '
      'FROM chars '
      'WHERE stroke_count BETWEEN ? AND ? AND medians IS NOT NULL',
      [minK, maxK],
    );

    const nPoints = 12;
    final userResampled = strokes.map((s) => resample(s, nPoints)).toList();

    const popBonus = {
      'rất cao': 15.0,
      'cao': 10.0,
      'trung bình': 5.0,
      'thấp': 0.0,
      'rất thấp': -10.0,
    };

    double strokeDist(List<Pt> u, List<Pt> m) {
      var dFwd = 0.0;
      for (var i = 0; i < nPoints; i++) {
        dFwd += u[i].dist(m[i]);
      }
      dFwd /= nPoints;

      var dRev = 0.0;
      for (var i = 0; i < nPoints; i++) {
        dRev += u[nPoints - 1 - i].dist(m[i]);
      }
      dRev = (dRev / nPoints) + 20.0;

      return dFwd < dRev ? dFwd : dRev;
    }

    final candidates =
        <({String char, String pinyin, String hanviet, double distance})>[];

    for (final r in rows) {
      final medJson = r['medians'] as String?;
      if (medJson == null || medJson.isEmpty) continue;

      final med = (jsonDecode(medJson) as List)
          .map((s) => (s as List)
              .map((p) =>
                  Pt((p[0] as num).toDouble(), (p[1] as num).toDouble()))
              .toList())
          .toList();

      if (med.isEmpty) continue;

      final ch = r['char'] as String;
      final py = (r['pinyin'] as String?) ?? '';
      final hv = (r['hanviet'] as String?) ?? '';
      final pop = (r['popular'] as String?) ?? '';
      final bonus = popBonus[pop] ?? 0.0;

      final medResampled = med.map((s) => resample(s, nPoints)).toList();

      double score;
      if (med.length == k) {
        var inOrder = 0.0;
        for (var i = 0; i < k; i++) {
          inOrder += strokeDist(userResampled[i], medResampled[i]);
        }
        inOrder /= k;

        if (k <= 4) {
          var bestPerm = 0.0;
          for (final u in userResampled) {
            var minD = double.infinity;
            for (final m in medResampled) {
              final d = strokeDist(u, m);
              if (d < minD) minD = d;
            }
            bestPerm += minD;
          }
          bestPerm /= k;
          score = (inOrder < bestPerm + 20.0 ? inOrder : bestPerm + 20.0) - bonus;
        } else {
          score = inOrder - bonus;
        }
      } else {
        var totalDist = 0.0;
        for (final u in userResampled) {
          var minD = double.infinity;
          for (final m in medResampled) {
            final d = strokeDist(u, m);
            if (d < minD) minD = d;
          }
          totalDist += minD;
        }
        totalDist /= k;
        final penalty = 45.0 * (med.length - k).abs();
        score = totalDist + penalty - bonus;
      }

      candidates.add((char: ch, pinyin: py, hanviet: hv, distance: score));
    }

    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates.take(limit).toList();
  }
}
