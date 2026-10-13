import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  // Patrón Singleton (Actividad 1)
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_environment.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Versión 3 para incluir la tabla de alertas
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        isAlert INTEGER NOT NULL
      )
    ''');

    // Tabla de alertas (Actividad 3)
    await db.execute('''
      CREATE TABLE alertas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sensor TEXT NOT NULL,
        valor TEXT NOT NULL,
        estado TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE readings ADD COLUMN ubicacion_nodo TEXT DEFAULT "Desconocida";');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alertas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sensor TEXT NOT NULL,
          valor TEXT NOT NULL,
          estado TEXT NOT NULL,
          fecha TEXT NOT NULL
        )
      ''');
    }
  }

  Future<int> insertReading(double value, String timestamp, int isAlert, String ubicacionNodo) async {
    final db = await instance.database;
    return await db.insert('readings', {
      'value': value,
      'timestamp': timestamp,
      'isAlert': isAlert,
      'ubicacion_nodo': ubicacionNodo,
    });
  }

  Future<List<Map<String, dynamic>>> getAllReadings() async {
    final db = await instance.database;
    return await db.query('readings', orderBy: 'id DESC');
  }

  // Método para insertar alertas reales o simuladas (Actividad 3)
  Future<int> insertAlerta(String sensor, String valor, String estado, String fecha) async {
    final db = await instance.database;
    return await db.insert('alertas', {
      'sensor': sensor,
      'valor': valor,
      'estado': estado,
      'fecha': fecha,
    });
  }

  Future<void> insertBatchReadings(List<Map<String, dynamic>> readingsList) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      var batch = txn.batch();
      for (var item in readingsList) {
        batch.insert('readings', item);
      }
      await batch.commit(noResult: true);
    });
  }

  String _generateChecksum(String fileContent) {
    var bytes = utf8.encode(fileContent);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> exportDataToCsv() async {
    final data = await getAllReadings();
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln("id,value,timestamp,isAlert,ubicacion_nodo");

    for (var row in data) {
      csvBuffer.writeln("${row['id']},${row['value']},${row['timestamp']},${row['isAlert']},${row['ubicacion_nodo']}");
    }

    String rawCsv = csvBuffer.toString();
    String checksum = _generateChecksum(rawCsv);
    return "# CHECKSUM:$checksum\n$rawCsv";
  }
}