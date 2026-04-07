import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qavision/core/window/app_launch_request.dart';
import 'package:qavision/core/window/app_window_command.dart';
import 'package:qavision/core/window/app_window_role.dart';

/// Canal de instancia unica por rol de ventana.
class AppWindowSingleInstance {
  AppWindowSingleInstance._({
    required this.role,
    required RandomAccessFile lockFile,
    required ServerSocket server,
  }) : _lockFile = lockFile,
       _server = server;

  /// Rol de la ventana de esta instancia.
  final AppWindowRole role;
  final RandomAccessFile _lockFile;
  final ServerSocket _server;

  /// Intenta adquirir la instancia unica definida en [request].
  ///
  /// Si ya existe una instancia, le envia un comando de activacion y
  /// retorna `null` para que el nuevo proceso finalice.
  static Future<AppWindowSingleInstance?> acquireOrNotify({
    required AppLaunchRequest request,
    required Future<void> Function(AppWindowCommand command) onCommand,
  }) async {
    final role = request.role;
    RandomAccessFile? lockFile;
    try {
      lockFile = await _acquireRoleLock(role);
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        role.singleInstancePort,
      );
      _startCommandServer(
        server: server,
        onCommand: onCommand,
      );

      return AppWindowSingleInstance._(
        role: role,
        lockFile: lockFile,
        server: server,
      );
    } on SocketException {
      await _releaseLock(lockFile);
      await sendCommand(
        role,
        AppWindowCommand.activation(request),
      );
      return null;
    } on FileSystemException {
      await _releaseLock(lockFile);
      await sendCommand(
        role,
        AppWindowCommand.activation(request),
      );
      return null;
    }
  }

  /// Envia un comando al proceso que posee [targetRole].
  static Future<void> sendCommand(
    AppWindowRole targetRole,
    AppWindowCommand command,
  ) async {
    Socket? socket;
    try {
      final connectedSocket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        targetRole.singleInstancePort,
        timeout: const Duration(milliseconds: 650),
      );
      socket = connectedSocket;
      connectedSocket.write('${command.toLineJson()}\n');
      await connectedSocket.flush();
    } on Exception {
      // No-op: si no existe proceso destino, el comando se descarta.
    } finally {
      await socket?.close();
    }
  }

  /// Emite shutdown a todos los roles conocidos.
  static Future<void> broadcastShutdown() async {
    for (final role in AppWindowRole.values) {
      await sendCommand(role, AppWindowCommand.shutdown());
    }
  }

  /// Libera el canal de instancia unica.
  Future<void> dispose() async {
    await _server.close();
    await _releaseLock(_lockFile);
  }

  static Future<RandomAccessFile> _acquireRoleLock(AppWindowRole role) async {
    final lockDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}qavision_locks',
    );
    if (!await lockDirectory.exists()) {
      await lockDirectory.create(recursive: true);
    }

    final file = File(
      '${lockDirectory.path}${Platform.pathSeparator}${role.cliValue}.lock',
    );
    final handle = await file.open(mode: FileMode.writeOnlyAppend);
    await handle.lock(FileLock.exclusive);
    await handle.setPosition(0);
    await handle.truncate(0);
    await handle.writeString('${pid}');
    await handle.flush();
    return handle;
  }

  static Future<void> _releaseLock(RandomAccessFile? handle) async {
    if (handle == null) return;
    try {
      await handle.unlock();
    } on FileSystemException {
      // Ignorar unlock sobre handles ya cerrados o liberados.
    }
    try {
      await handle.close();
    } on FileSystemException {
      // Ignorar cierre duplicado.
    }
  }

  static void _startCommandServer({
    required ServerSocket server,
    required Future<void> Function(AppWindowCommand command) onCommand,
  }) {
    unawaited(() async {
      await for (final socket in server) {
        unawaited(
          _handleSocketCommand(
            socket: socket,
            onCommand: onCommand,
          ),
        );
      }
    }());
  }

  static Future<void> _handleSocketCommand({
    required Socket socket,
    required Future<void> Function(AppWindowCommand command) onCommand,
  }) async {
    final lines = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final command = AppWindowCommand.fromLineJson(line);
        await onCommand(command);
      }
    } on Exception {
      // Error en la lectura del socket.
    } finally {
      await socket.close();
    }
  }
}
