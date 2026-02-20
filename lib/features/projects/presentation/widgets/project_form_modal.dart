import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_button.dart';
import 'package:qavision/core/widgets/app_color_picker.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/core/widgets/app_text_field.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Modal para crear o editar un proyecto (§5.1–§5.2).
class ProjectFormModal extends StatefulWidget {
  /// Crea una instancia de [ProjectFormModal].
  ///
  /// Si [project] es `null`, se crea un proyecto nuevo.
  /// Si se proporciona, se edita el proyecto existente.
  const ProjectFormModal({super.key, this.project});

  /// Proyecto a editar (null para crear nuevo).
  final ProjectEntity? project;

  @override
  State<ProjectFormModal> createState() => _ProjectFormModalState();
}

class _ProjectFormModalState extends State<ProjectFormModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _aliasController;
  late int _selectedColor;
  late bool _isDefault;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.project?.name ?? '',
    );
    _aliasController = TextEditingController(
      text: widget.project?.alias ?? '',
    );
    _selectedColor = widget.project?.color ?? 0xFF1E88E5;
    _isDefault = widget.project?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              AppText(
                _isEditing ? l10n.projectsEdit : l10n.projectsCreate,
                variant: TextVariant.titleLarge,
              ),
              const SizedBox(height: 24),

              // Nombre del proyecto
              AppTextField(
                label: l10n.projectsName,
                controller: _nameController,
              ),
              const SizedBox(height: 16),

              // Alias corto
              AppTextField(
                label: l10n.projectsAlias,
                hint: 'PR',
                controller: _aliasController,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  if (value.length < 2 || value.length > 4) {
                    return '2–4 letras';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Color
              AppColorPicker(
                label: l10n.projectsColor,
                selectedColor: Color(_selectedColor),
                onColorSelected: (color) {
                  setState(() => _selectedColor = color.toARGB32());
                },
              ),
              const SizedBox(height: 16),

              // Predeterminado
              CheckboxListTile(
                title: AppText(
                  l10n.projectsSetDefault,
                ),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Botones
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
                    label: _isEditing
                        ? l10n.projectsEditButton
                        : l10n.projectsCreateButton,
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
    final name = _nameController.text.trim();
    final alias = _aliasController.text.trim().toUpperCase();

    if (name.isEmpty || alias.length < 2 || alias.length > 4) return;

    if (_isEditing) {
      final updated = widget.project!.copyWith(
        name: name,
        alias: alias,
        color: _selectedColor,
        isDefault: _isDefault,
      );
      context.read<ProjectBloc>().add(ProjectUpdated(updated));
    } else {
      final newProject = ProjectEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        alias: alias,
        color: _selectedColor,
        isDefault: _isDefault,
      );
      context.read<ProjectBloc>().add(ProjectCreated(newProject));
    }

    Navigator.of(context).pop();
  }
}
