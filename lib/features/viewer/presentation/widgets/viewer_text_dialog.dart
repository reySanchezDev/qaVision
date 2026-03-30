import 'package:flutter/material.dart';

/// Diálogo reutilizable para crear/editar texto del visor.
class ViewerTextDialog {
  /// Solicita texto al usuario y retorna `null` si cancela.
  static Future<String?> prompt(
    BuildContext context, {
    String initialValue = '',
    String title = 'Agregar texto',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Escribe aqui'),
          onSubmitted: (submittedValue) =>
              Navigator.of(dialogContext).pop(submittedValue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
}
