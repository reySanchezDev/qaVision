import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Base viewer event.
sealed class ViewerEvent extends Equatable {
  /// Creates [ViewerEvent].
  const ViewerEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes viewer with an image.
final class ViewerStarted extends ViewerEvent {
  /// Creates [ViewerStarted].
  const ViewerStarted({
    required this.imagePath,
    this.defaultFrameBackgroundColor,
    this.defaultFrameBackgroundOpacity,
    this.defaultFrameBorderColor,
    this.defaultFrameBorderWidth,
    this.defaultFramePadding,
  });

  /// Base image path.
  final String imagePath;

  /// Default frame background color for newly created base frame.
  final int? defaultFrameBackgroundColor;

  /// Default frame background opacity.
  final double? defaultFrameBackgroundOpacity;

  /// Default frame border color.
  final int? defaultFrameBorderColor;

  /// Default frame border width.
  final double? defaultFrameBorderWidth;

  /// Default frame inner padding.
  final double? defaultFramePadding;

  @override
  List<Object?> get props => [
    imagePath,
    defaultFrameBackgroundColor,
    defaultFrameBackgroundOpacity,
    defaultFrameBorderColor,
    defaultFrameBorderWidth,
    defaultFramePadding,
  ];
}

/// Changes active tool.
final class ViewerToolChanged extends ViewerEvent {
  /// Creates [ViewerToolChanged].
  const ViewerToolChanged(this.tool);

  /// New active tool.
  final AnnotationType tool;

  @override
  List<Object?> get props => [tool];
}

/// Changes tool properties.
final class ViewerPropertiesChanged extends ViewerEvent {
  /// Creates [ViewerPropertiesChanged].
  const ViewerPropertiesChanged({
    this.color,
    this.strokeWidth,
    this.textSize,
    this.opacity,
  });

  /// Active color.
  final int? color;

  /// Active stroke width.
  final double? strokeWidth;

  /// Active text size.
  final double? textSize;

  /// Active opacity.
  final double? opacity;

  @override
  List<Object?> get props => [color, strokeWidth, textSize, opacity];
}

/// Changes canvas background color.
final class ViewerBackgroundColorChanged extends ViewerEvent {
  /// Creates [ViewerBackgroundColorChanged].
  const ViewerBackgroundColorChanged(this.color);

  /// New ARGB color.
  final int color;

  @override
  List<Object?> get props => [color];
}

/// Resizes the frame canvas.
final class ViewerCanvasResized extends ViewerEvent {
  /// Creates [ViewerCanvasResized].
  const ViewerCanvasResized(this.size);

  /// New frame size.
  final Size size;

  @override
  List<Object?> get props => [size];
}

/// Starts drawing annotation.
final class ViewerAnnotationStarted extends ViewerEvent {
  /// Creates [ViewerAnnotationStarted].
  const ViewerAnnotationStarted(this.position);

  /// Pointer position.
  final Offset position;

  @override
  List<Object?> get props => [position];
}

/// Updates drawing annotation.
final class ViewerAnnotationUpdated extends ViewerEvent {
  /// Creates [ViewerAnnotationUpdated].
  const ViewerAnnotationUpdated(this.position);

  /// Pointer position.
  final Offset position;

  @override
  List<Object?> get props => [position];
}

/// Ends drawing annotation.
final class ViewerAnnotationFinished extends ViewerEvent {
  /// Creates [ViewerAnnotationFinished].
  const ViewerAnnotationFinished();
}

/// Adds text/bubble content at a position.
final class ViewerTextAdded extends ViewerEvent {
  /// Creates [ViewerTextAdded].
  const ViewerTextAdded({
    required this.position,
    required this.text,
  });

  /// Placement position.
  final Offset position;

  /// Text to insert.
  final String text;

  @override
  List<Object?> get props => [position, text];
}

/// Undo action.
final class ViewerUndoRequested extends ViewerEvent {
  /// Creates [ViewerUndoRequested].
  const ViewerUndoRequested();
}

/// Redo action.
final class ViewerRedoRequested extends ViewerEvent {
  /// Creates [ViewerRedoRequested].
  const ViewerRedoRequested();
}

/// Exports composition.
final class ViewerExportRequested extends ViewerEvent {
  /// Creates [ViewerExportRequested].
  const ViewerExportRequested();
}

/// Copies composition to clipboard.
final class ViewerCopyRequested extends ViewerEvent {
  /// Creates [ViewerCopyRequested].
  const ViewerCopyRequested();
}

/// Shares composition.
final class ViewerShareRequested extends ViewerEvent {
  /// Creates [ViewerShareRequested].
  const ViewerShareRequested();
}

/// Loads recent captures from a project directory.
final class ViewerRecentCapturesRequested extends ViewerEvent {
  /// Creates [ViewerRecentCapturesRequested].
  const ViewerRecentCapturesRequested({required this.projectPath});

  /// Project folder path.
  final String projectPath;

  @override
  List<Object?> get props => [projectPath];
}

/// Reorders thumbnails inside the recent strip.
final class ViewerRecentCapturesReordered extends ViewerEvent {
  /// Creates [ViewerRecentCapturesReordered].
  const ViewerRecentCapturesReordered({
    required this.oldIndex,
    required this.newIndex,
  });

  /// Previous item index.
  final int oldIndex;

  /// New item index.
  final int newIndex;

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// Adds an image to frame.
final class ViewerImageAdded extends ViewerEvent {
  /// Creates [ViewerImageAdded].
  const ViewerImageAdded({
    required this.imagePath,
    required this.projectPath,
    this.position,
    this.defaultFrameBackgroundColor,
    this.defaultFrameBackgroundOpacity,
    this.defaultFrameBorderColor,
    this.defaultFrameBorderWidth,
    this.defaultFramePadding,
  });

  /// Image file path.
  final String imagePath;

  /// Project folder path.
  final String projectPath;

  /// Optional initial position.
  final Offset? position;

  /// Default frame background color.
  final int? defaultFrameBackgroundColor;

  /// Default frame background opacity.
  final double? defaultFrameBackgroundOpacity;

  /// Default frame border color.
  final int? defaultFrameBorderColor;

  /// Default frame border width.
  final double? defaultFrameBorderWidth;

  /// Default frame inner padding.
  final double? defaultFramePadding;

  @override
  List<Object?> get props => [
    imagePath,
    projectPath,
    position,
    defaultFrameBackgroundColor,
    defaultFrameBackgroundOpacity,
    defaultFrameBorderColor,
    defaultFrameBorderWidth,
    defaultFramePadding,
  ];
}

/// Updates style properties of selected image frame.
final class ViewerSelectedFrameStyleChanged extends ViewerEvent {
  /// Creates [ViewerSelectedFrameStyleChanged].
  const ViewerSelectedFrameStyleChanged({
    this.frameBackgroundColor,
    this.frameBackgroundOpacity,
    this.frameBorderColor,
    this.frameBorderWidth,
    this.framePadding,
  });

  /// New frame background color.
  final int? frameBackgroundColor;

  /// New frame background opacity.
  final double? frameBackgroundOpacity;

  /// New frame border color.
  final int? frameBorderColor;

  /// New frame border width.
  final double? frameBorderWidth;

  /// New frame inner padding.
  final double? framePadding;

  @override
  List<Object?> get props => [
    frameBackgroundColor,
    frameBackgroundOpacity,
    frameBorderColor,
    frameBorderWidth,
    framePadding,
  ];
}

/// Selects a canvas element.
final class ViewerElementSelected extends ViewerEvent {
  /// Creates [ViewerElementSelected].
  const ViewerElementSelected({
    this.elementId,
    this.centerImage = true,
  });

  /// Element id or null to clear.
  final String? elementId;

  /// True to center selected image inside viewer frame.
  final bool centerImage;

  @override
  List<Object?> get props => [elementId, centerImage];
}

/// Moves a canvas element.
final class ViewerElementMoved extends ViewerEvent {
  /// Creates [ViewerElementMoved].
  const ViewerElementMoved({
    required this.elementId,
    required this.position,
  });

  /// Target element id.
  final String elementId;

  /// New top-left position.
  final Offset position;

  @override
  List<Object?> get props => [elementId, position];
}

/// Moves image content inside an image frame (pan/encuadre).
final class ViewerImageContentMoved extends ViewerEvent {
  /// Creates [ViewerImageContentMoved].
  const ViewerImageContentMoved({
    required this.elementId,
    required this.contentOffset,
  });

  /// Target image element id.
  final String elementId;

  /// New content top-left offset inside the image frame viewport.
  final Offset contentOffset;

  @override
  List<Object?> get props => [elementId, contentOffset];
}

/// Resizes an element.
final class ViewerElementResized extends ViewerEvent {
  /// Creates [ViewerElementResized].
  const ViewerElementResized({
    required this.elementId,
    required this.size,
    this.position,
  });

  /// Target element id.
  final String elementId;

  /// New size.
  final Size size;

  /// Optional top-left position used for side/corner resize.
  final Offset? position;

  @override
  List<Object?> get props => [elementId, size, position];
}

/// Marks the start of a drag/resize interaction.
final class ViewerInteractionStarted extends ViewerEvent {
  /// Creates [ViewerInteractionStarted].
  const ViewerInteractionStarted();
}

/// Marks the end of a drag/resize interaction.
final class ViewerInteractionFinished extends ViewerEvent {
  /// Creates [ViewerInteractionFinished].
  const ViewerInteractionFinished();
}

/// Internal event that persists current frame composition.
final class ViewerAutoSaveRequested extends ViewerEvent {
  /// Creates [ViewerAutoSaveRequested].
  const ViewerAutoSaveRequested();
}

/// Deletes element.
final class ViewerElementDeleted extends ViewerEvent {
  /// Creates [ViewerElementDeleted].
  const ViewerElementDeleted({required this.elementId});

  /// Target element id.
  final String elementId;

  @override
  List<Object?> get props => [elementId];
}

/// Updates text content of selected text-capable element.
final class ViewerSelectedElementTextUpdated extends ViewerEvent {
  /// Creates [ViewerSelectedElementTextUpdated].
  const ViewerSelectedElementTextUpdated(this.text);

  /// New text.
  final String text;

  @override
  List<Object?> get props => [text];
}

/// Changes z-order.
final class ViewerElementZOrderChanged extends ViewerEvent {
  /// Creates [ViewerElementZOrderChanged].
  const ViewerElementZOrderChanged({
    required this.elementId,
    required this.isForward,
  });

  /// Target element id.
  final String elementId;

  /// True to bring forward, false to send backward.
  final bool isForward;

  @override
  List<Object?> get props => [elementId, isForward];
}
