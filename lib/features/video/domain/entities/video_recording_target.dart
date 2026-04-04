import 'dart:ui';

/// Fuente seleccionada para una grabación de video.
enum VideoRecordingSourceKind {
  /// Región manual elegida por el usuario.
  region,

  /// Pantalla completa de un monitor.
  display,
}

/// Rectángulo de escritorio a grabar.
///
/// Todas las coordenadas se guardan en píxeles de escritorio de Windows,
/// que es el espacio que consume `ffmpeg` con `gdigrab`.
class VideoRecordingTarget {
  /// Crea una instancia de [VideoRecordingTarget].
  const VideoRecordingTarget({
    required this.kind,
    required this.label,
    required this.desktopRect,
  });

  /// Tipo de origen elegido.
  final VideoRecordingSourceKind kind;

  /// Etiqueta mostrada al usuario.
  final String label;

  /// Rectángulo final a grabar en coordenadas de escritorio.
  final Rect desktopRect;
}
