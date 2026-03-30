import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_button.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/widgets/project_form_modal.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Item de la lista de proyectos.
///
/// Muestra nombre, alias, color, indicador de predeterminado
/// y acciones (editar, abrir carpeta, establecer predeterminado).
class ProjectListItem extends StatelessWidget {
  /// Crea una instancia de [ProjectListItem].
  const ProjectListItem({required this.project, super.key});

  /// El proyecto a mostrar.
  final ProjectEntity project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: project.isDefault ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: project.isDefault
            ? BorderSide(color: Color(project.color), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Indicador de color
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(project.color),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: AppText(
                  _buildShortCode(project.name),
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Nombre y detalles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    project.name,
                    variant: TextVariant.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (project.isDefault)
                    AppText(
                      '★ ${l10n.projectsSetDefault}',
                      variant: TextVariant.labelSmall,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),

            // Acciones
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.projectsEditButton,
                  onPressed: () => _showEditModal(context),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open_outlined),
                  tooltip: l10n.projectsOpenFolder,
                  onPressed: () {
                    if (Platform.isWindows) {
                      unawaited(
                        Process.run('explorer.exe', [project.folderPath]),
                      );
                    }
                  },
                ),
                if (!project.isDefault)
                  AppButton(
                    label: l10n.projectsSetDefaultButton,
                    variant: AppButtonVariant.text,
                    onPressed: () => context.read<ProjectBloc>().add(
                      ProjectSetDefault(project.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditModal(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ProjectBloc>(),
        child: ProjectFormModal(project: project),
      ),
    );
  }

  String _buildShortCode(String value) {
    final clean = value.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    if (clean.isEmpty) return 'PRY';
    if (clean.length >= 3) return clean.substring(0, 3);
    return clean.padRight(3, 'X');
  }
}
