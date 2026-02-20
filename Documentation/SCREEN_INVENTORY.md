# Inventario de Pantallas - QAVision

En este documento se registran todas las pantallas de la aplicación, su propósito y los componentes que las integran.

## Home Feature

### Pantalla: HomePage
- **Path**: `lib/main.dart` (Temporalmente, se moverá a `presentation/pages/`)
- **Propósito**: Pantalla de inicio para verificar la configuración de l10n y el Design System.
- **Componentes**: 
    - `AppText` (variante: `titleLarge`)
- **Reglas de Negocio Relacionadas**:
    - [Uso del Design System](BUSINESS_RULES.md#rule-uso-del-design-system-atomic-ui)
- **Notas**: Muestra el mensaje de "Hola Mundo" traducido.

---

### Pantalla: Storybook Home
- **Path**: `lib/main_storybook.dart`
- **Propósito**: Herramienta de desarrollo aislada para componentes.
- **Componentes**: 
    - `Storybook` base.
    - Catálogo de historias.
- **Notas**: Punto de entrada para el desarrollo visual.
