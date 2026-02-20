import 'package:equatable/equatable.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';

/// Eventos del BLoC de configuración.
sealed class SettingsEvent extends Equatable {
  /// Constructor base de [SettingsEvent].
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para cargar la configuración inicial.
final class SettingsLoaded extends SettingsEvent {
  /// Crea una instancia de [SettingsLoaded].
  const SettingsLoaded();
}

/// Evento para actualizar un campo de la configuración.
final class SettingsUpdated extends SettingsEvent {
  /// Crea una instancia de [SettingsUpdated].
  const SettingsUpdated(this.settings);

  /// Configuración actualizada.
  final SettingsEntity settings;

  @override
  List<Object?> get props => [settings];
}

/// Evento para seleccionar la carpeta raíz.
final class SettingsRootFolderSelected extends SettingsEvent {
  /// Crea una instancia de [SettingsRootFolderSelected].
  const SettingsRootFolderSelected(this.path);

  /// Ruta seleccionada.
  final String path;

  @override
  List<Object?> get props => [path];
}
