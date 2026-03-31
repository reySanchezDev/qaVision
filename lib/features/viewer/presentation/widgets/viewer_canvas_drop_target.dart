import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';

/// Zona de drop para insertar imagenes al canvas del visor.
class ViewerCanvasDropTarget extends StatelessWidget {
  /// Crea una instancia de [ViewerCanvasDropTarget].
  const ViewerCanvasDropTarget({
    required this.child,
    super.key,
  });

  /// Contenido visual principal del target.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.trim().isNotEmpty,
      onAcceptWithDetails: (details) {
        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox) return;

        final bloc = context.read<ViewerBloc>();
        final local = renderObject.globalToLocal(details.offset);
        final imagePath = details.data.trim();
        if (imagePath.isEmpty) return;

        bloc.add(
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
}
