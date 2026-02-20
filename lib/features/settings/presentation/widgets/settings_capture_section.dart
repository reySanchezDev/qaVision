// RadioListTile.groupValue/onChanged deprecated en Flutter 3.32+.
// Se migrará a RadioGroup cuando la API estabilice.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qavision/core/widgets/app_card.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:qavision/core/widgets/app_text_field.dart';
import 'package:qavision/features/settings/domain/entities/settings_entity.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:qavision/features/settings/presentation/bloc/settings_event.dart';
import 'package:qavision/l10n/app_localizations.dart';

/// Sección de captura y formato (§4.3–§4.7).
class SettingsCaptureSection extends StatelessWidget {
  /// Crea una instancia de [SettingsCaptureSection].
  const SettingsCaptureSection({required this.settings, super.key});

  /// Configuración actual.
  final SettingsEntity settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §4.3–§4.4 Formato y calidad JPG
        AppCard(
          title: l10n.settingsSaveFormat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                l10n.settingsSaveFormatDescription,
              ),
              const SizedBox(height: 16),
              AppText(l10n.settingsJpgQuality, variant: TextVariant.bodyLarge),
              const SizedBox(height: 8),
              _QualityRadio(
                label: l10n.settingsQualityHigh,
                value: JpgQuality.high,
                groupValue: settings.jpgQuality,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(jpgQuality: v),
                ),
              ),
              _QualityRadio(
                label: l10n.settingsQualityMax,
                value: JpgQuality.max,
                groupValue: settings.jpgQuality,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(jpgQuality: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // §4.5 Máscara de nombre
        AppCard(
          title: l10n.settingsFileNameFormat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: l10n.settingsFileNameMask,
                hint: '{PROYECTO}_{NUMERO}',
                controller: TextEditingController(
                  text: settings.fileNameMask,
                ),
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(fileNameMask: v),
                ),
              ),
              const SizedBox(height: 8),
              const AppText(
                'Tokens: {PROYECTO}, {NUMERO}, {FECHA}, {HORA}',
                variant: TextVariant.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // §4.6 Comportamiento post-captura
        AppCard(
          title: l10n.settingsAfterCapture,
          child: Column(
            children: [
              _PostCaptureRadio(
                label: l10n.settingsSaveAndOpenViewer,
                value: PostCaptureAction.saveAndOpenViewer,
                groupValue: settings.postCaptureAction,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(postCaptureAction: v),
                ),
              ),
              _PostCaptureRadio(
                label: l10n.settingsSaveAndShowThumbnail,
                value: PostCaptureAction.saveAndShowThumbnail,
                groupValue: settings.postCaptureAction,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(postCaptureAction: v),
                ),
              ),
              _PostCaptureRadio(
                label: l10n.settingsSaveSilent,
                value: PostCaptureAction.saveSilent,
                groupValue: settings.postCaptureAction,
                onChanged: (v) => _update(
                  context,
                  settings.copyWith(postCaptureAction: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // §4.7 Copiar al portapapeles
        AppCard(
          child: CheckboxListTile(
            title: AppText(
              l10n.settingsCopyToClipboard,
            ),
            value: settings.copyToClipboard,
            onChanged: (v) => _update(
              context,
              settings.copyWith(copyToClipboard: v),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _update(BuildContext context, SettingsEntity updated) {
    context.read<SettingsBloc>().add(SettingsUpdated(updated));
  }
}

/// Radio button para calidad JPG.
class _QualityRadio extends StatelessWidget {
  const _QualityRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final JpgQuality value;
  final JpgQuality groupValue;
  final ValueChanged<JpgQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    // RadioListTile.groupValue/onChanged deprecated en Flutter 3.32+.
    // Se migrará a RadioGroup cuando la API estabilice.
    return RadioListTile<JpgQuality>(
      title: AppText(label),
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Radio button para acción post-captura.
class _PostCaptureRadio extends StatelessWidget {
  const _PostCaptureRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final PostCaptureAction value;
  final PostCaptureAction groupValue;
  final ValueChanged<PostCaptureAction> onChanged;

  @override
  Widget build(BuildContext context) {
    // RadioListTile.groupValue/onChanged deprecated en Flutter 3.32+.
    // Se migrará a RadioGroup cuando la API estabilice.
    return RadioListTile<PostCaptureAction>(
      title: AppText(label),
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
