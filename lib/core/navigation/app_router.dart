import 'package:flutter/material.dart';
import 'package:qavision/core/window/app_launch_request.dart';
import 'package:qavision/core/window/app_window_launcher.dart';
import 'package:qavision/core/window/app_window_role.dart';
import 'package:qavision/core/window/app_window_single_instance.dart';
import 'package:window_manager/window_manager.dart';

/// Router de QAVision basado en ventanas/procesos independientes.
class AppRouter {
  /// Navigator key global para compatibilidad con flujos existentes.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Abre Configuracion en ventana independiente no modal.
  static Future<void> openSettings() {
    return AppWindowLauncher.launch(
      const AppLaunchRequest(role: AppWindowRole.settings),
    );
  }

  /// Abre Proyectos en ventana independiente no modal.
  static Future<void> openProjects({bool openCreateOnStart = false}) {
    return AppWindowLauncher.launch(
      AppLaunchRequest(
        role: AppWindowRole.projects,
        openCreateOnStart: openCreateOnStart,
      ),
    );
  }

  /// Abre Visor en ventana independiente no modal.
  static Future<void> openViewer({String? imagePath}) {
    return AppWindowLauncher.launch(
      AppLaunchRequest(
        role: AppWindowRole.viewer,
        imagePath: imagePath,
      ),
    );
  }

  /// Abre Historial en ventana independiente no modal.
  static Future<void> openHistory() {
    return AppWindowLauncher.launch(
      const AppLaunchRequest(role: AppWindowRole.history),
    );
  }

  /// Cierra el sistema completo (todas las ventanas/roles).
  static Future<void> closeSystem() async {
    await AppWindowSingleInstance.broadcastShutdown();
    await windowManager.destroy();
  }
}
