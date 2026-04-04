import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/di/service_locator.dart';
import 'package:qavision/core/services/video_recording_runtime_service.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_state.dart';
import 'package:qavision/features/capture/presentation/widgets/capture_thumbnail_overlay.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/floating_button/presentation/pages/floating_button_page.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Pantalla raiz permanente de la aplicacion QAVision.
///
/// Sirve como contenedor persistente de la pantalla flotante y
/// overlays globales. Las pantallas de configuracion,
/// proyectos, visor e historial se abren como dialogos
/// independientes desde aqui.
class ShellPage extends StatefulWidget {
  /// Crea una instancia de [ShellPage].
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage>
    with WindowListener, SingleTickerProviderStateMixin {
  bool _applyingWindowGeometry = false;
  bool _hoverExpanded = false;
  bool _nativeDragInProgress = false;
  Timer? _hoverCollapseTimer;
  int _topmostRefreshToken = 0;
  late final AnimationController _impactController;
  FloatingDockEdge? _impactEdge;

  @override
  void initState() {
    super.initState();
    _impactController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _impactEdge = null;
          });
        }
      });
    windowManager.addListener(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncDockingWithCurrentDisplay());
      _scheduleTopmostRefresh();
    });
  }

  @override
  void dispose() {
    _hoverCollapseTimer?.cancel();
    _topmostRefreshToken++;
    _impactController.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMove() {
    if (_applyingWindowGeometry || !mounted) {
      return;
    }
    if (sl<VideoRecordingRuntimeService>().isHudVisible) {
      return;
    }
    _hoverCollapseTimer?.cancel();
    if (_nativeDragInProgress) {
      return;
    }
    setState(() {
      _nativeDragInProgress = true;
      _hoverExpanded = true;
    });
  }

  @override
  Future<void> onWindowMoved() async {
    if (_applyingWindowGeometry || !mounted) {
      return;
    }
    if (sl<VideoRecordingRuntimeService>().isHudVisible) {
      return;
    }
    await _finalizeWindowDrag();
  }

  @override
  void onWindowBlur() {
    _scheduleTopmostRefresh();
  }

  @override
  void onWindowFocus() {
    _scheduleTopmostRefresh();
  }

  @override
  void onWindowResized() {
    _scheduleTopmostRefresh();
  }

  @override
  void onWindowRestore() {
    _scheduleTopmostRefresh();
  }

  @override
  Future<void> onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      return;
    }
    await windowManager.destroy();
  }

  Future<void> _syncDockingWithCurrentDisplay() async {
    if (!mounted) return;
    final videoRuntime = sl<VideoRecordingRuntimeService>();
    final isVideoRecording = videoRuntime.isRecording;
    final isVideoHudVisible = videoRuntime.isHudVisible;
    final floatingState = context.read<FloatingButtonBloc>().state;
    if (isVideoRecording ||
        isVideoHudVisible ||
        floatingState.isRegionSelecting ||
        floatingState.isVideoOverlayActive) {
      return;
    }

    final position = await windowManager.getPosition();
    final bounds = await _resolveDisplayBoundsForPosition(position);

    if (!mounted) return;
    context.read<FloatingButtonBloc>().add(
      FloatingButtonDragged(offset: position, screenBounds: bounds),
    );
  }

  Future<Rect> _resolveDisplayBoundsForPosition(Offset position) async {
    final displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      final display = await screenRetriever.getPrimaryDisplay();
      return _displayBounds(display);
    }

    final nearest = displays.reduce((best, candidate) {
      final bestDistance = _distanceToRect(position, _displayBounds(best));
      final candidateDistance = _distanceToRect(
        position,
        _displayBounds(candidate),
      );
      return candidateDistance < bestDistance ? candidate : best;
    });

    return _displayBounds(nearest);
  }

  Rect _displayBounds(Display display) {
    final origin = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  }

  double _distanceToRect(Offset point, Rect rect) {
    if (rect.contains(point)) {
      return 0;
    }

    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : point.dy > rect.bottom
        ? point.dy - rect.bottom
        : 0.0;
    return (dx * dx) + (dy * dy);
  }

  Future<void> _setHoverExpanded(bool value) async {
    if (!mounted || _nativeDragInProgress) {
      return;
    }

    final videoRuntime = sl<VideoRecordingRuntimeService>();
    final isVideoRecording = videoRuntime.isRecording;
    final isVideoHudVisible = videoRuntime.isHudVisible;
    final state = context.read<FloatingButtonBloc>().state;
    if (isVideoRecording ||
        isVideoHudVisible ||
        !state.isVisible ||
        state.isClipSessionActive ||
        state.isRegionSelecting ||
        state.isVideoOverlayActive) {
      return;
    }

    if (!value) {
      _hoverCollapseTimer?.cancel();
      _hoverCollapseTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || _nativeDragInProgress || !_hoverExpanded) {
          return;
        }
        unawaited(_setHoverExpandedNow(false));
      });
      return;
    }

    _hoverCollapseTimer?.cancel();
    if (_impactEdge != null) {
      _clearImpactVisual();
    }
    if (_hoverExpanded == value) {
      return;
    }

    await _setHoverExpandedNow(true);
  }

  Future<void> _setHoverExpandedNow(bool value) async {
    if (!mounted || _hoverExpanded == value || _nativeDragInProgress) {
      return;
    }

    final videoRuntime = sl<VideoRecordingRuntimeService>();
    final isVideoRecording = videoRuntime.isRecording;
    final isVideoHudVisible = videoRuntime.isHudVisible;
    final state = context.read<FloatingButtonBloc>().state;
    if (isVideoRecording || isVideoHudVisible) {
      return;
    }
    setState(() {
      _hoverExpanded = value;
    });

    await _applyWindowGeometry(state);
    if (!value) {
      _triggerDockImpact(state.dockEdge);
    }
  }

  Future<void> _applyWindowGeometry(FloatingButtonState state) async {
    final videoRuntime = sl<VideoRecordingRuntimeService>();
    if (videoRuntime.isHudVisible || videoRuntime.isRecording) {
      return;
    }
    _applyingWindowGeometry = true;
    try {
      await windowManager.setResizable(false);
      await windowManager.setMinimizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setMinimumSize(state.windowSize);
      await windowManager.setMaximumSize(state.windowSize);
      await windowManager.setSize(state.windowSize);
      await windowManager.setPosition(_effectiveWindowPosition(state));

      final isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show(inactive: true);
      }
      await _ensureFloatingWindowPriority();
    } finally {
      _applyingWindowGeometry = false;
    }
  }

  void _scheduleTopmostRefresh() {
    final token = ++_topmostRefreshToken;
    const refreshDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 140),
      Duration(milliseconds: 420),
    ];

    unawaited(() async {
      for (final delay in refreshDelays) {
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        if (!mounted || token != _topmostRefreshToken) {
          return;
        }
        await _ensureFloatingWindowPriority();
      }
    }());
  }

  Future<void> _ensureFloatingWindowPriority() async {
    if (!mounted) return;

    final videoRuntime = sl<VideoRecordingRuntimeService>();
    final isVideoRecording = videoRuntime.isRecording;
    final isVideoHudVisible = videoRuntime.isHudVisible;
    final state = context.read<FloatingButtonBloc>().state;
    if (isVideoRecording ||
        isVideoHudVisible ||
        !state.isVisible ||
        state.isClipSessionActive ||
        state.isRegionSelecting ||
        state.isVideoOverlayActive) {
      return;
    }

    final isVisible = await windowManager.isVisible();
    if (!isVisible) {
      return;
    }

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);

    final isFocused = await windowManager.isFocused();
    if (!isFocused) {
      await windowManager.show(inactive: true);
    }
  }

  void _collapseHoverExpansion() {
    _hoverCollapseTimer?.cancel();
    if (!_hoverExpanded || !mounted) {
      return;
    }
    setState(() {
      _hoverExpanded = false;
    });
  }

  void _handleWindowDragStarted() {
    if (!mounted) return;
    _hoverCollapseTimer?.cancel();
    _clearImpactVisual();
    setState(() {
      _nativeDragInProgress = true;
      _hoverExpanded = true;
    });
  }

  Future<void> _finalizeWindowDrag() async {
    if (!mounted) return;
    final floatingBloc = context.read<FloatingButtonBloc>();
    if (sl<VideoRecordingRuntimeService>().isHudVisible) {
      setState(() {
        _nativeDragInProgress = false;
        _hoverExpanded = false;
      });
      return;
    }
    await _syncDockingWithCurrentDisplay();
    if (!mounted) return;
    await Future<void>.delayed(Duration.zero);
    final dockEdge = floatingBloc.state.dockEdge;
    setState(() {
      _nativeDragInProgress = false;
      _hoverExpanded = false;
    });
    await _applyWindowGeometry(floatingBloc.state);
    _triggerDockImpact(dockEdge);
  }

  bool _shouldReduceMotion() {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.disableAnimations || media.accessibleNavigation;
  }

  void _triggerDockImpact(FloatingDockEdge edge) {
    if (_shouldReduceMotion()) {
      _clearImpactVisual();
      return;
    }

    _impactController.stop();
    setState(() {
      _impactEdge = edge;
    });
    unawaited(_impactController.forward(from: 0).orCancel);
  }

  void _clearImpactVisual() {
    _impactController.stop();
    if (_impactEdge == null) {
      return;
    }
    setState(() {
      _impactEdge = null;
    });
  }

  Offset _effectiveWindowPosition(FloatingButtonState state) {
    if (sl<VideoRecordingRuntimeService>().isHudVisible || !_hoverExpanded) {
      return state.position;
    }

    final size = state.windowSize;
    return switch (state.dockEdge) {
      FloatingDockEdge.left => Offset(
        state.position.dx + size.width - kFloatingDockPeek,
        state.position.dy,
      ),
      FloatingDockEdge.right => Offset(
        state.position.dx - size.width + kFloatingDockPeek,
        state.position.dy,
      ),
      FloatingDockEdge.top => Offset(
        state.position.dx,
        state.position.dy + size.height - kFloatingDockPeek,
      ),
      FloatingDockEdge.bottom => Offset(
        state.position.dx,
        state.position.dy - size.height + kFloatingDockPeek,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: BlocListener<FloatingButtonBloc, FloatingButtonState>(
        listenWhen: (previous, current) =>
            previous.isVisible != current.isVisible ||
            previous.position != current.position ||
            previous.dockEdge != current.dockEdge,
        listener: (context, state) async {
          final videoRuntime = sl<VideoRecordingRuntimeService>();
          final isVideoRecording = videoRuntime.isRecording;
          final isVideoHudVisible = videoRuntime.isHudVisible;
          if (!state.isVisible) {
            _collapseHoverExpansion();
            await windowManager.hide();
            return;
          }

          if (state.isClipSessionActive ||
              state.isRegionSelecting ||
              state.isVideoOverlayActive) {
            _collapseHoverExpansion();
            return;
          }

          if (isVideoRecording || isVideoHudVisible) {
            _collapseHoverExpansion();
            return;
          }

          await _applyWindowGeometry(state);
        },
        child: BlocListener<CaptureBloc, CaptureState>(
          listenWhen: (previous, current) =>
              previous is! CaptureInProgress && current is CaptureInProgress,
          listener: (_, current) {
            _collapseHoverExpansion();
          },
          child: MouseRegion(
            onEnter: (_) {
              unawaited(_setHoverExpanded(true));
            },
            onExit: (_) {
              unawaited(_setHoverExpanded(false));
            },
            child: Stack(
              children: [
                _FloatingWindowContent(
                  onDragStarted: _handleWindowDragStarted,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _impactController,
                      builder: (context, _) {
                        final edge = _impactEdge;
                        if (edge == null || _impactController.isDismissed) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: _DockImpactPainter(
                            edge: edge,
                            progress: _impactController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const CaptureThumbnailOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingWindowContent extends StatelessWidget {
  const _FloatingWindowContent({
    required this.onDragStarted,
  });

  final VoidCallback onDragStarted;

  @override
  Widget build(BuildContext context) {
    final isCapturing = context.select<CaptureBloc, bool>(
      (bloc) => bloc.state is CaptureInProgress,
    );
    return Offstage(
      offstage: isCapturing,
      child: FloatingButtonBody(
        onDragStarted: onDragStarted,
      ),
    );
  }
}

class _DockImpactPainter extends CustomPainter {
  const _DockImpactPainter({
    required this.edge,
    required this.progress,
  });

  final FloatingDockEdge edge;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = progress.clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(normalized);
    final fade = Curves.easeOutQuad.transform(1 - normalized);
    if (fade <= 0) {
      return;
    }

    final clip = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(28),
        ),
      );
    canvas
      ..save()
      ..clipPath(clip);

    _paintImpactBand(canvas, size, eased, fade);
    _paintImpactWaves(canvas, size, eased, fade);

    canvas.restore();
  }

  void _paintImpactBand(Canvas canvas, Size size, double eased, double fade) {
    final visibleSpan = _visibleSpan(size);
    final center = _impactCenter(size);
    final glowRadius = visibleSpan * (2.4 + ((1 - eased) * 0.8));
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xDDF8FDFF).withValues(alpha: 0.22 * fade),
          const Color(0x55DDF3FF).withValues(alpha: 0.16 * fade),
          const Color(0x00000000),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(
        Rect.fromCircle(center: center, radius: glowRadius),
      );

    canvas.drawCircle(center, glowRadius, glowPaint);
  }

  void _paintImpactWaves(Canvas canvas, Size size, double eased, double fade) {
    final visibleSpan = _visibleSpan(size);
    final center = _impactCenter(size);

    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFF8FDFF).withValues(alpha: 0.28 * fade);

    canvas.drawCircle(
      center,
      visibleSpan * (0.14 + ((1 - eased) * 0.08)),
      corePaint,
    );

    for (var i = 0; i < 3; i++) {
      final delay = i * 0.18;
      final waveProgress = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (waveProgress <= 0) {
        continue;
      }

      final waveEase = Curves.easeOutCubic.transform(waveProgress);
      final waveFade = (1 - waveEase) * fade;
      if (waveFade <= 0) {
        continue;
      }

      final radius = _waveRadius(size, visibleSpan, waveEase, i);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7 - (i * 0.2)
        ..color = const Color(0xFFF7FCFF).withValues(alpha: 0.72 * waveFade);

      canvas.drawCircle(center, radius, paint);
    }
  }

  double _visibleSpan(Size size) {
    return switch (edge) {
      FloatingDockEdge.left || FloatingDockEdge.right => kFloatingDockPeek,
      FloatingDockEdge.top => kFloatingDockPeek,
      FloatingDockEdge.bottom => 0,
    };
  }

  double _waveRadius(
    Size size,
    double visibleSpan,
    double waveEase,
    int index,
  ) {
    final baseExtent = switch (edge) {
      FloatingDockEdge.top => size.width * 0.18,
      FloatingDockEdge.left || FloatingDockEdge.right => size.height * 0.14,
      FloatingDockEdge.bottom => visibleSpan,
    };

    return (visibleSpan * 0.45) + (index * 9) + (waveEase * baseExtent);
  }

  Offset _impactCenter(Size size) {
    return switch (edge) {
      FloatingDockEdge.left => Offset(size.width + 3, size.height / 2),
      FloatingDockEdge.right => Offset(-3, size.height / 2),
      FloatingDockEdge.top => Offset(size.width / 2, size.height + 3),
      FloatingDockEdge.bottom => Offset(size.width / 2, -3),
    };
  }

  @override
  bool shouldRepaint(covariant _DockImpactPainter oldDelegate) {
    return oldDelegate.edge != edge || oldDelegate.progress != progress;
  }
}
