import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_button.dart';
import 'package:qavision/core/widgets/app_color_picker.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Modal para editar metadatos del proyecto (alias/color/default).
class ProjectFormModal extends StatefulWidget {
  /// Crea una instancia de [ProjectFormModal].
  const ProjectFormModal({required this.project, super.key});

  /// Proyecto a editar.
  final ProjectEntity project;

  @override
  State<ProjectFormModal> createState() => _ProjectFormModalState();
}

class _ProjectFormModalState extends State<ProjectFormModal> {
  late int _selectedColor;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.project.color;
    _isDefault = widget.project.isDefault;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                l10n.projectsEdit,
                variant: TextVariant.titleLarge,
              ),
              const SizedBox(height: 18),
              _ReadOnlyRow(
                label: l10n.projectsName,
                value: widget.project.name,
              ),
              const SizedBox(height: 12),
              _ReadOnlyRow(
                label: 'Ruta de carpeta',
                value: widget.project.folderPath,
              ),
              const SizedBox(height: 16),
              AppColorPicker(
                label: l10n.projectsColor,
                selectedColor: Color(_selectedColor),
                onColorSelected: (color) {
                  setState(() => _selectedColor = color.toARGB32());
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: AppText(l10n.projectsSetDefault),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: l10n.projectsCancelButton,
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: l10n.projectsEditButton,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final updated = widget.project.copyWith(
      color: _selectedColor,
      isDefault: _isDefault,
    );
    context.read<ProjectBloc>().add(ProjectUpdated(updated));
    Navigator.of(context).pop();
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, variant: TextVariant.labelSmall),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AppText(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
