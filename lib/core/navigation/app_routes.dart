/// Nombres de rutas de la aplicación QAVision.
///
/// Centraliza las constantes de navegación para evitar
/// strings hardcoded en los navegadores.
abstract class AppRoutes {
  /// Pantalla de configuración general (§4).
  static const String settings = '/settings';

  /// Pantalla de gestión de proyectos (§5).
  static const String projects = '/projects';

  /// Visor / Editor de capturas (§9).
  static const String viewer = '/viewer';

  /// Historial global de capturas (§12).
  static const String history = '/history';
}
