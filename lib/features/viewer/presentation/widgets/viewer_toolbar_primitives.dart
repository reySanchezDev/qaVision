import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

const _kViewerToolbarSurface = Color(0xFF1C1D21);
const _kViewerToolbarBorder = Color(0x1FFFFFFF);
const Color _kViewerToolbarForeground = Colors.white70;
const Color _kViewerToolbarSelected = Colors.lightBlueAccent;

/// Separador visual entre grupos de herramientas de la barra.
class ViewerToolbarGroupSeparator extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarGroupSeparator].
  const ViewerToolbarGroupSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white12,
    );
  }
}

/// Botón compacto de herramienta del visor.
class ViewerToolbarToolButton extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarToolButton].
  const ViewerToolbarToolButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    this.label,
    this.framed = true,
    super.key,
  });

  /// Ícono del botón.
  final IconData icon;

  /// Texto de ayuda.
  final String tooltip;

  /// Estado activo visual.
  final bool selected;

  /// Acción del botón.
  final VoidCallback onPressed;

  /// Texto opcional visible junto al icono.
  final String? label;

  /// Si se debe dibujar como boton individual con superficie propia.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? _kViewerToolbarSelected
        : _kViewerToolbarForeground;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              height: 36,
              padding: EdgeInsets.symmetric(
                horizontal: label == null ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: framed
                    ? selected
                        ? _kViewerToolbarSelected.withValues(alpha: 0.12)
                        : _kViewerToolbarSurface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: framed
                    ? Border.all(
                        color: selected
                            ? _kViewerToolbarSelected.withValues(alpha: 0.35)
                            : _kViewerToolbarBorder,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: foregroundColor),
                  if (label != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      label!,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Boton compacto con menu desplegable para grupos de herramientas.
class ViewerToolbarMenuButton<T> extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarMenuButton].
  const ViewerToolbarMenuButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.items,
    required this.onSelected,
    super.key,
  });

  /// Icono principal del grupo.
  final IconData icon;

  /// Titulo visible del grupo.
  final String label;

  /// Texto de ayuda.
  final String tooltip;

  /// Estado activo visual.
  final bool selected;

  /// Opciones disponibles dentro del menu.
  final List<PopupMenuEntry<T>> items;

  /// Callback de seleccion.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? _kViewerToolbarSelected
        : _kViewerToolbarForeground;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: PopupMenuButton<T>(
          tooltip: tooltip,
          onSelected: onSelected,
          itemBuilder: (context) => items,
          color: const Color(0xFF1E1E1E),
          elevation: 10,
          offset: const Offset(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? _kViewerToolbarSelected.withValues(alpha: 0.12)
                  : _kViewerToolbarSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? _kViewerToolbarSelected.withValues(alpha: 0.35)
                    : _kViewerToolbarBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: foregroundColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: foregroundColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenedor visual para acciones relacionadas dentro de la toolbar.
class ViewerToolbarActionCluster extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarActionCluster].
  const ViewerToolbarActionCluster({
    required this.children,
    super.key,
  });

  /// Botones o widgets internos.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: _kViewerToolbarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kViewerToolbarBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Swatch circular de color para propiedades del visor.
class ViewerToolbarColorSwatch extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarColorSwatch].
  const ViewerToolbarColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Color ARGB representado.
  final int color;

  /// Estado activo visual.
  final bool selected;

  /// Acción al seleccionar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.lightBlueAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

/// Campo unificado de color para propiedades de la toolbar.
class ViewerToolbarColorField extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarColorField].
  const ViewerToolbarColorField({
    required this.icon,
    required this.selectedColor,
    required this.swatches,
    required this.dialogTitle,
    required this.recentColors,
    required this.onColorSelected,
    this.label,
    this.tooltip,
    this.clearActionLabel,
    this.onClearSelected,
    this.advancedButtonLabel = 'Personalizar',
    super.key,
  });

  /// Etiqueta del campo.
  final String? label;

  /// Icono del selector.
  final IconData icon;

  /// Color actualmente activo.
  final int selectedColor;

  /// Colores rapidos visibles.
  final List<int> swatches;

  /// Titulo del selector avanzado.
  final String dialogTitle;

  /// Historial de colores recientes.
  final List<Color> recentColors;

  /// Callback al seleccionar color.
  final ValueChanged<int> onColorSelected;

  /// Tooltip opcional.
  final String? tooltip;

  /// Etiqueta para limpiar la propiedad cuando aplique.
  final String? clearActionLabel;

  /// Callback para limpiar la propiedad.
  final VoidCallback? onClearSelected;

  /// Etiqueta del boton avanzado.
  final String advancedButtonLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
        ],
        ViewerToolbarColorDropdown(
          icon: icon,
          selectedColor: selectedColor,
          swatches: swatches,
          dialogTitle: dialogTitle,
          recentColors: recentColors,
          tooltip: tooltip ?? dialogTitle,
          clearActionLabel: clearActionLabel,
          onClearSelected: onClearSelected,
          advancedButtonLabel: advancedButtonLabel,
          onColorSelected: onColorSelected,
        ),
      ],
    );
  }
}

/// Selector compacto de color con panel desplegable.
class ViewerToolbarColorDropdown extends StatefulWidget {
  /// Crea una instancia de [ViewerToolbarColorDropdown].
  const ViewerToolbarColorDropdown({
    required this.icon,
    required this.selectedColor,
    required this.swatches,
    required this.dialogTitle,
    required this.recentColors,
    required this.tooltip,
    required this.onColorSelected,
    this.clearActionLabel,
    this.onClearSelected,
    this.advancedButtonLabel = 'Personalizar',
    super.key,
  });

  /// Icono principal.
  final IconData icon;

  /// Color actual visible.
  final int selectedColor;

  /// Colores rapidos del menu.
  final List<int> swatches;

  /// Titulo del selector avanzado.
  final String dialogTitle;

  /// Colores recientes compartidos.
  final List<Color> recentColors;

  /// Tooltip del disparador.
  final String tooltip;

  /// Callback al elegir color.
  final ValueChanged<int> onColorSelected;

  /// Etiqueta para limpiar la propiedad cuando aplique.
  final String? clearActionLabel;

  /// Callback para limpiar la propiedad.
  final VoidCallback? onClearSelected;

  /// Etiqueta del boton avanzado.
  final String advancedButtonLabel;

  @override
  State<ViewerToolbarColorDropdown> createState() =>
      _ViewerToolbarColorDropdownState();
}

class _ViewerToolbarColorDropdownState extends State<ViewerToolbarColorDropdown> {
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _openMenu() async {
    final context = _anchorKey.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );

    final result = await showMenu<_ViewerToolbarColorMenuResult>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: const Color(0xFF1C1D21),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12),
      ),
      items: [
        PopupMenuItem<_ViewerToolbarColorMenuResult>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _ViewerToolbarColorMenuPanel(
            swatches: widget.swatches,
            selectedColor: widget.selectedColor,
            clearActionLabel: widget.clearActionLabel,
            advancedButtonLabel: widget.advancedButtonLabel,
            onColorTap: (color) {
              Navigator.of(context).pop(
                _ViewerToolbarColorMenuResult.color(color),
              );
            },
            onClearTap: widget.onClearSelected == null
                ? null
                : () {
                    Navigator.of(context).pop(
                      const _ViewerToolbarColorMenuResult.clear(),
                    );
                  },
            onAdvancedTap: () {
              Navigator.of(context).pop(
                const _ViewerToolbarColorMenuResult.custom(),
              );
            },
          ),
        ),
      ],
    );

    if (!mounted || result == null) return;

    switch (result.kind) {
      case _ViewerToolbarColorMenuResultKind.color:
        if (result.color != null) {
          widget.onColorSelected(result.color!);
        }
      case _ViewerToolbarColorMenuResultKind.clear:
        widget.onClearSelected?.call();
      case _ViewerToolbarColorMenuResultKind.custom:
        await _showAdvancedPicker();
    }
  }

  Future<void> _showAdvancedPicker() async {
    final selectedColor = await showColorPickerDialog(
      context,
      Color(widget.selectedColor),
      title: Text(widget.dialogTitle),
      showColorCode: true,
      showRecentColors: true,
      recentColors: List<Color>.from(widget.recentColors),
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.both: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      wheelSubheading: const Text('Rueda'),
      recentColorsSubheading: const Text('Recientes'),
    );

    if (!mounted) return;

    _rememberRecentColor(selectedColor);
    widget.onColorSelected(selectedColor.toARGB32());
  }

  void _rememberRecentColor(Color color) {
    widget.recentColors
      ..removeWhere((current) => current.toARGB32() == color.toARGB32())
      ..insert(0, color);
    if (widget.recentColors.length > 8) {
      widget.recentColors.removeRange(8, widget.recentColors.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: _anchorKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: widget.tooltip,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(36, 36),
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: Colors.white12),
              foregroundColor: Colors.white70,
              backgroundColor: const Color(0xFF1C1D21),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: _openMenu,
            child: Icon(widget.icon, size: 18),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Color(widget.selectedColor),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

class _ViewerToolbarColorMenuPanel extends StatelessWidget {
  const _ViewerToolbarColorMenuPanel({
    required this.swatches,
    required this.selectedColor,
    required this.advancedButtonLabel,
    required this.onColorTap,
    required this.onAdvancedTap,
    this.clearActionLabel,
    this.onClearTap,
  });

  final List<int> swatches;
  final int selectedColor;
  final String advancedButtonLabel;
  final ValueChanged<int> onColorTap;
  final VoidCallback onAdvancedTap;
  final String? clearActionLabel;
  final VoidCallback? onClearTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(selectedColor),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Color actual',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: swatches
                  .map(
                    (color) => ViewerToolbarColorSwatch(
                      color: color,
                      selected: selectedColor == color,
                      onTap: () => onColorTap(color),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (clearActionLabel != null && onClearTap != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onClearTap,
                icon: const Icon(Icons.format_clear, size: 16),
                label: Text(clearActionLabel!),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Colors.white12),
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF1C1D21),
              ),
              onPressed: onAdvancedTap,
              icon: const Icon(Icons.palette_outlined, size: 16),
              label: Text(
                advancedButtonLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ViewerToolbarColorMenuResultKind { color, custom, clear }

class _ViewerToolbarColorMenuResult {
  const _ViewerToolbarColorMenuResult.color(this.color)
    : kind = _ViewerToolbarColorMenuResultKind.color;

  const _ViewerToolbarColorMenuResult.custom()
    : kind = _ViewerToolbarColorMenuResultKind.custom,
      color = null;

  const _ViewerToolbarColorMenuResult.clear()
    : kind = _ViewerToolbarColorMenuResultKind.clear,
      color = null;

  final _ViewerToolbarColorMenuResultKind kind;
  final int? color;
}

/// Slider con etiqueta compacta para propiedades de herramienta.
class ViewerToolbarLabeledSlider extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarLabeledSlider].
  const ViewerToolbarLabeledSlider({
    required this.label,
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Etiqueta superior.
  final String label;

  /// Valor mínimo.
  final double min;

  /// Valor máximo.
  final double max;

  /// Cantidad de divisiones.
  final int divisions;

  /// Valor actual.
  final double value;

  /// Callback de cambio.
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        SizedBox(
          height: 26,
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Defaults visuales del frame al insertar imagen.
class ViewerFrameDefaults {
  /// Crea una instancia de [ViewerFrameDefaults].
  const ViewerFrameDefaults({
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.padding,
  });

  /// Color de fondo.
  final int backgroundColor;

  /// Opacidad de fondo.
  final double backgroundOpacity;

  /// Color de borde.
  final int borderColor;

  /// Grosor de borde.
  final double borderWidth;

  /// Padding interno.
  final double padding;
}
