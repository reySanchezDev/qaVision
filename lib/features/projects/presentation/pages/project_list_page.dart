import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';
import 'package:qavision/features/projects/presentation/widgets/project_form_modal.dart';
import 'package:qavision/features/projects/presentation/widgets/project_list_item.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Pantalla de Gestión de Proyectos (§5).
///
/// Muestra la lista de proyectos y permite
/// crear, editar y establecer predeterminados.
class ProjectListPage extends StatelessWidget {
  /// Crea una instancia de [ProjectListPage].
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: AppText(l10n.projectsTitle, variant: TextVariant.titleLarge),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateModal(context),
        icon: const Icon(Icons.add),
        label: AppText(
          l10n.projectsNewProject,
        ),
      ),
      body: BlocBuilder<ProjectBloc, ProjectState>(
        builder: (context, state) {
          if (state is ProjectLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProjectError) {
            return Center(
              child: AppText(state.message, variant: TextVariant.bodyLarge),
            );
          }

          if (state is ProjectLoadSuccess) {
            if (state.projects.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      l10n.projectsNewProject,
                      variant: TextVariant.bodyLarge,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.projects.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final project = state.projects[index];
                return ProjectListItem(project: project);
              },
            );
          }

          // Estado inicial: disparar carga
          context.read<ProjectBloc>().add(const ProjectsLoaded());
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Future<void> _showCreateModal(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ProjectBloc>(),
        child: const ProjectFormModal(),
      ),
    );
  }
}
