# REQUERIMIENTO GENERAL  
Sistema Profesional de Capturas para QA Funcionales  
Aplicación de Escritorio Windows – 100% Local

---

# 1. OBJETIVO DEL PROYECTO

Desarrollar una herramienta profesional de capturas de pantalla especializada para QA funcionales, enfocada exclusivamente en:

- Captura rápida y continua.
- Organización automática por proyectos (carpetas).
- Anotación visual avanzada mediante un kit de herramientas.
- Guardado automático en formato JPG de alta resolución.
- Flujo no intrusivo (no interrumpir al QA).
- Máxima productividad operativa.

Restricciones del sistema:

- No tendrá login.
- No usará nube.
- Funcionamiento 100% local.
- Carpeta raíz obligatoria.
- No incluir sistema de temas (Claro/Oscuro) en esta versión.

---

# 2. ESTRUCTURA DE CARPETAS

## 2.1 Carpeta Raíz Obligatoria

El sistema debe trabajar bajo una carpeta raíz única definida por el usuario en el primer uso.

Ejemplo:

Capturas_QA/
 ├── Prestazo/
 ├── SistemaVentas/
 ├── AppMobile/

Reglas obligatorias:

- Todas las capturas se guardan dentro del proyecto activo.
- Formato obligatorio: JPG.
- Alta resolución obligatoria.
- Nunca sobrescribir archivos existentes.
- Numeración automática ante conflicto de nombre.
- Los archivos originales nunca se eliminan automáticamente.

## 2.2 Proyectos y Subcarpetas

- Cada proyecto es una carpeta dentro de la carpeta raíz.
- El usuario puede crear subcarpetas manualmente dentro del proyecto (si desea ordenar por módulos, fechas, etc.).
- El sistema siempre guardará en el nivel raíz del proyecto (por defecto), a menos que el usuario haya seleccionado explícitamente una subcarpeta (si se implementa selección de subcarpeta como mejora futura; NO obligatoria en esta versión).

---

# 3. PANTALLAS Y COMPONENTES DEL SISTEMA

El sistema tendrá exactamente las siguientes pantallas/componentes visibles:

1. Pantalla de Configuración General
2. Pantalla de Gestión de Proyectos
3. Botón Flotante
4. Modo Captura (overlay/selector de área/ventana/pantalla)
5. Visor / Editor de Capturas

---

# 4. PANTALLA 1 – CONFIGURACIÓN GENERAL

Nombre: Configuración General  
Título visible: "Configuración del Sistema"

Regla de primer uso:
- Si el sistema detecta que es el primer uso (no existe carpeta raíz configurada), debe abrir esta pantalla obligatoriamente y bloquear el uso del resto del sistema hasta configurar carpeta raíz.

---

## 4.1 Carpeta Raíz

Texto visible:
"Carpeta raíz de capturas"

Campo (solo lectura):
[ Ruta actual configurada ]

Botón:
[ Seleccionar Carpeta ]

Comportamiento:
- Al presionar [ Seleccionar Carpeta ], se abre selector de carpeta.
- Al confirmar, se guarda la ruta y el sistema queda habilitado.
- Si el usuario cancela en primer uso, el sistema no permite continuar.

---

## 4.2 Botón Flotante

Texto visible:
"Botón flotante"

Opciones:
☐ Mostrar botón flotante  
☐ Iniciar con Windows  

Selector:
"Color del botón flotante"
[ Selector de color ]

Reglas:
- Si "Mostrar botón flotante" está desactivado, el botón flotante no aparece.
- El botón flotante debe ser movible libremente por el usuario.
- Al arrastrar: debe resaltar visualmente (estado “moviendo”).
- Al soltar: debe quedar visible en su nueva posición con un borde discreto.
- Debe recordar posición al cerrar y abrir el sistema.
- Debe mostrar el alias del proyecto activo (2–4 letras) dentro del botón.

---

## 4.3 Formato de Guardado de Imágenes (JPG)

Texto visible:
"Formato de guardado"

Texto fijo:
"Todas las capturas se guardan como JPG (alta resolución)."

---

## 4.4 Calidad JPG

Texto visible:
"Calidad JPG"

Selector:
( ) Alta  
( ) Máxima  

Reglas:
- Por defecto: Alta.
- Debe priorizar legibilidad de texto y elementos de UI en las capturas.
- La calidad debe aplicarse a todas las capturas y composiciones.

---

## 4.5 Formato de Nombre de Archivo

Título:
"Formato de nombre de archivo"

Texto visible:
"Máscara de nombre"

Campo editable:
[ Máscara de nombre ]

Tokens permitidos:
- {PROYECTO}
- {NUMERO}
- {FECHA}
- {HORA}

Ejemplos mostrados al usuario:
- {PROYECTO}_{NUMERO}
- {FECHA}_{HORA}
- Prestazo_{NUMERO}

Reglas:
- Si el usuario no define máscara, usar por defecto:
  YYYYMMDD_HHMMSS
- {NUMERO} es secuencial por proyecto (si la máscara lo usa).
- Si el nombre resultante ya existe, incrementar automáticamente {NUMERO} hasta encontrar uno libre.
- No permitir caracteres inválidos para Windows en el nombre final.

---

## 4.6 Comportamiento Después de Capturar (Elegir 1)

Título:
"Después de capturar"

Selector único (radio):
( ) Guardar y abrir visor  
( ) Guardar y mostrar miniatura (3s)  
( ) Guardar silencioso (sin visor ni miniatura)

Reglas:
- El usuario debe elegir 1 opción.
- Aplica únicamente en Modo Tradicional.
- En Modo Clip, esta configuración se ignora (Modo Clip fuerza guardado silencioso).

---

## 4.7 Copiar al Portapapeles

Checkbox:
☐ Copiar automáticamente al portapapeles después de capturar

Reglas:
- Siempre guardar el archivo JPG primero.
- Luego copiar la imagen al portapapeles.
- Aplica en modo tradicional y modo clip.
- No debe interferir con el guardado en disco.

---

## 4.8 Atajos de Teclado (Hotkeys Globales)

Título:
"Atajos de teclado"

Campos configurables:

Captura Tradicional:
[ Tecla configurable ]

Modo Clip ON/OFF:
[ Tecla configurable ]

Abrir Visor:
[ Tecla configurable ]

Botón:
[ Guardar configuración ]

### 4.8.1 Reglas Obligatorias

- Los atajos deben funcionar a nivel sistema (globales).
- Deben ejecutarse aunque la aplicación no tenga foco.
- Deben funcionar con aplicaciones en pantalla completa.
- Deben funcionar en múltiples monitores.
- No deben depender del foco de ventana.

### 4.8.2 Validación de Conflictos

- Si la combinación ya está en uso dentro del sistema → mostrar mensaje:
  "Esta combinación ya está en uso. Elige otra."
- No permitir guardar combinaciones en conflicto.
- Incluir botón:
  [ Restablecer valores por defecto ]

Valores por defecto sugeridos:
- Captura Tradicional: Ctrl + Shift + S  
- Modo Clip ON/OFF: Ctrl + Shift + C  
- Abrir Visor: Ctrl + Shift + V  

### 4.8.3 Limitaciones Declaradas

- En aplicaciones que capturen completamente el teclado (ejemplo: máquinas virtuales en pantalla completa), el atajo podría no ejecutarse.
- En ese caso:
  - El sistema no debe bloquearse.
  - El usuario puede usar el botón flotante como alternativa.
  - No mostrar errores técnicos al usuario.

---

## 4.9 Configuración de Modo Clip

Título:
"Modo Clip"

Opciones:
☐ Capturar solo clic izquierdo  
☐ Ignorar clic en barras de desplazamiento  
☐ Capturar cada X segundos (intervalo)

Campo:
"Intervalo (segundos)"
[   ]

Reglas:
- Si intervalo está activo, el modo clip captura por tiempo y no por clic.
- Si captura por clic está activo, respeta los filtros configurados.
- El modo clip siempre debe poder detenerse de inmediato.

---

## 4.10 Opciones del Visor / Editor

Título:
"Visor / Editor"

Opciones:
☐ Mostrar tira de "Capturas recientes" (últimas 5)  
☐ Mostrar indicador "Guardado"  

---

# 5. PANTALLA 2 – GESTIÓN DE PROYECTOS

Nombre: Gestión de Proyectos  
Título visible: "Proyectos"

Elementos visibles:
- Botón principal: [ Nuevo Proyecto ]
- Lista de proyectos existentes

Cada proyecto debe mostrar:
- Nombre del proyecto
- Alias corto (2–4 letras)
- Color identificador
- Indicador si es predeterminado

Acciones por proyecto:
[ Editar ]  [ Abrir Carpeta ]  [ Establecer Predeterminado ]

---

## 5.1 Crear Proyecto

Al presionar:
[ Nuevo Proyecto ]

Modal con título:
"Crear proyecto"

Campos:
"Nombre del proyecto"
[________________]

"Alias corto (2–4 letras)"
[____]  (Ejemplo: PR)

"Color del proyecto"
[ Selector de color ]

Checkbox:
☐ Establecer como predeterminado

Botones:
[ Crear ]  [ Cancelar ]

Comportamiento al presionar [ Crear ]:
- Crear carpeta dentro de la carpeta raíz con el "Nombre del proyecto".
- Registrar el proyecto como disponible para selección inmediata.
- Si es predeterminado, definirlo como proyecto activo por defecto.

---

## 5.2 Editar Proyecto

Al presionar:
[ Editar ]

Modal con título:
"Editar proyecto"

Campos editables:
- Nombre del proyecto
- Alias corto
- Color del proyecto
- Predeterminado

Reglas:
- Si cambia el nombre, la carpeta debe reflejar el cambio.
- El alias debe reflejarse en el botón flotante.
- El color debe reflejarse en el botón flotante y lista.

---

# 6. BOTÓN FLOTANTE

Componente: Botón flotante (si está habilitado)

## 6.1 Vista del botón (estado normal)

- Mostrar círculo/botón con color del proyecto activo.
- Mostrar alias del proyecto activo dentro del botón.
- Tooltip al pasar:
  "Proyecto activo: {NombreProyecto}"

## 6.2 Panel al hacer clic (menú compacto)

Título del panel:
"Capturas"

Sección: Proyecto activo
Texto:
"Proyecto activo"
Elemento:
[ Color + Alias + Nombre ]

Botón:
[ Cambiar proyecto ]

Sección: Proyectos más usados (máximo 8)
- Mostrar botones pequeños (Color + Alias).
- Clic en uno → cambia proyecto activo inmediatamente.

Botones adicionales:
[ Ver todos los proyectos ]
[ Crear nuevo proyecto ]

Sección: Acciones rápidas
Botones:
[ Capturar ]  
[ Modo Clip ] (toggle ON/OFF)  
[ Abrir Visor ]  
[ Abrir carpeta del proyecto actual ]  

Regla:
- [ Abrir carpeta del proyecto actual ] abre el Explorador de Windows en la carpeta del proyecto activo.

Sección: Comportamiento post-captura (sesión)
Dropdown:
- Usar configuración
- Abrir visor
- Miniatura 3s
- Silencioso

Reglas:
- "Usar configuración" es el valor por defecto.
- Si el usuario cambia aquí, aplica solo a la sesión (hasta cerrar la app).

---

# 7. MODO CAPTURA (TRADICIONAL)

Acción de entrada:
- Botón [ Capturar ] desde el panel del botón flotante
- o Hotkey "Captura Tradicional"

Flujo:
1) El botón flotante desaparece temporalmente.
2) El cursor cambia a modo selección.
3) El usuario selecciona tipo de captura:
   - Región (área)
   - Ventana activa
   - Pantalla completa
4) Se toma la captura.
5) Se guarda automáticamente como JPG en el proyecto activo con el nombre según máscara.
6) Luego se aplica el comportamiento “Después de capturar”:
   - Guardar y abrir visor
   - Guardar y mostrar miniatura 3s
   - Guardar silencioso

---

## 7.1 Miniatura Flotante (si aplica)

Condición:
- Modo Tradicional
- Opción elegida: "Guardar y mostrar miniatura (3s)"

Comportamiento:
- Mostrar miniatura pequeña en esquina inferior derecha por 3 segundos.
- Si el usuario hace clic en la miniatura → abrir visor con esa captura.
- Si el usuario la ignora → desaparece y la captura queda guardada.
- La miniatura no debe bloquear interacción del usuario.

Regla:
- En modo clip, no aparece miniatura.

---

# 8. MODO CLIP (CAPTURA CONTINUA)

Activación:
- Toggle [ Modo Clip ] desde botón flotante
- o Hotkey "Modo Clip ON/OFF"

Indicador obligatorio mientras esté activo:
- 🔴 Punto rojo parpadeante en el botón flotante
- Texto visible en el panel:
  "Modo Clip activo"

Reglas obligatorias:
- Modo Clip fuerza “Guardar silencioso”.
- Nunca abrir visor automáticamente.
- Nunca mostrar miniatura.
- Guardar todas las capturas como JPG en el proyecto activo.
- Aplicar filtros de modo clip (clic izquierdo / ignorar scroll / intervalo).
- Debe poder detenerse inmediatamente con:
  - Toggle [ Modo Clip ] o
  - Hotkey configurada

---

# 9. VISOR / EDITOR DE CAPTURAS

Nombre: Visor / Editor  
Título visible: "Editor de Captura"

Formas de abrir:
- Automáticamente si el usuario eligió “Guardar y abrir visor”.
- Manualmente desde el botón flotante: [ Abrir Visor ].
- Clic en miniatura (si miniatura está activa).

---

## 9.1 Canvas tipo Frame Expandible

- La captura se inserta dentro de un frame (contenedor).
- El frame puede redimensionarse (hacerlo más grande).
- El frame permite insertar múltiples imágenes dentro del mismo espacio.
- El usuario puede reorganizar las imágenes libremente dentro del frame (posición).

Objetivo:
- Documentar flujos de menús/pantallas sin depender de imágenes separadas dispersas.

---

## 9.2 Inserción de múltiples imágenes

Formas permitidas (al menos una):
- Botón dentro del visor: [ Agregar imagen al frame ]
- Arrastrar y soltar una captura reciente al frame (si está la tira activa)

Regla:
- No debe borrar ni alterar las capturas originales.

---

## 9.3 Composición Automática (Definición Formal)

Cuando el usuario inserta múltiples imágenes en el frame:

1) Mantener todas las imágenes originales intactas en el proyecto.
2) Generar automáticamente una imagen compuesta (collage/compuesta) representando el contenido del frame.
3) Guardar esa imagen compuesta como un NUEVO archivo JPG adicional dentro del proyecto.
4) Nombre sugerido de la compuesta:
   {PROYECTO}_COMPOSICION_{NUMERO}

Reglas:
- La compuesta debe actualizarse automáticamente con cada cambio del frame.
- La compuesta nunca debe reemplazar ni borrar las capturas individuales.

---

## 9.4 Barra de Herramientas (Kit de anotaciones)

Barra superior fija con iconos + tooltip.

Herramientas:
[ Seleccionar ]  
[ Flecha ]  
[ Rectángulo ]  
[ Círculo ]  
[ Resaltador ]  
[ Lápiz ]  
[ Texto ]  
[ Burbuja de comentario ]  
[ Numerador de pasos ]  
[ Blur ]  
[ Borrador ]  
[ Deshacer ]  
[ Rehacer ]

Atajos obligatorios:
- Ctrl + Z = Deshacer
- Ctrl + Y = Rehacer

---

## 9.5 Propiedades de herramientas (cuando aplique)

Al seleccionar herramientas como Flecha/Rectángulo/Lápiz/Texto:
Mostrar opciones:

Texto:
"Color"
[ Selector de color ]

Texto:
"Grosor"
[ Selector ]

Texto (solo para Texto):
"Tamaño"
[ Selector ]

Regla:
- Cambio de color debe ser rápido (QA usa rojo/naranja/verde con frecuencia).

---

## 9.6 Tira de “Capturas recientes” (Opcional por configuración)

Si está activada en Configuración:
- Mostrar una tira inferior con las últimas 5 capturas del proyecto activo.
- Al hacer clic en una miniatura:
  - abrir esa captura en el visor, o
  - permitir insertarla al frame (si el usuario así lo decide con [ Agregar al frame ]).

Si está desactivada:
- No mostrar la tira.

---

## 9.7 Guardado y estado

Regla principal:
- Guardado automático en todo momento.

Indicador:
- Si está activado, mostrar texto visible:
  "Guardado"

Comportamiento:
- Cada modificación (anotación, mover elemento, insertar imagen, mover imagen) actualiza automáticamente el resultado.
- No existe botón “Guardar como”.
- No se solicita ubicación ni formato (siempre JPG).

---

# 10. REGLAS CRÍTICAS FINALES

- JPG obligatorio.
- Alta resolución obligatoria.
- No sobrescribir archivos.
- Numeración automática.
- Hotkeys globales funcionales.
- Modo Clip con indicador visual obligatorio.
- Copiado opcional al portapapeles.
- Sistema 100% local.
- Sin login.
- Sin nube.
- Sin sistema de temas en esta versión.

---

# 11. OBSERVACIÓN PARA FUTURA VERSIÓN (PREPARACIÓN)

Aunque esta versión no incluirá modo claro/oscuro, se establece como recomendación obligatoria para implementación futura:

- Todos los colores de la interfaz deben definirse mediante variables centralizadas.
- No utilizar colores fijos directamente en componentes.
- La definición de colores debe permitir reemplazo global desde un único archivo o configuración.

Objetivo:
Facilitar que en una futura versión (2.0), activar modo oscuro sea un cambio centralizado sin rediseño completo.

---

# 12. RENDIMIENTO Y ESTABILIDAD

Esta sección es obligatoria para garantizar comportamiento profesional en el mundo real del QA.

## 12.1 Carga Diferida (Lazy Loading)

En la tira de "Capturas Recientes":

- Las miniaturas deben cargarse de forma ligera.
- No cargar en memoria todas las imágenes del proyecto.
- Solo cargar las necesarias para visualización inmediata.
- Si el proyecto tiene cientos o miles de capturas, el visor no debe consumir memoria excesiva.

Objetivo:
Evitar alto consumo de RAM y mantener la aplicación ágil.

---

## 12.2 Prevención de Congelamientos (Interfaz siempre fluida)

El guardado de JPG, especialmente en:

- Modo Clip (muchas capturas consecutivas)
- Composición automática del frame
- Proyectos con alto volumen

Debe ocurrir de forma que:

- La interfaz nunca se congele.
- El usuario pueda seguir interactuando normalmente.
- El botón flotante siga respondiendo aunque el disco sea lento.

Reglas:
- No debe haber “freeze” visible al usuario al guardar.
- El modo clip no debe detenerse por procesos de escritura.
- El sistema debe seguir sintiéndose veloz, ligero y profesional.

---

FIN DEL REQUERIMIENTO