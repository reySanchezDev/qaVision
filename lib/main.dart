import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/di/service_locator.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/navigation/app_routes.dart';
import 'package:qavision/core/storage/storage_service.dart';
import 'package:qavision/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:qavision/features/capture/presentation/services/capture_hotkey_service.dart';
import 'package:qavision/features/capture/presentation/widgets/capture_thumbnail_overlay.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_bloc.dart';
import 'package:qavision/features/floating_button/presentation/bloc/floating_button_event.dart';
import 'package:qavision/features/floating_button/presentation/pages/floating_button_page.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de dependencias
  setupServiceLocator();
  await sl<StorageService>().init();
  await sl<HotkeyService>().init();

  runApp(const QAVisionApp());
}

/// Widget raíz de la aplicación QAVision.
///
/// Configura el tema, localización y navegación globales.
class QAVisionApp extends StatelessWidget {
  /// Crea una instancia de [QAVisionApp].
  const QAVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ProjectBloc>()..add(const ProjectsLoaded()),
        ),
        BlocProvider(
          create: (_) =>
              sl<FloatingButtonBloc>()..add(const FloatingButtonStarted()),
        ),
        BlocProvider(
          create: (_) => sl<CaptureBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'QAVision',
        navigatorKey:
            AppRouter.navigatorKey, // Habilitar navegación global (§9.0)
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
          useMaterial3: true,
          fontFamily: 'Segoe UI',
        ),
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRoutes.settings,
        builder: (context, child) {
          return Stack(
            children: [
              ?child,
              const FloatingButtonWidget(),
              const CaptureThumbnailOverlay(),
            ],
          );
        },
      ),
    );
  }
}
