import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_state.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_capture_section.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_folder_section.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_hotkeys_section.dart';
import 'package:qavision/features/settings/presentation/widgets/settings_viewer_section.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Pantalla de Configuración General (§4).
///
/// Muestra todas las secciones de configuración del sistema.
/// Se abre obligatoriamente en el primer uso si no hay
/// carpeta raíz configurada.
class SettingsPage extends StatelessWidget {
  /// Crea una instancia de [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Ver Historial (§12)',
          ),
        ],
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
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
                  // Mensaje de primer uso (§4 regla)
                  if (!settings.isConfigured)
                    _FirstUseBanner(message: l10n.firstUseMessage),
                  const SizedBox(height: 8),

                  // §4.1 Carpeta raíz + §4.2 Botón flotante
                  SettingsFolderSection(settings: settings),
                  const SizedBox(height: 16),

                  // §4.3–§4.7 Captura y formato
                  SettingsCaptureSection(settings: settings),
                  const SizedBox(height: 16),

                  // §4.8–§4.9 Hotkeys y Modo Clip
                  SettingsHotkeysSection(settings: settings),
                  const SizedBox(height: 16),

                  // §4.10 Visor / Editor
                  SettingsViewerSection(settings: settings),
                ],
              ),
            );
          }

          // Estado inicial: disparar carga
          context.read<SettingsBloc>().add(const SettingsLoaded());
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

/// Banner de primer uso que obliga a configurar carpeta raíz.
class _FirstUseBanner extends StatelessWidget {
  const _FirstUseBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              message,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
