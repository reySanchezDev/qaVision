import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_card.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Sección de opciones del visor/editor (§4.10).
class SettingsViewerSection extends StatelessWidget {
  /// Crea una instancia de [SettingsViewerSection].
  const SettingsViewerSection({required this.settings, super.key});

  /// Configuración actual.
  final SettingsEntity settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      title: l10n.settingsViewer,
      child: Column(
        children: [
          CheckboxListTile(
            title: AppText(
              l10n.settingsShowRecentStrip,
            ),
            value: settings.showRecentStrip,
            onChanged: (v) => _update(
              context,
              settings.copyWith(showRecentStrip: v),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: AppText(
              l10n.settingsShowSavedIndicator,
            ),
            value: settings.showSavedIndicator,
            onChanged: (v) => _update(
              context,
              settings.copyWith(showSavedIndicator: v),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _update(BuildContext context, SettingsEntity updated) {
    context.read<SettingsBloc>().add(SettingsUpdated(updated));
  }
}
