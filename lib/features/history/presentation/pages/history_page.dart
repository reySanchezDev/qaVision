import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/navigation/app_routes.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/history/presentation/bloc/history_bloc.dart';
import 'package:qavision/features/history/presentation/bloc/history_event.dart';
import 'package:qavision/features/history/presentation/bloc/history_state.dart';

/// Pantalla de historial global de capturas (§12.0).
class HistoryPage extends StatelessWidget {
  /// Crea una instancia de [HistoryPage].
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const AppText(
          'Historial de Capturas',
          variant: TextVariant.titleLarge,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<HistoryBloc>().add(const HistoryStarted()),
          ),
        ],
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state is HistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HistoryError) {
            return Center(
              child: AppText(
                state.message,
                color: Colors.redAccent,
              ),
            );
          }

          if (state is HistoryLoadSuccess) {
            if (state.captures.isEmpty) {
              return const Center(
                child: AppText(
                  'No hay capturas en el historial',
                  variant: TextVariant.bodyLarge,
                  color: Colors.white38,
                ),
              );
            }

            return Column(
              children: [
                _buildProjectFilter(context, state),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: state.captures.length,
                    itemBuilder: (context, index) {
                      final capture = state.captures[index];
                      return _HistoryGridItem(
                        capturePath: capture.path,
                        id: capture.id,
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildProjectFilter(BuildContext context, HistoryLoadSuccess state) {
    // Obtener lista única de proyectos de las capturas
    final projects = state.captures.map((e) => e.projectName).toSet().toList();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: state.projectFilter == null,
              onSelected: (selected) {
                if (selected) {
                  context.read<HistoryBloc>().add(const HistoryFilterChanged());
                }
              },
            ),
          ),
          ...projects.map(
            (p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p),
                selected: state.projectFilter == p,
                onSelected: (selected) {
                  context.read<HistoryBloc>().add(
                    HistoryFilterChanged(projectPath: selected ? p : null),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryGridItem extends StatelessWidget {
  const _HistoryGridItem({required this.capturePath, required this.id});

  final String capturePath;
  final String id;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(
          Navigator.pushNamed(
            context,
            AppRoutes.viewer,
            arguments: capturePath,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(capturePath),
                fit: BoxFit.cover,
                cacheWidth: 300,
              ),
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    context.read<HistoryBloc>().add(
                      HistoryItemDeleted(capturePath: capturePath),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.black54,
                  child: AppText(
                    capturePath.split(Platform.pathSeparator).last,
                    variant: TextVariant.labelSmall,
                    color: Colors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
