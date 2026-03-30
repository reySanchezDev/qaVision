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
    final opacityPercent = (settings.viewerDefaultFrameBackgroundOpacity * 100)
        .round();

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
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: AppText(
              'Fondo por defecto de Frame',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _frameBackgroundOptions
                .map((color) {
                  final selected =
                      color == settings.viewerDefaultFrameBackgroundColor;
                  return InkWell(
                    onTap: () {
                      _update(
                        context,
                        settings.copyWith(
                          viewerDefaultFrameBackgroundColor: color,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Colors.lightBlueAccent
                              : Colors.black26,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const AppText('Opacidad'),
              Expanded(
                child: Slider(
                  divisions: 20,
                  value: settings.viewerDefaultFrameBackgroundOpacity.clamp(
                    0,
                    1,
                  ),
                  onChanged: (value) {
                    _update(
                      context,
                      settings.copyWith(
                        viewerDefaultFrameBackgroundOpacity: value,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 46,
                child: AppText(
                  '$opacityPercent%',
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _update(
                  context,
                  settings.copyWith(
                    viewerDefaultFrameBackgroundColor: 0xFFFFFFFF,
                    viewerDefaultFrameBackgroundOpacity: 1,
                    viewerDefaultFrameBorderColor: 0x33000000,
                    viewerDefaultFrameBorderWidth: 1,
                    viewerDefaultFramePadding: 0,
                  ),
                );
              },
              icon: const Icon(Icons.restore, size: 18),
              label: const AppText('Restaurar fondo por defecto'),
            ),
          ),
        ],
      ),
    );
  }

  void _update(BuildContext context, SettingsEntity updated) {
    context.read<SettingsBloc>().add(SettingsUpdated(updated));
  }

  static const List<int> _frameBackgroundOptions = [
    0xFFFFFFFF,
    0xFFF5F5F5,
    0xFFE3F2FD,
    0xFFE8F5E9,
    0xFFFFF3E0,
    0xFFFFEBEE,
    0x00000000,
  ];
}
