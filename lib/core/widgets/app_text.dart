import 'package:flutter/material.dart';

/// Variantes de texto definidas en el Design System.
enum TextVariant {
  /// Título grande (e.g., AppBar).
  titleLarge,

  /// Título mediano (e.g., encabezados de secciones).
  titleMedium,

  /// Título pequeño (e.g., encabezados de panels).
  titleSmall,

  /// Cuerpo de texto normal.
  bodyLarge,

  /// Cuerpo de texto mediano.
  bodyMedium,

  /// Cuerpo de texto pequeño.
  bodySmall,

  /// Etiquetas o pies de foto.
  labelSmall,
}

/// Widget estandarizado para mostrar texto según el Design System.
///
/// Este widget reemplaza el uso directo de [Text] para asegurar
/// consistencia visual en toda la aplicación.
class AppText extends StatelessWidget {
  /// Crea un [AppText] con el [text] y la [variant] especificada.
  const AppText(
    this.text, {
    super.key,
    this.variant = TextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
  });

  /// El contenido del texto a mostrar.
  final String text;

  /// La variante de estilo a aplicar.
  final TextVariant variant;

  /// Color opcional para el texto.
  final Color? color;

  /// Alineación del texto.
  final TextAlign? textAlign;

  /// Número máximo de líneas.
  final int? maxLines;

  /// Comportamiento del desbordamiento.
  final TextOverflow? overflow;

  /// Peso de la fuente opcional.
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    TextStyle? style;
    switch (variant) {
      case TextVariant.titleLarge:
        style = textTheme.titleLarge;
      case TextVariant.titleMedium:
        style = textTheme.titleMedium;
      case TextVariant.titleSmall:
        style = textTheme.titleSmall;
      case TextVariant.bodyLarge:
        style = textTheme.bodyLarge;
      case TextVariant.bodyMedium:
        style = textTheme.bodyMedium;
      case TextVariant.bodySmall:
        style = textTheme.bodySmall;
      case TextVariant.labelSmall:
        style = textTheme.labelSmall;
    }

    if (color != null || fontWeight != null) {
      style = style?.copyWith(
        color: color,
        fontWeight: fontWeight,
      );
    }

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
