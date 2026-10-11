# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · **Español** · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · [Bahasa Indonesia](id.md) · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Aprende los idiomas del mundo más rápido con IA.**

Versión 0.5.3 · Vista previa del código fuente · Compila desde el código fuente

Convierte YouTube en tu aula de idiomas personal. Aprende con tus vídeos favoritos gracias a los subtítulos y las traducciones automáticas de YouTube: lee dos idiomas en paralelo, repite cada frase y conserva el material que más te importa.

**24 idiomas de interfaz · Subtítulos multilingües**

24 es el número de idiomas disponibles para la interfaz. Los idiomas de los subtítulos dependen de las pistas disponibles en el vídeo elegido; no es una promesa de dominar 24 idiomas.

## Capturas de pantalla

Las capturas proceden de la aplicación real 0.5.3. El idioma de cada captura se indica por separado del idioma de este documento.

### Bienvenida y flujo principal

![Bienvenida y flujo principal](../assets/interface-en.png)

Las cuatro acciones de la barra de herramientas, los dos selectores de subtítulos visibles, el lema localizado y el estado desactivado claramente indicado antes de abrir un vídeo. — Captura de la aplicación en inglés

### Práctica centrada en cada frase

![Práctica centrada en cada frase](../assets/interface-study.png)

demo.mp4 — Búsqueda de frases, salto al hacer clic, frase anterior / siguiente, repetición, bucle, velocidad de reproducción y seguimiento de la frase actual. — Captura de la aplicación en inglés

### Primer y segundo subtítulo

![Primer y segundo subtítulo](../assets/interface-caption-languages.png)

Captura real de la interfaz en inglés con los menús independientes de subtítulos, configurados por defecto en inglés y chino tradicional. — Captura de la aplicación en inglés

### Abrir un enlace de YouTube

![Abrir un enlace de YouTube](../assets/interface-youtube-dialog.png)

Captura real del diálogo de enlace en la interfaz en inglés. Al abrir un enlace, comienza la reproducción y se solicitan las dos pistas de subtítulos elegidas. — Captura de la aplicación en inglés

## Primeros pasos

### 1. Abre YouTube

Pega el enlace de un vídeo. Se solicitan automáticamente los subtítulos disponibles, con inglés como primera pista y chino tradicional como segunda. La primera descarga puede tardar entre 1 y 2 minutos; su disponibilidad no está garantizada.

### 2. Elige y practica

Usa los dos menús desplegables de subtítulos visibles. Haz clic en una frase para ir a ella, volver a reproducirla o activar su repetición en bucle.

### 3. Guarda o exporta

Guardar vídeo permite elegir una carpeta para el contenido accesible y los subtítulos disponibles. Exportar subtítulos bilingües crea archivos Word, TXT o SRT a partir de los subtítulos cargados.

### 4. Adáptalo a ti

Cambia el idioma de la interfaz, la velocidad de reproducción, el tamaño de los subtítulos y el desfase temporal de cada pista. La aplicación recuerda los idiomas elegidos para la interfaz y los subtítulos.

## Funciones disponibles

### Dos pistas de subtítulos independientes

Inglés / chino tradicional por defecto; elige entre los originales y las traducciones automáticas disponibles para el vídeo actual. Si falla la segunda pista, los subtítulos de la primera que se hayan obtenido siguen disponibles.

### Práctica centrada en cada frase

Búsqueda de frases, salto al hacer clic, frase anterior / siguiente, repetición, bucle, velocidad de reproducción y seguimiento de la frase actual.

### Vídeo con subtítulos sincronizados

Puedes guardar mientras se cargan los subtítulos. Cada operación crea una carpeta nueva para el vídeo accesible y, cuando hay subtítulos disponibles, añade pistas SRT temporizadas y archivos de lectura bilingüe. También puedes guardar solo el vídeo; el trabajo incompleto permanece en una carpeta .partial.

### Exportación a Word, TXT y SRT

Exporta los subtítulos disponibles con los desfases temporales aplicados. Word y TXT emparejan el texto según la coincidencia temporal. Si solo hay una pista cargada, también puedes exportar su contenido.

### 24 interfaces localizadas

Los menús, los mensajes de estado y el lema de aprendizaje cambian de idioma a la vez. El árabe y el hebreo admiten diseños de derecha a izquierda; cambiar la interfaz no modifica el contenido de los subtítulos.

### Reproducción local y controles claros

Abre archivos locales de audio, vídeo y subtítulos desde el menú Archivo. Las acciones no disponibles aparecen atenuadas con su motivo; los modos elegidos se resaltan y muestran marcas de selección; al guardar se indica que hay una operación en curso.

## Por qué resulta útil

### De ver a practicar en pocos pasos

Cuatro acciones en la barra de herramientas simplifican el flujo principal: YouTube → Guardar vídeo → Subtítulos → Idioma. No hace falta un botón adicional para obtener subtítulos.

### Material de aprendizaje que puedes conservar

Los subtítulos temporizados y los archivos Word / TXT de fácil lectura sirven tanto para practicar la comprensión oral como para repasar después. Las exportaciones usan destinos nuevos y conservan los archivos originales.

### Trabajo local, sin clave de API de IA

Los archivos multimedia locales y los subtítulos guardados funcionan sin conexión. YouTube proporciona los subtítulos del sitio y las traducciones automáticas; la aplicación no tiene telemetría, no sube contenido multimedia local ni requiere una clave de API de IA de pago.

## Problemas pendientes y límites

### P0 · Disponibilidad de vídeos y subtítulos de YouTube

**Verificación del servicio real**

La última comprobación en línea se encontró con el requisito de inicio de sesión / verificación contra bots de YouTube. No se ha confirmado que las descargas en línea funcionen actualmente. Antes de publicar, hay que validar con la red prevista y una selección representativa de vídeos.

### P1 · Vídeos con restricciones de inserción o de cuenta

**Restricción de la plataforma**

Algunos autores o vídeos no permiten la reproducción integrada. No se ha implementado Google SSO dentro de la aplicación; el acceso directo al navegador usa una sesión de inicio de sesión y reproducción independiente. Estas restricciones no pueden presentarse como resueltas.

### P1 · Firma y pruebas en más Mac

**Distribución y compatibilidad**

El paquete tiene firma ad hoc, sin notarización con Developer ID. Se probó en Apple Silicon con macOS 26.5.2; no en macOS 27 ni en Mac Intel. macOS 14 es el objetivo de despliegue, no una prueba de que se haya verificado cada versión.

### P2 · Calidad de descarga y fidelidad de los subtítulos

**Límites de formato y calidad**

El guardado usa un flujo completo de audio y vídeo y no combina flujos separados de alta resolución. De ASS/SSA solo se importa el texto. Los subtítulos automáticos, las traducciones y el emparejamiento bilingüe por tiempo pueden contener errores. La reproducción local depende de la compatibilidad con los códecs. La conversión opcional con FFmpeg puede omitir pistas de audio adicionales, HDR y subtítulos integrados.

### P2 · Historial de aprendizaje y herramientas de estudio

**Sin implementar**

No se han implementado la restauración del historial de reproducción, las colecciones de vocabulario, el repaso espaciado, el OCR ni la extracción de subtítulos en imagen. Guardar las preferencias de idioma no equivale a guardar el progreso de aprendizaje.

### P2 · Revisión lingüística por hablantes nativos

**Revisión editorial**

Los 24 idiomas de interfaz y sus lemas localizados superaron las pruebas de cambio de idioma. Esto acredita la cobertura y el comportamiento, no una revisión profesional de todas las traducciones por hablantes nativos.

## Qué se ha verificado

Para 0.5.3: se superaron 105 comprobaciones del núcleo, 138 aserciones del modelo, 29 comprobaciones de subtítulos, 60 de guardado de vídeo y 317 aserciones de la interfaz nativa. Se seleccionaron los 24 idiomas en el menú real; se revisaron seis idiomas de interfaz y los diseños compactos en alemán.

Se verificaron la reproducción local, las exportaciones, las transiciones de estado y los diálogos nativos de guardado. Los datos de prueba sin conexión y las pruebas de guardado con un auxiliar simulado no demuestran que YouTube permita actualmente descargar subtítulos o vídeos en línea. No se importaron credenciales de usuarios.

[Registro detallado de verificación](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#es)

La aplicación tiene licencia MIT; los componentes de terceros conservan sus avisos. AxonTube no está afiliado a YouTube, Google ni Apple.

Fecha del documento: 2026-10-11
