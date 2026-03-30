import 'package:qavision/core/window/app_window_role.dart';

/// Parametros de lanzamiento de una ventana de QAVision.
class AppLaunchRequest {
  /// Crea una instancia de [AppLaunchRequest].
  const AppLaunchRequest({
    required this.role,
    this.imagePath,
    this.openCreateOnStart = false,
  });

  /// Construye el request desde argumentos CLI.
  factory AppLaunchRequest.fromArgs(List<String> args) {
    String? roleValue;
    String? imagePath;
    var openCreateOnStart = false;

    for (final arg in args) {
      if (arg.startsWith('--role=')) {
        roleValue = arg.substring('--role='.length).trim();
      } else if (arg.startsWith('--image-path=')) {
        imagePath = arg.substring('--image-path='.length);
      } else if (arg == '--open-create') {
        openCreateOnStart = true;
      } else if (arg.startsWith('--open-create=')) {
        final value = arg.substring('--open-create='.length).toLowerCase();
        openCreateOnStart = value == '1' || value == 'true';
      }
    }

    return AppLaunchRequest(
      role: roleValue == null
          ? AppWindowRole.floating
          : parseAppWindowRole(roleValue),
      imagePath: imagePath == null || imagePath.isEmpty ? null : imagePath,
      openCreateOnStart: openCreateOnStart,
    );
  }

  /// Rol objetivo de la ventana.
  final AppWindowRole role;

  /// Ruta inicial de imagen para visor (si aplica).
  final String? imagePath;

  /// Si proyectos debe abrir modal de creacion al iniciar.
  final bool openCreateOnStart;

  /// Convierte el request a argumentos CLI para lanzar un nuevo proceso.
  List<String> toArgs() {
    final args = <String>['--role=${role.cliValue}'];
    if (imagePath != null && imagePath!.isNotEmpty) {
      args.add('--image-path=$imagePath');
    }
    if (openCreateOnStart) {
      args.add('--open-create=true');
    }
    return args;
  }
}
