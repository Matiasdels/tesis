import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

    // Versión 1 de tu base de datos
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Tabla de Partidos
    await db.execute('''
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        opponent_name TEXT NOT NULL,
        match_date TEXT NOT NULL,
        is_live INTEGER NOT NULL DEFAULT 1,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabla de Eventos del partido (Goles, tarjetas, cambios)
    await db.execute('''
      CREATE TABLE match_events (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL,
        player_name TEXT NOT NULL,
        event_type TEXT NOT NULL, -- 'GOL', 'TARJETA_AMARILLA', 'ASISTENCIA'
        minute INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (match_id) REFERENCES matches (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- MÉTODOS PARA AGREGAR Y CONSULTAR DATOS ---

  // 1. Guardar un nuevo partido
  Future<int> insertMatch(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('matches', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 2. Guardar un evento (Gol, falta, etc.) del menú radial
  Future<int> insertEvent(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('match_events', row);
  }

  // 3. Traer todos los partidos (para tu Dashboard / Matches)
  Future<List<Map<String, dynamic>>> getMatches() async {
    final db = await instance.database;
    return await db.query('matches', orderBy: 'match_date DESC');
  }

  // 4. Traer los eventos de un partido específico
  Future<List<Map<String, dynamic>>> getEventsForMatch(String matchId) async {
    final db = await instance.database;
    return await db
        .query('match_events', where: 'match_id = ?', whereArgs: [matchId]);
  }

  Future close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
