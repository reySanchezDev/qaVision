import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';

/// Bridge liviano entre la toolbar del visor y el editor inline del panel.
class ViewerRichTextPanelRuntime {
  /// Creates [ViewerRichTextPanelRuntime].
  const ViewerRichTextPanelRuntime({
    required this.hasSelection,
    required this.boldActive,
    required this.italicActive,
    required this.highlightActive,
    required this.currentAlignment,
    required this.selectedTextColor,
    required this.selectedHighlightColor,
    required this.requestFocus,
    required this.applyTextColor,
    required this.applyHighlightColor,
    required this.applyAlignment,
    required this.clearHighlight,
    required this.toggleBold,
    required this.toggleItalic,
  });

  /// Whether current inline selection is valid.
  final bool hasSelection;

  /// Whether bold is active on current selection.
  final bool boldActive;

  /// Whether italic is active on current selection.
  final bool italicActive;

  /// Whether highlight is active on current selection.
  final bool highlightActive;

  /// Current paragraph alignment at the caret or selection.
  final ViewerTextPanelAlignment? currentAlignment;

  /// Selected text color when available.
  final int? selectedTextColor;

  /// Selected highlight color when available.
  final int? selectedHighlightColor;

  /// Requests focus back to the inline editor.
  final void Function() requestFocus;

  /// Applies text color to the current inline selection.
  final void Function(int color) applyTextColor;

  /// Applies highlight color to the current inline selection.
  final void Function(int color) applyHighlightColor;

  /// Applies paragraph alignment to the current inline selection/caret.
  final void Function(ViewerTextPanelAlignment alignment) applyAlignment;

  /// Clears highlight from the current inline selection.
  final void Function() clearHighlight;

  /// Toggles bold on current selection.
  final void Function() toggleBold;

  /// Toggles italic on current selection.
  final void Function() toggleItalic;
}
