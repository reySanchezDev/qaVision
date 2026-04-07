import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

/// Captura de pantalla nativa para Windows sin invocar herramientas del SO.
class NativeScreenCaptureService {
  /// Captura la pantalla principal y retorna bytes PNG sin perdida.
  ///
  /// Si [region] se provee, recorta esa zona en coordenadas de pantalla.
  /// [quality] se conserva solo por compatibilidad de API.
  Future<Uint8List> capturePngBytes({Rect? region, int quality = 95}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('NativeScreenCaptureService solo soporta Windows');
    }

    final frame = _captureVirtualDesktop();
    var image = _bgraToImage(frame.width, frame.height, frame.bytes);

    if (region != null) {
      image = _cropSafe(
        image,
        Rect.fromLTWH(
          region.left - frame.originX,
          region.top - frame.originY,
          region.width,
          region.height,
        ),
      );
    }

    // Guardamos directamente como JPG para evitar doble codificación PNG→JPG.
    return Uint8List.fromList(img.encodePng(image));
  }

  _ScreenFrame _captureVirtualDesktop() {
    final originX = GetSystemMetrics(SM_XVIRTUALSCREEN);
    final originY = GetSystemMetrics(SM_YVIRTUALSCREEN);
    final width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    final height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if (width <= 0 || height <= 0) {
      throw Exception('No se pudo obtener tamano del escritorio virtual');
    }

    final screenDc = GetDC(NULL);
    if (screenDc == 0) {
      throw Exception('No se pudo obtener DC de pantalla');
    }

    final memDc = CreateCompatibleDC(screenDc);
    if (memDc == 0) {
      ReleaseDC(NULL, screenDc);
      throw Exception('No se pudo crear DC compatible');
    }

    final bitmap = CreateCompatibleBitmap(screenDc, width, height);
    if (bitmap == 0) {
      DeleteDC(memDc);
      ReleaseDC(NULL, screenDc);
      throw Exception('No se pudo crear bitmap compatible');
    }

    final oldObj = SelectObject(memDc, bitmap);
    final bltOk = BitBlt(
      memDc,
      0,
      0,
      width,
      height,
      screenDc,
      originX,
      originY,
      SRCCOPY | CAPTUREBLT,
    );

    if (bltOk == 0) {
      SelectObject(memDc, oldObj);
      DeleteObject(bitmap);
      DeleteDC(memDc);
      ReleaseDC(NULL, screenDc);
      throw Exception('BitBlt fallo al capturar pantalla');
    }

    _drawMouseCursor(memDc, originX: originX, originY: originY);

    final bmi = calloc<BITMAPINFO>();
    final pixels = calloc<Uint8>(width * height * 4);
    try {
      bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmi.ref.bmiHeader.biWidth = width;
      bmi.ref.bmiHeader.biHeight = -height;
      bmi.ref.bmiHeader.biPlanes = 1;
      bmi.ref.bmiHeader.biBitCount = 32;
      bmi.ref.bmiHeader.biCompression = BI_RGB;

      final rows = GetDIBits(
        memDc,
        bitmap,
        0,
        height,
        pixels.cast(),
        bmi,
        DIB_RGB_COLORS,
      );
      if (rows == 0) {
        throw Exception('GetDIBits fallo al leer pixeles');
      }

      final bytes = Uint8List.fromList(pixels.asTypedList(width * height * 4));
      return _ScreenFrame(
        originX: originX.toDouble(),
        originY: originY.toDouble(),
        width: width,
        height: height,
        bytes: bytes,
      );
    } finally {
      calloc
        ..free(pixels)
        ..free(bmi);
      SelectObject(memDc, oldObj);
      DeleteObject(bitmap);
      DeleteDC(memDc);
      ReleaseDC(NULL, screenDc);
    }
  }

  img.Image _bgraToImage(int width, int height, Uint8List bgra) {
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < bgra.length; i += 4) {
      final b = bgra[i];
      final g = bgra[i + 1];
      final r = bgra[i + 2];
      final a = bgra[i + 3];
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = a;
    }

    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
  }

  img.Image _cropSafe(img.Image source, Rect region) {
    final x = region.left.round().clamp(0, source.width - 1);
    final y = region.top.round().clamp(0, source.height - 1);
    final maxW = source.width - x;
    final maxH = source.height - y;
    final w = region.width.round().clamp(1, maxW);
    final h = region.height.round().clamp(1, maxH);

    return img.copyCrop(source, x: x, y: y, width: w, height: h);
  }

  void _drawMouseCursor(
    int targetDc, {
    required int originX,
    required int originY,
  }) {
    final cursorInfo = calloc<CURSORINFO>();
    try {
      cursorInfo.ref.cbSize = sizeOf<CURSORINFO>();
      final hasCursor = GetCursorInfo(cursorInfo) != 0;
      if (!hasCursor) return;
      if (cursorInfo.ref.flags != CURSOR_SHOWING) return;

      final point = cursorInfo.ref.ptScreenPos;
      DrawIcon(
        targetDc,
        point.x - originX,
        point.y - originY,
        cursorInfo.ref.hCursor,
      );
    } finally {
      calloc.free(cursorInfo);
    }
  }
}

class _ScreenFrame {
  const _ScreenFrame({
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final double originX;
  final double originY;
  final int width;
  final int height;
  final Uint8List bytes;
}
