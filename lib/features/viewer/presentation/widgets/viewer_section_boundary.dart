import 'package:flutter/material.dart';

/// Boundary visual para aislar fallos de una sección del visor.
class ViewerSectionBoundary extends StatefulWidget {
  /// Crea una instancia de [ViewerSectionBoundary].
  const ViewerSectionBoundary({
    required this.sectionName,
    required this.builder,
    this.fallbackHeight,
    super.key,
  });

  /// Nombre técnico de la sección.
  final String sectionName;

  /// Builder de la sección protegida.
  final WidgetBuilder builder;

  /// Alto opcional del fallback.
  final double? fallbackHeight;

  @override
  State<ViewerSectionBoundary> createState() => _ViewerSectionBoundaryState();
}

class _ViewerSectionBoundaryState extends State<ViewerSectionBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildFallback(context);
    }

    try {
      return widget.builder(context);
    } catch (error, stackTrace) {
      _error = error;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'viewer_section_boundary',
          context: ErrorDescription(
            'Error en seccion ${widget.sectionName}',
          ),
        ),
      );
      return _buildFallback(context);
    }
  }

  Widget _buildFallback(BuildContext context) {
    final content = Container(
      alignment: Alignment.center,
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Error en ${widget.sectionName}',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
            child: const Text('Reintentar seccion'),
          ),
        ],
      ),
    );

    final fallbackHeight = widget.fallbackHeight;
    if (fallbackHeight == null) return content;
    return SizedBox(height: fallbackHeight, child: content);
  }
}
