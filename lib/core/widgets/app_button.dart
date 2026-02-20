import 'package:flutter/material.dart';

/// Botón estandarizado del Design System.
///
/// Reemplaza el uso directo de [ElevatedButton], [TextButton],
/// etc. para asegurar consistencia visual en toda la aplicación.
class AppButton extends StatelessWidget {
  /// Crea un [AppButton] con el [label] y la variante especificada.
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
  });

  /// Texto del botón.
  final String label;

  /// Callback al presionar.
  final VoidCallback? onPressed;

  /// Variante visual del botón.
  final AppButtonVariant variant;

  /// Ícono opcional a la izquierda del label.
  final IconData? icon;

  /// Si está en estado de carga, muestra un indicador.
  final bool isLoading;

  /// Si ocupa todo el ancho disponible.
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == AppButtonVariant.primary
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.primary,
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    };

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Variantes del botón del Design System.
enum AppButtonVariant {
  /// Botón principal con fondo sólido.
  primary,

  /// Botón secundario con borde.
  secondary,

  /// Botón de solo texto.
  text,
}
