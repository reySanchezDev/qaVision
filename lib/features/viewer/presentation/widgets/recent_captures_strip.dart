import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/domain/entities/viewer_entity.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';

/// Tira horizontal para navegar entre capturas recientes (§12.1).
class RecentCapturesStrip extends StatelessWidget {
  /// Crea una instancia de [RecentCapturesStrip].
  const RecentCapturesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: BlocBuilder<ViewerBloc, ViewerState>(
        builder: (context, state) {
          if (state.recentCaptures.isEmpty) {
            return const Center(
              child: Text(
                'No hay capturas recientes',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            itemCount: state.recentCaptures.length,
            itemBuilder: (context, index) {
              final path = state.recentCaptures[index];
              final isSelected = state.frame.elements
                  .whereType<ImageElement>()
                  .any((e) => e.path == path);

              return GestureDetector(
                onTap: () => _handleItemTap(context, path),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 200, // Optimización de memoria (§12.2)
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleItemTap(BuildContext context, String path) {
    // Si ya hay algo en el lienzo, preguntamos o permitimos añadir.
    // Para simplificar §7.0, por ahora si el lienzo no está vacío, añadimos.
    final state = context.read<ViewerBloc>().state;
    if (state.frame.elements.isEmpty) {
      context.read<ViewerBloc>().add(ViewerStarted(imagePath: path));
    } else {
      context.read<ViewerBloc>().add(
        ViewerImageAdded(
          imagePath: path,
          projectPath: File(path).parent.path,
        ),
      );
    }
  }
}
