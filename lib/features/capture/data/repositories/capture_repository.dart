import 'dart:convert';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';

/// Implementación concreta de [ICaptureRepository] usando [StorageService].
class CaptureRepository implements ICaptureRepository {
  /// Crea una instancia de [CaptureRepository].
  CaptureRepository({required StorageService storageService})
    : _storage = storageService;

  final StorageService _storage;
  static const _storageKey = 'capture_history';

  @override
  Future<void> saveCapture(CaptureEntity capture) async {
    final history = await _loadHistory();
    history.insert(
      0,
      capture,
    ); // Insertar al inicio para que el más reciente esté primero

    // Limitar a los últimos 50 para no saturar el JSON
    final limitedHistory = history.take(50).toList();
    await _saveHistory(limitedHistory);
  }

  @override
  Future<List<CaptureEntity>> getRecentCaptures({int limit = 10}) async {
    final history = await _loadHistory();
    return history.take(limit).toList();
  }

  @override
  Future<List<CaptureEntity>> getHistory() async {
    return _loadHistory();
  }

  @override
  Future<void> deleteCapture(String id) async {
    final history = await _loadHistory();
    history.removeWhere((c) => c.id == id);
    await _saveHistory(history);
  }

  Future<List<CaptureEntity>> _loadHistory() async {
    final data = _storage.getValue<String>(_storageKey);
    if (data == null) return [];

    try {
      final jsonList = json.decode(data) as List<dynamic>;
      return jsonList.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } on Exception catch (_) {
      return [];
    }
  }

  Future<void> _saveHistory(List<CaptureEntity> history) async {
    final jsonList = history.map(_toJson).toList();
    await _storage.setValue<String>(_storageKey, json.encode(jsonList));
  }

  CaptureEntity _fromJson(Map<String, dynamic> json) {
    return CaptureEntity(
      id: json['id'] as String,
      path: json['path'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      projectName: json['projectName'] as String,
    );
  }

  Map<String, dynamic> _toJson(CaptureEntity entity) {
    return {
      'id': entity.id,
      'path': entity.path,
      'timestamp': entity.timestamp.toIso8601String(),
      'projectName': entity.projectName,
    };
  }
}
