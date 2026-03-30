import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';

/// Implementación concreta del repositorio de configuración.
///
/// Persiste la configuración usando [StorageService] (JSON local).
class SettingsRepository implements ISettingsRepository {
  /// Crea una instancia de [SettingsRepository].
  SettingsRepository({required StorageService storageService})
    : _storage = storageService;

  final StorageService _storage;

  static const String _settingsKey = 'settings';

  @override
  Future<SettingsEntity> loadSettings() async {
    await _storage.reloadFromDisk();
    final map = _storage.getMap(_settingsKey);
    if (map == null) return const SettingsEntity();
    return _fromMap(map);
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    await _storage.setMap(_settingsKey, _toMap(settings));
  }

  /// Convierte un mapa JSON a [SettingsEntity].
  SettingsEntity _fromMap(Map<String, dynamic> map) {
    return SettingsEntity(
      rootFolder: map['rootFolder'] as String?,
      showFloatingButton: map['showFloatingButton'] as bool? ?? true,
      startWithWindows: map['startWithWindows'] as bool? ?? false,
      floatingButtonColor: map['floatingButtonColor'] as int? ?? 0xFF1E88E5,
      jpgQuality: _parseJpgQuality(map['jpgQuality'] as String?),
      fileNameMask: map['fileNameMask'] as String? ?? '',
      postCaptureAction: _parsePostCaptureAction(
        map['postCaptureAction'] as String?,
      ),
      copyToClipboard: map['copyToClipboard'] as bool? ?? false,
      hotkeyTraditional: map['hotkeyTraditional'] as String? ?? 'Ctrl+Shift+S',
      hotkeyClipMode: map['hotkeyClipMode'] as String? ?? 'Ctrl+Shift+C',
      hotkeyOpenViewer: map['hotkeyOpenViewer'] as String? ?? 'Ctrl+Shift+V',
      clipLeftClickOnly: map['clipLeftClickOnly'] as bool? ?? true,
      clipIgnoreScrollbar: map['clipIgnoreScrollbar'] as bool? ?? true,
      clipIntervalEnabled: map['clipIntervalEnabled'] as bool? ?? false,
      clipIntervalSeconds: map['clipIntervalSeconds'] as int? ?? 5,
      showRecentStrip: map['showRecentStrip'] as bool? ?? true,
      showSavedIndicator: map['showSavedIndicator'] as bool? ?? true,
      viewerDefaultFrameBackgroundColor:
          map['viewerDefaultFrameBackgroundColor'] as int? ?? 0xFFFFFFFF,
      viewerDefaultFrameBackgroundOpacity:
          (map['viewerDefaultFrameBackgroundOpacity'] as num?)?.toDouble() ??
          1.0,
      viewerDefaultFrameBorderColor:
          map['viewerDefaultFrameBorderColor'] as int? ?? 0x33000000,
      viewerDefaultFrameBorderWidth:
          (map['viewerDefaultFrameBorderWidth'] as num?)?.toDouble() ?? 1.0,
      viewerDefaultFramePadding:
          (map['viewerDefaultFramePadding'] as num?)?.toDouble() ?? 0.0,
      lastX: (map['lastX'] as num?)?.toDouble() ?? 0.0,
      lastY: (map['lastY'] as num?)?.toDouble() ?? 100.0,
    );
  }

  /// Convierte [SettingsEntity] a mapa JSON.
  Map<String, dynamic> _toMap(SettingsEntity settings) {
    return {
      'rootFolder': settings.rootFolder,
      'showFloatingButton': settings.showFloatingButton,
      'startWithWindows': settings.startWithWindows,
      'floatingButtonColor': settings.floatingButtonColor,
      'jpgQuality': settings.jpgQuality.name,
      'fileNameMask': settings.fileNameMask,
      'postCaptureAction': settings.postCaptureAction.name,
      'copyToClipboard': settings.copyToClipboard,
      'hotkeyTraditional': settings.hotkeyTraditional,
      'hotkeyClipMode': settings.hotkeyClipMode,
      'hotkeyOpenViewer': settings.hotkeyOpenViewer,
      'clipLeftClickOnly': settings.clipLeftClickOnly,
      'clipIgnoreScrollbar': settings.clipIgnoreScrollbar,
      'clipIntervalEnabled': settings.clipIntervalEnabled,
      'clipIntervalSeconds': settings.clipIntervalSeconds,
      'showRecentStrip': settings.showRecentStrip,
      'showSavedIndicator': settings.showSavedIndicator,
      'viewerDefaultFrameBackgroundColor':
          settings.viewerDefaultFrameBackgroundColor,
      'viewerDefaultFrameBackgroundOpacity':
          settings.viewerDefaultFrameBackgroundOpacity,
      'viewerDefaultFrameBorderColor': settings.viewerDefaultFrameBorderColor,
      'viewerDefaultFrameBorderWidth': settings.viewerDefaultFrameBorderWidth,
      'viewerDefaultFramePadding': settings.viewerDefaultFramePadding,
      'lastX': settings.lastX,
      'lastY': settings.lastY,
    };
  }

  JpgQuality _parseJpgQuality(String? value) {
    if (value == 'max') return JpgQuality.max;
    return JpgQuality.high;
  }

  PostCaptureAction _parsePostCaptureAction(String? value) {
    return PostCaptureAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PostCaptureAction.saveAndOpenViewer,
    );
  }
}
