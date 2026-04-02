import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import 'package:win32/win32.dart';

/// Servicio para operaciones con el portapapeles del sistema.
///
/// En Windows usamos una implementacion propia porque `pasteboard`
/// solo soporta lectura de imagenes en desktop, no escritura.
class ClipboardService {
  static const _maxClipboardOpenAttempts = 5;

  /// Copia una imagen al portapapeles del sistema.
  Future<void> copyImageToClipboard(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      return;
    }

    if (Platform.isWindows) {
      await _copyImageToClipboardWindows(imageBytes);
      return;
    }

    await Pasteboard.writeImage(imageBytes);
  }

  /// Copia una imagen desde disco al portapapeles del sistema.
  Future<void> copyImageFileToClipboard(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    await copyImageToClipboard(bytes);
  }

  /// Copia texto al portapapeles del sistema.
  Future<void> copyTextToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _copyImageToClipboardWindows(Uint8List imageBytes) async {
    final dibBytes = buildWindowsClipboardDib(imageBytes);
    final hMem = GlobalAlloc(GMEM_MOVEABLE, dibBytes.length);
    if (hMem.address == 0) {
      throw Exception('No se pudo reservar memoria para el portapapeles');
    }

    final memory = GlobalLock(hMem);
    if (memory.address == 0) {
      GlobalFree(hMem);
      throw Exception('No se pudo bloquear memoria del portapapeles');
    }

    try {
      memory.cast<Uint8>().asTypedList(dibBytes.length).setAll(0, dibBytes);
    } finally {
      GlobalUnlock(hMem);
    }

    if (!_openClipboardWithRetry()) {
      GlobalFree(hMem);
      throw Exception('No se pudo abrir el portapapeles de Windows');
    }

    try {
      if (EmptyClipboard() == 0) {
        GlobalFree(hMem);
        throw Exception('No se pudo limpiar el portapapeles');
      }

      final result = SetClipboardData(CF_DIB, hMem.address);
      if (result == 0) {
        GlobalFree(hMem);
        throw Exception('No se pudo copiar la imagen al portapapeles');
      }
    } finally {
      CloseClipboard();
    }
  }

  bool _openClipboardWithRetry() {
    for (var attempt = 0; attempt < _maxClipboardOpenAttempts; attempt++) {
      if (OpenClipboard(NULL) != 0) {
        return true;
      }
      Sleep(5);
    }
    return false;
  }
}

/// Convierte bytes de imagen comunes (PNG/JPG) al formato DIB usado por el
/// portapapeles de Windows.
@visibleForTesting
Uint8List buildWindowsClipboardDib(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    throw Exception('No se pudo decodificar la imagen para el portapapeles');
  }

  final width = decoded.width;
  final height = decoded.height;
  final rowStride = width * 4;
  final headerSize = sizeOf<BITMAPINFOHEADER>();
  final totalSize = headerSize + (rowStride * height);
  final dib = Uint8List(totalSize);
  final byteData = ByteData.sublistView(dib);

  // ignore: cascade_invocations, ByteData initialization is clearer as a single header block.
  byteData
    ..setUint32(0, headerSize, Endian.little)
    ..setInt32(4, width, Endian.little)
    ..setInt32(8, height, Endian.little)
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, 32, Endian.little)
    ..setUint32(16, BI_RGB, Endian.little)
    ..setUint32(20, rowStride * height, Endian.little)
    ..setInt32(24, 3780, Endian.little)
    ..setInt32(28, 3780, Endian.little)
    ..setUint32(32, 0, Endian.little)
    ..setUint32(36, 0, Endian.little);

  var offset = headerSize;
  for (var y = height - 1; y >= 0; y--) {
    for (var x = 0; x < width; x++) {
      final pixel = decoded.getPixel(x, y);
      dib[offset++] = pixel.b.toInt();
      dib[offset++] = pixel.g.toInt();
      dib[offset++] = pixel.r.toInt();
      dib[offset++] = pixel.a.toInt();
    }
  }

  return dib;
}
