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
  static Future<void>? _closeSystemInFlight;
  static AppWindowRole? _currentRole;
  static Future<void> Function()? _localShutdown;

  /// Registra el rol y el callback de cierre del proceso actual.
  static void configureCurrentProcess({
    required AppWindowRole role,
    required Future<void> Function() shutdown,
  }) {
    _currentRole = role;
    _localShutdown = shutdown;
  }

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
  static Future<void> closeSystem() {
    final inFlight = _closeSystemInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _closeSystemInternal();
    _closeSystemInFlight = future;
    return future.whenComplete(() {
      _closeSystemInFlight = null;
    });
  }

  static Future<void> _closeSystemInternal() async {
    await AppWindowSingleInstance.broadcastShutdown(excludeRole: _currentRole);
    final shutdown = _localShutdown;
    if (shutdown != null) {
      await shutdown();
      return;
    }
    await windowManager.destroy();
  }
}
