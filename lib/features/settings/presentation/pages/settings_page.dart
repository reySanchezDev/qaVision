import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/navigation/app_router.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_state.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_capture_section.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_folder_section.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_viewer_section.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Pantalla de Configuracion General.
class SettingsPage extends StatelessWidget {
  /// Crea una instancia de [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: AppText(
              l10n.settingsTitle,
              variant: TextVariant.titleLarge,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => unawaited(AppRouter.openHistory()),
                tooltip: 'Ver Historial (Â§12)',
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, SettingsState state) {
    if (state is SettingsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is SettingsError) {
      return Center(
        child: AppText(state.message, variant: TextVariant.bodyLarge),
      );
    }

    if (state is SettingsLoadSuccess) {
      final settings = state.settings;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsFolderSection(settings: settings),
            const SizedBox(height: 16),
            SettingsCaptureSection(settings: settings),
            const SizedBox(height: 16),
            SettingsViewerSection(settings: settings),
          ],
        ),
      );
    }

    context.read<SettingsBloc>().add(const SettingsLoaded());
    return const Center(child: CircularProgressIndicator());
  }
}
