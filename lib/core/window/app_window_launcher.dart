import 'dart:io';

import 'package:qavision/core/window/app_launch_request.dart';

/// Lanza nuevas ventanas de QAVision como procesos independientes.
class AppWindowLauncher {
  /// Lanza el proceso para [request].
  static Future<void> launch(AppLaunchRequest request) async {
    final executablePath = Platform.resolvedExecutable;

    await Process.start(
      executablePath,
      request.toArgs(),
      mode: ProcessStartMode.detached,
    );
  }
}
