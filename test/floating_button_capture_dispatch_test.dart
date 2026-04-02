import 'package:flutter_test/flutter_test.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/native_screen_capture_service.dart';
import 'package:qavision/features/capture/domain/entities/capture_entity.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_state.dart';
import 'package:qavision/features/projects/domain/entities/project_entity.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/core/services/clipboard_service.dart';

class _InMemoryProjectRepository implements IProjectRepository {
  _InMemoryProjectRepository(this._projects);

  List<ProjectEntity> _projects;

  @override
  Future<ProjectEntity> createProject(ProjectEntity project) async {
    _projects = <ProjectEntity>[..._projects, project];
    return project;
  }

  @override
  Future<void> removeFolder(String folderPath) async {
    _projects.removeWhere((p) => p.folderPath == folderPath);
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
      );
      return _projects[index];
    }

    final next = ProjectEntity(
      id: 'p_$now',
      name: normalized.split('/').last,
      folderPath: normalized,
      alias: 'PRY',
      color: 0xFF1E88E5,
      isDefault: _projects.isEmpty,
      usageCount: 1,
      lastUsedAt: now,
    );
    if (_projects.length >= 3) {
      _projects = _projects.sublist(1);
    }
    _projects = <ProjectEntity>[..._projects, next];
    return next;
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
      _projects[index] = project;
    } else if (_projects.length < 3) {
      _projects = <ProjectEntity>[..._projects, project];
    } else {
      _projects[2] = project;
    }
    return project;
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

class _SpyCaptureBloc extends CaptureBloc {
  _SpyCaptureBloc()
    : super(
        captureService: CaptureService(
          fileSystemService: FileSystemService(),
          nativeCaptureService: NativeScreenCaptureService(),
        ),
        captureRepository: _InMemoryCaptureRepository(),
        clipboardService: ClipboardService(),
      );

  final List<CaptureRequested> capturedRequests = <CaptureRequested>[];

  @override
  void add(CaptureEvent event) {
    if (event is CaptureRequested) {
      capturedRequests.add(event);
    }
  }
}

Future<void> _drainQueue() async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  group('FloatingButtonBloc capture dispatch', () {
    late _InMemoryProjectRepository projectRepository;
    late ProjectBloc projectBloc;
    late _SpyCaptureBloc captureBloc;
    late FloatingButtonBloc floatingBloc;

    setUp(() {
      projectRepository = _InMemoryProjectRepository(
        const <ProjectEntity>[
          ProjectEntity(
            id: 'p1',
            name: 'General2',
            folderPath: 'C:/tmp/qavision/General2',
            alias: 'GEN',
            color: 0xFF1E88E5,
            isDefault: true,
          ),
        ],
      );

      projectBloc = ProjectBloc(repository: projectRepository);
      captureBloc = _SpyCaptureBloc();
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

    test('no fuerza modo silencioso en screen, region ni clip', () async {
      floatingBloc.add(const FloatingButtonStarted());
      await _drainQueue();

      for (final mode in FloatingCaptureMode.values) {
        captureBloc.capturedRequests.clear();
        floatingBloc.add(FloatingButtonCaptureModeChanged(mode));
        await _drainQueue();

        floatingBloc.add(const FloatingButtonCaptureRequested());
        await _drainQueue();

        expect(captureBloc.capturedRequests, hasLength(1));
        expect(
          captureBloc.capturedRequests.single.forceSilent,
          isFalse,
          reason: 'forceSilent debe quedar en false para modo $mode',
        );
      }
    });
  });
}
