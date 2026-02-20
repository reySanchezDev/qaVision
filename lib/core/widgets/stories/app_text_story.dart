import 'package:flutter/material.dart';
import 'package:qavision/core/widgets/app_text.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

/// Historia para el widget [AppText].
Story appTextStory() => Story(
  name: 'Widgets/AppText',
  description: 'Widget de texto estandarizado del Design System.',
  builder: (context) {
    final text = context.knobs.text(
      label: 'Contenido',
      initial: 'Texto de prueba QAVision',
    );

    final variant = context.knobs.options(
      label: 'Variante',
      initial: TextVariant.bodyMedium,
      options: TextVariant.values
          .map(
            (v) => Option(
              label: v.name,
              value: v,
            ),
          )
          .toList(),
    );

    return Center(
      child: AppText(
        text,
        variant: variant,
      ),
    );
  },
);
