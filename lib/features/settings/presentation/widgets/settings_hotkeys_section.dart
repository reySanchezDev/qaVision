import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_button.dart';
import 'package:qavision/core/widgets/app_card.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/core/widgets/app_text_field.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Sección de hotkeys y modo clip (§4.8–§4.9).
class SettingsHotkeysSection extends StatelessWidget {
  /// Crea una instancia de [SettingsHotkeysSection].
  const SettingsHotkeysSection({required this.settings, super.key});

  /// Configuración actual.
  final SettingsEntity settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §4.8 Atajos de teclado
        AppCard(
          title: l10n.settingsHotkeys,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: l10n.settingsHotkeyTraditional,
                readOnly: true,
                controller: TextEditingController(
                  text: settings.hotkeyTraditional,
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: l10n.settingsHotkeyClipMode,
                readOnly: true,
                controller: TextEditingController(
                  text: settings.hotkeyClipMode,
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: l10n.settingsHotkeyOpenViewer,
                readOnly: true,
                controller: TextEditingController(
                  text: settings.hotkeyOpenViewer,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AppButton(
                    label: l10n.settingsSaveConfig,
                    onPressed: () {
                      // Por ahora los hotkeys son read-only.
                      // Se habilitarán en la Fase 4.
                    },
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: l10n.settingsResetDefaults,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _resetDefaults(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // §4.9 Modo Clip
        AppCard(
          title: l10n.settingsClipMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClipCheckbox(
                label: l10n.settingsClipLeftClick,
                value: settings.clipLeftClickOnly,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(clipLeftClickOnly: v),
                ),
              ),
              _ClipCheckbox(
                label: l10n.settingsClipIgnoreScrollbar,
                value: settings.clipIgnoreScrollbar,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(clipIgnoreScrollbar: v),
                ),
              ),
              _ClipCheckbox(
                label: l10n.settingsClipInterval,
                value: settings.clipIntervalEnabled,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(clipIntervalEnabled: v),
                ),
              ),
              if (settings.clipIntervalEnabled) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  child: AppTextField(
                    label: l10n.settingsClipIntervalSeconds,
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: settings.clipIntervalSeconds.toString(),
                    ),
                    onChanged: (v) {
                      final seconds = int.tryParse(v);
                      if (seconds != null && seconds > 0) {
                        _update(
                          context,
                          settings.copyWith(clipIntervalSeconds: seconds),
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _update(BuildContext context, SettingsEntity updated) {
    context.read<SettingsBloc>().add(SettingsUpdated(updated));
  }

  void _resetDefaults(BuildContext context) {
    _update(
      context,
      settings.copyWith(
        hotkeyTraditional: 'Ctrl+Shift+S',
        hotkeyClipMode: 'Ctrl+Shift+C',
        hotkeyOpenViewer: 'Ctrl+Shift+V',
      ),
    );
  }
}

/// Checkbox para opciones del modo clip.
class _ClipCheckbox extends StatelessWidget {
  const _ClipCheckbox({
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
