import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'db_bridge.dart';

class SrsCard {
  final int wordId;
  final String simp;
  final String pinyin;
  final String mean;
  final int reps;
  final int intervalDays;
  final double ease;
  final int dueMs;
  final int lastReviewMs;

  const SrsCard({
    required this.wordId,
    required this.simp,
    required this.pinyin,
    required this.mean,
    required this.reps,
    required this.intervalDays,
    required this.ease,
    required this.dueMs,
    required this.lastReviewMs,
  });

  factory SrsCard.fromRow(Map<String, Object?> r) => SrsCard(
        wordId: r['word_id'] as int,
        simp: (r['simp'] as String?) ?? '',
        pinyin: (r['pinyin'] as String?) ?? '',
        mean: (r['mean'] as String?) ?? '',
        reps: (r['reps'] as int?) ?? 0,
        intervalDays: (r['interval_days'] as int?) ?? 0,
        ease: ((r['ease'] as num?) ?? 2.5).toDouble(),
        dueMs: (r['due'] as int?) ?? 0,
        lastReviewMs: (r['last_review'] as int?) ?? 0,
      );

  /// Computes next SM-2 scheduling state for rating [grade] (0=Again, 1=Hard, 2=Good, 3=Easy).
  SrsCard review(int grade, {int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    var nextReps = reps;
    var nextInterval = intervalDays;
    var nextEase = ease;

    if (grade == 0) {
      nextReps = 0;
      nextInterval = 0; // Due again in 10 minutes
      nextEase = (ease - 0.2).clamp(1.3, 3.0);
      return SrsCard(
        wordId: wordId,
        simp: simp,
        pinyin: pinyin,
        mean: mean,
        reps: nextReps,
        intervalDays: nextInterval,
        ease: nextEase,
        dueMs: now + 10 * 60 * 1000,
        lastReviewMs: now,
      );
    }

    if (grade == 1) {
      nextEase = (ease - 0.15).clamp(1.3, 3.0);
      nextInterval = reps == 0 ? 1 : ((intervalDays * 1.2).round().clamp(1, 3650));
    } else if (grade == 2) {
      if (reps == 0) {
        nextInterval = 1;
      } else if (reps == 1) {
        nextInterval = 3;
      } else {
        nextInterval = (intervalDays * ease).round().clamp(1, 3650);
      }
    } else {
      nextEase = (ease + 0.15).clamp(1.3, 3.0);
      if (reps == 0) {
        nextInterval = 4;
      } else {
        nextInterval = (intervalDays * nextEase * 1.3).round().clamp(2, 3650);
      }
    }
    nextReps = reps + 1;

    return SrsCard(
      wordId: wordId,
      simp: simp,
      pinyin: pinyin,
      mean: mean,
      reps: nextReps,
      intervalDays: nextInterval,
      ease: nextEase,
      dueMs: now + nextInterval * 86400000,
      lastReviewMs: now,
    );
  }
}

/// Local, writable learner data: favourites, history, writing stats, SRS flashcards, quiz history, backup.
class UserDb {
  UserDb._();
  static final UserDb instance = UserDb._();
  late Database _db;

  Future<void> init() async {
    final path = useHttpBridge
        ? 'user.db'
        : p.join(await getDatabasesPath(), 'user.db');
    _db = await appDbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, v) async {
          await _createV1(db);
          await _createV2(db);
        },
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) {
            await _createV2(db);
          }
        },
      ),
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS favorites (word_id INTEGER PRIMARY KEY, '
        'simp TEXT, pinyin TEXT, mean TEXT, added INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS history (word_id INTEGER PRIMARY KEY, '
        'simp TEXT, pinyin TEXT, mean TEXT, ts INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS writing (char TEXT PRIMARY KEY, '
        'attempts INTEGER, mistakes INTEGER, best INTEGER, ts INTEGER)');
  }

  Future<void> _createV2(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS srs ('
        'word_id INTEGER PRIMARY KEY, '
        'simp TEXT, pinyin TEXT, mean TEXT, '
        'reps INTEGER DEFAULT 0, '
        'interval_days INTEGER DEFAULT 0, '
        'ease REAL DEFAULT 2.5, '
        'due INTEGER DEFAULT 0, '
        'last_review INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS quiz_runs ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'mode TEXT, score INTEGER, total INTEGER, ts INTEGER)');
    await db.execute('CREATE TABLE IF NOT EXISTS activity_days ('
        'day TEXT PRIMARY KEY, actions INTEGER DEFAULT 1)');
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  String get _todayKey {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _touchActivity() async {
    await _db.execute(
      'INSERT INTO activity_days (day, actions) VALUES (?, 1) '
      'ON CONFLICT(day) DO UPDATE SET actions = actions + 1',
      [_todayKey],
    );
  }

  /// Calculates consecutive study days up to today/yesterday.
  Future<int> streakDays() async {
    final rows = await _db.query('activity_days', orderBy: 'day DESC', limit: 400);
    if (rows.isEmpty) return 0;
    final days = rows.map((r) => r['day'] as String).toSet();
    var cursor = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (!days.contains(fmt(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(fmt(cursor))) return 0;
    }
    var count = 0;
    while (days.contains(fmt(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  // ---------------- Favorites & SRS sync ----------------

  Future<bool> isFavorite(int wordId) async =>
      (await _db.query('favorites', where: 'word_id = ?', whereArgs: [wordId]))
          .isNotEmpty;

  Future<void> setFavorite(int wordId, String simp, String pinyin, String mean,
      bool fav) async {
    if (fav) {
      await _db.insert(
          'favorites',
          {
            'word_id': wordId,
            'simp': simp,
            'pinyin': pinyin,
            'mean': mean,
            'added': _now
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await addSrsIfAbsent(wordId, simp, pinyin, mean);
      await _touchActivity();
    } else {
      await _db.delete('favorites', where: 'word_id = ?', whereArgs: [wordId]);
    }
  }

  Future<List<Map<String, Object?>>> favorites() =>
      _db.query('favorites', orderBy: 'added DESC');

  // ---------------- SRS Flashcards ----------------

  Future<void> addSrsIfAbsent(
      int wordId, String simp, String pinyin, String mean) async {
    await _db.insert(
      'srs',
      {
        'word_id': wordId,
        'simp': simp,
        'pinyin': pinyin,
        'mean': mean,
        'reps': 0,
        'interval_days': 0,
        'ease': 2.5,
        'due': _now,
        'last_review': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> importWordsToSrs(
      Iterable<({int id, String simp, String pinyin, String mean})> words) async {
    var added = 0;
    final batch = _db.batch();
    final now = _now;
    for (final w in words) {
      batch.insert(
        'srs',
        {
          'word_id': w.id,
          'simp': w.simp,
          'pinyin': w.pinyin,
          'mean': w.mean,
          'reps': 0,
          'interval_days': 0,
          'ease': 2.5,
          'due': now,
          'last_review': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      added++;
    }
    await batch.commit(noResult: true);
    return added;
  }

  Future<List<SrsCard>> dueSrsCards({int limit = 50}) async {
    // Ensure all favorites are also in SRS deck
    final favs = await favorites();
    for (final f in favs) {
      await addSrsIfAbsent(
        f['word_id'] as int,
        (f['simp'] as String?) ?? '',
        (f['pinyin'] as String?) ?? '',
        (f['mean'] as String?) ?? '',
      );
    }
    final rows = await _db.query(
      'srs',
      where: 'due <= ?',
      whereArgs: [_now],
      orderBy: 'due ASC',
      limit: limit,
    );
    return rows.map(SrsCard.fromRow).toList();
  }

  Future<List<SrsCard>> allSrsCards({int limit = 200}) async {
    final rows = await _db.query('srs', orderBy: 'due ASC', limit: limit);
    return rows.map(SrsCard.fromRow).toList();
  }

  Future<({int total, int due, int mastered})> srsSummary() async {
    final total = Sqflite.firstIntValue(
            await _db.rawQuery('SELECT COUNT(*) FROM srs')) ??
        0;
    final due = Sqflite.firstIntValue(await _db
            .rawQuery('SELECT COUNT(*) FROM srs WHERE due <= ?', [_now])) ??
        0;
    final mastered = Sqflite.firstIntValue(await _db
            .rawQuery('SELECT COUNT(*) FROM srs WHERE interval_days >= 21')) ??
        0;
    return (total: total, due: due, mastered: mastered);
  }

  Future<void> saveSrsCard(SrsCard card) async {
    await _db.insert(
      'srs',
      {
        'word_id': card.wordId,
        'simp': card.simp,
        'pinyin': card.pinyin,
        'mean': card.mean,
        'reps': card.reps,
        'interval_days': card.intervalDays,
        'ease': card.ease,
        'due': card.dueMs,
        'last_review': card.lastReviewMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _touchActivity();
  }

  // ---------------- History ----------------

  Future<void> addHistory(
      int wordId, String simp, String pinyin, String mean) async {
    await _db.insert('history',
        {'word_id': wordId, 'simp': simp, 'pinyin': pinyin, 'mean': mean, 'ts': _now},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.execute('DELETE FROM history WHERE word_id NOT IN '
        '(SELECT word_id FROM history ORDER BY ts DESC LIMIT 200)');
  }

  Future<List<Map<String, Object?>>> history() =>
      _db.query('history', orderBy: 'ts DESC', limit: 100);

  Future<void> clearHistory() => _db.delete('history');

  // ---------------- Writing & Quiz ----------------

  /// Records one completed writing of [char]; score is 0–100.
  Future<void> recordWriting(String char, int mistakes, int score) async {
    await _db.execute(
      'INSERT INTO writing (char, attempts, mistakes, best, ts) '
      'VALUES (?, 1, ?, ?, ?) ON CONFLICT(char) DO UPDATE SET '
      'attempts = attempts + 1, mistakes = mistakes + excluded.mistakes, '
      'best = MAX(best, excluded.best), ts = excluded.ts',
      [char, mistakes, score, _now],
    );
    await _touchActivity();
  }

  Future<List<Map<String, Object?>>> writingStats() =>
      _db.query('writing', orderBy: 'ts DESC');

  Future<void> recordQuizRun(String mode, int score, int total) async {
    await _db.insert('quiz_runs', {
      'mode': mode,
      'score': score,
      'total': total,
      'ts': _now,
    });
    await _touchActivity();
  }

  Future<List<Map<String, Object?>>> quizRuns() =>
      _db.query('quiz_runs', orderBy: 'ts DESC', limit: 30);

  // ---------------- Offline JSON Backup / Restore ----------------

  Future<String> exportBackupJson() async {
    final data = {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'favorites': await _db.query('favorites'),
      'srs': await _db.query('srs'),
      'writing': await _db.query('writing'),
      'quiz_runs': await _db.query('quiz_runs'),
      'activity_days': await _db.query('activity_days'),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<int> importBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    var count = 0;
    final batch = _db.batch();
    for (final table in const [
      'favorites',
      'srs',
      'writing',
      'activity_days',
    ]) {
      final list = decoded[table];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            batch.insert(
              table,
              item.map((k, v) => MapEntry(k.toString(), v)),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            count++;
          }
        }
      }
    }
    await batch.commit(noResult: true);
    return count;
  }
}
