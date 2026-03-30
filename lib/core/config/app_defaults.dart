import 'package:qavision/features/settings/domain/entities/settings_entity.dart';

/// Calidad fija de salida para todas las capturas.
const JpgQuality kDefaultJpgQuality = JpgQuality.max;

/// Mascara fija de nombres; vacia para usar el formato interno por defecto.
const String kDefaultFileNameMask = '';

/// Comportamiento fijo despues de guardar una captura.
const PostCaptureAction kDefaultPostCaptureAction =
    PostCaptureAction.saveSilent;

/// Indica si una captura debe copiarse al portapapeles.
const bool kDefaultCopyToClipboard = false;

/// Indica si el panel flotante arranca visible.
const bool kDefaultShowFloatingButton = true;

/// Color base fijo del panel flotante.
const int kDefaultFloatingButtonColor = 0xFF1E88E5;

/// Indica si el visor muestra la tira de recientes.
const bool kDefaultShowRecentStrip = true;

/// Indica si el visor muestra el estado de guardado.
const bool kDefaultShowSavedIndicator = true;

/// Fondo por defecto del frame del visor.
const int kDefaultViewerFrameBackgroundColor = 0xFFFFFFFF;

/// Opacidad por defecto del fondo del frame del visor.
const double kDefaultViewerFrameBackgroundOpacity = 1;

/// Color de borde por defecto del frame del visor.
const int kDefaultViewerFrameBorderColor = 0x33000000;

/// Grosor por defecto del borde del frame del visor.
const double kDefaultViewerFrameBorderWidth = 1;

/// Padding interno por defecto del frame del visor.
const double kDefaultViewerFramePadding = 0;

/// Posicion X inicial fija del panel flotante.
const double kDefaultFloatingLastX = 0;

/// Posicion Y inicial fija del panel flotante.
const double kDefaultFloatingLastY = 100;

/// Snapshot de defaults fijos de la aplicacion
/// sin persistencia de configuracion.
const SettingsEntity kAppDefaults = SettingsEntity(
  jpgQuality: kDefaultJpgQuality,
);
