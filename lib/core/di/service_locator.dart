import 'package:get_it/get_it.dart';
import 'package:qavision/core/services/capture_service.dart';
import 'package:qavision/core/services/clipboard_service.dart';
import 'package:qavision/core/services/file_system_service.dart';
import 'package:qavision/core/services/share_service.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/capture/data/repositories/capture_repository.dart';
import 'package:qavision/features/capture/domain/repositories/i_capture_repository.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/services/capture_hotkey_service.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/history/presentation/bloc/history_bloc.dart';
import 'package:qavision/features/projects/data/repositories/project_repository.dart';
import 'package:qavision/features/projects/domain/repositories/i_project_repository.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/settings/data/repositories/settings_repository.dart';
import 'package:qavision/features/settings/domain/repositories/i_settings_repository.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';

/// Instancia global de GetIt para inyección de dependencias.
final GetIt sl = GetIt.instance;

/// Configura la inyección de dependencias al iniciar la aplicación.
void setupServiceLocator() {
  // Core Services
  sl
    ..registerLazySingleton<StorageService>(StorageService.new)
    ..registerLazySingleton<FileSystemService>(FileSystemService.new)
    ..registerLazySingleton<CaptureService>(
      () => CaptureService(fileSystemService: sl<FileSystemService>()),
    )
    ..registerLazySingleton<ClipboardService>(ClipboardService.new)
    ..registerLazySingleton<ShareService>(ShareService.new)
    ..registerLazySingleton<HotkeyService>(
      () => HotkeyService(
        captureBloc: sl<CaptureBloc>(),
        projectBloc: sl<ProjectBloc>(),
      ),
    )
    // Data Sources / Repositories
    ..registerLazySingleton<ISettingsRepository>(
      () => SettingsRepository(storageService: sl<StorageService>()),
    )
    ..registerLazySingleton<IProjectRepository>(
      () => ProjectRepository(
        storageService: sl<StorageService>(),
        fileSystemService: sl<FileSystemService>(),
        settingsRepository: sl<ISettingsRepository>(),
      ),
    )
    ..registerLazySingleton<ICaptureRepository>(
      () => CaptureRepository(storageService: sl<StorageService>()),
    )
    // BLoCs
    ..registerFactory<SettingsBloc>(
      () => SettingsBloc(repository: sl<ISettingsRepository>()),
    )
    ..registerFactory<ProjectBloc>(
      () => ProjectBloc(repository: sl<IProjectRepository>()),
    )
    ..registerFactory<FloatingButtonBloc>(
      () => FloatingButtonBloc(
        projectRepository: sl<IProjectRepository>(),
        captureBloc: sl<CaptureBloc>(),
      ),
    )
    ..registerFactory<CaptureBloc>(
      () => CaptureBloc(
        captureService: sl<CaptureService>(),
        settingsRepository: sl<ISettingsRepository>(),
        captureRepository: sl<ICaptureRepository>(),
      ),
    )
    ..registerFactory<ViewerBloc>(
      () => ViewerBloc(
        fileSystemService: sl<FileSystemService>(),
        clipboardService: sl<ClipboardService>(),
        shareService: sl<ShareService>(),
      ),
    )
    ..registerFactory<HistoryBloc>(
      () => HistoryBloc(repository: sl<ICaptureRepository>()),
    );
}
