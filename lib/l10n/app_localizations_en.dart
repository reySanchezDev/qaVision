// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QAVision';

  @override
  String get settingsTitle => 'System Settings';

  @override
  String get settingsRootFolder => 'Root capture folder';

  @override
  String get settingsSelectFolder => 'Select Folder';

  @override
  String get settingsFloatingButton => 'Floating button';

  @override
  String get settingsShowFloatingButton => 'Show floating button';

  @override
  String get settingsStartWithWindows => 'Start with Windows';

  @override
  String get settingsFloatingButtonColor => 'Floating button color';

  @override
  String get settingsSaveFormat => 'Save format';

  @override
  String get settingsSaveFormatDescription =>
      'All captures are saved as JPG (high resolution).';

  @override
  String get settingsJpgQuality => 'JPG Quality';

  @override
  String get settingsQualityHigh => 'High';

  @override
  String get settingsQualityMax => 'Maximum';

  @override
  String get settingsFileNameFormat => 'File name format';

  @override
  String get settingsFileNameMask => 'Name mask';

  @override
  String get settingsAfterCapture => 'After capture';

  @override
  String get settingsSaveAndOpenViewer => 'Save and open viewer';

  @override
  String get settingsSaveAndShowThumbnail => 'Save and show thumbnail (3s)';

  @override
  String get settingsSaveSilent => 'Save silently (no viewer or thumbnail)';

  @override
  String get settingsCopyToClipboard =>
      'Automatically copy to clipboard after capture';

  @override
  String get settingsHotkeys => 'Keyboard shortcuts';

  @override
  String get settingsHotkeyTraditional => 'Traditional Capture';

  @override
  String get settingsHotkeyClipMode => 'Clip Mode ON/OFF';

  @override
  String get settingsHotkeyOpenViewer => 'Open Viewer';

  @override
  String get settingsSaveConfig => 'Save configuration';

  @override
  String get settingsResetDefaults => 'Reset to defaults';

  @override
  String get settingsHotkeyConflict =>
      'This combination is already in use. Choose another.';

  @override
  String get settingsClipMode => 'Clip Mode';

  @override
  String get settingsClipLeftClick => 'Capture only left click';

  @override
  String get settingsClipIgnoreScrollbar => 'Ignore scrollbar clicks';

  @override
  String get settingsClipInterval => 'Capture every X seconds (interval)';

  @override
  String get settingsClipIntervalSeconds => 'Interval (seconds)';

  @override
  String get settingsViewer => 'Viewer / Editor';

  @override
  String get settingsShowRecentStrip =>
      'Show \"Recent captures\" strip (last 5)';

  @override
  String get settingsShowSavedIndicator => 'Show \"Saved\" indicator';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsNewProject => 'New Project';

  @override
  String get projectsCreate => 'Create project';

  @override
  String get projectsEdit => 'Edit project';

  @override
  String get projectsName => 'Project name';

  @override
  String get projectsAlias => 'Short alias (2–4 letters)';

  @override
  String get projectsColor => 'Project color';

  @override
  String get projectsSetDefault => 'Set as default';

  @override
  String get projectsCreateButton => 'Create';

  @override
  String get projectsCancelButton => 'Cancel';

  @override
  String get projectsEditButton => 'Edit';

  @override
  String get projectsOpenFolder => 'Open Folder';

  @override
  String get projectsSetDefaultButton => 'Set Default';

  @override
  String floatingButtonTooltip(String projectName) {
    return 'Active project: $projectName';
  }

  @override
  String get floatingPanelTitle => 'Captures';

  @override
  String get floatingActiveProject => 'Active project';

  @override
  String get floatingChangeProject => 'Change project';

  @override
  String get floatingViewAllProjects => 'View all projects';

  @override
  String get floatingCreateProject => 'Create new project';

  @override
  String get floatingCapture => 'Capture';

  @override
  String get floatingClipMode => 'Clip Mode';

  @override
  String get floatingClipModeActive => 'Clip Mode active';

  @override
  String get floatingOpenViewer => 'Open Viewer';

  @override
  String get floatingOpenProjectFolder => 'Open current project folder';

  @override
  String get floatingPostCapture => 'Post-capture behavior';

  @override
  String get floatingUseConfig => 'Use configuration';

  @override
  String get viewerTitle => 'Capture Editor';

  @override
  String get viewerAddImage => 'Add image to frame';

  @override
  String get viewerSaved => 'Saved';

  @override
  String get viewerSelect => 'Select';

  @override
  String get viewerArrow => 'Arrow';

  @override
  String get viewerRectangle => 'Rectangle';

  @override
  String get viewerCircle => 'Circle';

  @override
  String get viewerHighlighter => 'Highlighter';

  @override
  String get viewerPencil => 'Pencil';

  @override
  String get viewerText => 'Text';

  @override
  String get viewerComment => 'Comment bubble';

  @override
  String get viewerStepNumber => 'Step numberer';

  @override
  String get viewerBlur => 'Blur';

  @override
  String get viewerEraser => 'Eraser';

  @override
  String get viewerUndo => 'Undo';

  @override
  String get viewerRedo => 'Redo';

  @override
  String get viewerColor => 'Color';

  @override
  String get viewerThickness => 'Thickness';

  @override
  String get viewerSize => 'Size';

  @override
  String get firstUseMessage =>
      'Set up the root folder to start using QAVision.';

  @override
  String get firstUseCancelWarning =>
      'You must set up a root folder to continue.';
}
