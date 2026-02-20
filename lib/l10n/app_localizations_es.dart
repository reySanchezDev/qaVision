// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'QAVision';

  @override
  String get settingsTitle => 'Configuración del Sistema';

  @override
  String get settingsRootFolder => 'Carpeta raíz de capturas';

  @override
  String get settingsSelectFolder => 'Seleccionar Carpeta';

  @override
  String get settingsFloatingButton => 'Botón flotante';

  @override
  String get settingsShowFloatingButton => 'Mostrar botón flotante';

  @override
  String get settingsStartWithWindows => 'Iniciar con Windows';

  @override
  String get settingsFloatingButtonColor => 'Color del botón flotante';

  @override
  String get settingsSaveFormat => 'Formato de guardado';

  @override
  String get settingsSaveFormatDescription =>
      'Todas las capturas se guardan como JPG (alta resolución).';

  @override
  String get settingsJpgQuality => 'Calidad JPG';

  @override
  String get settingsQualityHigh => 'Alta';

  @override
  String get settingsQualityMax => 'Máxima';

  @override
  String get settingsFileNameFormat => 'Formato de nombre de archivo';

  @override
  String get settingsFileNameMask => 'Máscara de nombre';

  @override
  String get settingsAfterCapture => 'Después de capturar';

  @override
  String get settingsSaveAndOpenViewer => 'Guardar y abrir visor';

  @override
  String get settingsSaveAndShowThumbnail => 'Guardar y mostrar miniatura (3s)';

  @override
  String get settingsSaveSilent =>
      'Guardar silencioso (sin visor ni miniatura)';

  @override
  String get settingsCopyToClipboard =>
      'Copiar automáticamente al portapapeles después de capturar';

  @override
  String get settingsHotkeys => 'Atajos de teclado';

  @override
  String get settingsHotkeyTraditional => 'Captura Tradicional';

  @override
  String get settingsHotkeyClipMode => 'Modo Clip ON/OFF';

  @override
  String get settingsHotkeyOpenViewer => 'Abrir Visor';

  @override
  String get settingsSaveConfig => 'Guardar configuración';

  @override
  String get settingsResetDefaults => 'Restablecer valores por defecto';

  @override
  String get settingsHotkeyConflict =>
      'Esta combinación ya está en uso. Elige otra.';

  @override
  String get settingsClipMode => 'Modo Clip';

  @override
  String get settingsClipLeftClick => 'Capturar solo clic izquierdo';

  @override
  String get settingsClipIgnoreScrollbar =>
      'Ignorar clic en barras de desplazamiento';

  @override
  String get settingsClipInterval => 'Capturar cada X segundos (intervalo)';

  @override
  String get settingsClipIntervalSeconds => 'Intervalo (segundos)';

  @override
  String get settingsViewer => 'Visor / Editor';

  @override
  String get settingsShowRecentStrip =>
      'Mostrar tira de \"Capturas recientes\" (últimas 5)';

  @override
  String get settingsShowSavedIndicator => 'Mostrar indicador \"Guardado\"';

  @override
  String get projectsTitle => 'Proyectos';

  @override
  String get projectsNewProject => 'Nuevo Proyecto';

  @override
  String get projectsCreate => 'Crear proyecto';

  @override
  String get projectsEdit => 'Editar proyecto';

  @override
  String get projectsName => 'Nombre del proyecto';

  @override
  String get projectsAlias => 'Alias corto (2–4 letras)';

  @override
  String get projectsColor => 'Color del proyecto';

  @override
  String get projectsSetDefault => 'Establecer como predeterminado';

  @override
  String get projectsCreateButton => 'Crear';

  @override
  String get projectsCancelButton => 'Cancelar';

  @override
  String get projectsEditButton => 'Editar';

  @override
  String get projectsOpenFolder => 'Abrir Carpeta';

  @override
  String get projectsSetDefaultButton => 'Establecer Predeterminado';

  @override
  String floatingButtonTooltip(String projectName) {
    return 'Proyecto activo: $projectName';
  }

  @override
  String get floatingPanelTitle => 'Capturas';

  @override
  String get floatingActiveProject => 'Proyecto activo';

  @override
  String get floatingChangeProject => 'Cambiar proyecto';

  @override
  String get floatingViewAllProjects => 'Ver todos los proyectos';

  @override
  String get floatingCreateProject => 'Crear nuevo proyecto';

  @override
  String get floatingCapture => 'Capturar';

  @override
  String get floatingClipMode => 'Modo Clip';

  @override
  String get floatingClipModeActive => 'Modo Clip activo';

  @override
  String get floatingOpenViewer => 'Abrir Visor';

  @override
  String get floatingOpenProjectFolder => 'Abrir carpeta del proyecto actual';

  @override
  String get floatingPostCapture => 'Comportamiento post-captura';

  @override
  String get floatingUseConfig => 'Usar configuración';

  @override
  String get viewerTitle => 'Editor de Captura';

  @override
  String get viewerAddImage => 'Agregar imagen al frame';

  @override
  String get viewerSaved => 'Guardado';

  @override
  String get viewerSelect => 'Seleccionar';

  @override
  String get viewerArrow => 'Flecha';

  @override
  String get viewerRectangle => 'Rectángulo';

  @override
  String get viewerCircle => 'Círculo';

  @override
  String get viewerHighlighter => 'Resaltador';

  @override
  String get viewerPencil => 'Lápiz';

  @override
  String get viewerText => 'Texto';

  @override
  String get viewerComment => 'Burbuja de comentario';

  @override
  String get viewerStepNumber => 'Numerador de pasos';

  @override
  String get viewerBlur => 'Blur';

  @override
  String get viewerEraser => 'Borrador';

  @override
  String get viewerUndo => 'Deshacer';

  @override
  String get viewerRedo => 'Rehacer';

  @override
  String get viewerColor => 'Color';

  @override
  String get viewerThickness => 'Grosor';

  @override
  String get viewerSize => 'Tamaño';

  @override
  String get firstUseMessage =>
      'Configura la carpeta raíz para comenzar a usar QAVision.';

  @override
  String get firstUseCancelWarning =>
      'Debes configurar una carpeta raíz para continuar.';
}
