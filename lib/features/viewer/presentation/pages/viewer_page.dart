import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_state.dart';
import 'package:qavision/features/viewer/presentation/widgets/recent_captures_strip.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_canvas.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_properties_panel.dart';
import 'package:qavision/features/viewer/presentation/widgets/viewer_toolbar.dart';

/// Pantalla principal del visor y editor de capturas (§9).
class ViewerPage extends StatelessWidget {
  /// Crea una instancia de [ViewerPage].
  const ViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context),
      body: BlocBuilder<ViewerBloc, ViewerState>(
        builder: (context, state) {
          if (state.isLoading && state.frame.elements.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              const ViewerPropertiesPanel(),
              Expanded(
                child: Row(
                  children: [
                    const ViewerToolbar(),
                    Expanded(
                      child: ClipRect(
                        child: InteractiveViewer(
                          maxScale: 4,
                          minScale: 0.5,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio:
                                  state.frame.canvasSize.width /
                                  state.frame.canvasSize.height,
                              child: const ViewerCanvas(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const RecentCapturesStrip(),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Visor de Captura'),
      backgroundColor: Colors.grey[900],
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            context.read<ViewerBloc>().add(const ViewerCopyRequested());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Imagen copiada al portapapeles')),
            );
          },
          tooltip: 'Copiar al portapapeles',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            context.read<ViewerBloc>().add(const ViewerShareRequested());
          },
          tooltip: 'Compartir',
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            context.read<ViewerBloc>().add(const ViewerExportRequested());
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check),
          label: const Text('Finalizar'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
