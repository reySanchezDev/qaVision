import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';

/// BLoC que gestiona el estado y acciones del botón flotante (§3).
class FloatingButtonBloc
    extends Bloc<FloatingButtonEvent, FloatingButtonState> {
  /// Crea una instancia del [FloatingButtonBloc].
  FloatingButtonBloc({
    required IProjectRepository projectRepository,
    required CaptureBloc captureBloc,
  }) : _projectRepo = projectRepository,
       _captureBloc = captureBloc,
       super(const FloatingButtonState()) {
    on<FloatingButtonStarted>(_onStarted);
    on<FloatingButtonDragged>(_onDragged);
    on<FloatingButtonToggled>(_onToggled);
    on<FloatingButtonProjectChanged>(_onProjectChanged);
    on<FloatingButtonCaptureRequested>(_onCaptureRequested);
  }

  final IProjectRepository _projectRepo;
  final CaptureBloc _captureBloc;

  Future<void> _onStarted(
    FloatingButtonStarted event,
    Emitter<FloatingButtonState> emit,
  ) async {
    final project = await _projectRepo.getDefaultProject();
    emit(state.copyWith(activeProject: project));
  }

  void _onDragged(
    FloatingButtonDragged event,
    Emitter<FloatingButtonState> emit,
  ) {
    emit(state.copyWith(position: event.offset));
  }

  void _onToggled(
    FloatingButtonToggled event,
    Emitter<FloatingButtonState> emit,
  ) {
    emit(state.copyWith(isExpanded: !state.isExpanded));
  }

  void _onProjectChanged(
    FloatingButtonProjectChanged event,
    Emitter<FloatingButtonState> emit,
  ) {
    emit(state.copyWith(activeProject: event.project, isExpanded: false));
  }

  void _onCaptureRequested(
    FloatingButtonCaptureRequested event,
    Emitter<FloatingButtonState> emit,
  ) {
    final project = state.activeProject;
    if (project == null) return;

    // Delegar la captura al CaptureBloc
    _captureBloc.add(
      CaptureRequested(
        project: project,
        captureRegion: event.captureRegion,
      ),
    );

    // Ocultar panel después de capturar
    emit(state.copyWith(isExpanded: false));
  }
}
