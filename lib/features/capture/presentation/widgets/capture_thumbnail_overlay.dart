import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/navigation/app_routes.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';

/// Overlay que muestra una miniatura de la captura reciente (§4.0, §9.1).
///
/// Implementa animaciones de entrada y salida automáticas.
class CaptureThumbnailOverlay extends StatefulWidget {
  /// Crea una instancia de [CaptureThumbnailOverlay].
  const CaptureThumbnailOverlay({super.key});

  @override
  State<CaptureThumbnailOverlay> createState() =>
      _CaptureThumbnailOverlayState();
}

class _CaptureThumbnailOverlayState extends State<CaptureThumbnailOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _autoCloseTimer;
  CaptureSuccess? _currentCapture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoClose() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _close();
    });
  }

  void _close() {
    _autoCloseTimer?.cancel();
    unawaited(
      _controller.reverse().then((_) {
        if (mounted) {
          context.read<CaptureBloc>().add(const CaptureResetRequested());
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CaptureBloc, CaptureState>(
      listener: (context, state) {
        if (state is CaptureSuccess) {
          setState(() => _currentCapture = state);
          unawaited(_controller.forward());
          _startAutoClose();
        } else if (state is CaptureIdle) {
          if (_controller.status == AnimationStatus.completed) {
            unawaited(
              _controller.reverse().then((_) {
                if (mounted) setState(() => _currentCapture = null);
              }),
            );
          } else {
            setState(() => _currentCapture = null);
          }
        }
      },
      child: _currentCapture == null
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  bottom: 100,
                  right: 20,
                  child: Transform.scale(
                    scale: _animation.value,
                    child: Opacity(
                      opacity: _animation.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: _ThumbnailCard(
                path: _currentCapture!.capture.path,
                onOpen: () {
                  _autoCloseTimer?.cancel();
                  context.read<CaptureBloc>().add(
                    const CaptureResetRequested(),
                  );
                  unawaited(
                    AppRouter.navigatorKey.currentState?.pushNamed(
                      AppRoutes.viewer,
                      arguments: _currentCapture!.capture.path,
                    ),
                  );
                },
                onClose: _close,
              ),
            ),
    );
  }
}

class _ThumbnailCard extends StatelessWidget {
  const _ThumbnailCard({
    required this.path,
    required this.onOpen,
    required this.onClose,
  });

  final String path;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: Image.file(
                  File(path),
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 32),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Abrir Editor'),
            ),
          ),
        ],
      ),
    );
  }
}
