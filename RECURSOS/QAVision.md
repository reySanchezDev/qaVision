# QAVision

QAVision es una herramienta de apoyo para equipos de Quality Assurance orientada a capturar evidencia visual, documentarla con contexto y organizarla de forma rápida dentro de un flujo de trabajo real.

Su enfoque combina tres necesidades clave del trabajo QA:

- capturar evidencia con rapidez
- enriquecer esa evidencia con anotaciones claras
- mantener organizada la información para compartirla, revisarla o usarla en documentación

## Qué ofrece esta versión

### 1. Captura de pantalla lista para trabajar

QAVision permite realizar capturas de pantalla con una ventana flotante siempre disponible, pensada para reducir fricción durante la ejecución de pruebas.

Capacidades disponibles:

- captura de pantalla completa
- captura por región seleccionada
- modo clip para capturas rápidas del flujo de trabajo
- copia automática al portapapeles después de capturar
- guardado directo en la carpeta activa del proyecto
- apertura inmediata en el visor cuando el flujo lo requiere

Las capturas nuevas se guardan en formato PNG, lo que mejora notablemente la nitidez de texto, bordes, iconos y elementos de interfaz.

### 2. Visor de evidencia con edición visual

El visor permite convertir una captura simple en evidencia clara y explicativa, sin salir del flujo de trabajo.

Herramientas disponibles:

- flechas
- rectángulos
- círculos
- comentarios
- texto
- panel de texto enriquecido
- numeradores o pasos visuales

El panel de texto enriquecido permite escribir descripciones extensas directamente sobre el área de trabajo, con opciones de formato como:

- negrita
- cursiva
- resaltado
- alineación
- color de texto
- color y grosor del borde del panel
- color de fondo del panel

Además, el visor permite:

- mover y redimensionar elementos
- trabajar con múltiples imágenes dentro del mismo lienzo
- organizar la composición por capas
- copiar el resultado al portapapeles
- guardar la imagen final para verla correctamente fuera del visor

### 3. Autosave y recuperación de sesión

QAVision protege el trabajo en curso mientras se edita una evidencia.

Esta versión ya incorpora:

- autoguardado de borrador
- recuperación de sesión al reabrir
- distinción visual entre borrador local y guardado final

Esto ayuda a reducir pérdida de trabajo cuando el usuario cierra accidentalmente o interrumpe una edición.

### 4. Organización por carpetas de trabajo

La aplicación permite manejar varias carpetas activas para organizar evidencias por contexto, módulo, cliente, ambiente o tipo de prueba.

Incluye:

- cinta de carpetas activas
- selección rápida de carpeta
- cambio de directorio por carpeta
- eliminación de carpeta desde su menú contextual
- límite controlado para mantener la interfaz ordenada

Dentro de cada carpeta activa, QAVision muestra las capturas recientes para facilitar:

- reabrir evidencia
- reutilizar capturas
- insertar imágenes dentro del visor

### 5. Grabación de video por zona seleccionada

QAVision ya incorpora grabación de video enfocada en capturar evidencia visual de un flujo dentro de un área específica de pantalla.

El flujo actual incluye:

- selección del modo video
- elección de grabación por zona
- cuenta regresiva `3, 2, 1`
- HUD de grabación con:
  - indicador de estado
  - tiempo transcurrido
  - pausa
  - detener
- guardado del video dentro de la carpeta activa

Esto permite documentar recorridos, fallos y validaciones dinámicas sin depender de herramientas externas para iniciar la evidencia.

### 6. Ventana flotante pensada para productividad

La ventana flotante de QAVision está pensada para permanecer accesible durante la prueba, sin obligar al usuario a navegar entre varias pantallas para capturar evidencia.

Características de esta versión:

- comportamiento flotante siempre visible
- acople a bordes de pantalla
- acceso rápido a modos de captura
- acceso rápido a modo video
- transición hacia HUD de grabación durante video

## Impacto para los equipos de QA

QAVision aporta valor directo al trabajo diario de pruebas porque reduce tiempo operativo y mejora la calidad de la evidencia.

### Beneficios prácticos

- acelera la toma de evidencia sin interrumpir el flujo de prueba
- mejora la claridad de los hallazgos mediante anotaciones visuales
- facilita explicar errores, validaciones y pasos funcionales
- reduce la dependencia de varias herramientas separadas
- ayuda a construir evidencia más útil para desarrolladores, líderes y usuarios de negocio
- disminuye retrabajo al permitir guardar borradores y recuperar sesiones
- mejora la presentación de reportes, tickets, documentos y conversaciones de seguimiento

### Valor para el proceso QA

Con QAVision, una captura deja de ser solo una imagen y se convierte en evidencia explicada, estructurada y lista para ser compartida.

Esto es especialmente útil para:

- reportes de bugs
- validaciones funcionales
- evidencia para aprobaciones
- documentación de pruebas
- soporte a despliegues
- comunicación con desarrollo, producto y negocio

## Resumen

Esta versión de QAVision ya entrega una base sólida para captura, documentación visual, edición de evidencia y grabación por zona, con un enfoque claro en productividad real para QA.

Su propuesta de valor está en permitir que el equipo se concentre más en analizar y comunicar hallazgos, y menos en pelear con herramientas dispersas o flujos lentos.

## Mejoras agregadas en esta versión

Para actualizar el descriptivo del producto en la página de descarga, estas son las mejoras nuevas ya incorporadas y disponibles para los usuarios:

### 1. Soporte multimonitor para captura por región

QAVision ahora permite seleccionar regiones de captura sobre el escritorio extendido completo, no solo sobre el monitor principal.

Esto permite:

- capturar una zona directamente en un monitor secundario
- arrastrar una selección que cruce más de un monitor
- trabajar de forma más natural en configuraciones de QA con dos o más pantallas

### 2. Mejor soporte multimonitor para grabación por zona

La grabación de video por zona ahora funciona mejor en ambientes con múltiples monitores.

Mejoras incluidas:

- selección de zona sobre varios monitores
- mejor posicionamiento de la ventana de opciones de grabación
- mejor posicionamiento de la HUD de grabación para que aparezca en el monitor correcto

### 3. Capturas con mejor fidelidad visual

Las capturas se guardan como PNG, lo que mejora la nitidez de:

- texto
- bordes
- iconos
- interfaces de usuario

Esto hace que la evidencia sea más útil para documentación, reportes y validaciones visuales.

### 4. Copia automática al portapapeles

Después de realizar una captura, la imagen queda disponible en el portapapeles para pegarla inmediatamente en herramientas como:

- WhatsApp
- Word
- editores de texto enriquecido
- tickets o plataformas de seguimiento

### 5. Mayor estabilidad de la ventana flotante

La ventana flotante ha sido reforzada para ofrecer una experiencia más consistente en uso real.

Esto incluye:

- mejor comportamiento al trabajar con capturas y video
- mejor control del foco para evitar interferencias con el teclado
- mejor manejo de estados para que la herramienta se mantenga estable durante la prueba

### 6. Mejoras en la gestión de carpetas de trabajo

Se fortaleció el flujo de selección de carpetas para que el usuario pueda organizar mejor la evidencia.

Mejoras incluidas:

- posibilidad de navegar a subcarpetas internas
- mejor comportamiento al cancelar la selección de carpeta
- gestión más estable de carpetas activas desde la ventana flotante
