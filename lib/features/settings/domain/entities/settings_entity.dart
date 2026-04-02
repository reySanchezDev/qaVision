import 'package:equatable/equatable.dart';

/// Calidad de compresión JPG para las capturas.
enum JpgQuality {
  /// Calidad alta (85%).
  high,

  /// Calidad máxima (100%).
  max,
}

/// Comportamiento después de realizar una captura.
enum PostCaptureAction {
  /// Guardar y abrir el visor/editor.
  saveAndOpenViewer,

  /// Guardar y mostrar miniatura flotante por 3 segundos.
  saveAndShowThumbnail,

  /// Guardar silenciosamente sin abrir nada.
  saveSilent,
}

/// Entidad de configuración general del sistema.
///
/// Contiene todos los ajustes configurables definidos
/// en la pantalla de Configuración General (§4).
class SettingsEntity extends Equatable {
  /// Crea una instancia de [SettingsEntity].
  const SettingsEntity({
    this.rootFolder,
    this.showFloatingButton = true,
    this.startWithWindows = false,
    this.floatingButtonColor = 0xFF1E88E5,
    this.jpgQuality = JpgQuality.high,
    this.fileNameMask = '',
    this.postCaptureAction = PostCaptureAction.saveAndOpenViewer,
    this.copyToClipboard = true,
    this.hotkeyTraditional = 'Ctrl+Shift+S',
    this.hotkeyClipMode = 'Ctrl+Shift+C',
    this.hotkeyOpenViewer = 'Ctrl+Shift+V',
    this.clipLeftClickOnly = true,
    this.clipIgnoreScrollbar = true,
    this.clipIntervalEnabled = false,
    this.clipIntervalSeconds = 5,
    this.showRecentStrip = true,
    this.showSavedIndicator = true,
    this.viewerDefaultFrameBackgroundColor = 0xFFFFFFFF,
    this.viewerDefaultFrameBackgroundOpacity = 1.0,
    this.viewerDefaultFrameBorderColor = 0x33000000,
    this.viewerDefaultFrameBorderWidth = 1.0,
    this.viewerDefaultFramePadding = 0.0,
    this.lastX = 0,
    this.lastY = 100,
  });

  /// Ruta de la carpeta raíz de capturas (§4.1).
  /// `null` indica que no se ha configurado (primer uso).
  final String? rootFolder;

  /// Si el botón flotante está visible (§4.2).
  final bool showFloatingButton;

  /// Si la app inicia con Windows (§4.2).
  final bool startWithWindows;

  /// Color ARGB del botón flotante (§4.2).
  final int floatingButtonColor;

  /// Calidad de compresión JPG (§4.4).
  final JpgQuality jpgQuality;

  /// Máscara de nombre de archivo (§4.5).
  /// Si está vacía, se usa el formato por defecto YYYYMMDD_HHMMSS.
  final String fileNameMask;

  /// Comportamiento después de capturar (§4.6).
  final PostCaptureAction postCaptureAction;

  /// Si se copia automáticamente al portapapeles (§4.7).
  final bool copyToClipboard;

  /// Hotkey para captura tradicional (§4.8).
  final String hotkeyTraditional;

  /// Hotkey para modo clip ON/OFF (§4.8).
  final String hotkeyClipMode;

  /// Hotkey para abrir visor (§4.8).
  final String hotkeyOpenViewer;

  /// Modo clip: capturar solo clic izquierdo (§4.9).
  final bool clipLeftClickOnly;

  /// Modo clip: ignorar clic en barras de desplazamiento (§4.9).
  final bool clipIgnoreScrollbar;

  /// Modo clip: capturar por intervalo de tiempo (§4.9).
  final bool clipIntervalEnabled;

  /// Modo clip: intervalo en segundos (§4.9).
  final int clipIntervalSeconds;

  /// Si se muestra la tira de capturas recientes (§4.10).
  final bool showRecentStrip;

  /// Si se muestra el indicador de guardado (§4.10).
  final bool showSavedIndicator;

  /// Color por defecto del fondo del frame en visor.
  final int viewerDefaultFrameBackgroundColor;

  /// Opacidad por defecto del fondo del frame.
  final double viewerDefaultFrameBackgroundOpacity;

  /// Color por defecto del borde del frame.
  final int viewerDefaultFrameBorderColor;

  /// Grosor por defecto del borde del frame.
  final double viewerDefaultFrameBorderWidth;

  /// Padding interno por defecto del frame.
  final double viewerDefaultFramePadding;

  /// Última posición X del botón flotante (§H-012).
  final double lastX;

  /// Última posición Y del botón flotante (§H-012).
  final double lastY;

  /// Indica si la configuración de primer uso está completa.
  bool get isConfigured => rootFolder != null && rootFolder!.isNotEmpty;

  /// Calidad numérica JPG para el codificador.
  int get jpgQualityValue => jpgQuality == JpgQuality.max ? 100 : 85;

  /// Crea una copia con los campos especificados modificados.
  SettingsEntity copyWith({
    String? rootFolder,
    bool? showFloatingButton,
    bool? startWithWindows,
    int? floatingButtonColor,
    JpgQuality? jpgQuality,
    String? fileNameMask,
    PostCaptureAction? postCaptureAction,
    bool? copyToClipboard,
    String? hotkeyTraditional,
    String? hotkeyClipMode,
    String? hotkeyOpenViewer,
    bool? clipLeftClickOnly,
    bool? clipIgnoreScrollbar,
    bool? clipIntervalEnabled,
    int? clipIntervalSeconds,
    bool? showRecentStrip,
    bool? showSavedIndicator,
    int? viewerDefaultFrameBackgroundColor,
    double? viewerDefaultFrameBackgroundOpacity,
    int? viewerDefaultFrameBorderColor,
    double? viewerDefaultFrameBorderWidth,
    double? viewerDefaultFramePadding,
    double? lastX,
    double? lastY,
  }) {
    return SettingsEntity(
      rootFolder: rootFolder ?? this.rootFolder,
      showFloatingButton: showFloatingButton ?? this.showFloatingButton,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      floatingButtonColor: floatingButtonColor ?? this.floatingButtonColor,
      jpgQuality: jpgQuality ?? this.jpgQuality,
      fileNameMask: fileNameMask ?? this.fileNameMask,
      postCaptureAction: postCaptureAction ?? this.postCaptureAction,
      copyToClipboard: copyToClipboard ?? this.copyToClipboard,
      hotkeyTraditional: hotkeyTraditional ?? this.hotkeyTraditional,
      hotkeyClipMode: hotkeyClipMode ?? this.hotkeyClipMode,
      hotkeyOpenViewer: hotkeyOpenViewer ?? this.hotkeyOpenViewer,
      clipLeftClickOnly: clipLeftClickOnly ?? this.clipLeftClickOnly,
      clipIgnoreScrollbar: clipIgnoreScrollbar ?? this.clipIgnoreScrollbar,
      clipIntervalEnabled: clipIntervalEnabled ?? this.clipIntervalEnabled,
      clipIntervalSeconds: clipIntervalSeconds ?? this.clipIntervalSeconds,
      showRecentStrip: showRecentStrip ?? this.showRecentStrip,
      showSavedIndicator: showSavedIndicator ?? this.showSavedIndicator,
      viewerDefaultFrameBackgroundColor:
          viewerDefaultFrameBackgroundColor ??
          this.viewerDefaultFrameBackgroundColor,
      viewerDefaultFrameBackgroundOpacity:
          viewerDefaultFrameBackgroundOpacity ??
          this.viewerDefaultFrameBackgroundOpacity,
      viewerDefaultFrameBorderColor:
          viewerDefaultFrameBorderColor ?? this.viewerDefaultFrameBorderColor,
      viewerDefaultFrameBorderWidth:
          viewerDefaultFrameBorderWidth ?? this.viewerDefaultFrameBorderWidth,
      viewerDefaultFramePadding:
          viewerDefaultFramePadding ?? this.viewerDefaultFramePadding,
      lastX: lastX ?? this.lastX,
      lastY: lastY ?? this.lastY,
    );
  }

  @override
  List<Object?> get props => [
    rootFolder,
    showFloatingButton,
    startWithWindows,
    floatingButtonColor,
    jpgQuality,
    fileNameMask,
    postCaptureAction,
    copyToClipboard,
    hotkeyTraditional,
    hotkeyClipMode,
    hotkeyOpenViewer,
    clipLeftClickOnly,
    clipIgnoreScrollbar,
    clipIntervalEnabled,
    clipIntervalSeconds,
    showRecentStrip,
    showSavedIndicator,
    viewerDefaultFrameBackgroundColor,
    viewerDefaultFrameBackgroundOpacity,
    viewerDefaultFrameBorderColor,
    viewerDefaultFrameBorderWidth,
    viewerDefaultFramePadding,
    lastX,
    lastY,
  ];
}
