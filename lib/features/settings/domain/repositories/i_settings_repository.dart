import 'package:qavision/features/settings/domain/entities/settings_entity.dart';

/// Interfaz del repositorio de configuración.
///
/// Define el contrato para la persistencia de la
/// configuración general del sistema (§4).
abstract class ISettingsRepository {
  /// Carga la configuración actual del almacenamiento.
  Future<SettingsEntity> loadSettings();

  /// Guarda la configuración en el almacenamiento.
  Future<void> saveSettings(SettingsEntity settings);
}
