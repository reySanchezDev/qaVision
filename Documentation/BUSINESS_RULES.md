# Registro de Reglas de Negocio - QAVision

Este documento es la **única fuente de verdad** para las reglas de negocio del proyecto. Cualquier cambio en la lógica o comportamiento debe quedar registrado aquí.

## Core / Inicialización

### Rule: Uso del Design System (Atomic UI)
- **Description**: Todos los componentes visuales deben ser construidos usando los widgets base definidos en `lib/core/widgets/`. Está prohibido usar widgets nativos de Flutter (como `Text`) directamente si existe una variante en el Design System.
- **Rationale**: Asegurar consistencia visual, facilitar cambios globales de estilo y permitir la visualización controlada en Storybook.
- **Example(s)**: Usar `AppText('hola', variant: TextVariant.bodyMedium)` en lugar de `Text('hola')`.
- **Edge cases**: Widgets de terceros que requieran `Text` deben ser envueltos en componentes del Design System si es posible.
- **Data impact**: N/A.
- **Notes**: Se utiliza `storybook_flutter` para validar estas reglas de forma aislada.

---

## Estructura de Documentación

Este directorio `Documentation/` contiene:
1. `BUSINESS_RULES.md`: Reglas de lógica y comportamiento.
2. `SCREEN_INVENTORY.md`: Registro y descripción de todas las pantallas de la aplicación.
3. `API_CONTRACTS.md`: Definición de integraciones y modelos de datos (a implementar).
