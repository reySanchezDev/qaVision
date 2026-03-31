import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_component.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_style.dart';
import 'package:qavision/features/viewer/domain/entities/image_frame_transform.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_image_frame_defaults.dart';
import 'package:qavision/features/viewer/domain/services/image_frame_component_service.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_composition_helper.dart';
import 'package:qavision/features/viewer/presentation/utils/viewer_workspace_layout.dart';
import 'package:uuid/uuid.dart';

/// Resultado de preparar un documento editable para guardado/exportacion.
class ViewerDocumentSavePlan {
  /// Crea un plan de guardado del documento editable.
  const ViewerDocumentSavePlan({
    required this.editableFrame,
    required this.focusImageId,
    required this.saveAsComposite,
    required this.outputPathWithoutExtension,
  });

  /// Frame editable estable que se persistira como sidecar.
  final FrameState editableFrame;

  /// Imagen raiz enfocada para exportacion individual.
  final String? focusImageId;

  /// Indica si la composicion tiene varias imagenes raiz.
  final bool saveAsComposite;

  /// Ruta base sin extension para el archivo exportado.
  final String outputPathWithoutExtension;
}

/// Resultado de carga del documento del visor.
class ViewerDocumentLoadResult {
  /// Crea un resultado de carga.
  const ViewerDocumentLoadResult({
    required this.frame,
    required this.recoveredFromDraft,
  });

  /// Frame final listo para el visor.
  final FrameState frame;

  /// `true` si el frame provino de un borrador de recuperación.
  final bool recoveredFromDraft;
}

/// Servicio responsable de cargar y persistir documentos editables del visor.
///
/// Esta pieza separa la fuente editable (`sidecar`) del resultado aplanado
/// exportado (`jpg`) para evitar duplicaciones e inconsistencias al reabrir.
class ViewerDocumentPersistenceService {
  /// Crea el servicio de persistencia de documentos del visor.
  ViewerDocumentPersistenceService({
    required FileSystemService fileSystemService,
  }) : _fileSystemService = fileSystemService;

  final FileSystemService _fileSystemService;
  static const _uuid = Uuid();

  /// Carga el documento editable asociado a una imagen o crea uno por defecto.
  Future<FrameState> loadFrameForImage({
    required String imagePath,
    required ViewerImageFrameDefaults defaults,
  }) async {
    final result = await loadFrameResultForImage(
      imagePath: imagePath,
      defaults: defaults,
    );
    return result.frame;
  }

  /// Carga el documento del visor resolviendo sidecar oficial + draft.
  Future<ViewerDocumentLoadResult> loadFrameResultForImage({
    required String imagePath,
    required ViewerImageFrameDefaults defaults,
  }) async {
    final sidecarFile = await _resolveSidecarFile(imagePath);
    final draftFile = io.File(recoveryDraftPathForImage(imagePath));

    final sidecarFrame = await _tryLoadFrameFromFile(
      sidecarFile,
      fallbackImagePath: imagePath,
      defaults: defaults,
    );
    final draftFrame = await _tryLoadFrameFromFile(
      draftFile,
      fallbackImagePath: imagePath,
      defaults: defaults,
    );

    final shouldUseDraft =
        draftFrame != null &&
        (sidecarFrame == null ||
            !sidecarFile.existsSync() ||
            (draftFile.existsSync() &&
                !draftFile.lastModifiedSync().isBefore(
                  sidecarFile.lastModifiedSync(),
                )));
    if (shouldUseDraft) {
      return ViewerDocumentLoadResult(
        frame: draftFrame,
        recoveredFromDraft: true,
      );
    }
    if (sidecarFrame != null) {
      return ViewerDocumentLoadResult(
        frame: sidecarFrame,
        recoveredFromDraft: false,
      );
    }

    return ViewerDocumentLoadResult(
      frame: await buildDefaultFrame(imagePath, defaults: defaults),
      recoveredFromDraft: false,
    );
  }

  /// Crea un plan de guardado con un frame editable estable para reapertura.
  Future<ViewerDocumentSavePlan> prepareSavePlan({
    required String activeImagePath,
    required FrameState frame,
  }) async {
    final images = frame.elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    );
    final rootImages = images
        .where((image) => image.parentImageId == null)
        .toList(growable: false);
    final rootImageCount = rootImages.length;
    final focusImageId = rootImageCount == 1 ? rootImages.first.id : null;
    final saveAsComposite = rootImageCount > 1;
    final outputPathWithoutExtension = saveAsComposite
        ? composedOutputNoExt(activeImagePath)
        : stripFileExtension(activeImagePath);

    final editableFrame = saveAsComposite
        ? frame
        : await _buildEditableFrameForSingleOutput(
            documentImagePath: activeImagePath,
            frame: frame,
          );

    return ViewerDocumentSavePlan(
      editableFrame: editableFrame,
      focusImageId: focusImageId,
      saveAsComposite: saveAsComposite,
      outputPathWithoutExtension: outputPathWithoutExtension,
    );
  }

  /// Persiste el documento editable del visor en formato sidecar.
  Future<void> saveEditableFrame({
    required String imagePath,
    required FrameState frame,
  }) async {
    await _writeFrameDocument(
      filePath: sidecarPathForImage(imagePath),
      frame: frame,
      documentKind: 'viewer_editable_document',
      sourceImagePath: imagePath,
    );
  }

  /// Persiste un borrador de recuperación para retomar la edición.
  Future<void> saveRecoveryDraft({
    required String imagePath,
    required FrameState frame,
  }) async {
    await _writeFrameDocument(
      filePath: recoveryDraftPathForImage(imagePath),
      frame: frame,
      documentKind: 'viewer_recovery_draft',
      sourceImagePath: imagePath,
    );
  }

  /// Elimina el borrador de recuperación de una imagen.
  Future<void> clearRecoveryDraft({
    required String imagePath,
  }) async {
    final file = io.File(recoveryDraftPathForImage(imagePath));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Construye el frame base inicial cuando aun no existe documento editable.
  Future<FrameState> buildDefaultFrame(
    String imagePath, {
    required ViewerImageFrameDefaults defaults,
  }) async {
    final image = await _loadImage(imagePath);
    const frameSize = Size(1500, 900);
    final workspaceRect = ViewerWorkspaceLayout.resolve(frameSize);
    final rawSize = Size(image.width.toDouble(), image.height.toDouble());
    final visualSize = ImageFrameComponentService.fitImageInsideFrame(
      rawSize,
      workspaceRect.size,
      maxFillRatio: 0.84,
    );
    final centeredPosition = Offset(
      workspaceRect.left + ((workspaceRect.width - visualSize.width) / 2),
      workspaceRect.top + ((workspaceRect.height - visualSize.height) / 2),
    );

    final baseImage = ImageFrameComponent(
      id: _uuid.v4(),
      position: centeredPosition,
      zIndex: 0,
      path: imagePath,
      contentSize: visualSize,
      style: ImageFrameStyle(
        backgroundColor: defaults.backgroundColor,
        backgroundOpacity: defaults.backgroundOpacity,
        borderColor: defaults.borderColor,
        borderWidth: defaults.borderWidth,
        padding: defaults.padding,
      ),
      transform: ImageFrameTransform(
        position: centeredPosition,
        size: visualSize,
      ),
      image: image,
      isLockedBase: true,
    );

    return FrameState(
      canvasSize: frameSize,
      elements: [baseImage],
    );
  }

  /// Ruta del sidecar editable asociado a una imagen.
  String sidecarPathForImage(String imagePath) {
    final file = io.File(imagePath);
    final dir = file.parent.path;
    final name = file.path.split(io.Platform.pathSeparator).last;
    return '$dir${io.Platform.pathSeparator}.qavision'
        '${io.Platform.pathSeparator}$name.qav.json';
  }

  /// Ruta del borrador de recuperación asociado a una imagen.
  String recoveryDraftPathForImage(String imagePath) {
    final file = io.File(imagePath);
    final dir = file.parent.path;
    final name = file.path.split(io.Platform.pathSeparator).last;
    return '$dir${io.Platform.pathSeparator}.qavision'
        '${io.Platform.pathSeparator}recovery'
        '${io.Platform.pathSeparator}$name.draft.qav.json';
  }

  /// Ruta de un asset editable preservado para evitar aplanados acumulativos.
  String editableAssetPathForImage(
    String imagePath, {
    required String elementId,
  }) {
    final file = io.File(imagePath);
    final dir = file.parent.path;
    final name = file.path.split(io.Platform.pathSeparator).last;
    return '$dir${io.Platform.pathSeparator}.qavision'
        '${io.Platform.pathSeparator}assets'
        '${io.Platform.pathSeparator}$elementId-$name';
  }

  /// Quita la extension de un archivo manteniendo la ruta completa.
  String stripFileExtension(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return normalized;

    final slash = math.max(
      normalized.lastIndexOf('/'),
      normalized.lastIndexOf(io.Platform.pathSeparator),
    );
    final dot = normalized.lastIndexOf('.');
    if (dot <= slash) return normalized;
    return normalized.substring(0, dot);
  }

  /// Construye la ruta base del compuesto cuando hay varias raices.
  String composedOutputNoExt(String activeImagePath) {
    final base = stripFileExtension(activeImagePath);
    if (base.toLowerCase().endsWith('_compuesto')) {
      return base;
    }
    return '${base}_compuesto';
  }

  Future<FrameState> _parseFrameFromJson(
    Map<String, dynamic> json, {
    required String fallbackImagePath,
    required ViewerImageFrameDefaults defaults,
  }) async {
    final payloadVersion = (json['version'] as num?)?.toInt() ?? 1;
    final canvasRaw = json['canvasSize'];
    final canvasSize = canvasRaw is Map<String, dynamic>
        ? Size(
            (canvasRaw['width'] as num?)?.toDouble() ?? 1500,
            (canvasRaw['height'] as num?)?.toDouble() ?? 900,
          )
        : const Size(1500, 900);
    final backgroundColor = (json['backgroundColor'] as int?) ?? 0xFF111111;

    final elementsRaw = json['elements'];
    if (elementsRaw is! List) {
      return buildDefaultFrame(fallbackImagePath, defaults: defaults);
    }

    final parsedElements = <CanvasElement>[];
    for (final raw in elementsRaw) {
      if (raw is! Map<String, dynamic>) continue;
      final kind = (raw['kind'] as String? ?? '').trim().toLowerCase();
      final id = (raw['id'] as String? ?? '').trim();
      if (id.isEmpty) continue;
      final zIndex = (raw['zIndex'] as int?) ?? parsedElements.length;
      final x = (raw['x'] as num?)?.toDouble() ?? 0;
      final y = (raw['y'] as num?)?.toDouble() ?? 0;

      if (kind == 'image') {
        final path = (raw['path'] as String? ?? '').trim();
        if (path.isEmpty) continue;
        final file = io.File(path);
        if (!file.existsSync()) continue;

        final width = (raw['width'] as num?)?.toDouble() ?? 0;
        final height = (raw['height'] as num?)?.toDouble() ?? 0;
        final image = await _loadImage(path);
        final targetWidth = width > 0 ? width : image.width.toDouble();
        final targetHeight = height > 0 ? height : image.height.toDouble();
        final contentWidth =
            (raw['contentWidth'] as num?)?.toDouble() ?? targetWidth;
        final contentHeight =
            (raw['contentHeight'] as num?)?.toDouble() ?? targetHeight;
        final contentOffsetX = (raw['contentOffsetX'] as num?)?.toDouble() ?? 0;
        final contentOffsetY = (raw['contentOffsetY'] as num?)?.toDouble() ?? 0;
        final parentImageId = (raw['parentImageId'] as String?)?.trim();

        parsedElements.add(
          ImageFrameComponent(
            id: id,
            position: Offset(x, y),
            zIndex: zIndex,
            path: path,
            contentSize: Size(contentWidth, contentHeight),
            style: ImageFrameStyle(
              backgroundColor:
                  (raw['frameBackgroundColor'] as int?) ??
                  defaults.backgroundColor,
              backgroundOpacity:
                  ((raw['frameBackgroundOpacity'] as num?)?.toDouble() ??
                          defaults.backgroundOpacity)
                      .clamp(0.0, 1.0),
              borderColor:
                  (raw['frameBorderColor'] as int?) ?? defaults.borderColor,
              borderWidth:
                  ((raw['frameBorderWidth'] as num?)?.toDouble() ??
                          defaults.borderWidth)
                      .clamp(0.0, 20.0),
              padding:
                  ((raw['framePadding'] as num?)?.toDouble() ??
                          defaults.padding)
                      .clamp(0.0, 300.0),
            ),
            transform: ImageFrameTransform(
              position: Offset(x, y),
              size: Size(targetWidth, targetHeight),
              contentOffset: Offset(contentOffsetX, contentOffsetY),
            ),
            image: image,
            parentImageId: parentImageId == null || parentImageId.isEmpty
                ? null
                : parentImageId,
            isLockedBase: (raw['isLockedBase'] as bool?) ?? false,
          ),
        );
        continue;
      }

      if (kind != 'annotation') continue;

      final typeName = (raw['type'] as String? ?? '').trim();
      final type = AnnotationType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => AnnotationType.rectangle,
      );
      final pointsRaw = raw['points'];
      final points = <Offset>[];
      if (pointsRaw is List) {
        for (final pointRaw in pointsRaw) {
          if (pointRaw is! Map<String, dynamic>) continue;
          points.add(
            Offset(
              (pointRaw['x'] as num?)?.toDouble() ?? 0,
              (pointRaw['y'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }

      final endX = (raw['endX'] as num?)?.toDouble();
      final endY = (raw['endY'] as num?)?.toDouble();
      final attachedImageId = (raw['attachedImageId'] as String?)?.trim();
      final coordinateSpaceName =
          (raw['coordinateSpace'] as String?)?.trim() ?? '';
      final coordinateSpace = AnnotationCoordinateSpace.values.firstWhere(
        (value) => value.name == coordinateSpaceName,
        orElse: () => AnnotationCoordinateSpace.workspace,
      );
      parsedElements.add(
        AnnotationElement(
          id: id,
          type: type,
          color: (raw['color'] as int?) ?? 0xFFE53935,
          strokeWidth: (raw['strokeWidth'] as num?)?.toDouble() ?? 4,
          textSize: (raw['textSize'] as num?)?.toDouble() ?? 20,
          opacity: (raw['opacity'] as num?)?.toDouble() ?? 1,
          text: (raw['text'] as String?) ?? '',
          position: Offset(x, y),
          endPosition: (endX != null && endY != null)
              ? Offset(endX, endY)
              : null,
          points: points,
          attachedImageId: attachedImageId == null || attachedImageId.isEmpty
              ? null
              : attachedImageId,
          coordinateSpace: coordinateSpace,
          zIndex: zIndex,
        ),
      );
    }

    if (parsedElements.isEmpty) {
      return buildDefaultFrame(fallbackImagePath, defaults: defaults);
    }

    final frame = FrameState(
      canvasSize: canvasSize,
      backgroundColor: backgroundColor,
      elements: _normalizeZ(parsedElements),
    );
    return payloadVersion >= 2
        ? frame
        : _migrateLegacyAnnotationSpaces(frame);
  }

  Future<io.File> _resolveSidecarFile(String imagePath) async {
    final newSidecarPath = sidecarPathForImage(imagePath);
    final oldSidecarPath = '$imagePath.qav.json';

    var sidecarFile = io.File(newSidecarPath);
    if (!sidecarFile.existsSync()) {
      final oldFile = io.File(oldSidecarPath);
      if (oldFile.existsSync()) {
        try {
          await sidecarFile.parent.create(recursive: true);
          await oldFile.rename(newSidecarPath);
          sidecarFile = io.File(newSidecarPath);
        } on Object {
          sidecarFile = oldFile;
        }
      }
    }
    return sidecarFile;
  }

  Future<FrameState?> _tryLoadFrameFromFile(
    io.File file, {
    required String fallbackImagePath,
    required ViewerImageFrameDefaults defaults,
  }) async {
    if (!file.existsSync()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final parsed = await _parseFrameFromJson(
        decoded,
        fallbackImagePath: fallbackImagePath,
        defaults: defaults,
      );
      if (parsed.elements.isEmpty) {
        return null;
      }
      return parsed;
    } on Exception {
      return null;
    }
  }

  Future<void> _writeFrameDocument({
    required String filePath,
    required FrameState frame,
    required String documentKind,
    required String sourceImagePath,
  }) async {
    final file = io.File(filePath);
    final elements = <Map<String, dynamic>>[];
    for (final element in frame.elements) {
      if (element is ImageFrameComponent) {
        elements.add(<String, dynamic>{
          'kind': 'image',
          'id': element.id,
          'path': element.path,
          'x': element.position.dx,
          'y': element.position.dy,
          'width': element.size.width,
          'height': element.size.height,
          'contentWidth': element.contentSize.width,
          'contentHeight': element.contentSize.height,
          'contentOffsetX': element.contentOffset.dx,
          'contentOffsetY': element.contentOffset.dy,
          'parentImageId': element.parentImageId,
          'frameBackgroundColor': element.style.backgroundColor,
          'frameBackgroundOpacity': element.style.backgroundOpacity,
          'frameBorderColor': element.style.borderColor,
          'frameBorderWidth': element.style.borderWidth,
          'framePadding': element.style.padding,
          'zIndex': element.zIndex,
          'isLockedBase': element.isLockedBase,
        });
        continue;
      }
      if (element is AnnotationElement) {
        elements.add(<String, dynamic>{
          'kind': 'annotation',
          'id': element.id,
          'type': element.type.name,
          'color': element.color,
          'strokeWidth': element.strokeWidth,
          'textSize': element.textSize,
          'opacity': element.opacity,
          'text': element.text,
          'attachedImageId': element.attachedImageId,
          'coordinateSpace': element.coordinateSpace.name,
          'x': element.position.dx,
          'y': element.position.dy,
          'endX': element.endPosition?.dx,
          'endY': element.endPosition?.dy,
          'points': element.points
              .map((point) => <String, dynamic>{'x': point.dx, 'y': point.dy})
              .toList(growable: false),
          'zIndex': element.zIndex,
        });
      }
    }

    final payload = <String, dynamic>{
      'version': 3,
      'documentKind': documentKind,
      'sourceImagePath': sourceImagePath,
      'savedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'canvasSize': <String, dynamic>{
        'width': frame.canvasSize.width,
        'height': frame.canvasSize.height,
      },
      'backgroundColor': frame.backgroundColor,
      'elements': elements,
    };

    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<FrameState> _buildEditableFrameForSingleOutput({
    required String documentImagePath,
    required FrameState frame,
  }) async {
    final elements = <CanvasElement>[];

    for (final element in frame.elements) {
      if (element is! ImageFrameComponent) {
        elements.add(element);
        continue;
      }

      if (_samePath(element.path, documentImagePath)) {
        final editablePath = editableAssetPathForImage(
          documentImagePath,
          elementId: element.id,
        );
        await _ensureEditableSourceCopy(
          sourceImagePath: documentImagePath,
          editablePath: editablePath,
        );
        elements.add(element.copyWith(path: editablePath));
        continue;
      }

      elements.add(element);
    }

    return frame.copyWith(elements: elements);
  }

  Future<void> _ensureEditableSourceCopy({
    required String sourceImagePath,
    required String editablePath,
  }) async {
    final editableFile = io.File(editablePath);
    if (editableFile.existsSync()) {
      return;
    }

    final sourceFile = io.File(sourceImagePath);
    if (!sourceFile.existsSync()) {
      return;
    }

    await editableFile.parent.create(recursive: true);
    await sourceFile.copy(editablePath);
  }

  bool _samePath(String left, String right) {
    String normalizePath(String path) {
      return path.trim().replaceAll(r'\', '/').toLowerCase();
    }

    return normalizePath(left) == normalizePath(right);
  }

  Future<ui.Image> _loadImage(String path) async {
    final bytes = await _fileSystemService.readFileAsBytes(path);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  FrameState _migrateLegacyAnnotationSpaces(FrameState frame) {
    final migrated = frame.elements.map((element) {
      if (element is! AnnotationElement) {
        return element;
      }
      if (element.attachedImageId == null || element.attachedImageId!.isEmpty) {
        return element;
      }
      if (element.coordinateSpace == AnnotationCoordinateSpace.imageContent) {
        return element;
      }

      final attachedImage = _findImageById(
        frame.elements,
        element.attachedImageId!,
      );
      if (attachedImage == null) {
        return element;
      }

      return element.copyWith(
        position: ViewerCompositionHelper.canvasPointToImageContent(
          attachedImage,
          element.position,
        ),
        endPosition: element.endPosition == null
            ? null
            : ViewerCompositionHelper.canvasPointToImageContent(
                attachedImage,
                element.endPosition!,
              ),
        points: element.points
            .map(
              (point) => ViewerCompositionHelper.canvasPointToImageContent(
                attachedImage,
                point,
              ),
            )
            .toList(growable: false),
        coordinateSpace: AnnotationCoordinateSpace.imageContent,
      );
    }).toList(growable: false);

    return frame.copyWith(elements: migrated);
  }

  ImageFrameComponent? _findImageById(
    List<CanvasElement> elements,
    String imageId,
  ) {
    for (final element in elements.whereType<ImageFrameComponent>()) {
      if (element.id == imageId) return element;
    }
    return null;
  }
  static List<CanvasElement> _normalizeZ(List<CanvasElement> elements) {
    final images = elements.whereType<ImageFrameComponent>().toList(
      growable: false,
    )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final annotations = elements.whereType<AnnotationElement>().toList(
      growable: false,
    )..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final normalizedSource = <CanvasElement>[...images, ...annotations];

    final normalized = <CanvasElement>[];
    for (var i = 0; i < normalizedSource.length; i++) {
      final element = normalizedSource[i];
      if (element is ImageFrameComponent) {
        normalized.add(element.copyWith(zIndex: i));
      } else if (element is AnnotationElement) {
        normalized.add(element.copyWith(zIndex: i));
      }
    }
    return normalized;
  }
}
