import 'package:flutter/material.dart';
import 'package:qavision/core/widgets/stories/app_text_story.dart';
import 'package:qavision/l10n/app_localizations.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

void main() => runApp(const StorybookApp());

/// Aplicación de Storybook para QAVision.
class StorybookApp extends StatelessWidget {
  /// Crea una instancia de [StorybookApp].
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Storybook(
      stories: [
        appTextStory(),
      ],
      wrapperBuilder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }
}
