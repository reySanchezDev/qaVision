import 'package:flutter/material.dart';

/// Card estandarizada del Design System.
///
/// Provee una envoltura visual consistente para agrupar
/// contenido relacionado, como secciones de configuración.
class AppCard extends StatelessWidget {
  /// Crea un [AppCard] con el [child] especificado.
  const AppCard({
    required this.child,
    super.key,
    this.title,
    this.padding,
    this.margin,
  });

  /// Contenido interno de la card.
  final Widget child;

  /// Título opcional que aparece arriba del contenido.
  final String? title;

  /// Padding interno personalizado.
  final EdgeInsetsGeometry? padding;

  /// Margen externo personalizado.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
