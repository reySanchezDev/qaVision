import 'dart:io';

import 'package:flutter/material.dart';

/// Tile de miniatura para capturas recientes.
class RecentStripThumbnailTile extends StatelessWidget {
  /// Crea una instancia de [RecentStripThumbnailTile].
  const RecentStripThumbnailTile({
    required this.path,
    required this.isSelected,
    required this.onOpen,
    required this.onInsert,
    super.key,
  });

  /// Ruta de la imagen.
  final String path;

  /// Estado de selección visual.
  final bool isSelected;

  /// Acción de abrir captura como principal.
  final VoidCallback onOpen;

  /// Acción de insertar captura al frame actual.
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    final tile = _RecentStripThumbnailTileBody(
      path: path,
      isSelected: isSelected,
      onOpen: onOpen,
      onInsert: onInsert,
    );

    return LongPressDraggable<String>(
      data: path,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 140,
          height: 92,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 260,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _RecentStripThumbnailTileBody extends StatelessWidget {
  const _RecentStripThumbnailTileBody({
    required this.path,
    required this.isSelected,
    required this.onOpen,
    required this.onInsert,
  });

  final String path;
  final bool isSelected;
  final VoidCallback onOpen;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.lightBlueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: onOpen,
                onDoubleTap: onInsert,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 220,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: onInsert,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
