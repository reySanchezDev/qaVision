import 'package:flutter/material.dart';

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
