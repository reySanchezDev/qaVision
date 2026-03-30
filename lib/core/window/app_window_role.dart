/// Roles de ventana soportados por QAVision.
enum AppWindowRole {
  /// Sistema completo con pantalla flotante y servicios.
  floating,

  /// Ventana de visor/editor.
  viewer,

  /// Ventana de configuracion.
  settings,

  /// Ventana de proyectos.
  projects,

  /// Ventana de historial.
  history,
}

/// Extensiones útiles para [AppWindowRole].
extension AppWindowRoleX on AppWindowRole {
  /// Valor CLI para lanzar la ventana.
  String get cliValue => switch (this) {
    AppWindowRole.floating => 'floating',
    AppWindowRole.viewer => 'viewer',
    AppWindowRole.settings => 'settings',
    AppWindowRole.projects => 'projects',
    AppWindowRole.history => 'history',
  };

  /// Puerto TCP de instancia unica para el rol.
  int get singleInstancePort => switch (this) {
    AppWindowRole.floating => 45901,
    AppWindowRole.viewer => 45902,
    AppWindowRole.settings => 45903,
    AppWindowRole.projects => 45904,
    AppWindowRole.history => 45905,
  };

  /// Titulo de ventana por defecto.
  String get windowTitle => switch (this) {
    AppWindowRole.floating => 'QAVision - Pantalla flotante',
    AppWindowRole.viewer => 'QAVision - Visor',
    AppWindowRole.settings => 'QAVision - Configuracion',
    AppWindowRole.projects => 'QAVision - Proyectos',
    AppWindowRole.history => 'QAVision - Historial',
  };
}

/// Parsea un rol desde string.
AppWindowRole parseAppWindowRole(String value) {
  return AppWindowRole.values.firstWhere(
    (role) => role.cliValue == value,
    orElse: () => AppWindowRole.floating,
  );
}
