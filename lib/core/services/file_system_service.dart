import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Servicio para operaciones de sistema de archivos.
///
/// Encapsula la creación de carpetas, guardado de imágenes JPG,
/// generación de nombres según máscara y numeración automática
/// para evitar sobrescrituras.
class FileSystemService {
  /// Caracteres no permitidos en nombres de archivo Windows.
  static const _invalidChars = r'<>:"/\|?*';

  /// Crea un directorio en la [path] especificada.
  ///
  /// Si ya existe, no hace nada. Crea carpetas intermedias
  /// si es necesario.
  Future<Directory> createDirectory(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Renombra un directorio de [oldPath] a [newPath].
  ///
  /// Retorna el directorio renombrado o `null` si falla.
  Future<Directory?> renameDirectory(
    String oldPath,
    String newPath,
  ) async {
    try {
      final dir = Directory(oldPath);
      if (dir.existsSync()) {
        return dir.rename(newPath);
      }
    } on FileSystemException catch (e) {
      debugPrint('Error al renombrar directorio: $e');
    }
    return null;
  }

  /// Verifica si un directorio existe.
  Future<bool> directoryExists(String path) async {
    return Directory(path).existsSync();
  }

  /// Lista subdirectorios directos de [path].
  Future<List<String>> listDirectories(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return <String>[];
    }

    final children = await dir
        .list(followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    children.sort((a, b) => a.path.compareTo(b.path));
    return children.map((directory) => directory.path).toList(growable: false);
  }

  /// Guarda una imagen como JPG con la calidad especificada.
  ///
  /// [imageBytes] son los bytes crudos de la imagen (PNG/BMP).
  /// [outputPath] es la ruta completa (sin extensión, se añade .jpg).
  /// [quality] es la calidad JPG (1-100). Alta=85, Máxima=100.
  ///
  /// Retorna la ruta final del archivo guardado.
  /// Usa [compute] para no bloquear la UI (§12).
  Future<String> saveAsJpg({
    required Uint8List imageBytes,
    required String outputPath,
    int quality = 95,
    bool overwrite = false,
  }) async {
    final safePath = overwrite
        ? '$outputPath.jpg'
        : _ensureUniqueFilename('$outputPath.jpg');

    // Encodificar en isolate para no bloquear UI (§12.2)
    await compute(
      _encodeAndSaveJpg,
      _JpgEncodeParams(
        imageBytes: imageBytes,
        outputPath: safePath,
        quality: quality,
      ),
    );

    final savedFile = File(safePath);
    if (!savedFile.existsSync() || savedFile.lengthSync() == 0) {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw Exception('No se pudo decodificar la imagen capturada');
      }
      final jpgBytes = img.encodeJpg(decoded, quality: quality);
      await savedFile.parent.create(recursive: true);
      await savedFile.writeAsBytes(jpgBytes, flush: true);
    }

    return safePath;
  }

  /// Guarda bytes JPG ya codificados directamente en disco sin re-codificación.
  ///
  /// Usa este método cuando los bytes ya están en formato JPG (p.ej. captura
  /// nativa directa) para evitar una segunda codificacion
  /// con perdida de calidad.
  /// [outputPath] es la ruta completa sin extensión; se añadirá `.jpg`.
  Future<String> saveRawJpgBytes({
    required Uint8List imageBytes,
    required String outputPath,
  }) async {
    final safePath = _ensureUniqueFilename('$outputPath.jpg');
    final file = File(safePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
    return safePath;
  }

  /// Genera un nombre de archivo según la máscara configurada.
  ///
  /// [mask] es la máscara con tokens: {PROYECTO}, {NUMERO}, {FECHA}, {HORA}.
  /// [projectName] nombre del proyecto activo.
  /// [projectDir] directorio del proyecto (para contar archivos existentes).
  String generateFileName({
    required String mask,
    required String projectName,
    required String projectDir,
  }) {
    final now = DateTime.now();

    // Resolver tokens
    var result = mask
        .replaceAll('{PROYECTO}', projectName)
        .replaceAll(
          '{FECHA}',
          '${now.year}${_pad(now.month)}${_pad(now.day)}',
        )
        .replaceAll(
          '{HORA}',
          '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}',
        );

    // Resolver {NUMERO} como secuencial del proyecto
    if (result.contains('{NUMERO}')) {
      final nextNumber = _getNextSequentialNumber(projectDir);
      result = result.replaceAll('{NUMERO}', nextNumber.toString());
    }

    // Limpiar caracteres no válidos para Windows
    return _sanitizeFileName(result);
  }

  /// Genera el nombre por defecto si no hay máscara: YYYYMMDD_HHMMSS.
  String generateDefaultFileName() {
    final now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  /// Asegura que el nombre de archivo es único en su directorio.
  ///
  /// Si el archivo ya existe, incrementa un sufijo numérico
  /// hasta encontrar uno disponible. Nunca sobrescribe (§2.1).
  String _ensureUniqueFilename(String filePath) {
    var file = File(filePath);
    if (!file.existsSync()) return filePath;

    final dir = file.parent.path;
    final nameWithoutExt = _fileNameWithoutExtension(filePath);
    final ext = _fileExtension(filePath);

    var counter = 1;
    while (file.existsSync()) {
      final newPath = '$dir/$nameWithoutExt _($counter)$ext';
      file = File(newPath);
      counter++;
    }
    return file.path;
  }

  /// Obtiene el siguiente número secuencial para un proyecto.
  int _getNextSequentialNumber(String projectDir) {
    final dir = Directory(projectDir);
    if (!dir.existsSync()) return 1;

    final jpgFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList();

    return jpgFiles.length + 1;
  }

  /// Limpia caracteres no válidos para nombres de archivo en Windows.
  String _sanitizeFileName(String name) {
    var sanitized = name;
    for (final char in _invalidChars.split('')) {
      sanitized = sanitized.replaceAll(char, '_');
    }
    return sanitized;
  }

  /// Lista los archivos JPG en un directorio, ordenados por fecha
  /// (más nuevos primero).
  Future<List<String>> listJpgFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final files = await dir
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.toLowerCase().endsWith('.jpg'),
        )
        .cast<File>()
        .toList();

    // Ordenar por fecha de modificación descendente
    files.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    return files.map((f) => f.path).toList();
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _fileNameWithoutExtension(String path) {
    final name = path.split('/').last.split(r'\').last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return name;
    return name.substring(0, dotIndex);
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return path.substring(dotIndex);
  }

  /// Lee el contenido de un archivo como bytes.
  Future<Uint8List> readFileAsBytes(String path) async {
    return File(path).readAsBytes();
  }

  /// Elimina un archivo si existe.
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

/// Parámetros para la codificación JPG en isolate.
class _JpgEncodeParams {
  const _JpgEncodeParams({
    required this.imageBytes,
    required this.outputPath,
    required this.quality,
  });

  final Uint8List imageBytes;
  final String outputPath;
  final int quality;
}

/// Función top-level para ejecutar en isolate (§12.2).
///
/// Decodifica los bytes de imagen y los recodifica como JPG
/// con la calidad especificada.
Future<void> _encodeAndSaveJpg(_JpgEncodeParams params) async {
  final decoded = img.decodeImage(params.imageBytes);
  if (decoded == null) {
    throw Exception('No se pudo decodificar imagen para JPG');
  }

  final jpgBytes = img.encodeJpg(decoded, quality: params.quality);
  final file = File(params.outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(jpgBytes);
}
