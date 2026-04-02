import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/config/app_defaults.dart';
import 'package:qavision/core/di/service_locator.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/navigation/shell_page.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/core/window/app_launch_request.dart';
import 'package:qavision/core/window/app_window_command.dart';
import 'package:qavision/core/window/app_window_role.dart';
import 'package:qavision/core/window/app_window_single_instance.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/constants/floating_window_metrics.dart';
import 'package:qavision/features/history/presentation/bloc/history_bloc.dart';
import 'package:qavision/features/history/presentation/pages/history_page.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/pages/project_list_page.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/pages/viewer_page.dart';
import 'package:qavision/l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:window_manager/window_manager.dart';

const _kWindowsRuntimeIconAsset = 'RECURSOS/app_icon.ico';

AppWindowSingleInstance? _singleInstanceLock;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final launchRequest = AppLaunchRequest.fromArgs(args);
  var viewerInitialImagePath = launchRequest.imagePath;
  final projectsOpenCreateController =
      launchRequest.role == AppWindowRole.projects
      ? StreamController<void>()
      : null;
  final viewerOpenImageController = launchRequest.role == AppWindowRole.viewer
      ? StreamController<String>()
      : null;

  await windowManager.ensureInitialized();

  final singleInstance = await AppWindowSingleInstance.acquireOrNotify(
    request: launchRequest,
    onCommand: (command) async {
      await _handleIncomingRoleCommand(
        command,
        role: launchRequest.role,
        projectsOpenCreateController: projectsOpenCreateController,
        onViewerImageRequested: (imagePath) {
          viewerInitialImagePath = imagePath;
          final controller = viewerOpenImageController;
          if (controller != null) {
            controller.add(imagePath);
          }
        },
      );
    },
  );

  if (singleInstance == null) {
    await projectsOpenCreateController?.close();
    await viewerOpenImageController?.close();
    return;
  }
  _singleInstanceLock = singleInstance;

  await _configureWindowForRole(launchRequest.role);

  setupServiceLocator();
  await sl<StorageService>().init();

  runApp(
    QAVisionRoleApp(
      launchRequest: launchRequest,
      projectsOpenCreateRequests: projectsOpenCreateController?.stream,
      viewerInitialImagePath: viewerInitialImagePath,
      viewerOpenImageRequests: viewerOpenImageController?.stream,
    ),
  );
}

Future<void> _handleIncomingRoleCommand(
  AppWindowCommand command, {
  required AppWindowRole role,
  StreamController<void>? projectsOpenCreateController,
  void Function(String imagePath)? onViewerImageRequested,
}) async {
  if (command.shutdown) {
    await _singleInstanceLock?.dispose();
    await windowManager.destroy();
    exit(0);
  }

  if (command.requestFocus) {
    await windowManager.show();
    await windowManager.focus();
  }

  if (role == AppWindowRole.projects && command.openCreateOnStart) {
    projectsOpenCreateController?.add(null);
  }

  if (role == AppWindowRole.viewer) {
    final imagePath = command.imagePath?.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      onViewerImageRequested?.call(imagePath);
    }
  }
}

Future<void> _configureWindowForRole(AppWindowRole role) async {
  if (role == AppWindowRole.floating) {
    const options = WindowOptions(
      size: kFloatingHorizontalSize,
      center: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setMinimizable(false);
      await windowManager.setMinimumSize(kFloatingHorizontalSize);
      await windowManager.setMaximumSize(kFloatingHorizontalSize);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setPreventClose(true);
      await windowManager.setIcon(_kWindowsRuntimeIconAsset);
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setTitle(role.windowTitle);
    });
    return;
  }

  const normalSize = Size(1200, 780);
  const options = WindowOptions(
    size: normalSize,
    center: true,
    backgroundColor: Colors.white,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    alwaysOnTop: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    final isViewer = role == AppWindowRole.viewer;

    await windowManager.setTitle(role.windowTitle);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setHasShadow(true);
    await windowManager.setResizable(true);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setPreventClose(false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setMinimumSize(const Size(900, 640));
    await windowManager.setMaximumSize(const Size(4000, 4000));
    await windowManager.setIcon(_kWindowsRuntimeIconAsset);
    if (!isViewer) {
      await windowManager.setSize(normalSize);
      await windowManager.center();
    }
    await windowManager.show();
    if (isViewer) {
      await windowManager.maximize();
    }
    await windowManager.focus();
  });
}

/// App raiz que se adapta al rol lanzado por argumentos.
class QAVisionRoleApp extends StatelessWidget {
  /// Crea [QAVisionRoleApp].
  const QAVisionRoleApp({
    required this.launchRequest,
    this.projectsOpenCreateRequests,
    this.viewerInitialImagePath,
    this.viewerOpenImageRequests,
    super.key,
  });

  /// Parametros de lanzamiento y rol actual.
  final AppLaunchRequest launchRequest;

  /// Solicitudes externas para abrir el modal de crear proyecto.
  final Stream<void>? projectsOpenCreateRequests;

  /// Imagen inicial a abrir en la ventana visor.
  final String? viewerInitialImagePath;

  /// Solicitudes externas para abrir una imagen en el visor.
  final Stream<String>? viewerOpenImageRequests;

  @override
  Widget build(BuildContext context) {
    return switch (launchRequest.role) {
      AppWindowRole.floating => const _FloatingRootApp(),
      AppWindowRole.settings => const _SettingsRootApp(),
      AppWindowRole.projects => _ProjectsRootApp(
        openCreateOnStart: launchRequest.openCreateOnStart,
        externalOpenCreateRequests: projectsOpenCreateRequests,
      ),
      AppWindowRole.viewer => _ViewerRootApp(
        imagePath: viewerInitialImagePath ?? launchRequest.imagePath,
        externalImageRequests: viewerOpenImageRequests,
      ),
      AppWindowRole.history => const _HistoryRootApp(),
    };
  }
}

class _FloatingRootApp extends StatelessWidget {
  const _FloatingRootApp();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ProjectBloc>()..add(const ProjectsLoaded()),
        ),
        BlocProvider(
          create: (_) =>
              sl<FloatingButtonBloc>()
                ..add(const FloatingButtonStarted())
                ..add(
                  const FloatingButtonSettingsUpdated(
                    isVisible: kDefaultShowFloatingButton,
                    color: kDefaultFloatingButtonColor,
                    position: Offset(
                      kDefaultFloatingLastX,
                      kDefaultFloatingLastY,
                    ),
                  ),
                ),
        ),
        BlocProvider(
          create: (_) => sl<CaptureBloc>(),
        ),
      ],
      child: const _BaseMaterialApp(
        home: ShellPage(),
      ),
    );
  }
}

class _SettingsRootApp extends StatelessWidget {
  const _SettingsRootApp();

  @override
  Widget build(BuildContext context) {
    return const _BaseMaterialApp(
      home: _SettingsRemovedPage(),
    );
  }
}

class _SettingsRemovedPage extends StatelessWidget {
  const _SettingsRemovedPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La configuracion persistida fue removida. '
            'Las capturas ahora se guardan por defecto en calidad maxima.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ProjectsRootApp extends StatelessWidget {
  const _ProjectsRootApp({
    required this.openCreateOnStart,
    this.externalOpenCreateRequests,
  });

  final bool openCreateOnStart;
  final Stream<void>? externalOpenCreateRequests;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProjectBloc>()..add(const ProjectsLoaded()),
      child: _BaseMaterialApp(
        home: ProjectListPage(
          openCreateOnStart: openCreateOnStart,
          externalOpenCreateRequests: externalOpenCreateRequests,
        ),
      ),
    );
  }
}

class _ViewerRootApp extends StatelessWidget {
  const _ViewerRootApp({
    required this.imagePath,
    this.externalImageRequests,
  });

  final String? imagePath;
  final Stream<String>? externalImageRequests;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ProjectBloc>()..add(const ProjectsLoaded()),
        ),
        BlocProvider(
          create: (_) => sl<ViewerBloc>(),
        ),
      ],
      child: _BaseMaterialApp(
        home: _ViewerWindowHost(
          initialImagePath: imagePath,
          externalImageRequests: externalImageRequests,
        ),
      ),
    );
  }
}

class _ViewerWindowHost extends StatefulWidget {
  const _ViewerWindowHost({
    required this.initialImagePath,
    this.externalImageRequests,
  });

  final String? initialImagePath;
  final Stream<String>? externalImageRequests;

  @override
  State<_ViewerWindowHost> createState() => _ViewerWindowHostState();
}

class _ViewerWindowHostState extends State<_ViewerWindowHost> {
  StreamSubscription<String>? _externalImageSubscription;
  String? _currentImagePath;

  @override
  void initState() {
    super.initState();
    _currentImagePath = _normalizePath(widget.initialImagePath);

    final initialPath = _currentImagePath;
    if (initialPath != null) {
      context.read<ViewerBloc>().add(_buildViewerStarted(initialPath));
    }

    final stream = widget.externalImageRequests;
    if (stream != null) {
      _externalImageSubscription = stream.listen(_openImage);
    }
  }

  @override
  void dispose() {
    unawaited(_externalImageSubscription?.cancel());
    super.dispose();
  }

  void _openImage(String rawPath) {
    final normalized = _normalizePath(rawPath);
    if (normalized == null || !mounted) return;

    setState(() {
      _currentImagePath = normalized;
    });
    context.read<ViewerBloc>().add(_buildViewerStarted(normalized));
  }

  ViewerStarted _buildViewerStarted(String imagePath) {
    return ViewerStarted(
      imagePath: imagePath,
      defaultFrameBackgroundColor: kDefaultViewerFrameBackgroundColor,
      defaultFrameBackgroundOpacity: kDefaultViewerFrameBackgroundOpacity,
      defaultFrameBorderColor: kDefaultViewerFrameBorderColor,
      defaultFrameBorderWidth: kDefaultViewerFrameBorderWidth,
      defaultFramePadding: kDefaultViewerFramePadding,
    );
  }

  String? _normalizePath(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return const ViewerPage();
  }
}

class _HistoryRootApp extends StatelessWidget {
  const _HistoryRootApp();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HistoryBloc>(),
      child: const _BaseMaterialApp(
        home: HistoryPage(),
      ),
    );
  }
}

class _BaseMaterialApp extends StatelessWidget {
  const _BaseMaterialApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppRouter.navigatorKey,
      title: 'QAVision',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        FlutterQuillLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: home,
    );
  }
}
