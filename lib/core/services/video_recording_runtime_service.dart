import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:qavision/core/services/video_recording_service.dart';

/// Runtime compartido de la grabacion de video.
///
/// Mantiene separada la sesion viva de grabacion respecto a la UI de la
/// pantalla flotante para que la HUD pueda renderizarse como una instancia
/// independiente del toolbar normal.
class VideoRecordingRuntimeService extends ChangeNotifier {
  VideoRecordingSession? _session;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  Duration _elapsedAccumulated = Duration.zero;
  DateTime? _elapsedStartedAt;
  bool _isPaused = false;
  bool _isBusy = false;
  bool _isHudVisible = false;
  Offset? _returnPosition;
  Offset? _hudPosition;

  /// Sesion actual de grabacion.
  VideoRecordingSession? get session => _session;

  /// Tiempo transcurrido visible.
  Duration get elapsed => _elapsed;

  /// Indica si la sesion esta en pausa.
  bool get isPaused => _isPaused;

  /// Indica si la HUD esta procesando una accion.
  bool get isBusy => _isBusy;

  /// Posicion a la que debe volver la flotante al detener.
  Offset? get returnPosition => _returnPosition;

  /// Posicion objetivo de la HUD durante la grabacion.
  Offset? get hudPosition => _hudPosition;

  /// True cuando la HUD de video debe ocupar la ventana flotante.
  bool get isHudVisible => _isHudVisible;

  /// True cuando hay una sesion viva de grabacion.
  bool get isRecording => _session != null;

  /// Activa la HUD antes de iniciar la sesion real.
  void showHud({
    required Offset returnPosition,
    required Offset hudPosition,
  }) {
    _returnPosition = returnPosition;
    _hudPosition = hudPosition;
    _isHudVisible = true;
    notifyListeners();
  }

  /// Desactiva la HUD manteniendo el resto del runtime intacto.
  void hideHud() {
    if (!_isHudVisible) {
      return;
    }
    _isHudVisible = false;
    notifyListeners();
  }

  /// Registra una nueva sesion viva.
  void begin({
    required VideoRecordingSession session,
    required Offset returnPosition,
    required Offset hudPosition,
  }) {
    _elapsedTimer?.cancel();
    _session = session;
    _returnPosition = returnPosition;
    _elapsed = Duration.zero;
    _elapsedAccumulated = Duration.zero;
    _elapsedStartedAt = DateTime.now();
    _isPaused = false;
    _isBusy = false;
    _isHudVisible = true;
    _hudPosition = hudPosition;
    _startElapsedTicker();
    notifyListeners();
  }

  /// Alterna pausa o reanudacion.
  Future<void> togglePause() async {
    final currentSession = _session;
    if (currentSession == null || _isBusy) {
      return;
    }

    _isBusy = true;
    notifyListeners();
    try {
      await currentSession.togglePause();
      if (_isPaused) {
        _elapsedStartedAt = DateTime.now();
        _isPaused = false;
      } else {
        final startedAt = _elapsedStartedAt;
        if (startedAt != null) {
          _elapsedAccumulated += DateTime.now().difference(startedAt);
        }
        _elapsedStartedAt = null;
        _isPaused = true;
        _elapsed = _elapsedAccumulated;
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Detiene la grabacion y limpia el runtime.
  Future<VideoRecordingStopResult?> stop() async {
    final currentSession = _session;
    if (currentSession == null || _isBusy) {
      return null;
    }

    _isBusy = true;
    notifyListeners();
    try {
      final result = await currentSession.stop();
      _reset();
      return result;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Limpia el runtime sin intentar detener nada.
  void reset() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _session = null;
    _elapsed = Duration.zero;
    _elapsedAccumulated = Duration.zero;
    _elapsedStartedAt = null;
    _isPaused = false;
    _isHudVisible = false;
    _returnPosition = null;
    _hudPosition = null;
  }

  void _startElapsedTicker() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session == null) {
        return;
      }
      _elapsed = _currentElapsed();
      notifyListeners();
    });
  }

  Duration _currentElapsed() {
    final startedAt = _elapsedStartedAt;
    if (_isPaused || startedAt == null) {
      return _elapsedAccumulated;
    }
    return _elapsedAccumulated + DateTime.now().difference(startedAt);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
