import 'package:flutter/material.dart';

/// Separador visual entre grupos de herramientas de la barra.
class ViewerToolbarGroupSeparator extends StatelessWidget {
  /// Crea una instancia de [ViewerToolbarGroupSeparator].
  const ViewerToolbarGroupSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white24,
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: IconButton(
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon),
          onPressed: onPressed,
          color: selected ? Colors.lightBlueAccent : Colors.white70,
        ),
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
