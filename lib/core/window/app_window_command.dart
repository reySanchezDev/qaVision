import 'dart:convert';

import 'package:qavision/core/window/app_launch_request.dart';

/// Comando recibido por canal de instancia unica.
class AppWindowCommand {
  /// Crea una instancia de [AppWindowCommand].
  const AppWindowCommand({
    this.requestFocus = true,
    this.shutdown = false,
    this.openCreateOnStart = false,
    this.imagePath,
  });

  /// Deserializa desde linea JSON.
  factory AppWindowCommand.fromLineJson(String line) {
    try {
      final raw = jsonDecode(line);
      if (raw is! Map<String, dynamic>) return const AppWindowCommand();
      return AppWindowCommand.fromMap(raw);
    } on Exception {
      return const AppWindowCommand();
    }
  }

  /// Crea un comando de activacion desde un request de lanzamiento.
  factory AppWindowCommand.activation(AppLaunchRequest request) {
    return AppWindowCommand(
      openCreateOnStart: request.openCreateOnStart,
      imagePath: request.imagePath,
    );
  }

  /// Crea un comando de apagado.
  factory AppWindowCommand.shutdown() {
    return const AppWindowCommand(
      requestFocus: false,
      shutdown: true,
    );
  }

  /// Deserializa desde mapa.
  factory AppWindowCommand.fromMap(Map<String, dynamic> map) {
    return AppWindowCommand(
      requestFocus: map['requestFocus'] as bool? ?? true,
      shutdown: map['shutdown'] as bool? ?? false,
      openCreateOnStart: map['openCreateOnStart'] as bool? ?? false,
      imagePath: map['imagePath'] as String?,
    );
  }

  /// Si la ventana existente debe enfocarse.
  final bool requestFocus;

  /// Si debe cerrar el proceso completo de esa ventana.
  final bool shutdown;

  /// Si en proyectos debe abrir modal de creacion.
  final bool openCreateOnStart;

  /// Ruta de imagen opcional para visor.
  final String? imagePath;

  /// Serializa a mapa JSON.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'requestFocus': requestFocus,
      'shutdown': shutdown,
      'openCreateOnStart': openCreateOnStart,
      'imagePath': imagePath,
    };
  }

  /// Serializa a linea JSON.
  String toLineJson() => jsonEncode(toMap());
}
