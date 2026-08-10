import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('estadisticas_futbol.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await _createCacheAndSyncTables(db);
    await _createAuthTables(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _dropLegacyTables(db);
    }
    await _createCacheAndSyncTables(db);
    await _createAuthTables(db);
  }

  Future<void> _dropLegacyTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS match_events');
    await db.execute('DROP TABLE IF EXISTS matches');
  }

  Future<void> _createCacheAndSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_cache (
        cache_key TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        entity TEXT NOT NULL,
        action TEXT NOT NULL,
        method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
  }

  Future<void> _createAuthTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        data TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveJson(String key, Object? value) async {
    final db = await database;
    await db.insert(
      'local_cache',
      {
        'cache_key': key,
        'payload': jsonEncode(value),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<dynamic>?> readJsonList(String key) async {
    final data = await _readJson(key);
    return data is List<dynamic> ? data : null;
  }

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final data = await _readJson(key);
    return data is Map<String, dynamic> ? data : null;
  }

  Future<Object?> _readJson(String key) async {
    final db = await database;
    final rows = await db.query(
      'local_cache',
      columns: ['payload'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Object?;
  }

  Future<PendingSyncAction> enqueueSyncAction({
    required String entity,
    required String action,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    final id = '${DateTime.now().toUtc().microsecondsSinceEpoch}_$entity';
    final row = {
      'id': id,
      'entity': entity,
      'action': action,
      'method': method,
      'endpoint': endpoint,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
      'last_error': null,
    };
    await db.insert('sync_queue', row);
    return PendingSyncAction.fromDb(row);
  }

  Future<List<PendingSyncAction>> getPendingSyncActions() async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingSyncAction.fromDb).toList();
  }

  Future<void> markSyncActionCompleted(String id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSyncActionFailed(String id, Object error) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE sync_queue
      SET attempts = attempts + 1,
          last_error = ?
      WHERE id = ?
      ''',
      [error.toString(), id],
    );
  }

  Future<void> markSyncActionConnectionFailed(String id, Object error) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE sync_queue
      SET last_error = ?
      WHERE id = ?
      ''',
      [error.toString(), id],
    );
  }

  Future<void> deletePendingEventByLocalId(int localEventoId) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      columns: ['id', 'payload'],
      where: 'entity = ? AND action = ?',
      whereArgs: [
        'evento_partido',
        'create',
      ],
    );

    for (final row in rows) {
      final payloadText = row['payload'] as String?;
      if (payloadText == null) continue;

      try {
        final payload = jsonDecode(payloadText) as Map<String, dynamic>;
        if (payload['localEventoId'] == localEventoId) {
          await db.delete(
            'sync_queue',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      } catch (_) {
        // Si el payload esta corrupto, no se elimina automaticamente.
      }
    }
  }

  Future<void> removeCachedEventByLocalId(
    int partidoId,
    int localEventoId,
  ) async {
    final key = 'matches:$partidoId:events';
    final cached = await readJsonList(key);
    if (cached == null) return;

    var changed = false;
    final filtered = <dynamic>[];
    for (final item in cached) {
      if (item is Map<String, dynamic> && item['eventoId'] == localEventoId) {
        changed = true;
        continue;
      }
      filtered.add(item);
    }

    if (changed) {
      await saveJson(key, filtered);
    }
  }

  Future<void> deletePendingMatchEstado(int partidoId) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: "entity = ? AND action = ? AND endpoint LIKE ?",
      whereArgs: [
        'partido_estado',
        'update_period',
        '%/api/Partidos/$partidoId/estado%',
      ],
    );
  }

  Future<int> pendingSyncCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS count FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

class PendingSyncAction {
  final String id;
  final String entity;
  final String action;
  final String method;
  final String endpoint;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  const PendingSyncAction({
    required this.id,
    required this.entity,
    required this.action,
    required this.method,
    required this.endpoint,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  factory PendingSyncAction.fromDb(Map<String, Object?> row) {
    return PendingSyncAction(
      id: row['id'] as String,
      entity: row['entity'] as String,
      action: row['action'] as String,
      method: row['method'] as String,
      endpoint: row['endpoint'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(row['created_at'] as String),
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String?,
    );
  }
}
