import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_button.dart';
import 'package:qavision/core/widgets/app_card.dart';
import 'package:qavision/core/widgets/app_color_picker.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Sección de carpeta raíz y botón flotante (§4.1–§4.2).
class SettingsFolderSection extends StatelessWidget {
  /// Crea una instancia de [SettingsFolderSection].
  const SettingsFolderSection({required this.settings, super.key});

  /// Configuración actual.
  final SettingsEntity settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §4.1 Carpeta raíz
        AppCard(
          title: l10n.settingsRootFolder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo readonly con la ruta actual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppText(
                  settings.rootFolder ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l10n.settingsSelectFolder,
                icon: Icons.folder_open,
                onPressed: () => _selectFolder(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // §4.2 Botón flotante
        AppCard(
          title: l10n.settingsFloatingButton,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsCheckbox(
                label: l10n.settingsShowFloatingButton,
                value: settings.showFloatingButton,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(showFloatingButton: v),
                ),
              ),
              _SettingsCheckbox(
                label: l10n.settingsStartWithWindows,
                value: settings.startWithWindows,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(startWithWindows: v),
                ),
              ),
              const SizedBox(height: 12),
              AppColorPicker(
                label: l10n.settingsFloatingButtonColor,
                selectedColor: Color(settings.floatingButtonColor),
                onColorSelected: (color) => _update(
                  context,
                  settings.copyWith(
                    floatingButtonColor: color.toARGB32(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _update(BuildContext context, SettingsEntity updated) {
    context.read<SettingsBloc>().add(SettingsUpdated(updated));
  }

  /// Abre el selector de carpetas nativo.
  Future<void> _selectFolder(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null && context.mounted) {
      context.read<SettingsBloc>().add(
        SettingsRootFolderSelected(result),
      );
    }
  }
}

/// Checkbox reutilizable para la pantalla de configuración.
class _SettingsCheckbox extends StatelessWidget {
  const _SettingsCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: AppText(label),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}
