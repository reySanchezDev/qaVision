import 'package:get_it/get_it.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/native_screen_capture_service.dart';
import 'package:qavision/core/services/share_service.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/capture/data/repositories/capture_repository.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/history/presentation/bloc/history_bloc.dart';
import 'package:qavision/features/projects/data/repositories/project_repository.dart';
import 'package:qavision/features/projects/data/services/project_folder_watch_service.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/viewer/data/services/viewer_document_persistence_service.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';

/// Instancia global de GetIt para inyeccion de dependencias.
final GetIt sl = GetIt.instance;

/// Configura la inyeccion de dependencias al iniciar la aplicacion.
void setupServiceLocator() {
  sl
    ..registerLazySingleton<StorageService>(StorageService.new)
    ..registerLazySingleton<FileSystemService>(FileSystemService.new)
    ..registerLazySingleton<NativeScreenCaptureService>(
      NativeScreenCaptureService.new,
    )
    ..registerLazySingleton<CaptureService>(
      () => CaptureService(
        fileSystemService: sl<FileSystemService>(),
        nativeCaptureService: sl<NativeScreenCaptureService>(),
      ),
    )
    ..registerLazySingleton<ClipboardService>(ClipboardService.new)
    ..registerLazySingleton<ShareService>(ShareService.new)
    ..registerLazySingleton<ViewerDocumentPersistenceService>(
      () => ViewerDocumentPersistenceService(
        fileSystemService: sl<FileSystemService>(),
      ),
    )
    ..registerLazySingleton<IProjectRepository>(
      () => ProjectRepository(
        storageService: sl<StorageService>(),
        fileSystemService: sl<FileSystemService>(),
      ),
    )
    ..registerLazySingleton<ProjectFolderWatchService>(
      ProjectFolderWatchService.new,
    )
    ..registerLazySingleton<ICaptureRepository>(
      () => CaptureRepository(storageService: sl<StorageService>()),
    )
    ..registerLazySingleton<ProjectBloc>(
      () => ProjectBloc(
        repository: sl<IProjectRepository>(),
        externalChanges: sl<StorageService>().changes,
        folderWatchService: sl<ProjectFolderWatchService>(),
      ),
    )
    ..registerLazySingleton<FloatingButtonBloc>(
      () => FloatingButtonBloc(
        projectRepository: sl<IProjectRepository>(),
        projectBloc: sl<ProjectBloc>(),
        captureBloc: sl<CaptureBloc>(),
      ),
    )
    ..registerLazySingleton<CaptureBloc>(
      () => CaptureBloc(
        captureService: sl<CaptureService>(),
        captureRepository: sl<ICaptureRepository>(),
      ),
    )
    ..registerLazySingleton<ViewerBloc>(
      () => ViewerBloc(
        fileSystemService: sl<FileSystemService>(),
        clipboardService: sl<ClipboardService>(),
        shareService: sl<ShareService>(),
        documentPersistenceService: sl<ViewerDocumentPersistenceService>(),
      ),
    )
    ..registerLazySingleton<HistoryBloc>(
      () => HistoryBloc(repository: sl<ICaptureRepository>()),
    );
}
