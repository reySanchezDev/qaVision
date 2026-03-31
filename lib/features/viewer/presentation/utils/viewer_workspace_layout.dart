import 'package:flutter/material.dart';

/// Define el workspace util visible dentro del canvas del visor.
class ViewerWorkspaceLayout {
  /// Rectangulo real de trabajo donde pueden moverse las capturas.
  static Rect resolve(Size canvasSize) {
    return Offset.zero & canvasSize;
  }
}
