# Informe de pruebas en Roblox Studio n.º 2

Fecha: 2026-10-18. Rama `claude/modest-albattani-hcyxrm`, base `0aae2e1` (iteraciones 4–6).
Entorno: Roblox Studio (lugar `Template_95206881_AutoRecovery_0`, **sin publicar**), Rojo 7.4.4,
MCP de Studio, *Play* con 1 jugador.

## Niveles de verificación

- **(a) Automático:** StyLua 2.6.0 limpio en `src` y `tests` (con fin de línea CRLF, el que deja Git
  en Windows). **`luaucheck` no se ha ejecutado:** necesita Rust/cargo y aquí no está instalado. Por
  tanto ni `tests/run.lua` (incluido el test nuevo de materiales) ni `tests/static_checks.lua` se
  han pasado en esta tanda. **Hay que pasarlos** antes de dar los cambios por cerrados.
- **(b) VM de Luau:** nada nuevo ejecutado aquí (ver arriba).
- **(c) Studio:** lo marcado OK en la tabla se ha visto funcionar en Studio (consola, valor leído
  por código o captura).

## Cómo se probó

- **Entrada real:** E y clic para cavar; F, G, H, L, Q, R y T reales; los menús con clics de ratón.
- **Puente de pruebas (solo durante Play):** el MCP tiene su propia caché de `require`, así que para
  leer el perfil y medir creé scripts temporales en `ServerScriptService` durante la sesión. Se
  borran al parar Play; no están en el repositorio ni en el lugar.
- **Mediciones:** `os.clock()` en el servidor alrededor de `TerrainChunkService.writeBox` (sector
  completo = `THNE.GenerateSlab`), del golpe completo, de `CounterRoomBuilder.build`,
  `CaveScenes.build` y `CaveProps.decorate`, y la duración de cada `Heartbeat` del servidor. El MCP
  no lee el MicroProfiler.
- **Atajos usados:** monedas (100, 20 000 y 30 000), pico industrial y taladro portátil en vez de
  cavar con la pala, gancho/linterna/cuerdas dados por código en la última sesión, teletransportes
  (galería del Contador, interior de la sala, superficie, fondo de cuevas cuando el personaje se
  quedaba en un borde), fijar la cámara mirando al suelo para cavar en vertical y, solo para
  validar el arreglo de las palancas sin reconstruir la sala, poner `MaxActivationDistance = 4.6` en
  los tres indicadores durante una sesión (es el mismo valor que hay en el repositorio).

## 1. Resultados

### Arreglos pendientes del informe 1

| ID | Resultado | Evidencia | Atajos |
|---|---|---|---|
| Arranque | OK | `[Server] THE HOLE NEVER ENDS started`, `[PlotService] removing the template Baseplate`, ningún `failed to start`. | — |
| R1 Generación fuera del golpe | OK | 0 de 30 sectores generados dentro de un golpe; golpe máx. 1,90 ms. | Pico industrial |
| R2 Llegada a la Estación del Contador | OK | Montacargas → llegada en (22,1, −563,7, 45,5), centro de la plataforma; caminar 8 studs al O, S y E: dy ≈ 0 (antes caía 178 studs). | Teletransporte a la superficie |
| R3 Pantalla del Contador sin parpadeo | OK | La pantalla sube hasta «875» y no vuelve a mostrar glifos después; `cellsDug` = 875. | — |
| R4 Golpes perdidos en esquinas o al fondo | PARCIAL | Ningún golpe perdido en 4 descensos de hasta 311 m. Es intermitente; no reproduje el caso exacto del informe 1. | Pico/taladro |

### Iteración 5 (AUDIT §7)

| ID | Resultado | Evidencia | Atajos |
|---|---|---|---|
| V1 | PARCIAL | Capturas a 65 m (sepia) y 196–201 m (Cristal). **Cristal a 200 m se veía casi negro**: subido el ambiente (ver §4). Transición: para el usuario. | Taladro |
| V2 | NO PROBADA | Mezcla en los límites: visual. | — |
| V3 | NO PROBADA | Con la ventana de Studio sin foco el cliente se limita a 15 FPS en los tres modos (Auto/Bajo/Alto: 66 ms constantes). No es medible desde el MCP. Con «Alto» hay 2 emisores activos y con «Bajo» 1. | — |
| V4–V7 | NO PROBADA | Escenas de cueva: visual. Costes medidos en §2. | — |
| V8 | OK | A 311 m: 4 161 piezas en `World` (3 576 eran la superficie de las 8 parcelas vacías). Tras unir los travesaños de la valla: **1 928 piezas al empezar** (237 por parcela vacía, antes 447). | Taladro |
| V9 | NO PROBADA | Sensación de cada herramienta: visual. | — |
| V10 | OK | «Vendido por 20 monedas · conservas 11 pieza(s) para la vitrina»; los fragmentos siguen en la mochila. Botón «Vender» de una pieza: no probado. | Monedas |
| V11 | OK | F en la vitrina: «Expuesto en la vitrina: Fragmento antiguo», `collection.exhibit = {antique_fragment = true}`, la pieza se ve dentro (captura). Salir y volver: necesita guardado real. | — |
| V12 | PARCIAL | *Mochila → Descubrimientos*: las 6 colecciones con barra («Restos de quien vino antes 1/3» tras exponer). Partida antigua → «station_1»: necesita guardado real. | — |
| V13 | FALLA → arreglado | Con alcance 6, Roblox mantiene el indicador que apareció primero: delante del anillo II salía el I. Con 4, el propio quedaba fuera (4,13 studs). Con **4,6**, delante de cada palanca sale su anillo, vengas de un lado o del otro. La palanca de un anillo bloqueado deja de ofrecer «Girar»: OK. | Valor 4,6 puesto en sesión (ver arriba) |
| V14 | NO PROBADA | Fósil repetido. | — |
| V15 | FALLA → arreglado | Desde el labio funcionaba; 2 studs atrás, la pendiente suave del borde daba «Aquí no hace falta cuerda». Ahora el servidor prueba hasta 4,5 studs más adelante: desde esa misma posición, «Cuerda colocada (12 m)». | Taladro, teletransporte al borde |
| V16 | OK | Cientos de golpes sin ningún aviso de `swoosh.wav` en la consola. | — |

### Iteración 6 (AUDIT §8)

| ID | Resultado | Evidencia | Atajos |
|---|---|---|---|
| W1 | PARCIAL | Pasos: «Apunta al suelo...», «Cada bloque roto va a tu mochila...», «Tu mochila lleva minerales. Sube (R)...» con «▼ VENDER», «Reúne 100 monedas...», «Ya puedes comprar la Pala reforzada...» con «▼ GARAJE»; desaparece pasados los 25 m. **Fallo:** a 3 m R no hacía nada (el botón salía a partir de 8 m) y no se puede salir saltando: arreglado (2 m) y verificado. Salir y volver: necesita guardado. | 100 monedas |
| W2 | NO PROBADA | Necesita guardado real. | — |
| W3 | OK | Garaje → Equipo: Cuerda 25, Linterna 400, Detector 1 500 (con confirmación), Gancho 2 500. Al comprar: botones en la columna derecha y barra «Batería 60/60». | 20 000 monedas |
| W4 | PARCIAL | L: `PointLight` alcance 60, brillo 2,2; gasta 0,57/s (≈105 s con la batería básica). Segundo jugador: no probado. | — |
| W5 | PARCIAL | G a 117 m: «Resonancia: un cofre, muy cerca.»; segundo pulso: «El detector se está recargando.»; −12 de batería. La flecha: visual. | — |
| W6 | OK | A 134,5 m sin haber encontrado la sala: «Resonancia: algo que no es roca, cerca.». A 117 m ganaba un cofre más cercano (el detector señala lo más cercano: correcto según el código; la prueba de AUDIT era imprecisa). | — |
| W7 | PARCIAL → ajustado | T tira a 70 studs/s y se para antes de la pared, sin meterse en el terreno (vóxel final: aire). **Pero** en un pozo sin repisa soltaba al instante y volvías a caer. Ahora se queda agarrado 1,5 s (saltar suelta con más impulso). En pozos estrechos la pendiente frena el tirón antes del agarre; probar en una cámara grande. | Gancho dado por código |
| W8 | OK | Cavar no gasta (60/60 tras 134 m de excavación). Junto a la estación se recarga (36 → 60). | — |
| W9 | OK | A 311 m solo quedan cargadas las decoraciones de los sectores 7–9. | Taladro |
| W10 | OK → mejorado | Volver con la baliza recargaba 5 sectores en un fotograma (~4 ms; peor fotograma del servidor 23,2 ms frente a 16,6). Ahora es un sector por fotograma (dos cargas separadas 15 ms en la prueba). | Teletransporte |

### Pruebas anteriores repetidas o nuevas

| ID | Resultado | Evidencia |
|---|---|---|
| C2, C3 | OK | «La pala resbala...»; al abrir: `found=true`. |
| C6 | OK | Pantalla «875» = `stats.cellsDug` 875. |
| M7 | OK | Menú del montacargas con la Estación del Contador; viaje correcto. |
| M9 | OK | Baliza desde 311 m: «Te subirá hasta Estación del Contador. Coste: 171»; «Rescatado hasta Estación del Contador (-171 monedas)». |
| Resto de S, F, C, M | Sin cambios | Mismo estado que en `STUDIO_REPORT_1.md`. |

## 2. Rendimiento (servidor de Studio, `os.clock`)

| Medida | Valor |
|---|---|
| `GenerateSlab` (n=30) | mín. 1,18 · mediana 1,48 · p90 2,60 · **máx. 3,51 ms**; 0 dentro de un golpe |
| Golpe completo (n=87, pico industrial) | mediana 0,65 · p90 1,17 · **máx. 1,90 ms** |
| Sala del Contador | 2,11 ms |
| `CaveScenes.build` por sector | 0,19–0,96 ms; 15–77 piezas |
| `CaveProps.decorate` por sector | 0,22–0,73 ms; 22–35 piezas |
| Recarga de 5 sectores al volver (antes del arreglo) | ~4 ms en un fotograma; peor `Heartbeat` 23,2 ms (normal 16,6) |
| Piezas en `World` a 311 m | 4 161 (subsuelo de la parcela: 559; superficie de 8 parcelas: 3 576) |
| Piezas en `World` al empezar, tras unir la valla | 1 928 (237 por parcela vacía) |
| Luces en `World` a 311 m | 99 |
| A 1000 m | NO PROBADO (no llegué) |
| FPS del cliente | No medible desde el MCP (ventana sin foco = 15 FPS fijos) |

## 3. Fallos encontrados y arreglados

| # | Gravedad | Fallo | Arreglo | Studio |
|---|---|---|---|---|
| 1 | **Alta** | **El hierro (40–400 m) era césped.** `Granite` no es un material de terreno: Roblox escribe `Grass`. El hierro se veía como césped verde con briznas bajo tierra y el cliente lo etiquetaba «Césped». | `WoodPlanks` (el único material libre) con el color del hierro. Test nuevo: todo `terrainMaterial` debe ser un material de terreno real y no repetirse. | OK (393 vóxeles WoodPlanks, 0 de césped entre 25 y 115 m) |
| 2 | Media | Texto «Label» (y luego «Nos está contando.») fijo en el centro de la pantalla: el contorno del cartel se ve aunque el texto sea transparente. | Texto vacío al empezar y al acabar el fundido. | OK (captura) |
| 3 | Media | A 2–8 m no había forma de subir: R dependía del botón, que salía a 8 m, y el tutorial pide subir a ~3 m. | `ReturnButtonMinDepth` 8 → 2. | OK |
| 4 | Media | Palancas del Contador: salía el indicador del anillo equivocado. | Alcance 6 → 4,6. | OK (validado con el mismo valor) |
| 5 | Media | Cuerda desde el borde: había que estar justo en el labio. | El servidor prueba también a 5,5, 7 y 8,5 studs, con las mismas comprobaciones. | OK |
| 6 | Baja | El panel ⚙ quedaba abierto encima de la Mochila y tapaba su botón de cerrar y «Vender todo». | Abrir Mochila, garaje o un menú de movilidad cierra ⚙, y viceversa. | OK |
| 7 | Baja | Recarga de decoración en un solo fotograma. | Un sector por fotograma, comprobando que la parcela sigue igual tras cada espera. | OK |
| 8 | Baja | Gancho inútil en pozos sin repisa. | Agarre de 1,5 s; saltar suelta con impulso 34. | PARCIAL |
| 9 | Media (rendimiento) | 447 piezas por parcela vacía, ×8 siempre. | Travesaños de la valla por tramo continuo: 237 por parcela. | OK (recuento) |
| 10 | Media (aspecto) | Cristal casi negro a 200 m. | Ambiente de Cristal (60,60,110) → (92,94,150) y del Abismo (24,40,52) → (34,56,70). | OK (capturas antes/después) |

## 4. Observaciones sin arreglar (para decidir)

- **Cavar desde un borde con E, mando o táctil:** cuando el personaje queda de pie en el borde de un
  hueco, el rayo central cae al fondo, fuera del alcance, y E no hace nada. Con ratón se apunta a
  otro sitio. Me pasó 4 veces bajando por cuevas. Propuesta: si el rayo central se va lejos, que el
  fallback apunte al suelo bajo los pies antes que «delante y abajo».
- **Los indicadores solo salen si están en pantalla:** es el comportamiento de Roblox. La tienda
  está dentro del garaje: hay que entrar y mirar al mostrador.
- **Hierro con textura de madera:** WoodPlanks coloreado. Si quieres otro aspecto, hace falta un
  `MaterialVariant` con una textura tuya (no invento IDs).
- **«[H] Instalar Estación de las Minas»** aparece aunque ya tengas la Estación del Contador en la
  misma capa (son estaciones distintas; correcto según las reglas actuales).

## 5. Para que lo mires tú

Prepara: `rojo serve`, *Connect* (y *Accept* si Rojo lo pide), Play.

- **Luz por capas:** baja por el centro; capturas de referencia a 65 m y a 196 m (antes/después).
  ¿Cristal se lee azul violeta sin quedar plano? ¿El Abismo (650 m+) sigue siendo el más oscuro?
- **Hierro:** entre 40 y 400 m, vetas de WoodPlanks color pardo grisáceo. ¿Aceptable hasta tener
  textura propia?
- **Valla de la parcela:** travesaños largos en lugar de por tramos; debe verse igual.
- **Escenas (V4–V7):** raíles, vagoneta, campamento de E., flechas de tiza hacia el Contador,
  cristales y corazón de cristal (150–350 m). Que nada flote ni estorbe al cavar.
- **Gancho:** en una cámara grande, T hacia una pared a menos de 40 studs: ¿se agarra, se puede
  cavar un hueco o saltar a una repisa?
- **FPS (V3):** con la ventana de juego activa, Ctrl+Shift+F5 en Bajo y en Alto, a 65 m y a 200 m.
- **Móvil:** *Test → Device* (por ejemplo iPhone SE): barra inferior, columna de equipo, ⚙,
  tutorial y menús. El MCP no permite cambiar el emulador.

## 6. Lo que tienes que probar tú (no se puede con el MCP)

Con **dos jugadores** (*Test → Clients and Servers*, 2 jugadores):
- **S6:** el otro ve el gesto, oye el golpe y ve la rotura.
- **C5:** el segundo jugador gira una palanca de tu sala: «La máquina no reacciona a tu mano.».
- **M4:** el segundo no puede recoger tus cuerdas.
- **W4:** el segundo ve la luz de tu linterna.

Con el **lugar publicado y API Services activado**:
- **G1:** jugar 5 min, salir y entrar: todo se conserva.
- **G2:** cerrar Studio a la fuerza y volver a entrar.
- **G3:** perfil antiguo carga sin pérdidas.
- **W2:** los ajustes se conservan.
- **F4, F5:** fósiles extraídos no reaparecen; perfil antiguo.
- **C8:** la sala sigue resuelta tras volver.
- **M5:** las cuerdas colocadas siguen ahí.
- **V11, V12:** vitrina tras volver; partida antigua continúa la cadena.
