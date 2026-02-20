import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/di/service_locator.dart';
import 'package:qavision/core/navigation/app_routes.dart';
import 'package:qavision/features/history/presentation/bloc/history_bloc.dart';
import 'package:qavision/features/history/presentation/bloc/history_event.dart';
import 'package:qavision/features/history/presentation/pages/history_page.dart';
import 'package:qavision/features/projects/presentation/bloc/project_bloc.dart';
import 'package:qavision/features/projects/presentation/bloc/project_event.dart';
import 'package:qavision/features/projects/presentation/pages/project_list_page.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/features/settings/presentation/pages/settings_page.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_bloc.dart';
import 'package:qavision/features/viewer/presentation/bloc/viewer_event.dart';
import 'package:qavision/features/viewer/presentation/pages/viewer_page.dart';

/// Genera las rutas de la aplicación de forma centralizada.
class AppRouter {
  /// Navigator key global para acceder al contexto desde fuera de la UI.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Genera la ruta correspondiente a los [settings] dados.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.settings:
        return _buildRoute(
          BlocProvider(
            create: (_) => sl<SettingsBloc>()..add(const SettingsLoaded()),
            child: const SettingsPage(),
          ),
        );
      case AppRoutes.projects:
        return _buildRoute(
          BlocProvider(
            create: (_) => sl<ProjectBloc>()..add(const ProjectsLoaded()),
            child: const ProjectListPage(),
          ),
        );
      case AppRoutes.viewer:
        final imagePath = settings.arguments as String?;
        if (imagePath == null) return null;

        return _buildRoute(
          BlocProvider(
            create: (_) =>
                sl<ViewerBloc>()..add(ViewerStarted(imagePath: imagePath)),
            child: const ViewerPage(),
          ),
        );
      case AppRoutes.history:
        return _buildRoute(
          BlocProvider(
            create: (_) => sl<HistoryBloc>()..add(const HistoryStarted()),
            child: const HistoryPage(),
          ),
        );
      default:
        return null;
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(Widget page) {
    return MaterialPageRoute<dynamic>(builder: (_) => page);
  }
}
