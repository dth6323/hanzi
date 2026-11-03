import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'http_post_stub.dart'
    if (dart.library.io) 'http_post_io.dart'
    if (dart.library.html) 'http_post_web.dart';

bool get useHttpBridge =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.windows;

final DatabaseFactory _bridgeFactory = HttpBridgeDatabaseFactory();

DatabaseFactory get appDbFactory =>
    useHttpBridge ? _bridgeFactory : sqflite.databaseFactory;

/// A DatabaseFactory for Web & Desktop preview that proxies SQL queries
/// to a lightweight local Dart HTTP bridge backed by `sqlite3` CLI.
class HttpBridgeDatabaseFactory extends DatabaseFactory {
  final String baseUrl;
  HttpBridgeDatabaseFactory({this.baseUrl = 'http://127.0.0.1:43821'});

  @override
  Future<String> getDatabasesPath() async => '/home/hadz/code/hanzi';

  @override
  Future<void> setDatabasesPath(String path) async {}

  @override
  Future<bool> databaseExists(String path) async => true;

  @override
  Future<void> deleteDatabase(String path) async {}

  @override
  Future<Uint8List> readDatabaseBytes(String path) async => Uint8List(0);

  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) async {}

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) async {
    final db = _BridgeDatabase(
      baseUrl: baseUrl,
      dbName: path.endsWith('user.db') ? 'user.db' : 'vi_full.db',
    );
    if (options != null) {
      final v = options.version ?? 1;
      if (options.onCreate != null) {
        await options.onCreate!(db, v);
      }
      if (options.onUpgrade != null) {
        await options.onUpgrade!(db, 1, v);
      }
    }
    return db;
  }
}

class _BridgeDatabase implements Database {
  final String baseUrl;
  final String dbName;
  _BridgeDatabase({required this.baseUrl, required this.dbName});

  Future<List<Map<String, Object?>>> _rpc(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final payload = jsonEncode({
      'db': dbName,
      'sql': sql,
      'args': arguments ?? const [],
    });

    final resText = await postJson('$baseUrl/sql', payload);
    final decoded = jsonDecode(resText);
    if (decoded is Map && decoded['error'] != null) {
      throw Exception(decoded['error']);
    }
    final rows = (decoded['rows'] as List?) ?? const [];
    return rows
        .map((r) => (r as Map).map((k, v) => MapEntry(k.toString(), v as Object?)))
        .toList();
  }

  @override
  String get path => dbName;

  @override
  bool get isOpen => true;

  @override
  Database get database => this;

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _rpc(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    await _rpc(sql, arguments);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql,
      [List<Object?>? arguments]) {
    return _rpc(sql, arguments);
  }

  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments,
      {int? bufferSize}) {
    throw UnimplementedError();
  }

  @override
  Future<QueryCursor> queryCursor(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset,
      int? bufferSize}) {
    throw UnimplementedError();
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    await _rpc(sql, arguments);
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    await _rpc(sql, arguments);
    return 1;
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    final cols = values.keys.toList();
    final args = cols.map((k) => values[k]).toList();
    final conflict = conflictAlgorithm == ConflictAlgorithm.replace
        ? 'OR REPLACE'
        : conflictAlgorithm == ConflictAlgorithm.ignore
            ? 'OR IGNORE'
            : '';
    final placeholders = List.filled(cols.length, '?').join(', ');
    final sql =
        'INSERT $conflict INTO $table (${cols.join(", ")}) VALUES ($placeholders)';
    await _rpc(sql, args);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) {
    final cols = (columns == null || columns.isEmpty) ? '*' : columns.join(', ');
    final sb = StringBuffer('SELECT ${distinct == true ? "DISTINCT " : ""}$cols FROM $table');
    if (where != null && where.isNotEmpty) sb.write(' WHERE $where');
    if (groupBy != null && groupBy.isNotEmpty) sb.write(' GROUP BY $groupBy');
    if (having != null && having.isNotEmpty) sb.write(' HAVING $having');
    if (orderBy != null && orderBy.isNotEmpty) sb.write(' ORDER BY $orderBy');
    if (limit != null) sb.write(' LIMIT $limit');
    if (offset != null) sb.write(' OFFSET $offset');
    return _rpc(sb.toString(), whereArgs);
  }

  @override
  Future<int> update(String table, Map<String, Object?> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) async {
    final cols = values.keys.toList();
    final setClause = cols.map((c) => '$c = ?').join(', ');
    final args = [
      ...cols.map((k) => values[k]),
      ...(whereArgs ?? const []),
    ];
    final sql =
        'UPDATE $table SET $setClause${where != null ? " WHERE $where" : ""}';
    await _rpc(sql, args);
    return 1;
  }

  @override
  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    final sql = 'DELETE FROM $table${where != null ? " WHERE $where" : ""}';
    await _rpc(sql, whereArgs);
    return 1;
  }

  @override
  Batch batch() => _BridgeBatch(this);

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
      {bool? exclusive}) async {
    throw UnimplementedError();
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) {
    throw UnimplementedError();
  }

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) {
    throw UnimplementedError();
  }

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql,
      [List<Object?>? arguments]) {
    throw UnimplementedError();
  }
}

class _BridgeBatch implements Batch {
  final _BridgeDatabase _db;
  final List<Future<void> Function()> _ops = [];
  _BridgeBatch(this._db);

  @override
  int get length => _ops.length;

  @override
  Future<List<Object?>> commit(
      {bool? exclusive, bool? noResult, bool? continueOnError}) async {
    for (final op in _ops) {
      await op();
    }
    return const [];
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) =>
      commit(noResult: noResult, continueOnError: continueOnError);

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.rawInsert(sql, arguments));
  }

  @override
  void insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    _ops.add(() => _db.insert(table, values,
        nullColumnHack: nullColumnHack, conflictAlgorithm: conflictAlgorithm));
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.rawUpdate(sql, arguments));
  }

  @override
  void update(String table, Map<String, Object?> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) {
    _ops.add(() => _db.update(table, values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm));
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.rawDelete(sql, arguments));
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _ops.add(() => _db.delete(table, where: where, whereArgs: whereArgs));
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.execute(sql, arguments));
  }

  @override
  void query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) {}

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {}
}
