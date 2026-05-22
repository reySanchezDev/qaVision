# Auditoria Tecnica 2026-05-22

## Validacion

- `flutter analyze --no-pub`: OK.
- `flutter test --concurrency 1`: OK, 88 tests.
- `flutter build windows --no-pub`: OK.

## Acciones Aplicadas

- BLoCs registrados como factories para evitar singletons cerrados por `BlocProvider`.
- Settings restaurado como pantalla funcional con `SettingsBloc`.
- Validacion serial documentada en `tool/validate.ps1`.
- FFmpeg consolidado en una sola ruta de empaquetado de Windows.
- Metadata y README actualizados para declarar QAVision como app Windows-first.

## Deuda Pendiente

- Refactor incremental de `floating_button_page.dart`, `viewer_bloc.dart` y `viewer_composition_helper.dart`.
- Persistencia de proyectos/settings aun basada en claves JSON completas; evaluar tablas dedicadas o merge transaccional por entidad.
- Las carpetas Android, iOS, macOS, Linux y Web siguen presentes por scaffolding Flutter, pero no son targets soportados por los flujos nativos actuales.
