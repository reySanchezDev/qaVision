import 'package:flutter/material.dart';

/// Overlay visual cuando el visor no tiene elementos cargados.
class ViewerEmptyStateOverlay extends StatelessWidget {
  /// Crea una instancia de [ViewerEmptyStateOverlay].
  const ViewerEmptyStateOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xCC000000),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Text(
                'Selecciona una carpeta y abre una miniatura para editar',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
