# Backlog de Proyecto - QAVision

Este archivo contiene el historial completo de tareas, requerimientos y su estado de ejecución.

## Estado del Proyecto
- **Fase Actual**: Fase 5 – Visores y Edición.
- **Última Actualización**: 19/02/2026

---

## 📅 Historial de Tareas Completadas

### [2026-02-19] Inicialización del Cascarón
- [x] **Validación de Herramientas**: Confirmación de acceso a Dart MCP.
- [x] **Raíces del Proyecto**: Configuración de paths en el entorno.
- [x] **Creación de App**: `flutter create --empty --project-name qavision .`.
- [x] **Estándares de Código**: Configuración de `very_good_analysis` y `analysis_options.yaml`.
- [x] **Internationalization (l10n)**: Soporte ES/EN y configuración de generación.
- [x] **Design System Inicial**: Implementación de `AppText` (Atomic UI).
- [x] **Storybook**: Integración de `storybook_flutter` para desarrollo aislado.
- [x] **Estructura de Documentación**: Creación de `/Documentation` con `BUSINESS_RULES.md`, `SCREEN_INVENTORY.md` y `BACKLOG.md`.
- [x] **Inventario Atómico**: Creación de `UI_ATOMIC_INVENTORY.md` para control granular de objetos visuales.
- [x] **Análisis de Requerimiento**: Lectura y análisis completo de `Requerimiento_general.md` (675 líneas).
- [x] **Plan de Implementación**: Creación de plan cronológico en 6 fases.
- [x] **Fase 1 – Infraestructura Core**: DI (GetIt), StorageService (JSON), FileSystemService (JPG en isolate), ClipboardService, navegación, Design System (AppButton, AppTextField, AppCard, AppColorPicker), l10n ES/EN completo.
- [x] **Fase 2 – Configuración General**: Implementación completa de Settings (§4.1–§4.10) con Clean Architecture.
- [x] **Fase 3 – Gestión de Proyectos**: CRUD de proyectos, alias, colores y carpetas (§3.0).
- [x] **Fase 3b – Botón Flotante**: Implementación global, draggability y panel lateral (§9.0).
- [x] **Fase 4 – Captura Tradicional**: Captura nativa, guardado JPG en isolates y máscaras (§2.0).
- [x] **Fase 5 – Visor y Editor (Base)**: Implementación de `ViewerPage`, sistema de anotaciones vectoriales (flechas, formas, texto, blur, pasos), Undo/Redo, composición off-screen (`ViewerCompositionHelper`) y exportado a JPG (§9.1, §9.7).
- [x] **Fase 5 – Navegación y Tira**: Refactorización modular de componentes y tira de capturas recientes con lazy loading (§12.1, §5.0).

## Fase 5 – Visor / Editor (Completada) ✅
- [x] Carga y renderizado automático de imagen capturada (§9.2).
- [x] Implementar Visor Multi-imagen (§7.0).
- [x] Acciones de edición rápida: Copiado [x], Compartido [x].
- [x] Composición de múltiples imágenes y anotaciones vectoriales.

---

## Próximos Pasos (Fase 4 – Refactorización de Captura Profesional)
- [/] Crear `CaptureBloc` para centralizar la lógica (§4.0).
- [ ] Implementar `HotkeyService` para capturas nativas (PrintScreen, shortcuts).
- [ ] Implementar `CaptureThumbnailOverlay` (Miniatura premium post-captura).
- [ ] Desacoplar captura del `FloatingButtonBloc`.

## 📋 Backlog de Tareas Pendientes

### Configuración Core
- [ ] Implementar Inyección de Dependencias con `GetIt`.
- [ ] Configurar Logger global para la aplicación.
- [ ] Definir Theme detallado (Dark/Light mode).

### Funcionalidades (Features)
- [ ] *Por definir requerimiento inicial...*
