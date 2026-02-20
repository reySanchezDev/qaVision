import 'package:flutter/material.dart';

/// Campo de texto estandarizado del Design System.
///
/// Reemplaza el uso directo de [TextField] o [TextFormField]
/// para asegurar consistencia visual y de validación.
class AppTextField extends StatelessWidget {
  /// Crea un [AppTextField] con el [label] especificado.
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.validator,
    this.keyboardType,
  });

  /// Etiqueta del campo.
  final String label;

  /// Controlador del campo.
  final TextEditingController? controller;

  /// Texto de ayuda dentro del campo.
  final String? hint;

  /// Si el campo es de solo lectura.
  final bool readOnly;

  /// Si el texto debe ocultarse.
  final bool obscureText;

  /// Número máximo de líneas.
  final int maxLines;

  /// Ícono al final del campo.
  final Widget? suffixIcon;

  /// Ícono al inicio del campo.
  final Widget? prefixIcon;

  /// Callback al cambiar el texto.
  final ValueChanged<String>? onChanged;

  /// Función de validación.
  final String? Function(String?)? validator;

  /// Tipo de teclado.
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );
  }
}
