# QAVision - Especificaciones Visor Pro

Fecha: 24/02/2026  
Objetivo: consolidar en un solo documento todos los requerimientos solicitados para dejar el visor en nivel "pro" y facilitar handoff a otro desarrollador.

---

## 1. Alcance

Este documento aplica a la pantalla del visor/editor y su comportamiento completo de interacción:

- composición visual por componentes tipo lego
- carga de captura seleccionada
- movimiento y redimensionamiento del frame de imagen
- zoom
- guardado de composición
- estabilidad post-reinicio

---

## 2. Componentes principales (solo visuales)

| Nombre del objeto | Para qué sirve |
|---|---|
| `VisorGeneralComponent` | Área total de trabajo del visor; define límites máximos para mover/redimensionar el frame. |
| `ImageFrameComponent` | Frame/contenedor de la captura seleccionada; se puede mover y redimensionar. |
| `ImageContentLayer` | Renderiza la imagen dentro del frame sin deformarla al redimensionar el frame. |
| `AnnotationOverlayLayer` | Renderiza herramientas/anotaciones encima del `ImageFrameComponent`. |
| `TopToolbarComponent` | Barra superior de herramientas y acciones (incluye guardado manual). |
| `ZoomControlsComponent` | Control de zoom del visor. |
| `RecentCapturesStripComponent` | Tira inferior de capturas recientes (si está activa). |

---

## 3. Requerimientos de arquitectura (modo lego)

1. El visor debe estar compuesto por piezas desacopladas (componentes independientes).
2. Cada componente debe exponer propiedades claras (props/configuración) y eventos.
3. Si falla un componente, no debe caerse toda la pantalla del visor.
4. Debe evitarse lógica monolítica concentrada en un único widget/clase.
5. `ImageElement` no se debe tratar como entidad suelta de UI: el núcleo visual debe ser `ImageFrameComponent` con contrato explícito.

---

## 4. Requerimientos funcionales críticos del `ImageFrameComponent`

### 4.1 Creación y carga

1. Al seleccionar una captura, se debe crear/cargar un `ImageFrameComponent`.
2. Ese frame debe contener la imagen seleccionada como contenido interno.

### 4.2 Movimiento (drag)

1. El frame debe moverse en cualquier dirección.
2. El movimiento debe funcionar de forma consistente (sin comportamiento intermitente).
3. El frame debe poder recorrer todo el espacio del `VisorGeneralComponent`.
4. El único límite de movimiento permitido es el borde del `VisorGeneralComponent`.
5. No debe existir una zona "recortada" o límite oculto que bloquee el arrastre antes del borde real.
6. Debe seguir funcionando después de cerrar y reabrir el visor.

### 4.3 Redimensionamiento (resize)

1. El frame debe redimensionarse hacia derecha, izquierda, arriba y abajo.
2. También debe redimensionarse desde esquinas.
3. Debe poder iniciarse resize desde cualquier punto del borde, no solo desde "puntos azules" fijos.
4. Los handles puntuales visibles (anclas azules rígidas) no deben ser el único mecanismo.
5. El único límite de resize permitido es el borde del `VisorGeneralComponent`.
6. No debe frenarse antes por colisiones/límites internos no deseados.
7. Debe seguir funcionando después de cerrar y reabrir el visor.

### 4.4 Relación frame vs imagen interna

1. Al redimensionar `ImageFrameComponent`, la imagen interna no debe escalarse automáticamente.
2. El resize debe afectar el frame/contenedor, no deformar la captura.
3. Si el frame queda más pequeño que la imagen, el contenido debe recortarse (clip), no estirarse.

### 4.5 Propiedades mínimas requeridas del componente

1. `position` (x, y)
2. `size` (width, height)
3. `minSize`
4. `maxBounds` (límite = `VisorGeneralComponent`)
5. `backgroundColor`
6. `backgroundOpacity`
7. `borderColor`
8. `borderWidth`
9. `padding`
10. `contentOffset` (si aplica encuadre interno)
11. `zoom` (integración con visor)
12. flags de bloqueo (`lockMove`, `lockResize`) si aplica

---

## 5. Requerimientos del `VisorGeneralComponent`

1. Debe ser el contenedor maestro de interacción.
2. `ImageFrameComponent` vive dentro de este contenedor.
3. Debe permitir aprovechar el mayor espacio posible para visualización.
4. La toolbar de herramientas debe permanecer arriba para liberar área útil del visor.

---

## 6. Requerimientos de guardado/exportación

1. Al guardar, debe exportarse el `ImageFrameComponent` completo como una sola imagen plana.
2. Deben incluirse en la imagen final las anotaciones/herramientas aplicadas sobre el frame.
3. No debe perderse contenido visual del frame al guardar.
4. Debe existir acción manual de guardado en la barra superior.
5. Para diagnóstico, el guardado automático debe poder desactivarse sin romper interacción.

---

## 7. Requerimientos de estabilidad

1. No se acepta comportamiento "a veces funciona / a veces no" en drag o resize.
2. No se acepta regresión del zoom al ajustar drag/resize.
3. El estado debe mantenerse estable al recargar captura y al reabrir visor.
4. Interacciones de puntero no deben bloquearse por tareas en background (ejemplo: guardado).

---

## 8. Criterios de aceptación (QA)

### AC-01 - Creación del frame

- Dado que el usuario abre una captura
- Cuando se carga en visor
- Entonces existe un `ImageFrameComponent` visible y seleccionable

### AC-02 - Movimiento completo

- Dado un frame seleccionado
- Cuando el usuario arrastra
- Entonces se mueve en cualquier dirección dentro de todo el `VisorGeneralComponent`

### AC-03 - Resize 4 lados + esquinas

- Dado un frame seleccionado
- Cuando el usuario inicia resize en cualquier punto del borde
- Entonces puede redimensionar en 4 lados y esquinas

### AC-04 - Sin escalado de imagen interna

- Dado un frame con captura
- Cuando se redimensiona el frame
- Entonces la imagen interna mantiene su escala original y solo se recorta/encuadra

### AC-05 - Límites correctos

- Dado un frame seleccionado
- Cuando se mueve o redimensiona
- Entonces solo se detiene al tocar borde real del `VisorGeneralComponent`

### AC-06 - Persistencia post-reinicio

- Dado que el usuario cierra y vuelve a abrir visor
- Cuando carga captura
- Entonces drag/resize/zoom siguen operativos sin degradación

### AC-07 - Guardado de composición

- Dado un frame con anotaciones
- Cuando el usuario guarda
- Entonces se genera una imagen plana con frame + overlays

---

## 9. Plan técnico recomendado para el nuevo dev

1. Separar claramente: `ViewerShell`, `VisorGeneralComponent`, `ImageFrameComponent`, `ImageContentLayer`, `AnnotationOverlayLayer`, `InteractionController`.
2. Centralizar hit-testing de drag/resize en un servicio dedicado.
3. Definir contrato de eventos de interacción (`start/update/end`) para drag y resize.
4. Persistir estado de frame y recargarlo sin alterar contratos de interacción.
5. Ejecutar pruebas manuales de estrés antes de entregar (no entregar sin validación propia).

---

## 10. Notas de implementación pedidas explícitamente

1. El componente clave se llama `ImageFrameComponent`.
2. Debe comportarse como un frame/canvas real, no como un objeto con anclas rígidas.
3. Debe ser fácil de escalar y mantener; cambios futuros no deben romper todo el visor.




revisa el archivo VISOR_PRO_ESPECIFICACIONES.md en Documentacion y revisa la pantalla del visor, centrate solo en esa pantalla tu mision serà dejarla funcional y operativo 100% se hiso un documento inicial que es VISOR_PRO_ESPECIFICACIONES.md  pero te doy la livertad para que lo analises y tomes la desiion de mejorarlo o hacer un refactor completo a esa pantalla y si tenes alguna observaciones para mejorar el visor o agregar mejoras tenes todo mi apoyo y aceptacion para hacerlo.