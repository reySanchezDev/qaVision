import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/video/domain/entities/video_recording_target.dart';
import 'package:win32/win32.dart';

const int _kWindowsExcludeFromCaptureAffinity = 0x00000011;

/// Sesión viva de grabación de video.
class VideoRecordingSession {
  VideoRecordingSession({
    required this.outputPath,
    required Process process,
    required StreamSubscription<List<int>> stdoutSubscription,
    required StreamSubscription<List<int>> stderrSubscription,
    required StringBuffer logBuffer,
  }) : _process = process,
       _stdoutSubscription = stdoutSubscription,
       _stderrSubscription = stderrSubscription,
       _logBuffer = logBuffer,
       startedAt = DateTime.now();

  final Process _process;
  final StreamSubscription<List<int>> _stdoutSubscription;
  final StreamSubscription<List<int>> _stderrSubscription;
  final StringBuffer _logBuffer;

  /// Ruta del video generado.
  final String outputPath;

  /// Instante en que comenzó la sesión.
  final DateTime startedAt;

  /// Detiene la grabación solicitando cierre limpio a `ffmpeg`.
  Future<VideoRecordingStopResult> stop() async {
    try {
      _process.stdin.writeln('q');
      await _process.stdin.flush();
      await _process.stdin.close();
    } on Object {
      // Ignorar: si el proceso ya murió, el exitCode nos lo dirá.
    }

    final exitCode = await _process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );

    // Cancelar suscripciones inmediatamente tras el exitCode (o timeout).
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();

    final file = File(outputPath);
    final exists = await file.exists();
    final length = exists ? await file.length() : 0;

    return VideoRecordingStopResult(
      outputPath: outputPath,
      exitCode: exitCode,
      exists: exists,
      bytesLength: length,
      log: _logBuffer.toString(),
    );
  }

  /// Alterna pausa o reanudación usando el modo interactivo de ffmpeg.
  Future<void> togglePause() async {
    _process.stdin.writeln('p');
    await _process.stdin.flush();
  }
}

/// Resultado al terminar una sesión de grabación.
class VideoRecordingStopResult {
  const VideoRecordingStopResult({
    required this.outputPath,
    required this.exitCode,
    required this.exists,
    required this.bytesLength,
    required this.log,
  });

  final String outputPath;
  final int exitCode;
  final bool exists;
  final int bytesLength;
  final String log;

  /// Indica si el video quedó listo para usarse.
  bool get isSuccess => exists && bytesLength > 0;
}

/// Servicio encargado de grabar video de pantalla en Windows.
///
/// Mantiene este flujo separado del pipeline de screenshots para no romper
/// miniaturas, historial de imágenes ni el visor.
class VideoRecordingService {
  /// Crea una instancia de [VideoRecordingService].
  VideoRecordingService({
    required FileSystemService fileSystemService,
  }) : _fileSystem = fileSystemService;

  final FileSystemService _fileSystem;

  /// Intenta excluir la ventana flotante del contenido grabado.
  ///
  /// En Windows 10 2004+ esto permite que la flotante siga visible para
  /// detener la grabación sin aparecer dentro del video.
  Future<bool> excludeFloatingWindowFromCapture() async {
    if (!Platform.isWindows) {
      return false;
    }

    final hwnd = GetForegroundWindow();
    if (hwnd == 0) {
      return false;
    }
    return SetWindowDisplayAffinity(
          hwnd,
          _kWindowsExcludeFromCaptureAffinity,
        ) !=
        0;
  }

  /// Inicia una grabación sin audio del área seleccionada.
  Future<VideoRecordingSession> startRecording({
    required ProjectEntity project,
    required VideoRecordingTarget target,
    int frameRate = 30,
  }) async {
    final ffmpegPath = _resolveFfmpegExecutable();
    if (ffmpegPath == null) {
      throw Exception(
        'No se encontró ffmpeg empaquetado para iniciar la grabación.',
      );
    }

    final projectDir = project.folderPath.trim();
    if (projectDir.isEmpty) {
      throw Exception('La carpeta activa del proyecto no es válida.');
    }
    await _fileSystem.createDirectory(projectDir);

    final outputPath = _buildOutputPath(projectDir);
    final args = buildFfmpegArgs(
      target: target,
      outputPath: outputPath,
      frameRate: frameRate,
    );

    final process = await Process.start(
      ffmpegPath,
      args,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );

    final buffer = StringBuffer();
    final stdoutSub = process.stdout.listen((data) {
      final text = utf8.decode(data, allowMalformed: true);
      buffer.write(text);
    });
    final stderrSub = process.stderr.listen((data) {
      final text = utf8.decode(data, allowMalformed: true);
      buffer.write(text);
    });

    final session = VideoRecordingSession(
      outputPath: outputPath,
      process: process,
      stdoutSubscription: stdoutSub,
      stderrSubscription: stderrSub,
      logBuffer: buffer,
    );
    final startupResult = await Future.any<Object?>(<Future<Object?>>[
      process.exitCode.then<Object?>((code) => code),
      Future<Object?>.delayed(const Duration(milliseconds: 2000)),
    ]);

    if (startupResult is int) {
      // Si el proceso murió inmediatamente, lo matamos y limpiamos todo.
      process.kill(ProcessSignal.sigkill);
      await stdoutSub.cancel();
      await stderrSub.cancel();
      throw Exception(
        'ffmpeg falló al arrancar (Código $startupResult).\n'
        'Logs recientes:\n'
        '${buffer.toString().split('\n').reversed.take(6).toList().reversed.join('\n')}',
      );
    }

    return session;
  }

  /// Construye los argumentos de `ffmpeg` para grabación de escritorio.
  @visibleForTesting
  List<String> buildFfmpegArgs({
    required VideoRecordingTarget target,
    required String outputPath,
    int frameRate = 30,
  }) {
    final rect = _normalizeRect(target.desktopRect);

    return <String>[
      '-y',
      '-f',
      'gdigrab',
      '-framerate',
      frameRate.toString(),
      '-offset_x',
      rect.left.round().toString(),
      '-offset_y',
      rect.top.round().toString(),
      '-video_size',
      '${rect.width.round()}x${rect.height.round()}',
      '-draw_mouse',
      '1',
      '-i',
      'desktop',
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '18',
      '-pix_fmt',
      'yuv420p',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  String _buildOutputPath(String projectDir) {
    final fileName = '${_fileSystem.generateDefaultFileName()}_video';
    final basePath = p.join(projectDir, fileName);
    var candidate = '$basePath.mp4';
    var counter = 1;
    while (File(candidate).existsSync()) {
      candidate = '${basePath}_($counter).mp4';
      counter++;
    }
    return candidate;
  }

  Rect _normalizeRect(Rect rect) {
    final left = rect.left.roundToDouble();
    final top = rect.top.roundToDouble();

    // ffmpeg con libx264 y yuv420p falla si las dimensiones no son pares.
    var widthValue = rect.width.round();
    if (widthValue % 2 != 0) widthValue++;
    var heightValue = rect.height.round();
    if (heightValue % 2 != 0) heightValue++;

    final width = math.max(16, widthValue).toDouble();
    final height = math.max(16, heightValue).toDouble();
    return Rect.fromLTWH(left, top, width, height);
  }

  String? _resolveFfmpegExecutable() {
    final candidates = <String>[
      p.join(
        Directory.current.path,
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
        'tools',
        'ffmpeg',
        'ffmpeg.exe',
      ),
      p.join(
        Directory.current.path,
        'third_party',
        'ffmpeg',
        'bin',
        'ffmpeg.exe',
      ),
      p.join(
        File(Platform.resolvedExecutable).parent.path,
        'tools',
        'ffmpeg',
        'ffmpeg.exe',
      ),
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }
}
