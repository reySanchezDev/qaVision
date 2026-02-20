import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Servicio para operaciones con el portapapeles del sistema.
///
/// Permite copiar imágenes al portapapeles de Windows
/// después de guardar la captura en disco (§4.7).
class ClipboardService {
  /// Copia una imagen al portapapeles del sistema.
  ///
  /// [imageBytes] son los bytes de la imagen a copiar.
  Future<void> copyImageToClipboard(Uint8List imageBytes) async {
    await Pasteboard.writeImage(imageBytes);
  }

  /// Copia texto al portapapeles del sistema.
  Future<void> copyTextToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
