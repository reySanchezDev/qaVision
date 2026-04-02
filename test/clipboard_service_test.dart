import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:win32/win32.dart';

void main() {
  test('buildWindowsClipboardDib genera un DIB valido de 32 bits', () {
    final source = img.Image(width: 2, height: 1)
      ..setPixelRgba(0, 0, 255, 0, 0, 255)
      ..setPixelRgba(1, 0, 0, 255, 0, 255);
    final pngBytes = Uint8List.fromList(img.encodePng(source));

    final dib = buildWindowsClipboardDib(pngBytes);
    final header = ByteData.sublistView(dib, 0, 40);

    expect(header.getUint32(0, Endian.little), sizeOf<BITMAPINFOHEADER>());
    expect(header.getInt32(4, Endian.little), 2);
    expect(header.getInt32(8, Endian.little), 1);
    expect(header.getUint16(12, Endian.little), 1);
    expect(header.getUint16(14, Endian.little), 32);
    expect(header.getUint32(16, Endian.little), BI_RGB);
    expect(header.getUint32(20, Endian.little), 8);

    expect(dib.length, 40 + 8);
    expect(dib[40], 0); // B del pixel rojo
    expect(dib[41], 0); // G del pixel rojo
    expect(dib[42], 255); // R del pixel rojo
    expect(dib[44], 0); // B del pixel verde
    expect(dib[45], 255); // G del pixel verde
    expect(dib[46], 0); // R del pixel verde
  });
}
