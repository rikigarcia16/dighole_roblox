# Propuesta técnica: ensanchar el subsuelo de 64 a ~160 studs

**Estado: propuesta. No se ha migrado ni modificado ningún dato.** La prueba aislada
(`tests/bench_width.lua`) carga el proyecto desde cero con cada anchura y mide en la VM de Luau;
no toca perfiles ni terreno real.

## 1. Qué cambiaría

| | Hoy | Propuesta |
|---|---|---|
| Boca del agujero en superficie | 16 × 16 celdas (64 studs) | Igual: no cambian la casa, el garaje ni la valla |
| Subsuelo (desde ~10 m) | 16 × 16 | **40 × 40 celdas (160 studs)**, centrado bajo la boca |
| Separación entre parcelas | 288 studs | Igual: 160 + anillo protegido = 168 studs < 288 |

Entre 0 y ~10 m, las celdas fuera de la boca serían roca protegida (como el anillo actual), para que
nadie cave bajo la casa. Por debajo, todo el ancho es excavable.

## 2. Mediciones (5 ejecuciones, VM de Luau, mismo contenedor)

Generación de parcelas completas de 0 a 416 m, capa a capa, como hace el trabajador en segundo
plano. Incluye los costes únicos (sectores de cuevas, capas de fósiles) donde ocurren.

| Ancho | Studs | Capa de 4 m: media | Capa de 4 m: peor | 16 m de terreno | Sector de cuevas (frío) | Memoria por sector cacheado | Vóxeles hasta 1 500 m | Guardado* |
|---|---|---|---|---|---|---|---|---|
| 16 | 64 | 5,7–8,9 ms | 12,5–20,9 ms | 23–36 ms | 1,3–2,5 ms | 133 KB | 486 000 | 14,2 KB |
| 24 | 96 | 12,7–16,5 ms | 31,6–34,5 ms | 51–66 ms | 1,6–2,9 ms | 293 KB | 1 014 000 | 14,2 KB |
| 32 | 128 | 22,2–29,1 ms | 46–72 ms | 89–116 ms | 2,2–4,1 ms | 517 KB | 1 734 000 | 14,3 KB |
| **40** | **160** | **33,1–39,7 ms** | **64–71 ms** | **133–159 ms** | 2,7–4,6 ms | **805 KB** | **2 646 000** | 14,9 KB |

\* Agujero de prueba: pozo de 6×6 hasta 500 m más 30 galerías que cruzan todo el ancho.

**Conclusiones medidas**
- Coste de generación con 40 frente a 16: **entre 3,7 y 6,5 veces** según la ejecución (crece con
  el área, ×6,25, algo amortiguado por los costes fijos). No es "exactamente 5".
- El tamaño de guardado **no** depende del ancho: depende de cuántos tramos excavados haya.
- La memoria de Lua de las cuevas cacheadas sube ×6: con la caché actual de 48 sectores serían
  **~38 MB** por servidor. Inaceptable tal cual (ver 4.2).

**No medido (necesita Studio)**: memoria real del terreno de Roblox por vóxel, ancho de banda de
replicación de `WriteVoxels` (una capa de 42×42×4 son ~7 000 vóxeles por escritura), coste del
cliente para mallar y colisionar terreno más ancho, y rendimiento en móvil.

## 3. Impacto por área

| Área | Impacto | Trabajo necesario |
|---|---|---|
| **Generación** | Una capa de 4 m tarda 33–71 ms: rompe el presupuesto de 4 ms por frame. | Partir cada capa en columnas (por ejemplo 4 capas × 10 columnas ≈ 4–8 ms por trozo). |
| **Cuevas** | Las recetas actuales están pensadas para 16 de ancho: a 40 quedarían espacios vacíos. | Escalar galerías y cámaras por sector con el área; permitir radios de cámara de hasta ~16 celdas (64 studs). Es lo que da "cámaras enormes". |
| **Excavación** | `DiggingService` no depende del ancho; un golpe sigue escribiendo como mucho 7×7×7. | Ninguno. |
| **Colisiones** | Las calcula el motor a partir del terreno: sin cambios de código. | Medir en Studio con 8 parcelas profundas. |
| **Persistencia** | `Grid.key` usa el ancho: las claves guardadas con 16 no valen con 40. | Migración versionada (sección 5). |
| **Memoria del servidor** | Terreno ×5,4 (2,6 M vóxeles por parcela a 1 500 m; 21 M con 8 parcelas). | Medir en Studio. Si es alto, generar solo cerca de los jugadores y vaciar el terreno lejano. |
| **Memoria de Lua** | Sectores cacheados ×6. | Guardar la rejilla de cada sector en un `buffer` (1 byte por celda: 51 KB en vez de 805 KB) y reducir la caché a ~12 sectores. |
| **Cliente** | `PlotLocator` y `DigController` usan el ancho para localizar celdas. | Leer el ancho de los atributos de la carpeta de la parcela. |
| **Hitos, fósiles y geodas** | Las posiciones dependen del ancho. | Mantener los hitos de historia bajo la boca (posición fija respecto al centro); el resto se adapta solo. |
| **Cofres y geodas abiertos** | Los ids (`s4_k1`, `f12`...) dependen de la disposición, que cambiará. | Cambio de versión de generación: los ids viejos no se reutilizan, así que no se puede cobrar dos veces. |

## 4. Diseño técnico propuesto

### 4.1 Geometría
`Grid` pasa a tener dos anchos: `SurfaceCells = 16` (boca) y `UndergroundCells = 40` a partir de
`OpenDepth = 10`. `Grid.inDigArea` comprueba la boca por encima de `OpenDepth` y el ancho completo
por debajo. El origen de celdas se desplaza 12 celdas para que la boca quede centrada.

### 4.2 Rendimiento
- El trabajador en segundo plano genera trozos de columnas, no capas completas.
- Rejilla de sector en `buffer` y caché de ~12 sectores (~0,6 MB).
- Medir `THNE.GenerateSlab` en el MicroProfiler (ya instrumentado) antes y después.

### 4.3 Formato de guardado
Se añade `profile.plot.layout = { version = 2, width = 40, offset = 12 }`. La clave de celda se
calcula con el ancho del layout guardado.

## 5. Plan de compatibilidad y recuperación (sin migraciones destructivas)

1. **Copia de seguridad antes de convertir**: al cargar un perfil con layout 1, se copia
   `plot.dug` tal cual a `plot.legacy = { version = 1, dug = <original> }`. Nunca se borra en esta
   versión del juego.
2. **Conversión pura y probada**: `(cx, d, cz)` en layout 1 → `(cx + 12, d, cz + 12)` en layout 2.
   Función pura con tests de ida y vuelta sobre agujeros reales y sintéticos.
3. **Verificación al cargar**: se comprueba que el número de celdas excavadas coincide antes y
   después; si no, se usa el layout 1 sin convertir y se registra un aviso.
4. **Vuelta atrás**: si hay que revertir la actualización, el código anterior sigue leyendo
   `plot.dug` en layout 1. Para eso, durante la transición se guardan **ambos** formatos
   (`dug` convertido y `legacy`), y `legacy` se actualiza con las celdas nuevas que caigan dentro
   de la antigua zona de 16×16.
5. **Cambio de generación**: las parcelas existentes se regeneran con la nueva disposición. Los
   agujeros excavados se conservan en su sitio exacto. Las cuevas y los fósiles alrededor
   cambiarán, y eso hay que avisarlo en las notas de la actualización.
6. **Despliegue por fases**: primero un lugar de pruebas con la opción activada, medición en Studio
   con 8 jugadores simulados y un móvil modesto, y solo después producción.

## 6. Recomendación

Es viable, y es lo que permite cuevas con la personalidad que buscas. Pero no es solo cambiar un
número: requiere partir la generación en trozos más pequeños, guardar las cuevas de forma compacta
y reescalar las recetas de cuevas.

Propongo hacerlo **después** de validar en Studio la versión actual de 16 de ancho, para tener una
línea base real de memoria y red con la que comparar. Si las mediciones en Studio resultan
ajustadas, 32 celdas (128 studs) es un punto intermedio con la mitad de coste que 40.
