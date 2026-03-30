import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/native_screen_capture_service.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';

class _InMemoryProjectRepository implements IProjectRepository {
  _InMemoryProjectRepository(this._projects);

  List<ProjectEntity> _projects;

  @override
  Future<ProjectEntity> createProject(ProjectEntity project) async {
    _projects = <ProjectEntity>[..._projects, project];
    return project;
  }

  @override
  Future<ProjectEntity?> addOrActivateFolder(String folderPath) async {
    final normalized = folderPath.trim();
    if (normalized.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final index = _projects.indexWhere((p) => p.folderPath == normalized);
    if (index >= 0) {
      final existing = _projects[index];
      _projects[index] = existing.copyWith(
        usageCount: existing.usageCount + 1,
        lastUsedAt: now,
        isDefault: true,
      );
      for (var i = 0; i < _projects.length; i++) {
        if (i == index) continue;
        _projects[i] = _projects[i].copyWith(isDefault: false);
      }
      return _projects[index];
    }

    final added = ProjectEntity(
      id: 'p_${now}_${_projects.length}',
      name: normalized.split('/').last,
      folderPath: normalized,
      alias: 'PRY',
      color: 0xFF1E88E5,
      isDefault: true,
      usageCount: 1,
      lastUsedAt: now,
    );
    if (_projects.length >= 3) {
      _projects.removeAt(_resolveLeastUsedIndex(_projects));
    }
    _projects = <ProjectEntity>[
      ..._projects.map((project) => project.copyWith(isDefault: false)),
      added,
    ];
    return added;
  }

  @override
  Future<ProjectEntity?> replaceProjectAt({
    required int slotIndex,
    required String folderPath,
  }) async {
    final normalized = folderPath.trim();
    if (normalized.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final project = ProjectEntity(
      id: 'slot_${slotIndex}_$now',
      name: normalized.split('/').last,
      folderPath: normalized,
      alias: 'PRY',
      color: 0xFF1E88E5,
      isDefault: _projects.isEmpty,
      usageCount: 1,
      lastUsedAt: now,
    );

    final index = slotIndex.clamp(0, 2);
    if (index < _projects.length) {
      final replacedDefault = _projects[index].isDefault;
      _projects[index] = project.copyWith(isDefault: replacedDefault);
    } else if (_projects.length < 3) {
      _projects.add(project);
    } else {
      _projects[2] = project;
    }

    if (_projects.where((item) => item.isDefault).isEmpty &&
        _projects.isNotEmpty) {
      _projects[0] = _projects[0].copyWith(isDefault: true);
    }
    return _projects[index.clamp(0, _projects.length - 1)];
  }

  @override
  Future<List<ProjectEntity>> reconcileWithDisk() async {
    return List<ProjectEntity>.from(_projects);
  }

  @override
  Future<void> markProjectUsed(String projectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _projects = _projects
        .map(
          (project) => project.id == projectId
              ? project.copyWith(
                  usageCount: project.usageCount + 1,
                  lastUsedAt: now,
                )
              : project,
        )
        .toList(growable: false);
  }

  @override
  Future<ProjectEntity?> getDefaultProject() async {
    if (_projects.isEmpty) return null;
    return _projects.firstWhere(
      (project) => project.isDefault,
      orElse: () => _projects.first,
    );
  }

  @override
  Future<List<ProjectEntity>> getProjects() async {
    return List<ProjectEntity>.from(_projects);
  }

  @override
  Future<void> setDefaultProject(String projectId) async {
    _projects = _projects
        .map((project) => project.copyWith(isDefault: project.id == projectId))
        .toList(growable: false);
  }

  @override
  Future<void> updateProject(ProjectEntity project) async {
    _projects = _projects
        .map((item) => item.id == project.id ? project : item)
        .toList(growable: false);
  }

  int _resolveLeastUsedIndex(List<ProjectEntity> projects) {
    var index = 0;
    for (var i = 1; i < projects.length; i++) {
      final current = projects[i];
      final candidate = projects[index];
      if (current.usageCount < candidate.usageCount) {
        index = i;
        continue;
      }
      if (current.usageCount == candidate.usageCount &&
          current.lastUsedAt < candidate.lastUsedAt) {
        index = i;
      }
    }
    return index;
  }
}

class _InMemoryCaptureRepository implements ICaptureRepository {
  final List<CaptureEntity> _captures = <CaptureEntity>[];

  @override
  Future<void> deleteCapture(String id) async {
    _captures.removeWhere((capture) => capture.id == id);
  }

  @override
  Future<List<CaptureEntity>> getHistory() async =>
      List<CaptureEntity>.from(_captures);

  @override
  Future<List<CaptureEntity>> getRecentCaptures({int limit = 10}) async {
    return _captures.take(limit).toList(growable: false);
  }

  @override
  Future<void> saveCapture(CaptureEntity capture) async {
    _captures.add(capture);
  }
}

Future<void> _drainQueue() async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  group('FloatingButtonBloc docking and project load', () {
    late _InMemoryProjectRepository projectRepository;
    late ProjectBloc projectBloc;
    late CaptureBloc captureBloc;
    late FloatingButtonBloc floatingBloc;

    setUp(() {
      projectRepository = _InMemoryProjectRepository(
        <ProjectEntity>[
          const ProjectEntity(
            id: 'p1',
            name: 'General2',
            folderPath: 'C:/tmp/qavision/General2',
            alias: 'GEN',
            color: 0xFF1E88E5,
            isDefault: true,
          ),
          const ProjectEntity(
            id: 'p2',
            name: 'Prestazo',
            folderPath: 'C:/tmp/qavision/Prestazo',
            alias: 'PRE',
            color: 0xFF43A047,
          ),
          const ProjectEntity(
            id: 'p3',
            name: 'Papeleria',
            folderPath: 'C:/tmp/qavision/Papeleria',
            alias: 'PAP',
            color: 0xFF00897B,
          ),
        ],
      );

      projectBloc = ProjectBloc(repository: projectRepository);
      captureBloc = CaptureBloc(
        captureService: CaptureService(
          fileSystemService: FileSystemService(),
          nativeCaptureService: NativeScreenCaptureService(),
        ),
        captureRepository: _InMemoryCaptureRepository(),
      );
      floatingBloc = FloatingButtonBloc(
        projectRepository: projectRepository,
        projectBloc: projectBloc,
        captureBloc: captureBloc,
      );
    });

    tearDown(() async {
      await floatingBloc.close();
      await projectBloc.close();
      await captureBloc.close();
    });

    test(
      'carga proyectos al iniciar aunque ProjectBloc aun no haya cargado',
      () async {
        floatingBloc.add(const FloatingButtonStarted());
        await _drainQueue();

        expect(floatingBloc.state.projects, isNotEmpty);
        expect(floatingBloc.state.activeProject?.id, 'p1');
        expect(floatingBloc.state.projects.length, 3);
        expect(floatingBloc.state.quickProjectIds.length, 3);
        expect(
          floatingBloc.state.quickProjectIds,
          containsAll(['p1', 'p2', 'p3']),
        );
      },
    );

    test('acopla al borde mas cercano al recibir drag', () async {
      floatingBloc.add(const FloatingButtonStarted());
      await _drainQueue();

      floatingBloc.add(
        const FloatingButtonDragged(
          offset: Offset(700, 400),
          screenBounds: Rect.fromLTWH(0, 0, 1280, 720),
        ),
      );
      await _drainQueue();

      expect(floatingBloc.state.dockEdge, FloatingDockEdge.right);
      expect(floatingBloc.state.position.dx, 1280 - kFloatingDockPeek);
      expect(floatingBloc.state.position.dy, 720 - kFloatingVerticalHeight);
    });

    test('acopla correctamente a izquierda, derecha y arriba', () async {
      floatingBloc.add(const FloatingButtonStarted());
      await _drainQueue();

      floatingBloc.add(
        const FloatingButtonDragged(
          offset: Offset(20, 350),
          screenBounds: Rect.fromLTWH(0, 0, 1280, 720),
        ),
      );
      await _drainQueue();
      expect(floatingBloc.state.dockEdge, FloatingDockEdge.left);
      expect(
        floatingBloc.state.position.dx,
        -kFloatingVerticalWidth + kFloatingDockPeek,
      );

      floatingBloc.add(
        const FloatingButtonDragged(
          offset: Offset(640, 10),
          screenBounds: Rect.fromLTWH(0, 0, 1280, 720),
        ),
      );
      await _drainQueue();
      expect(floatingBloc.state.dockEdge, FloatingDockEdge.top);
      expect(
        floatingBloc.state.position.dy,
        -kFloatingHorizontalHeight + kFloatingDockPeek,
      );

      floatingBloc.add(
        const FloatingButtonDragged(
          offset: Offset(300, 680),
          screenBounds: Rect.fromLTWH(0, 0, 1280, 720),
        ),
      );
      await _drainQueue();
      expect(floatingBloc.state.dockEdge, FloatingDockEdge.left);
      expect(
        floatingBloc.state.position.dx,
        -kFloatingVerticalWidth + kFloatingDockPeek,
      );
      expect(
        floatingBloc.state.position.dy,
        720 - kFloatingVerticalHeight,
      );
    });

    test('clip session inicia y se detiene al cambiar de modo', () async {
      floatingBloc.add(const FloatingButtonStarted());
      await _drainQueue();

      floatingBloc
        ..add(
          const FloatingButtonCaptureModeChanged(FloatingCaptureMode.clip),
        )
        ..add(const FloatingButtonClipSessionStarted());
      await _drainQueue();
      expect(floatingBloc.state.captureMode, FloatingCaptureMode.clip);
      expect(floatingBloc.state.isClipSessionActive, isTrue);

      floatingBloc.add(
        const FloatingButtonCaptureModeChanged(FloatingCaptureMode.region),
      );
      await _drainQueue();

      expect(floatingBloc.state.captureMode, FloatingCaptureMode.region);
      expect(floatingBloc.state.isClipSessionActive, isFalse);
    });
  });
}
