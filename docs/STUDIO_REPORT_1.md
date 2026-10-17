# Informe de pruebas en Roblox Studio n.º 1

Fecha: 2026-10-17. Rama `claude/modest-albattani-hcyxrm`, base `390879b`.
Entorno: Roblox Studio con Rojo 7.4.4 (`rojo serve`) y el MCP de Studio. Lugar **sin publicar**
(PlaceId 0), 1 jugador, *Play* en solitario.

## Cómo se probó (léelo antes de la tabla)

- **Entrada real:** los golpes se hicieron con la tecla **E** real (DigController, con animación y
  sonido), las interacciones con **F/H/Q/R** reales y los menús con **clics de ratón** reales.
- **Cámara:** para cavar en vertical fijé la cámara mirando hacia abajo sobre el personaje (en
  tercera persona, mantener E cava hacia delante y el personaje no baja).
- **Puente de pruebas:** el MCP ejecuta el código con su propia caché de `require`, así que
  `require(PlayerDataService).get(player)` devuelve `nil` desde ahí. Para leer el perfil y medir
  creé en la sesión de Play (nunca en el repositorio ni en el lugar) scripts temporales que se
  ejecutan en el contexto del juego. Desaparecen al parar Play.
- **Mediciones:** el MCP no puede leer el MicroProfiler. Los tiempos son de `os.clock()`
  alrededor de las mismas funciones que marcan las etiquetas (`writeBox` de un sector completo =
  `THNE.GenerateSlab`; de `MobilityService.interrupt` a `FxService.broadcast` = `THNE.Dig`), en el
  servidor real de Studio. Son números de Roblox, pero no capturas del MicroProfiler.
- **Baseplate:** el lugar «Place1» trae la `Baseplate` de la plantilla (2048×16×2048, de y=−16 a
  0), que tapa el agujero. En cada sesión la desactivé (`CanCollide=false`, invisible) solo durante
  Play. Ver fallo 6.
- **Atajos usados**, indicados en la tabla: pico industrial en vez de la pala oxidada para bajar
  rápido, teletransportes, fijar al personaje a la altura de las manivelas y poner las monedas a 0.

## 1. Resultados

| ID | Resultado | Evidencia | Atajos |
|---|---|---|---|
| Arranque | OK | `[Server] THE HOLE NEVER ENDS started`; ningún `failed to start`. Árbol Shared/Server/Client presente (26/27/17 descendientes, cuadra con `src`). | — |
| A. GenerateSlab | OK | 29 sectores: mediana 2,48 ms, máx. 4,61 ms. | Pico industrial |
| A. Dig | **FALLA → arreglado** | 3 de 3 sectores se generaban **dentro** del golpe (golpes de ~3 ms frente a ~0,9 ms). Tras el arreglo: 0 de 7 dentro, golpe máx. 2,34 ms. Fallo 1. | Pico industrial |
| A. Sala del Contador | OK | Construcción 2,57 ms, 273 piezas (364 descendientes). Se construye al generar el sector, no al revelarla. | — |
| A. Cuerdas (`rebuildRopes`) | NO PROBADA | No medido (función local; solo hubo 1 cuerda). | — |
| S1 | PARCIAL | E real produce golpes, sonido y animación (no evaluados por mí). `swoosh.wav` no carga. | — |
| S2 | PARCIAL | La etiqueta muestra «Piedra · 4 golpes» y 4 segmentos; no capturé cómo se vacían. | Pala oxidada equipada a mano |
| S3 | OK | Con la pala oxidada sobre pizarra (a 101 m, no a 50 m): contorno rojo (255,80,80), «🔒 Pizarra · necesitas potencia 2»; el servidor responde «Pizarra es demasiado dura: necesitas potencia 2 (tienes 1)» y no la daña. | Teletransporte |
| S4, S5 | NO PROBADA | Solo audiovisual. Para el usuario. | — |
| S6 | NO PROBADA | Necesita 2 jugadores (el MCP solo inicia Play en solitario). | — |
| S7 | OK | F7 ejecutado; la consola se llenó de avisos de `swoosh.wav` y cortó las líneas `[SoundTest]`, así que repetí la misma comprobación por código (sección 3). | — |
| F1 | OK | A 7,5 m: «Algo con forma de hueso asoma en la roca...», `Revealed=true`, Highlight color hueso (235,225,195). | Teletransporte a la superficie encima |
| F2 | OK | Mantener F 2 s: «Nuevo fósil registrado: Escarabajo de túnel · +40 monedas»; `collection.fossils.tunnel_beetle = {count=1, firstDepth=6}`. La ficha la mira el usuario. | — |
| F3 | PARCIAL | Segundo «Topo de seis patas»: «(repetido): obtienes un Fragmento fósil», `count=2`, +1 `fossil`. Pero **sí entraron +225 monedas** por «¡Nuevo descubrimiento: Fragmento fósil!» (bonificación de primer hallazgo de ese objeto). Decisión 7. | Teletransporte a 80 m |
| F4, F5 | NO PROBADA | Necesitan guardado real (lugar sin publicar). | — |
| E1 | PARCIAL | La etiqueta «Energía 60/60» existe pero está oculta; nunca salió «Sin energía». No comprobé la pestaña Mejoras. | — |
| C1 | PARCIAL | El golpeteo suena (`collide.wav`, cargado) con ecualizador: agudos −27 dB lejos y −2 dB cerca. Lo audible lo juzga el usuario. | — |
| C2 | OK | La envoltura no se raya: «La pala resbala: esta pared no se deja rayar. Suena hueca.» La galería guiada este llega hasta x=13, pegada al acceso (x=12). | Teletransporte a la galería |
| C3 | OK | Al abrir el acceso este: «¡Has abierto una cueva!», «Nueva entrada en el diario: «Una sala que nadie excavó»», cartel «UNA SALA QUE NADIE EXCAVÓ». Dentro, el golpeteo se para y suena el zumbido. | — |
| C4 | NO PROBADA | Visual. Para el usuario. | — |
| C5 | PARCIAL | Placa con F: «Nueva pista: La placa de piedra · +1.000 monedas». Anillos: cada giro +1, el correcto queda `Locked`. **Problema:** solo se puede girar el anillo I desde el suelo (decisión 8). Segundo jugador no probado. | Personaje fijado a la altura de las manivelas II y III |
| C6 | **OK** | La pantalla terminó en «1 239» y `profile.stats.cellsDug` era **1239** en el servidor justo antes de resolver; `Count=1239`. Hubo un parpadeo de glifos de ~60 ms al final (fallo 3, arreglado). | — |
| C7 | OK | Tras 9 bloques más: `cellsDug=1248`, `Count=1248` y la pantalla del cliente muestra «1 248». | — |
| C8 | NO PROBADA | Necesita guardado real. | — |
| M1 | PARCIAL | A 11,5 m: «↑ Superficie» visible y R sube. A 80 m solo aparece «Baliza» y R la abre. No pude forzar el evento desde el MCP. | — |
| M2 | OK | Garaje → Equipo: «Comprar · ● 25». 6 clics: 879 → 754 monedas (5×25), cuerdas = 5; el sexto no cobra. | — |
| M3 | PARCIAL | Q colocó la cuerda («Cuerda colocada (7 m)», TrussPart de 31 studs). «Aquí no hace falta cuerda» sale con el borde demasiado cerca. **Subir** trepando: OK (estado `Climbing`, de y=−43 a −11). **Bajar**: no lo conseguí con entrada simulada. «No llega al fondo» y «No hay espacio» no probados. Desde la boca del agujero Q no hace nada (decisión 9). | Teletransportes para colocarse en el borde |
| M4 | PARCIAL | Desde abajo no hay aviso; desde arriba «Cuerda · Recoger» (mantener F 0,6 s) la devuelve (4 → 5). Segundo jugador no probado. | — |
| M5 | NO PROBADA | Necesita guardado real. | — |
| M6 | OK | H: «Estación de las Minas instalada...», 1.175 → 925 monedas. «Demasiado cerca» no probado (estaba a 6,7 celdas de otra, el mínimo es 6). | — |
| M7 | OK | F en el torno: menú «Superficie / Estación del Contador · 141 m / Estación de las Minas · 141 m»; viaje y vuelta. **Pero** se llega medio metido en la pared (fallo 2). | — |
| M8 | OK | Al resolver: «Un montacargas ha encontrado el camino hasta esta sala.», `Station_counter` creada y en el menú. | — |
| M9 | OK | A 80,6 m con mochila de valor 140: «Coste: 46», pagó 46 (925 → 879), mochila idéntica (comparada en JSON), destino superficie. Con 0 monedas a 186 m: «pagas 0 y el resto se perdona», destino Estación del Contador, monedas siguen en 0. Moverse la cancela (no hubo rescate). | Monedas a 0; teletransporte |
| M10 | OK | `StarterGui:GetCore("ResetButtonCallback") == false`. | — |
| M11 | OK | Muerte a 147,9 m → reaparición a 141,9 m en la Estación del Contador. | Teletransporte; `Health = 0` |
| G1–G3 | NO PROBADA | Lugar sin publicar. La consola avisa: `[PlayerData] DataStore unavailable, progress will not be saved: You must publish this place to the web to access DataStore.` Sin errores. | — |

## 2. Rendimiento (servidor de Studio, `os.clock`)

| Medida | Antes del arreglo | Después |
|---|---|---|
| `GenerateSlab` (4 capas, 18×4×18 celdas) | n=29, min 1,77, mediana 2,48, p90 3,26, **máx. 4,61 ms** | n=7, mediana 2,13, máx. 2,87 ms |
| `Dig` completo (pico industrial, radio 1,5) | n=85, mediana 1,28, p90 4,75, **máx. 8,47 ms** | n=25, mediana 1,06, p90 1,48, **máx. 2,34 ms** |
| `WriteVoxels` del golpe | mediana 0,09 ms, máx. 0,68 ms | — |
| Golpes con un sector generado dentro | **3 de 3** sectores | **0 de 7** |
| Construcción de la sala del Contador | 2,57 ms, 273 piezas, 364 descendientes | — |

Descenso de 0 a 133 m en ~26 s de E con el pico industrial: 29 sectores generados sin tirones
apreciables en el servidor.

## 3. Sonidos (`Config/Sounds.lua`, 35 claves, 7 archivos)

| Archivo | Carga | Duración | Claves |
|---|---|---|---|
| `action_footsteps_plastic.mp3` | sí | 2,48 s | dig_soil, hit_soil, break_soil, fossil_extract |
| `collide.wav` | sí | 1,20 s | dig/hit/break de roca y mineral, counter_knock, too_hard, hit_dense, hit_lava |
| `electronicpingshort.wav` | sí | 0,72 s | cristal, descubrimientos, counter_lock, geode_open, pickup, sell, purchase, zone, plasma |
| `clickfast.wav` | sí | 0,29 s | counter_hum, drill |
| `button.wav` | sí | 0,58 s | ui_click, error |
| `impact_water.mp3` | sí | 2,38 s | cave_open, counter_found |
| **`swoosh.wav`** | **no** | 0 | **swing_light, swing_heavy** |

`swoosh.wav` falla con «Asset is not approved for the requester» (Roblox lo redirige a
`rbxassetid://911864050`). Como se intenta en cada golpe, llena la consola. No lo he sustituido.
Además `counter_hum` es un clic de 0,29 s en bucle, no un zumbido.

## 4. Fallos encontrados

| # | Gravedad | Fallo | Estado |
|---|---|---|---|
| 1 | Media | `TerrainChunkService.requestDepth` lanzaba el generador con `task.spawn`, que se ejecuta en el acto: los primeros sectores se generaban **dentro** del manejador de `Dig`. | **Arreglado** (`task.defer`) y **verificado en Studio** (0 de 7). |
| 2 | Alta | El punto de llegada a una estación era `stationFloor * CFrame.new(0, 4, 2)`. La Estación del Contador está en la última celda junto a la envoltura (z 44–48), así que el montacargas, la baliza y la reaparición dejan al personaje en z≈48,4, medio dentro de la roca. **Pasos:** resolver el Contador, viajar a su estación (o morir debajo), caminar 8 studs al oeste → atraviesa el suelo y cae ~178 studs (a ~186 m). Reproducido 2 de 2 veces; desde z=46 no ocurre. | **Arreglado** (llegada al centro de la plataforma, `stationArrival`). **Sin volver a probar en Studio.** La plataforma sigue atravesando 1,5 studs la pared (estético). |
| 3 | Baja | Al acabar la secuencia del Contador la pantalla volvía a mostrar glifos ~60 ms antes del número (el cliente acaba a los 6,8 s y el servidor pone `Solved` a los 7 s). | **Arreglado** (el cliente conserva el número mostrado). **Sin volver a probar en Studio.** |
| 4 | **Alta** | Golpes que se pierden en silencio. Con terreno suave, en esquinas o en el fondo de un pozo, el rayo choca con una superficie dentro de una celda ya abierta y con la normal inclinada; las tres sondas del servidor (0,5 / 2 / 3,5 studs) caen en aire y el golpe se ignora. El cliente sigue mostrando «Piedra · 4 golpes». **Pasos:** cavar en vertical con el pico industrial; en una partida me quedé atascado a 44 m (impacto (32, −176,7, 31), normal (−0,72, 0,62, 0,31), las sondas dan la celda excavada (8,44,7)). También a 101 m en una esquina. | **Arreglado**: si las sondas fallan, se usa la celda excavable del bloque 3×3×3 más cercana al impacto (siguen las comprobaciones de alcance y visión). **Sin volver a probar en Studio.** |
| 5 | Media | `stylua.toml` usa `syntax = "Luau"`, que StyLua 0.20.0 (la versión de `aftman.toml`) no acepta: `stylua src tests` falla con esa versión. | Sin arreglar (comprobé el formato con una copia sin esa línea: limpio). |
| 6 | Media | El lugar de Studio trae la `Baseplate` de la plantilla, que tapa todas las parcelas a la altura de la superficie. Rojo no la quita. | Sin arreglar: es del lugar, no del repo. Bórrala en Studio (y la `SpawnLocation` de la plantilla, si no la usáis). |

## 5. Decisiones para ti

7. **Fósil repetido y monedas:** el repetido no paga por la colección, pero el primer Fragmento
   fósil dispara la bonificación genérica de descubrimiento (+225). ¿Se excluye?
8. **Manivelas del Contador:** los tres indicadores usan F con `Exclusivity = OnePerButton`, y
   desde el suelo Roblox siempre elige el del anillo I, incluso ya bloqueado. II y III solo aparecen
   **en el aire** al saltar. Opciones: teclas distintas, desactivar el indicador de un anillo
   bloqueado o poner las manivelas a la misma altura.
9. **Cuerda desde la boca del agujero:** el botón de cuerda solo existe a más de 1 m de
   profundidad (`depth > 1`), así que Q no hace nada al borde del pozo en la superficie.
10. **Bajo la sala del Contador** hay una cámara natural (d 143–146, poza en d 147) y el final de la
    galería guiada este (x=13, d 142) da a ella: al acercarse al acceso es fácil caer debajo de la sala.
11. La placa de piedra da **+1.000 monedas** como pista: mucho para 140 m.
12. Una nota abierta (la placa) se queda en pantalla bajo el menú del montacargas si no se cierra.

## 6. Para que lo mire el usuario

Prepara: `rojo serve`, conecta, borra/desactiva la Baseplate, Play. Para llegar rápido, en la
consola del servidor durante la prueba (no en el repo) puedes darte el pico industrial y bajar con
E mirando al suelo.

- **S1, S4, S5 (golpe, materiales, raros/épicos):** cava con la pala oxidada en la superficie;
  cobre/roca/cristal entre 20 y 60 m. Escucha sobre todo que **falta el silbido del gesto**
  (`swoosh.wav` no carga).
- **S2:** barra de segmentos sobre la celda al golpear piedra (4 golpes) con la pala oxidada.
- **C1:** baja de 80 a 130 m por el centro: ¿se oyen los tres golpes apagados? ¿Desde qué profundidad?
- **C4:** la sala del Contador (centro de la parcela, 136–141 m; acceso este por la galería que
  baja desde la esquina (14,137,14)). Escala, luz, legibilidad de la placa, plataforma de la
  estación que atraviesa la pared sur-este.
- **C6:** la secuencia completa (apagón, tres golpes, anillos, número que sube, «Nos está contando.»).
- **F2:** ficha del fósil y *Mochila → Fósiles*. El primero está a ~7 m bajo (18, 48).
- **M3:** bajar por una cuerda con el teclado (S / alejarse) y si se entiende cómo hacerlo.
- **M7/M9:** fundido a negro del montacargas y la barra de 4 s de la baliza.
- **HUD:** las etiquetas de monedas y profundidad tienen su centro en y = −25 px con
  `IgnoreGuiInset = true`: comprueba si quedan cortadas arriba.
- **Dos jugadores (S6, C5, M4):** *Test → Clients and Servers* con 2 jugadores; el segundo debe ver
  y oír el golpe, recibir «La máquina no reacciona a tu mano.» y no poder recoger tus cuerdas.

## 7. Qué queda pendiente

- Volver a probar en Studio los arreglos 2, 3 y 4.
- ~~`luaucheck` no ejecutado~~ → ejecutado después en la sesión en la nube: los 66 scripts compilan,
  `tests/static_checks.lua` pasa y `tests/run.lua` pasa (49/49) tras adaptar un test que simulaba
  `task.spawn` en vez de `task.defer`. Ese test ahora reproduce el fallo 1: falla con el código
  anterior y pasa con el arreglo.
- G1–G3, F4, F5, C8, M5 (lugar publicado con API Services) y las pruebas de dos jugadores.
