import 'package:flutter/material.dart';

/// Dialogo multilinea para editar contenido de un bloque de texto enriquecido.
class ViewerRichTextPanelDialog {
  /// Solicita contenido enriquecido y retorna `null` si el usuario cancela.
  static Future<String?> prompt(
    BuildContext context, {
    String initialValue = '',
    String title = 'Agregar descripcion',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            void wrapSelection(String prefix, String suffix) {
              final selection = controller.selection;
              final text = controller.text;
              if (!selection.isValid) return;

              if (selection.isCollapsed) {
                final insertion = '$prefix$suffix';
                final nextText = text.replaceRange(
                  selection.start,
                  selection.end,
                  insertion,
                );
                controller.value = TextEditingValue(
                  text: nextText,
                  selection: TextSelection.collapsed(
                    offset: selection.start + prefix.length,
                  ),
                );
                setState(() {});
                return;
              }

              final selected = selection.textInside(text);
              final replacement = '$prefix$selected$suffix';
              final nextText = text.replaceRange(
                selection.start,
                selection.end,
                replacement,
              );
              controller.value = TextEditingValue(
                text: nextText,
                selection: TextSelection(
                  baseOffset: selection.start,
                  extentOffset: selection.start + replacement.length,
                ),
              );
              setState(() {});
            }

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FormatActionChip(
                          icon: Icons.format_bold,
                          label: 'Negrita',
                          onTap: () => wrapSelection('**', '**'),
                        ),
                        _FormatActionChip(
                          icon: Icons.format_italic,
                          label: 'Cursiva',
                          onTap: () => wrapSelection('_', '_'),
                        ),
                        _FormatActionChip(
                          icon: Icons.format_color_fill,
                          label: 'Resaltar',
                          onTap: () => wrapSelection('==', '=='),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tip: selecciona una parte del texto y usa las acciones de arriba para resaltarlo o enfatizarlo.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 180,
                        maxHeight: 360,
                      ),
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Describe aqui la evidencia, flujo o hallazgo',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
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
            );
          },
        );
      },
    );
    controller.dispose();
    return value;
  }
}

class _FormatActionChip extends StatelessWidget {
  const _FormatActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
