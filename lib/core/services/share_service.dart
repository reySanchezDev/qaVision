import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

/// Servicio para compartir contenido mediante el diálogo nativo
/// del sistema (§9.7).
class ShareService {
  /// Comparte una imagen archivo desde su [path].
  ///
  /// [text] texto opcional que acompaña a la imagen.
  /// [subject] asunto opcional para el compartido.
  Future<void> shareImage(
    String path, {
    String? text,
    String? subject,
  }) async {
    await Share.shareXFiles(
      [XFile(path)],
      text: text,
      subject: subject,
    );
  }

  /// Comparte los bytes de una imagen como un archivo temporal.
  Future<void> shareImageBytes(
    List<int> bytes,
    String fileName, {
    String? text,
    String? subject,
  }) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType: 'image/jpeg',
        ),
      ],
      text: text,
      subject: subject,
    );
  }
}
