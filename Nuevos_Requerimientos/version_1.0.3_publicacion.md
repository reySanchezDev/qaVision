# QAVision 1.0.3

Documento de apoyo para actualizar la pagina del producto con las novedades de la version `1.0.3`.

## Resumen corto para publicar

QAVision 1.0.3 incorpora mejoras importantes en el flujo de capturas continuas en modo clip. Ahora el usuario puede seleccionar el area exacta a capturar, definir nombres personalizados para cada imagen y reutilizar un patron de nomenclatura automatica para el resto de la sesion. Tambien se mejoro la experiencia visual de las ventanas del flujo clip y se optimizo el cierre del sistema para evitar bloqueos por multiples clics.

## Texto sugerido para la pagina del producto

### Novedades de la version 1.0.3

Esta actualizacion mejora de forma significativa la experiencia de captura continua en modo clip. El flujo ahora permite trabajar con mayor precision, mejor organizacion de archivos y una interaccion mas clara para el usuario final.

### Mejoras incluidas

1. Seleccion de area para el modo clip

Antes, el modo clip podia incluir contenido no deseado cuando habia varios monitores activos. Ahora el usuario selecciona primero el area exacta que desea capturar y esa misma zona se utiliza durante la sesion de capturas continuas.

2. Ventana para nombrar la captura

Despues de seleccionar el area de trabajo, el sistema muestra una ventana dedicada para definir el nombre base de la captura antes de comenzar la toma continua.

3. Nomenclatura automatica para capturas consecutivas

El usuario puede indicar un patron de nombre para reutilizarlo en las siguientes capturas de la sesion. Ejemplos:

- `cafecaliente` + `1` genera `cafecaliente-1`, `cafecaliente-2`, `cafecaliente-3`
- `cafecaliente` + `1a` genera `cafecaliente-1a`, `cafecaliente-2a`, `cafecaliente-3a`
- `cafecaliente` + `A1` genera `cafecaliente-A1`, `cafecaliente-A2`, `cafecaliente-A3`

4. Opcion para omitir o cancelar

La ventana de nombrado ahora incluye opciones para:

- guardar el nombre indicado
- omitir el nombre personalizado y continuar con el nombre por defecto
- cancelar el flujo antes de iniciar la captura

Si el usuario omite y no escribe un nombre, el sistema muestra una alerta informando que la captura se guardara con el nombre por defecto.

5. Mejora visual del flujo clip

Se ajusto el tamano, contraste, enfoque y comportamiento de las ventanas asociadas al modo clip para que sean mas visibles, coherentes y faciles de usar en entornos Windows.

6. Aviso de finalizacion de capturas continuas

Cuando el usuario finaliza la sesion de capturas en modo clip, el sistema muestra una ventana de confirmacion para indicar que el proceso ha terminado correctamente. Esta ventana incluye boton `OK` y cierre automatico.

7. Reemplazo correcto de carpetas en la flotante

Se corrigio el comportamiento de los slots de carpetas en `FloatingButtonBody` para que, aun cuando ya existan tres carpetas visibles, el usuario pueda sustituir una por otra correctamente en equipos donde antes el reemplazo fallaba.

8. Cierre del sistema mas estable

Se optimizo el boton de cierre del sistema en la ventana flotante para reducir la demora al cerrar y evitar bloqueos cuando el usuario hace varios clics seguidos.

## Beneficios para el usuario final

- Mayor control sobre el area exacta que desea capturar.
- Mejor organizacion de las imagenes guardadas.
- Menos pasos manuales al trabajar con secuencias de capturas.
- Ventanas mas claras y mejor enfocadas durante el flujo.
- Mejor estabilidad al cerrar el sistema desde la barra flotante.

## Resumen tecnico de cambios

- Se rediseño el flujo del modo clip para seleccionar primero la region de captura.
- Se incorporo un dialogo de nombre y nomenclatura previa a la captura.
- Se agrego soporte para secuencias automaticas de nombres.
- Se mejoro el comportamiento de cierre y restauracion de ventanas durante la sesion clip.
- Se añadieron avisos de finalizacion del proceso.
- Se corrigio la sustitucion de carpetas en los slots rapidos de la flotante.
- Se optimizo el cierre general del sistema para evitar multiples ejecuciones simultaneas del apagado.

## Recomendacion de publicacion

Para la pagina del producto se recomienda destacar principalmente estos tres puntos:

- nuevo flujo de capturas continuas con seleccion de area
- nomenclatura automatica para series de capturas
- mejoras de estabilidad y experiencia en la ventana flotante

## Version

- Version publica: `1.0.3`
- Build interna: `1.0.3+4`
