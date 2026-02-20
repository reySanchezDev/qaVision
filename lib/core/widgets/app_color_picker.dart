import 'package:flutter/material.dart';

/// Selector de color compacto del Design System.
///
/// Muestra una paleta de colores predefinidos que el usuario
/// puede seleccionar. Utilizado para proyectos (§5.1) y
/// botón flotante (§4.2).
class AppColorPicker extends StatelessWidget {
  /// Crea un [AppColorPicker] con el color [selectedColor] activo.
  const AppColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
    super.key,
    this.label,
  });

  /// Color actualmente seleccionado.
  final Color selectedColor;

  /// Callback cuando se selecciona un color.
  final ValueChanged<Color> onColorSelected;

  /// Etiqueta opcional del selector.
  final String? label;

  /// Paleta de colores disponibles para QA.
  static const List<Color> defaultColors = [
    Color(0xFFE53935), // Rojo
    Color(0xFFD81B60), // Rosa
    Color(0xFF8E24AA), // Púrpura
    Color(0xFF5E35B1), // Violeta
    Color(0xFF3949AB), // Índigo
    Color(0xFF1E88E5), // Azul
    Color(0xFF039BE5), // Azul claro
    Color(0xFF00ACC1), // Cian
    Color(0xFF00897B), // Teal
    Color(0xFF43A047), // Verde
    Color(0xFF7CB342), // Verde claro
    Color(0xFFC0CA33), // Lima
    Color(0xFFFDD835), // Amarillo
    Color(0xFFFFB300), // Ámbar
    Color(0xFFFB8C00), // Naranja
    Color(0xFFF4511E), // Naranja oscuro
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: defaultColors.map((color) {
            final isSelected = color.toARGB32() == selectedColor.toARGB32();
            return GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: theme.colorScheme.onSurface,
                          width: 2.5,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
