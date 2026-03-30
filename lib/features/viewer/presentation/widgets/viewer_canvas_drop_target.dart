import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';

/// Zona de drop para insertar imágenes al canvas del visor.
class ViewerCanvasDropTarget extends StatelessWidget {
  /// Crea una instancia de [ViewerCanvasDropTarget].
  const ViewerCanvasDropTarget({
    required this.child,
    required this.frameSize,
    required this.contentZoom,
    super.key,
  });

  /// Contenido visual principal del target.
  final Widget child;

  /// Tamaño del frame del canvas.
  final Size frameSize;

  /// Zoom visual actual del contenido.
  final double contentZoom;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.trim().isNotEmpty,
      onAcceptWithDetails: (details) {
        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox) return;

        final local = _toLogicalPoint(
          renderObject.globalToLocal(details.offset),
          frameSize: frameSize,
          zoom: contentZoom,
        );
        final imagePath = details.data.trim();
        if (imagePath.isEmpty) return;

        context.read<ViewerBloc>().add(
          ViewerImageAdded(
            imagePath: imagePath,
            projectPath: File(imagePath).parent.path,
            position: local,
            defaultFrameBackgroundColor:
                kAppDefaults.viewerDefaultFrameBackgroundColor,
            defaultFrameBackgroundOpacity:
                kAppDefaults.viewerDefaultFrameBackgroundOpacity,
            defaultFrameBorderColor: kAppDefaults.viewerDefaultFrameBorderColor,
            defaultFrameBorderWidth: kAppDefaults.viewerDefaultFrameBorderWidth,
            defaultFramePadding: kAppDefaults.viewerDefaultFramePadding,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHovering ? Colors.lightBlueAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Offset _toLogicalPoint(
    Offset point, {
    required Size frameSize,
    required double zoom,
  }) {
    if ((zoom - 1).abs() <= 0.001) {
      return point;
    }
    final center = frameSize.center(Offset.zero);
    return Offset(
      ((point.dx - center.dx) / zoom) + center.dx,
      ((point.dy - center.dy) / zoom) + center.dy,
    );
  }
}
