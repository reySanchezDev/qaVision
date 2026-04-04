import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_state.dart';

/// Bloc que controla estado y acciones de la pantalla flotante.
class FloatingButtonBloc
    extends Bloc<FloatingButtonEvent, FloatingButtonState> {
  /// Crea una instancia de [FloatingButtonBloc].
  FloatingButtonBloc({
    required IProjectRepository projectRepository,
    required ProjectBloc projectBloc,
    required CaptureBloc captureBloc,
  }) : _projectRepo = projectRepository,
       _projectBloc = projectBloc,
       _captureBloc = captureBloc,
       super(const FloatingButtonState()) {
    on<FloatingButtonStarted>(_onStarted);
    on<FloatingButtonDragged>(_onDragged);
    on<FloatingButtonProjectChanged>(_onProjectChanged);
    on<FloatingButtonQuickSlotFolderSelected>(_onQuickSlotFolderSelected);
    on<FloatingButtonCaptureRequested>(_onCaptureRequested);
    on<FloatingButtonCaptureModeChanged>(_onCaptureModeChanged);
    on<FloatingButtonSettingsUpdated>(_onSettingsUpdated);
    on<FloatingButtonProjectsSynced>(_onProjectsSynced);
    on<FloatingButtonClipSessionStarted>(_onClipSessionStarted);
    on<FloatingButtonClipSessionStopped>(_onClipSessionStopped);
    on<FloatingButtonRegionSelectionStarted>(_onRegionSelectionStarted);
    on<FloatingButtonRegionSelectionEnded>(_onRegionSelectionEnded);
    on<FloatingButtonVideoOverlayStarted>(_onVideoOverlayStarted);
    on<FloatingButtonVideoOverlayEnded>(_onVideoOverlayEnded);
    on<FloatingButtonVideoRecordingStarted>(_onVideoRecordingStarted);
    on<FloatingButtonVideoRecordingStopped>(_onVideoRecordingStopped);

    _projectSubscription = _projectBloc.stream.listen((projectState) {
      if (projectState is ProjectLoadSuccess) {
        add(FloatingButtonProjectsSynced(projectState.projects));
      }
    });
  }

  final IProjectRepository _projectRepo;
  final ProjectBloc _projectBloc;
  final CaptureBloc _captureBloc;

  StreamSubscription<ProjectState>? _projectSubscription;

  @override
  Future<void> close() async {
    await _projectSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    FloatingButtonStarted event,
    Emitter<FloatingButtonState> emit,
  ) async {
    final fromProjectBloc = _projectBloc.state;
    final projects = fromProjectBloc is ProjectLoadSuccess
        ? fromProjectBloc.projects
        : await _projectRepo.getProjects();

    final activeProject = _resolveActiveProject(
      projects,
      preferredId: state.activeProject?.id,
    );
    final quickIds = _reconcileQuickProjectIds(projects, state.quickProjectIds);

    emit(
      state.copyWith(
        projects: projects,
        activeProject: activeProject,
        clearActiveProject: activeProject == null,
        quickProjectIds: quickIds,
      ),
    );
  }

  void _onDragged(
    FloatingButtonDragged event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.isRegionSelecting) return;

    final dockResult = _dockToClosestEdge(
      desiredPosition: event.offset,
      bounds: event.screenBounds,
      currentEdge: state.dockEdge,
    );

    if (dockResult.position == state.position &&
        dockResult.edge == state.dockEdge) {
      return;
    }

    emit(
      state.copyWith(
        position: dockResult.position,
        dockEdge: dockResult.edge,
      ),
    );
  }

  void _onProjectChanged(
    FloatingButtonProjectChanged event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.projects.isEmpty) {
      emit(
        state.copyWith(
          clearActiveProject: true,
          quickProjectIds: const <String>[],
        ),
      );
      return;
    }

    final selectedProject = _resolveProjectFromState(event.project);

    emit(
      state.copyWith(
        activeProject: selectedProject,
      ),
    );
  }

  Future<void> _onQuickSlotFolderSelected(
    FloatingButtonQuickSlotFolderSelected event,
    Emitter<FloatingButtonState> emit,
  ) async {
    final folderPath = event.folderPath.trim();
    if (folderPath.isEmpty) return;

    final selected = await _projectRepo.addOrActivateFolder(folderPath);
    final projects = await _projectRepo.getProjects();

    if (projects.isEmpty) {
      emit(
        state.copyWith(
          projects: const <ProjectEntity>[],
          clearActiveProject: true,
          quickProjectIds: const <String>[],
        ),
      );
      return;
    }

    final selectedProject =
        _resolveProjectByPath(projects, folderPath) ??
        (selected == null
            ? null
            : _resolveActiveProject(projects, preferredId: selected.id)) ??
        _resolveActiveProject(projects, preferredId: state.activeProject?.id) ??
        projects.first;

    final quickIds = _assignProjectToSlot(
      projects: projects,
      currentQuickIds: state.quickProjectIds,
      selectedProjectId: selectedProject.id,
      slotIndex: event.slotIndex,
    );

    emit(
      state.copyWith(
        projects: projects,
        activeProject: selectedProject,
        quickProjectIds: quickIds,
      ),
    );
  }

  Future<void> _onCaptureRequested(
    FloatingButtonCaptureRequested event,
    Emitter<FloatingButtonState> emit,
  ) async {
    final project = _resolveCurrentProject();
    if (project == null) return;

    _dispatchCapture(
      project: project,
      captureRect: event.captureRect,
      forceSilent: false,
      restoreFloatingWindow: event.restoreFloatingWindow,
      windowAlreadyHidden: event.windowAlreadyHidden,
    );

    await _projectRepo.markProjectUsed(project.id);
    final projects = await _projectRepo.getProjects();
    final resolvedProject = _resolveActiveProject(
      projects,
      preferredId: project.id,
    );

    emit(
      state.copyWith(
        projects: projects,
        activeProject: resolvedProject,
        clearActiveProject: resolvedProject == null,
        quickProjectIds: _reconcileQuickProjectIds(
          projects,
          state.quickProjectIds,
        ),
      ),
    );
  }

  void _onCaptureModeChanged(
    FloatingButtonCaptureModeChanged event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.captureMode == event.mode) {
      if (state.isClipSessionActive && event.mode != FloatingCaptureMode.clip) {
        add(const FloatingButtonClipSessionStopped());
      }
      return;
    }

    if (state.isClipSessionActive && event.mode != FloatingCaptureMode.clip) {
      add(const FloatingButtonClipSessionStopped());
    }

    emit(state.copyWith(captureMode: event.mode));
  }

  void _onSettingsUpdated(
    FloatingButtonSettingsUpdated event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.isVisible == event.isVisible &&
        state.color == event.color &&
        state.position == event.position) {
      return;
    }

    emit(
      state.copyWith(
        isVisible: event.isVisible,
        color: event.color,
        position: event.position,
      ),
    );
  }

  void _onProjectsSynced(
    FloatingButtonProjectsSynced event,
    Emitter<FloatingButtonState> emit,
  ) {
    final projects = event.projects;

    if (projects.isEmpty) {
      if (state.isClipSessionActive) {
        add(const FloatingButtonClipSessionStopped());
      }
      emit(
        state.copyWith(
          projects: const <ProjectEntity>[],
          clearActiveProject: true,
          quickProjectIds: const <String>[],
        ),
      );
      return;
    }

    final activeProject = _resolveActiveProject(
      projects,
      preferredId: state.activeProject?.id,
    );

    final quickIds = _projectsToQuickIds(
      projects,
      currentQuickIds: state.quickProjectIds,
    );

    emit(
      state.copyWith(
        projects: projects,
        activeProject: activeProject,
        clearActiveProject: activeProject == null,
        quickProjectIds: quickIds,
      ),
    );
  }

  void _onClipSessionStopped(
    FloatingButtonClipSessionStopped event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.isClipSessionActive) {
      emit(state.copyWith(isClipSessionActive: false));
    }
  }

  void _onClipSessionStarted(
    FloatingButtonClipSessionStarted event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (!state.isClipSessionActive) {
      emit(state.copyWith(isClipSessionActive: true));
    }
  }

  void _onRegionSelectionStarted(
    FloatingButtonRegionSelectionStarted event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.isRegionSelecting) return;
    emit(state.copyWith(isRegionSelecting: true));
  }

  void _onRegionSelectionEnded(
    FloatingButtonRegionSelectionEnded event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (!state.isRegionSelecting) return;
    emit(state.copyWith(isRegionSelecting: false));
  }

  void _onVideoOverlayStarted(
    FloatingButtonVideoOverlayStarted event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (state.isVideoOverlayActive) return;
    emit(state.copyWith(isVideoOverlayActive: true));
  }

  void _onVideoOverlayEnded(
    FloatingButtonVideoOverlayEnded event,
    Emitter<FloatingButtonState> emit,
  ) {
    if (!state.isVideoOverlayActive) return;
    emit(state.copyWith(isVideoOverlayActive: false));
  }

  void _onVideoRecordingStarted(
    FloatingButtonVideoRecordingStarted event,
    Emitter<FloatingButtonState> emit,
  ) {
    emit(
      state.copyWith(
        position: event.position,
        isVideoRecordingHud: true,
        isVideoOverlayActive: false,
        isRegionSelecting: false,
      ),
    );
  }

  void _onVideoRecordingStopped(
    FloatingButtonVideoRecordingStopped event,
    Emitter<FloatingButtonState> emit,
  ) {
    emit(
      state.copyWith(
        position: event.position,
        isVideoRecordingHud: false,
        isVideoOverlayActive: false,
        isRegionSelecting: false,
      ),
    );
  }

  void _dispatchCapture({
    required ProjectEntity project,
    required bool forceSilent,
    required bool restoreFloatingWindow,
    required bool windowAlreadyHidden,
    Rect? captureRect,
  }) {
    _captureBloc.add(
      CaptureRequested(
        project: project,
        captureRect: captureRect,
        forceSilent: forceSilent,
        restoreFloatingWindow: restoreFloatingWindow,
        windowAlreadyHidden: windowAlreadyHidden,
      ),
    );
  }

  ProjectEntity _resolveProjectFromState(ProjectEntity project) {
    return state.projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );
  }

  ProjectEntity? _resolveCurrentProject() {
    if (state.projects.isEmpty) return null;

    final current = state.activeProject;
    if (current != null) {
      final index = state.projects.indexWhere((p) => p.id == current.id);
      if (index >= 0) return state.projects[index];
    }

    return _resolveActiveProject(state.projects);
  }

  ProjectEntity? _resolveActiveProject(
    List<ProjectEntity> projects, {
    String? preferredId,
  }) {
    if (projects.isEmpty) return null;

    if (preferredId != null) {
      final preferred = projects.where((p) => p.id == preferredId).toList();
      if (preferred.isNotEmpty) return preferred.first;
    }

    final defaults = projects.where((p) => p.isDefault).toList();
    return defaults.isNotEmpty ? defaults.first : projects.first;
  }

  ProjectEntity? _resolveProjectByPath(
    List<ProjectEntity> projects,
    String folderPath,
  ) {
    final normalized = _normalizePath(folderPath).toLowerCase();
    for (final project in projects) {
      if (_normalizePath(project.folderPath).toLowerCase() == normalized) {
        return project;
      }
    }
    return null;
  }

  List<String> _projectsToQuickIds(
    List<ProjectEntity> projects, {
    required List<String> currentQuickIds,
  }) {
    return _reconcileQuickProjectIds(projects, currentQuickIds);
  }

  List<String> _reconcileQuickProjectIds(
    List<ProjectEntity> projects,
    List<String> currentQuickIds,
  ) {
    final available = <String>{for (final project in projects) project.id};
    final result = <String>[];

    for (final id in currentQuickIds) {
      if (result.length >= kFloatingQuickAccessCount) break;
      if (id.isEmpty) continue;
      if (available.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }

    for (final project in projects) {
      if (result.length >= kFloatingQuickAccessCount) break;
      if (!result.contains(project.id)) {
        result.add(project.id);
      }
    }

    return result;
  }

  List<String> _assignProjectToSlot({
    required List<ProjectEntity> projects,
    required List<String> currentQuickIds,
    required String selectedProjectId,
    required int slotIndex,
  }) {
    final normalized = _reconcileQuickProjectIds(
      projects,
      currentQuickIds,
    ).toList(growable: true);

    while (normalized.length < kFloatingQuickAccessCount) {
      normalized.add('');
    }

    normalized.removeWhere((id) => id == selectedProjectId);
    while (normalized.length < kFloatingQuickAccessCount) {
      normalized.add('');
    }

    final clampedIndex = slotIndex.clamp(0, kFloatingQuickAccessCount - 1);
    normalized.insert(clampedIndex, selectedProjectId);

    while (normalized.length > kFloatingQuickAccessCount) {
      normalized.removeLast();
    }

    final seen = <String>{};
    for (var i = 0; i < normalized.length; i++) {
      final id = normalized[i];
      if (id.isEmpty) continue;
      if (!seen.add(id)) {
        normalized[i] = '';
      }
    }

    for (final project in projects) {
      if (seen.contains(project.id)) continue;
      final emptyIndex = normalized.indexWhere((id) => id.isEmpty);
      if (emptyIndex < 0) break;
      normalized[emptyIndex] = project.id;
      seen.add(project.id);
    }

    return normalized;
  }

  String _normalizePath(String path) {
    var normalized = path.trim().replaceAll(r'\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  _DockResult _dockToClosestEdge({
    required Offset desiredPosition,
    required Rect bounds,
    required FloatingDockEdge currentEdge,
  }) {
    final currentSize = _sizeForEdge(currentEdge);
    final clampedCurrent = _clampToBounds(
      desiredPosition: desiredPosition,
      size: currentSize,
      bounds: bounds,
    );

    final nearestEdge = _resolveNearestEdge(
      position: clampedCurrent,
      size: currentSize,
      bounds: bounds,
    );

    final targetSize = _sizeForEdge(nearestEdge);
    final reclamped = _clampToBounds(
      desiredPosition: clampedCurrent,
      size: targetSize,
      bounds: bounds,
    );

    final snapped = _snapPositionToEdge(
      position: reclamped,
      size: targetSize,
      bounds: bounds,
      edge: nearestEdge,
    );

    return _DockResult(position: snapped, edge: nearestEdge);
  }

  Size _sizeForEdge(FloatingDockEdge edge) {
    return edge.isVertical ? kFloatingVerticalSize : kFloatingHorizontalSize;
  }

  Offset _clampToBounds({
    required Offset desiredPosition,
    required Size size,
    required Rect bounds,
  }) {
    final minX = bounds.left;
    final minY = bounds.top;
    final maxX = math.max(minX, bounds.right - size.width);
    final maxY = math.max(minY, bounds.bottom - size.height);

    final x = desiredPosition.dx.clamp(minX, maxX);
    final y = desiredPosition.dy.clamp(minY, maxY);
    return Offset(x, y);
  }

  FloatingDockEdge _resolveNearestEdge({
    required Offset position,
    required Size size,
    required Rect bounds,
  }) {
    final leftDistance = (position.dx - bounds.left).abs();
    final rightDistance = (bounds.right - size.width - position.dx).abs();
    final topDistance = (position.dy - bounds.top).abs();

    final pairs = <MapEntry<FloatingDockEdge, double>>[
      MapEntry(FloatingDockEdge.left, leftDistance),
      MapEntry(FloatingDockEdge.right, rightDistance),
      MapEntry(FloatingDockEdge.top, topDistance),
    ];

    return (pairs..sort((a, b) => a.value.compareTo(b.value))).first.key;
  }

  Offset _snapPositionToEdge({
    required Offset position,
    required Size size,
    required Rect bounds,
    required FloatingDockEdge edge,
  }) {
    final minX = bounds.left;
    final minY = bounds.top;
    final maxX = math.max(minX, bounds.right - size.width);
    final maxY = math.max(minY, bounds.bottom - size.height);
    const peek = kFloatingDockPeek;

    return switch (edge) {
      FloatingDockEdge.left => Offset(
        minX - size.width + peek,
        position.dy.clamp(minY, maxY),
      ),
      FloatingDockEdge.right => Offset(
        bounds.right - peek,
        position.dy.clamp(minY, maxY),
      ),
      FloatingDockEdge.top => Offset(
        position.dx.clamp(minX, maxX),
        minY - size.height + peek,
      ),
      FloatingDockEdge.bottom => Offset(
        position.dx.clamp(minX, maxX),
        bounds.bottom - peek,
      ),
    };
  }
}

class _DockResult {
  const _DockResult({required this.position, required this.edge});

  final Offset position;
  final FloatingDockEdge edge;
}
