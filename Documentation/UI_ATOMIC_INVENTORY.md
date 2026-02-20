# Inventario Atómico de UI - QAVision

Este documento registra cada elemento visual de la aplicación para asegurar consistencia y cobertura total de internacionalización (l10n).

## 🧩 Componentes Base (Core Widgets)

| Componente | Tipo | l10n? | Storybook? | Descripción |
| :--- | :--- | :---: | :---: | :--- |
| `AppText` | Label/Text | ✅ | ✅ | Widget central para toda la tipografía. |

---

## 📱 Inventario por Pantalla

### Pantalla: HomePage
| Elemento | Tipo | ID/Key l10n | Estado | Notas |
| :--- | :--- | :--- | :---: | :--- |
| Título AppBar | AppText | N/A (Hardcoded "QAVision") | ⚠️ | Debería ser l10n. |
| Mensaje Central | AppText | `helloWorld` | ✅ | |

### Pantalla: Storybook
| Elemento | Tipo | ID/Key l10n | Estado | Notas |
| :--- | :--- | :--- | :---: | :--- |
| Panel Lateral | Plugins | N/A | ✅ | |
| Knobs | Controls | N/A | ✅ | Para pruebas dinámicas. |

---

## 🛠️ Guía de Auditoría
- **l10n**: ¿El texto proviene de `AppLocalizations.of(context)`?
- **Style**: ¿Usa una variante del Design System?
- **Storybook**: ¿Tiene una historia para pruebas aisladas?
