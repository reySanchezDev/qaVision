import 'dart:async';
import 'dart:io';

/// Tipo de cambio detectado en carpetas de proyecto.
enum ProjectFolderChangeType {
  /// Cambio inespecífico que requiere sincronización completa.
  dirty,

  /// Cambio por movimiento o renombrado de carpeta.
  moved,
}

/// Evento emitido por [ProjectFolderWatchService].
class ProjectFolderChangeEvent {
  /// Crea una instancia de [ProjectFolderChangeEvent].
  const ProjectFolderChangeEvent._({
    required this.type,
    this.oldPath,
    this.newPath,
  });

  /// Evento para reconciliacion general.
  const ProjectFolderChangeEvent.dirty()
    : this._(type: ProjectFolderChangeType.dirty);

  /// Evento con pista de move/rename.
  const ProjectFolderChangeEvent.moved({
    required String oldPath,
    required String newPath,
  }) : this._(
         type: ProjectFolderChangeType.moved,
         oldPath: oldPath,
         newPath: newPath,
       );

  /// Tipo de cambio.
  final ProjectFolderChangeType type;

  /// Ruta anterior cuando [type] es moved.
  final String? oldPath;

  /// Ruta nueva cuando [type] es moved.
  final String? newPath;
}

/// Watcher de carpetas de proyecto con fallback por polling.
class ProjectFolderWatchService {
  /// Crea una instancia de [ProjectFolderWatchService].
  ProjectFolderWatchService({Duration? pollingInterval})
    : _pollingInterval = pollingInterval ?? const Duration(seconds: 3);

  final Duration _pollingInterval;
  final Map<String, StreamSubscription<FileSystemEvent>> _parentSubscriptions =
      <String, StreamSubscription<FileSystemEvent>>{};
  final StreamController<ProjectFolderChangeEvent> _controller =
      StreamController<ProjectFolderChangeEvent>.broadcast();

  Timer? _pollTimer;
  Set<String> _trackedFolders = <String>{};

  /// Stream de cambios detectados.
  Stream<ProjectFolderChangeEvent> get changes => _controller.stream;

  /// Actualiza carpetas a vigilar.
  Future<void> updateTrackedFolders(List<String> folderPaths) async {
    final normalizedTracked = folderPaths
        .map(_normalizePath)
        .where((path) => path.isNotEmpty)
        .toSet();
    _trackedFolders = normalizedTracked;

    final parents = normalizedTracked
        .map(_parentPath)
        .where((path) => path.isNotEmpty)
        .toSet();

    final toRemove = _parentSubscriptions.keys
        .where((parent) => !parents.contains(parent))
        .toList(growable: false);
    for (final parent in toRemove) {
      await _parentSubscriptions[parent]?.cancel();
      _parentSubscriptions.remove(parent);
    }

    final toAdd = parents
        .where((parent) => !_parentSubscriptions.containsKey(parent))
        .toList(growable: false);
    for (final parent in toAdd) {
      final directory = Directory(parent);
      if (!directory.existsSync()) {
        continue;
      }

      try {
        _parentSubscriptions[parent] = directory.watch().listen(
          _onFileSystemEvent,
        );
      } on Exception {
        // Ignorar fallos de watch por directorio; polling cubre fallback.
      }
    }

    _restartPolling();
  }

  /// Libera recursos.
  Future<void> dispose() async {
    _pollTimer?.cancel();
    for (final subscription in _parentSubscriptions.values) {
      await subscription.cancel();
    }
    _parentSubscriptions.clear();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    if (_controller.isClosed) return;

    if (event is FileSystemMoveEvent) {
      final oldPath = _normalizePath(event.path);
      final destination = event.destination;
      final newPath = destination == null ? '' : _normalizePath(destination);
      if (oldPath.isNotEmpty &&
          newPath.isNotEmpty &&
          _trackedFolders.contains(oldPath)) {
        _controller.add(
          ProjectFolderChangeEvent.moved(oldPath: oldPath, newPath: newPath),
        );
      }
    }

    _controller.add(const ProjectFolderChangeEvent.dirty());
  }

  void _restartPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollingInterval, (_) {
      if (_controller.isClosed) return;
      _controller.add(const ProjectFolderChangeEvent.dirty());
    });
  }

  String _normalizePath(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(r'\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _parentPath(String path) {
    final normalized = _normalizePath(path);
    final slash = normalized.lastIndexOf('/');
    if (slash <= 0) return '';
    return normalized.substring(0, slash);
  }
}
