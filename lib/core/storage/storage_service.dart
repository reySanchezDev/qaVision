import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Servicio de persistencia local basado en SQLite embebido.
///
/// Mantiene una API de pares clave/valor para no romper repositorios
/// existentes, pero con consistencia transaccional entre procesos.
class StorageService {
  /// Crea una instancia de [StorageService].
  ///
  /// [filePath] permite inyectar ruta base para pruebas.
  /// Si termina en `.json`, se usa como archivo legado y la DB se crea
  /// como `*.json.db`.
  StorageService({String? filePath}) : _filePath = filePath;

  final String? _filePath;
  Database? _database;
  Map<String, dynamic> _cache = <String, dynamic>{};
  bool _initialized = false;
  String _cacheFingerprint = '{}';
  StreamSubscription<FileSystemEvent>? _dbWatchSubscription;
  Timer? _reloadDebounce;
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  /// Emite un evento cada vez que cambia el almacenamiento compartido.
  Stream<void> get changes => _changesController.stream;

  /// Ruta legacy del archivo JSON (usada para migración inicial).
  String get configFilePath {
    final localPath = _filePath;
    if (localPath != null && localPath.toLowerCase().endsWith('.json')) {
      return localPath;
    }
    final appData = Platform.environment['APPDATA'] ?? '.';
    return '$appData/QAVision/config.json';
  }

  /// Ruta del archivo SQLite.
  String get databaseFilePath {
    final localPath = _filePath;
    if (localPath != null) {
      if (localPath.toLowerCase().endsWith('.json')) {
        return '$localPath.db';
      }
      return localPath;
    }
    final appData = Platform.environment['APPDATA'] ?? '.';
    return '$appData/QAVision/qavision.db';
  }

  /// Inicializa conexión, esquema, migración y watcher.
  Future<void> init() async {
    if (_initialized) return;

    final dbFile = File(databaseFilePath);
    final dir = dbFile.parent;
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    _database = sqlite3.open(dbFile.path);
    _configureDatabase(_database!);
    _createSchema(_database!);
    await _migrateLegacyJsonIfNeeded(_database!);
    await _reloadFromDatabase(notify: false);

    _initialized = true;
    await _startWatching(dbFile);
  }

  /// Lee un valor del almacenamiento por su [key].
  T? getValue<T>(String key) {
    final value = _cache[key];
    if (value is T) return value;
    return null;
  }

  /// Guarda un [value] bajo la [key] indicada.
  Future<void> setValue<T>(String key, T value) async {
    await _upsertKey(key, value);
  }

  /// Elimina un valor del almacenamiento por su [key].
  Future<void> removeValue(String key) async {
    await _ensureInitialized();
    final db = _database;
    if (db == null) return;

    db.execute('DELETE FROM kv_store WHERE storage_key = ?', <Object?>[key]);
    _cache.remove(key);
    _cacheFingerprint = _computeFingerprint(_cache);
    _notifyChange();
  }

  /// Obtiene un mapa completo almacenado bajo [key].
  Map<String, dynamic>? getMap(String key) {
    final value = _cache[key];
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Guarda un mapa completo bajo [key].
  Future<void> setMap(String key, Map<String, dynamic> value) async {
    await _upsertKey(key, Map<String, dynamic>.from(value));
  }

  /// Obtiene una lista de mapas almacenada bajo [key].
  List<Map<String, dynamic>> getMapList(String key) {
    final value = _cache[key];
    if (value is List) {
      return value
          .whereType<Map<Object?, Object?>>()
          .map((entry) => entry.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  /// Guarda una lista de mapas bajo [key].
  Future<void> setMapList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    await _upsertKey(
      key,
      value.map(Map<String, dynamic>.from).toList(),
    );
  }

  /// Fuerza una recarga desde SQLite para reflejar cambios de otros procesos.
  Future<void> reloadFromDisk() async {
    await _ensureInitialized();
    await _reloadFromDatabase();
  }

  /// Libera recursos internos (watcher + conexión).
  Future<void> dispose() async {
    _reloadDebounce?.cancel();
    await _dbWatchSubscription?.cancel();
    try {
      _database?.dispose();
    } on Exception {
      // No-op
    }
    _database = null;
    _initialized = false;
    if (!_changesController.isClosed) {
      await _changesController.close();
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  Future<void> _upsertKey(String key, Object? value) async {
    await _ensureInitialized();
    final db = _database;
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final encoded = jsonEncode(value);

    db.execute(
      '''
      INSERT INTO kv_store (storage_key, json_value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(storage_key) DO UPDATE SET
        json_value = excluded.json_value,
        updated_at = excluded.updated_at
      ''',
      <Object?>[key, encoded, now],
    );

    _cache[key] = value;
    _cacheFingerprint = _computeFingerprint(_cache);
    _notifyChange();
  }

  Future<void> _reloadFromDatabase({bool notify = true}) async {
    final db = _database;
    if (db == null) return;

    final rows = db.select(
      'SELECT storage_key, json_value FROM kv_store ORDER BY storage_key',
    );

    final next = <String, dynamic>{};
    for (final row in rows) {
      final key = row['storage_key'] as String?;
      final payload = row['json_value'] as String?;
      if (key == null || payload == null) continue;

      try {
        next[key] = jsonDecode(payload);
      } on Exception {
        next[key] = payload;
      }
    }

    final nextFingerprint = _computeFingerprint(next);
    if (nextFingerprint == _cacheFingerprint) return;

    _cache = next;
    _cacheFingerprint = nextFingerprint;
    if (notify) {
      _notifyChange();
    }
  }

  Future<void> _startWatching(File dbFile) async {
    await _dbWatchSubscription?.cancel();

    final dir = dbFile.parent;
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    try {
      _dbWatchSubscription = dir.watch().listen((event) {
        if (!_isDatabaseFileEvent(event.path)) return;
        _scheduleReloadFromDatabase();
      });
    } on Exception catch (e) {
      debugPrint('QAVision: no se pudo iniciar watcher SQLite: $e');
    }
  }

  bool _isDatabaseFileEvent(String path) {
    final expected = _extractFileName(databaseFilePath).toLowerCase();
    final incoming = _extractFileName(path).toLowerCase();
    return incoming == expected ||
        incoming == '$expected-wal' ||
        incoming == '$expected-shm';
  }

  String _extractFileName(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final pieces = normalized.split('/');
    return pieces.isEmpty ? normalized : pieces.last;
  }

  void _scheduleReloadFromDatabase() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(_reloadFromDatabase());
    });
  }

  Future<void> _migrateLegacyJsonIfNeeded(Database db) async {
    final rows = db.select('SELECT COUNT(*) AS total FROM kv_store');
    final total = rows.isEmpty ? 0 : ((rows.first['total'] as int?) ?? 0);
    if (total > 0) {
      return;
    }

    final legacyFile = File(configFilePath);
    if (!legacyFile.existsSync()) {
      return;
    }

    try {
      final content = await legacyFile.readAsString();
      final legacyMap = _decodeConfigMap(content);
      if (legacyMap.isEmpty) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      db.execute('BEGIN IMMEDIATE TRANSACTION');
      try {
        for (final entry in legacyMap.entries) {
          db.execute(
            '''
            INSERT INTO kv_store (storage_key, json_value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(storage_key) DO UPDATE SET
              json_value = excluded.json_value,
              updated_at = excluded.updated_at
            ''',
            <Object?>[entry.key, jsonEncode(entry.value), now],
          );
        }
        db.execute('COMMIT');
      } on Exception {
        db.execute('ROLLBACK');
        rethrow;
      }
    } on Exception catch (e) {
      debugPrint('QAVision: error migrando config legacy a SQLite: $e');
    }
  }

  Map<String, dynamic> _decodeConfigMap(String content) {
    if (content.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final raw = jsonDecode(content);
    if (raw is! Map) {
      return <String, dynamic>{};
    }

    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  void _configureDatabase(Database db) {
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } on Exception {
      // Si WAL no se habilita, SQLite funciona con journal por defecto.
    }
    db
      ..execute('PRAGMA busy_timeout = 4000;')
      ..execute('PRAGMA synchronous = NORMAL;')
      ..execute('PRAGMA foreign_keys = ON;');
  }

  void _createSchema(Database db) {
    db
      ..execute('''
      CREATE TABLE IF NOT EXISTS kv_store (
        storage_key TEXT PRIMARY KEY,
        json_value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS idx_kv_store_updated_at '
        'ON kv_store(updated_at)',
      );
  }

  String _computeFingerprint(Map<String, dynamic> map) {
    final entries = map.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final sorted = <String, dynamic>{
      for (final entry in entries) entry.key: entry.value,
    };
    return jsonEncode(sorted);
  }

  void _notifyChange() {
    if (_changesController.isClosed) return;
    _changesController.add(null);
  }
}
