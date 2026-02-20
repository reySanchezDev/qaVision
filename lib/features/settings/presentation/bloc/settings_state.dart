import 'package:equatable/equatable.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';

/// Estados del BLoC de configuración.
sealed class SettingsState extends Equatable {
  /// Constructor base de [SettingsState].
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// Estado inicial antes de cargar la configuración.
final class SettingsInitial extends SettingsState {
  /// Crea una instancia de [SettingsInitial].
  const SettingsInitial();
}

/// Estado de carga mientras se lee la configuración.
final class SettingsLoading extends SettingsState {
  /// Crea una instancia de [SettingsLoading].
  const SettingsLoading();
}

/// Estado cuando la configuración se ha cargado correctamente.
final class SettingsLoadSuccess extends SettingsState {
  /// Crea una instancia de [SettingsLoadSuccess].
  const SettingsLoadSuccess(this.settings);

  /// La configuración actual del sistema.
  final SettingsEntity settings;

  @override
  List<Object?> get props => [settings];
}

/// Estado de error al cargar o guardar la configuración.
final class SettingsError extends SettingsState {
  /// Crea una instancia de [SettingsError].
  const SettingsError(this.message, {this.exception});

  /// Mensaje de error para el usuario.
  final String message;

  /// Excepción original (si existe).
  final Exception? exception;

  @override
  List<Object?> get props => [message, exception];
}
