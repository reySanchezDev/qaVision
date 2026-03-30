import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/history/presentation/bloc/history_bloc.dart';
import 'package:qavision/features/history/presentation/bloc/history_event.dart';
import 'package:qavision/features/history/presentation/bloc/history_state.dart';

/// Pantalla de historial global de capturas (§12.0).
class HistoryPage extends StatefulWidget {
  /// Crea una instancia de [HistoryPage].
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // Disparar carga inicial automática (§H-013)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HistoryBloc>().add(const HistoryStarted());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const AppText(
          'Historial de Capturas',
          variant: TextVariant.titleLarge,
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar historial',
            onPressed: () =>
                context.read<HistoryBloc>().add(const HistoryStarted()),
          ),
        ],
      ),
      body: BlocBuilder<HistoryBloc, HistoryState>(
        builder: (context, state) {
          if (state is HistoryInitial || state is HistoryLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  AppText(
                    'Cargando historial...',
                  ),
                ],
              ),
            );
          }

          if (state is HistoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  AppText(
                    state.message,
                    color: colorScheme.error,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<HistoryBloc>().add(const HistoryStarted()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (state is HistoryLoadSuccess) {
            if (state.captures.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      'No hay capturas en el historial',
                      variant: TextVariant.bodyLarge,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
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
    final projects = state.captures.map((e) => e.projectName).toSet().toList();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        unawaited(
          AppRouter.openViewer(
            imagePath: capturePath,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(capturePath),
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colorScheme.errorContainer,
                  child: Icon(Icons.broken_image, color: colorScheme.error),
                ),
              ),
              // Overlay de gradiente para legibilidad del nombre
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black26,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {
                      context.read<HistoryBloc>().add(
                        HistoryItemDeleted(capturePath: capturePath),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: AppText(
                  capturePath.split(Platform.pathSeparator).last,
                  variant: TextVariant.labelSmall,
                  color: Colors.white,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
