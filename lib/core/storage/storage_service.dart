import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Servicio de persistencia local basado en archivo JSON.
///
/// Almacena la configuración del sistema y datos de proyectos
/// en un archivo JSON local. Es la única fuente de verdad para
/// la persistencia de datos de la aplicación.
class StorageService {
  /// Crea una instancia de [StorageService].
  ///
  /// [filePath] es la ruta absoluta al archivo JSON de configuración.
  /// Si no se proporciona, se usará la ruta por defecto del sistema.
  StorageService({String? filePath}) : _filePath = filePath;

  final String? _filePath;
  Map<String, dynamic> _cache = {};
  bool _initialized = false;

  /// Ruta al archivo de configuración.
  String get configFilePath {
    if (_filePath != null) return _filePath;
    // Ruta por defecto en AppData del usuario
    final appData = Platform.environment['APPDATA'] ?? '.';
    return '$appData/QAVision/config.json';
  }

  /// Inicializa el servicio cargando los datos del archivo JSON.
  ///
  /// Si el archivo no existe, se crea con un mapa vacío.
  Future<void> init() async {
    if (_initialized) return;

    final file = File(configFilePath);
    if (file.existsSync()) {
      try {
        final content = await file.readAsString();
        _cache = json.decode(content) as Map<String, dynamic>;
      } on Exception catch (e) {
        debugPrint('Error al leer configuración: $e');
        _cache = {};
      }
    } else {
      _cache = {};
      await _persist();
    }
    _initialized = true;
  }

  /// Lee un valor del almacenamiento por su [key].
  ///
  /// Retorna `null` si la clave no existe.
  T? getValue<T>(String key) {
    final value = _cache[key];
    if (value is T) return value;
    return null;
  }

  /// Guarda un [value] en el almacenamiento bajo la [key] dada.
  Future<void> setValue<T>(String key, T value) async {
    _cache[key] = value;
    await _persist();
  }

  /// Elimina un valor del almacenamiento por su [key].
  Future<void> removeValue(String key) async {
    _cache.remove(key);
    await _persist();
  }

  /// Obtiene un mapa completo almacenado bajo [key].
  Map<String, dynamic>? getMap(String key) {
    final value = _cache[key];
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  /// Guarda un mapa completo bajo [key].
  Future<void> setMap(String key, Map<String, dynamic> value) async {
    _cache[key] = value;
    await _persist();
  }

  /// Obtiene una lista de mapas almacenada bajo [key].
  List<Map<String, dynamic>> getMapList(String key) {
    final value = _cache[key];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Guarda una lista de mapas bajo [key].
  Future<void> setMapList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    _cache[key] = value;
    await _persist();
  }

  /// Persiste el caché en disco de forma segura.
  Future<void> _persist() async {
    try {
      final file = File(configFilePath);
      final dir = file.parent;
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      final jsonString = const JsonEncoder.withIndent('  ').convert(_cache);
      await file.writeAsString(jsonString);
    } on Exception catch (e) {
      debugPrint('Error al persistir configuración: $e');
    }
  }
}
