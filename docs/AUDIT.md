# Auditoría técnica y de diseño

Auditoría hecha sobre el repositorio real (rama `claude/modest-albattani-hcyxrm`), no sobre los
informes anteriores. **Acceso a Roblox Studio: ninguno.** El entorno es un contenedor en la nube sin
Studio, y no hay ninguna sesión de Claude en tu PC conectada a este trabajo. Todo lo que figura como
"verificado" se ha comprobado con:

- compilación Luau de todos los scripts;
- análisis de tipos contra las definiciones de la API de Roblox;
- 49 tests de lógica e integración (`tests/run.lua`, iteración 4) y comprobaciones estáticas (`tests/static_checks.lua`);
- mediciones de rendimiento en la VM de Luau (`tests/bench_generation.lua`, `tests/bench_width.lua`);
- cortes renderizados del subsuelo generado (`tools/render`).

La física, la red, el aspecto visual, el audio y los DataStores **no se han ejecutado nunca**.

## 1. Estado real de cada sistema

| Sistema | Estado | Dónde | Notas |
|---|---|---|---|
| Excavación autoritativa en servidor | Implementado, sin probar en Studio | `DiggingService.handleDig` | Validación completa: tipos, frecuencia, cooldown, alcance, parcela, línea de visión y potencia. **Ya no gasta energía** (decisión de diseño) |
| Sensación del golpe | **Nuevo en la iteración 3**, sin probar en Studio | `DigController`, `EffectsController`, `Config/DigFeel`, `Util/HardnessView` | Impacto sincronizado con la animación, barra de dureza, preajustes por material, hallazgos por niveles |
| Terreno por vóxeles y regeneración | Implementado | `TerrainChunkService`, `Logic/OreGeneration` | Generación movida fuera del golpe en esta iteración |
| Cuevas | **Reescrito en esta iteración** | `Logic/Caves`, `CaveProps`, `SpecialsService` | Antes: una elipse por bloque de 8×8×8 |
| Geodas | **Estructura física nueva** | `Logic/Caves` (huecos), `CaveProps.geode`, `SpecialsService.openGeode` | Antes: solo un objeto de inventario |
| Fósiles | **Nuevo en la iteración 3**, sin probar en Studio | `Config/Fossils`, `Logic/FossilBeds`, `Logic/Collection`, `CaveProps.fossil` | 7 especies con modelo físico, colección con profundidad y texto, sesgo de novedad |
| Reliquias y artefactos | Parcial | `Config/Resources` (`find`) | Siguen siendo objetos vendibles; se convertirán en piezas narrativas (ver `DESIGN_MOBILITY_AND_MINES.md`) |
| Anomalías únicas | **El Contador** (iteración 4), sin probar en Studio | `Logic/CounterPuzzle`, `AnomalyService`, `CounterRoomBuilder`, `CounterController` | Sala reservada en 136–141 m, enigma de 3 anillos, secuencia con el contador real |
| Registro de descubrimientos | Parcial | `UI/InventoryUI`, `Config/Journal` | Fósiles con profundidad; diario con entradas que crecen (iteración 4); los minerales todavía no |
| Notas e hitos de historia | Implementado (2 hitos y una nota) | `Config/Story`, `SpecialsService` | Solo texto: faltan estructuras, máquinas y grabaciones |
| Misiones | Implementado (cadena fija de 12) | `Config/Quests`, `Logic/QuestLogic` | Sin misiones opcionales ni temporales |
| Expediciones y equipamiento | No existe | — | Solo herramienta, mochila y batería |
| Linterna / detector como equipo | No existe | — | La linterna de cabeza es automática y el "detector" es un resaltado gratuito |
| Movilidad | **v1** (iteración 4), sin probar en Studio | `MobilityService`, `UI/MobilityUI`, `Config/Mobility`, `Util/MobilityRules` | Cuerda, estaciones del montacargas, baliza; retorno libre solo hasta 50 m. Gancho y jetpack pendientes |
| Casa y garaje evolutivos | No existe | `WorldBuilder` | Construcción fija |
| Multijugador | Parcial | `PlotService` | Parcelas separadas; el permiso de colaborador existe sin interfaz |
| Guardado | Implementado, sin probar en Studio | `PlayerDataService` | Bloqueo de sesión, reintentos, **versión 4** con migraciones desde v1–v3; tests de sesión con DataStore simulado (iteración 4) |
| Audio | Sin verificar | `Config/Sounds` | Cada sonido lleva `verified = false` y su propósito; prueba F7 en Studio (`SoundTestController`) |
| Animaciones | Provisional | `EffectsController.swingOffset` | Rotación procedural del hombro, sin assets de Animator |

## 2. Hallazgos priorizados

### P0: corregidos en esta iteración

| # | Problema | Archivo / función | Medición o prueba | Arreglo |
|---|---|---|---|---|
| 1 | La generación de cada chunk de 16 m corría **dentro del golpe** que cruzaba el límite: 55–90 ms bloqueando el servidor. | `TerrainChunkService.onDugTo` → `ensureDepth` | `tests/bench_generation.lua` | Cola en segundo plano por capas de 4 celdas con un presupuesto de 4 ms por frame. El golpe ya no genera nada. |
| 2 | El hash costaba 5,4 µs por llamada (emulaba multiplicaciones de 64 bits). | `Util/Hash.int` | Benchmark | Multiplicadores de 21 bits, exactos en doubles: 1,4 µs. Tests de independencia entre celdas vecinas, ejes, sales y semillas. |
| 3 | El arnés de tests usaba `setfenv`, que desactiva las optimizaciones de Luau y **duplicaba los tiempos medidos**. | `tests/harness.lua` | Comparación directa | Los módulos se cargan con `loadwrapped` (nombres inyectados como locales). |
| 4 | Cuevas repetitivas: la misma elipse en cada bloque. | `OreGeneration.caveInBlock` (eliminado) | Cortes renderizados | Nuevo `Logic/Caves`: galerías, 4 tipos de cámara, chimeneas, pozas y geodas, con sistemas conectados. |
| 5 | Una galería que pasaba junto a una poza dejaba **agua tocando aire**, que en Roblox se vería flotando. | `Logic/Caves` (encontrado por un test nuevo) | Test "pools are contained" | Paso final que vacía el agua sin contención. |
| 6 | Bandera del trabajador de generación puesta tarde: con `task.defer` arrancarían dos trabajadores. | `TerrainChunkService.requestDepth` | Test de la cola | La bandera se pone antes de lanzar el trabajador. |

### P1: decisiones de diseño que necesito que tomes

| # | Problema | Dónde | Propuesta |
|---|---|---|---|
| 7 | **Doble límite artificial**: la mochila y la batería obligan a volver, y la energía no aporta ninguna decisión. Va contra el punto 9 del encargo. | `EnergyService`, `Config/Upgrades` | Quitar la energía como freno y convertir la batería en un recurso táctico (golpe cargado, detector, linterna potente) que forme parte de la preparación de expediciones. |
| 8 | **El teletransporte gratuito a la superficie** elimina el viaje y la orientación. | `DiggingService` (`ReturnToSurface`) | Sustituirlo por puntos de acceso que se desbloquean (montacargas o cabrestante por cada 50 m alcanzados) más cuerda y gancho como equipo. |
| 9 | **Área excavable de 16×16 celdas (64 studs)**: limita el tamaño horizontal de las cuevas. Las cámaras ya ocupan casi todo el ancho. | `GameConfig.PlotDigCells`, `Grid.key` | Ensanchar solo el subsuelo (por ejemplo 40×40 por debajo de 10 m) manteniendo la boca de 16×16 en la superficie. Exige migrar las claves de celdas guardadas y multiplica las celdas por chunk por ~5,4, así que el coste pasaría de ~20 ms (medido) a unos 110–120 ms (estimado, no medido), repartidos en segundo plano. |
| 10 | **Sonidos sin verificar**: el encargo pide no inventar identificadores. Las rutas `rbxasset://sounds/...` son sonidos internos del cliente que no he podido comprobar. | `Config/Sounds` | Verificarlos en Studio o sustituirlos por audio propio subido por ti. Si falta alguno, el código no falla: simplemente no suena. |

### P2: corregir antes de activar las funciones relacionadas

| # | Problema | Dónde | Riesgo | Propuesta |
|---|---|---|---|---|
| 11 | Cofres y geodas en parcela ajena: la clave "abierto" se guarda en el perfil del **dueño** y el premio en el del **colaborador**. Si el servidor cae entre los dos guardados, el colaborador podría cobrar dos veces. | `SpecialsService.claimOpen` | Solo cuando existan colaboradores (aún sin interfaz) | Pagar solo al dueño, o guardar el id abierto también en el perfil de quien lo abre. |
| 12 | Las decoraciones de cuevas se acumulan con la profundidad (estimado: unas 30–60 piezas por sector de 32 m) y nunca se descargan. | `CaveProps.decorate` | Miles de piezas a 1 500 m con 8 parcelas | Medir en Studio; descargar los sectores lejanos de cualquier jugador. |
| 13 | Todo se vende, incluidos fósiles y reliquias. | `InventoryService.sellAll` | Contradice "no todo debe convertirse en dinero" | Marcar objetos de colección y no venderlos por defecto. Darles usos: investigación, vitrinas, mejoras. |
| 14 | El registro no dice dónde se encontró cada cosa. | `InventoryService.collect`, `UI/InventoryUI` | Pérdida de información | Guardar la profundidad y la zona del primer hallazgo. |
| 15 | Se envía el estado completo en cada cambio. | `StateService.push` | Ancho de banda (bajo ahora) | Enviar solo lo que ha cambiado cuando crezca el perfil. |

### P3: pulido

- La tienda reconstruye todas las vistas previas 3D en cada cambio de estado mientras está abierta (`UI/ShopUI.render`).
- Al reaparecer, el personaje sale en el hub y luego se teletransporta (parpadeo).
- El sonido del golpe se reproduce al enviar la petición y no en el momento del impacto de la animación (`DigController`).
- No hay indicador de la dureza restante de la celda apuntada (`DigController.updateHighlight`).

## 3. Límites del motor de excavación

| Límite | Consecuencia | Cómo se trabaja con él |
|---|---|---|
| Vóxel mínimo de 4 studs | Los detalles finos (raíces, vetas finas) no pueden ser terreno | Detalles con piezas dentro de huecos (geodas, hitos, decoración) |
| 22 materiales de terreno con color global; **21 ya en uso** | No se pueden añadir más recursos visibles como terreno | Nuevos hallazgos como estructuras con piezas. Hay `MaterialVariant`, pero sigue siendo uno por material |
| Terreno suave | Aspecto redondeado, no cúbico | Es el aspecto elegido; el daño parcial reduce la ocupación |
| Agua de terreno estática | No fluye | Pozas contenidas por roca, comprobadas por test |
| Coste de `WriteVoxels` por golpe y su replicación | Golpes con radio grande cuestan más | Una sola escritura de la caja mínima (~1,4 ms con radio 3) |
| Área de 16×16 celdas | Cuevas de 64 studs de ancho como máximo | Ver P1-9 |

## 4. Cómo verificar en Studio lo hecho en esta iteración

1. `rojo serve`, conecta, Play. Abre el **MicroProfiler** (Ctrl+F6) en la vista del servidor
   (*Test → Clients and Servers*, ventana del servidor).
2. Cava en vertical desde la superficie. Cada vez que cruces un múltiplo de 16 m, busca las etiquetas
   `THNE.GenerateSlab`: deben aparecer repartidas en varios frames, cada una de unos pocos ms, y
   **nunca** dentro de `THNE.Dig`. Anota los tiempos reales.
3. Baja a 64–100 m (zona Minas Olvidadas). Deberías encontrar galerías rectangulares de unos 3 m de
   alto con puntales de madera y faroles. Al abrir una: aviso "¡Has abierto una cueva!", misión
   "Explora una cueva".
4. Busca una cámara: en las Minas son sobre todo galerías alargadas o cámaras dobles, con farol y
   cajas. Si hay poza, el agua debe estar hundida en el suelo y no flotando.
5. Geoda: aviso "La roca suena hueca...", contorno violeta al acercarte. Mantén pulsada la tecla F
   con la pala oxidada → "La corteza es demasiado dura". Con la reforzada se abre: la cáscara se
   aparta, los cristales se encienden y recibes una Geoda y cristales. Sal y vuelve a entrar: no
   reaparece.
6. `docs/images/caves_section.png` (corte vertical) y `caves_plans.png` (plantas cada 4 m) muestran
   un ejemplo de la semilla 98765. Cada parcela tiene su propia semilla, así que tu agujero será
   distinto, pero los tipos de forma y sus tamaños deben parecerse.


## 5. Iteración 3: sensación del golpe, fósiles y propuestas

### Comprobado en la VM de Luau (sin Studio)
- Compilación de los 55 scripts y análisis de tipos contra la API de Roblox.
- 37 tests: preajustes completos por material, sonidos existentes, impacto antes del siguiente
  golpe en cada herramienta, lógica de la barra de dureza, batería oculta, fósiles (huecos sellados,
  profundidad válida, cobertura por parcela), colección (paga una vez) y migración v2 → v3.
- `tests/static_checks.lua`: todos los eventos remotos usados están declarados y todos los sonidos
  reproducidos existen. **Detectó un fallo real** (faltaba el evento `FossilFound`), ya corregido.
- `tests/bench_width.lua`: comparación aislada de anchuras (ver `PROPOSAL_WIDE_UNDERGROUND.md`).

### Pendiente de ejecutar en Roblox Studio
Todo lo visual, sonoro y de red de esta iteración. Lista concreta:

| # | Prueba | Qué debe pasar |
|---|---|---|
| S1 | Cavar tierra con la pala oxidada | El brazo sube, y al bajar suena el golpe con un poco de polvo marrón y un fragmento. **No** debe haber retraso apreciable entre el gesto y el sonido. |
| S2 | Golpear la misma celda hasta romperla | La barra de segmentos encima de la celda se vacía golpe a golpe; al romperse, ráfaga de fragmentos y sonido más grave. |
| S3 | Apuntar a pizarra (≈50 m) con la pala oxidada | Contorno rojo y "🔒 Pizarra · necesitas potencia 2". Al golpear: chispa y sonido de rebote, sin daño. |
| S4 | Golpear cobre, roca y cristal | Tres sonidos y partículas distinguibles; el cristal tintinea y brilla. |
| S5 | Encontrar oro (raro), rubí (épico) | Raro: brillo y campanilla. Épico: destello de luz y una línea de texto bajo el centro que desaparece a los ~2 s. Nunca en cada golpe. |
| S6 | Dos jugadores | El otro jugador ve el gesto, oye el golpe y ve la rotura a la vez. |
| S7 | F7 en Studio | Recorre todos los sonidos; la consola indica `loaded=true/false` y la duración de cada uno. Anota los que no carguen. |
| F1 | Cavar entre 6 y 60 m | Antes o después aparece "Algo con forma de hueso asoma en la roca..." con contorno color hueso. |
| F2 | Mantener F 2 s sobre el fósil | Los huesos suben y se desvanecen; ficha con nombre, rareza, profundidad y texto; aparece en *Mochila → Fósiles* con la profundidad. |
| F3 | Extraer una especie repetida | "(repetido): obtienes un Fragmento fósil"; la colección suma +1 y no se pagan monedas. |
| F4 | Salir y volver a entrar | Los fósiles extraídos no reaparecen; la colección se conserva. |
| F5 | Perfil guardado con la versión anterior | Carga sin perder inventario (el antiguo "Fósil raro" pasa a ser "Fragmento fósil"). |
| E1 | Cavar mucho rato | No aparece ninguna barra de energía ni el mensaje "Sin energía"; la mejora de batería no está en la tienda. |

### Sonidos pendientes de verificación
Todas las rutas de `Config/Sounds.lua` siguen sin verificar: `action_footsteps_plastic.mp3`,
`collide.wav`, `electronicpingshort.wav`, `swoosh.wav`, `clickfast.wav`, `button.wav` e
`impact_water.mp3` (todas en `rbxasset://sounds/`). Si alguna no carga, el juego sigue funcionando
sin ese sonido. El hallazgo de las Minas (diseño en `DESIGN_MOBILITY_AND_MINES.md`) necesitará
audio propio.

### Nuevos hallazgos de auditoría
| # | Gravedad | Problema | Estado |
|---|---|---|---|
| 16 | Alta | Evento remoto `FossilFound` usado pero no declarado: habría fallado en la primera extracción. | Corregido; `tests/static_checks.lua` lo impide en el futuro. |
| 17 | Media | Fósil "Huella de una pala" en solo el 31 % de las parcelas: colección imposible para la mayoría (cada jugador cava una sola parcela). | Corregido con sesgo de novedad y rango ampliado: todas las especies en el 84–100 % de las parcelas. |
| 18 | Media | Un ancho de 40 celdas multiplicaría por 6 la memoria de las cuevas cacheadas (~38 MB con la caché actual). | Documentado en la propuesta; no aplica mientras el ancho sea 16. |


## 6. Iteración 4: El Contador, movilidad v1 y pruebas de sesión

Tres niveles de verificación, separados a propósito:

### (a) Compilación y comprobaciones automáticas, hechas
- Los 66 scripts compilan (`luaucheck check`) y están formateados con `stylua`.
- `tests/static_checks.lua`: 51 usos de eventos remotos, todos declarados (incluidos los 8 nuevos de
  movilidad), y todos los sonidos reproducidos existen.
- Análisis de tipos, archivo por archivo, de los scripts nuevos o tocados. Solo quedan avisos del
  analizador sin el árbol de Rojo (`Key 'Shared' not found`, `pcall`), no errores reales.

### (b) Tests en la VM de Luau, hechos (49 en total, 12 nuevos)
- **Contador de bloques:** `stats.cellsDug` solo lo suma el servidor y sobrevive a un viaje de ida y
  vuelta por el DataStore. Nunca se calcula a partir del agujero (perfil con 1 247 bloques y 3
  celdas abiertas).
- **Sala del Contador** en 40 parcelas: sellada, con dos accesos que alcanzan las galerías y nada
  aleatorio dentro (ni cofres ni geodas).
- **Enigma:** solución distinta por parcela, nunca empieza resuelto, los anillos correctos se
  bloquean, se resuelve en 15 giros como mucho y el estado guardado se sanea.
- **Diario:** entradas y párrafos según los descubrimientos; los números se rellenan.
- **Perfil v3 → v4:** el Contador y la movilidad se sanean. Se descartan estaciones duplicadas,
  desconocidas o con NaN y cuerdas infinitas o de más de 80 studs.
- **Baliza:** gratis hasta 50 m, coste acotado, nunca más que las monedas que llevas, destino en la
  estación más cercana por encima. **Estaciones:** una por zona, separación mínima, la del Contador
  no se vende.
- **Sesiones** (`PlayerDataService` real con un DataStore simulado que serializa como el de verdad
  y varios «servidores»):
  1. Guardar al salir y volver a entrar en otro servidor conserva el contador, el Contador, las
     estaciones, las cuerdas, los rescates y los fósiles.
  2. Un segundo servidor espera mientras otro tiene la sesión y carga después los datos más
     recientes.
  3. El bloqueo de un servidor caído caduca, y su autoguardado tardío **no** sobrescribe al nuevo
     dueño.
  4. Si el jugador sale **mientras se carga** su perfil, el bloqueo se libera.
  5. Con el DataStore caído se juega con un perfil temporal que nunca sobrescribe los datos reales.

### (c) Studio: visual, sonido, red y rendimiento. **Primera pasada hecha: ver `STUDIO_REPORT_1.md`.**

**Verificado en Studio (2026-10-17, 1 jugador, lugar sin publicar):** arranque sin errores; tiempos
reales de `GenerateSlab` (mediana 2,5 ms, máx. 4,6 ms) y de la sala (2,6 ms, 273 piezas); S3, S7, F1, F2,
C2, C3, **C6 (el número coincide con `cellsDug`)**, C7, M2, M6, M7, M8, M9, M10, M11. Parciales: S1, S2, F3, E1,
C1, C5, M1, M3, M4. Sin probar: lo que necesita guardado real (G1–G3, F4, F5, C8, M5), dos jugadores
(S6, y la parte multijugador de C5 y M4) y lo solo audiovisual. `swoosh.wav` no carga.
Fallos 22–25 abajo.

Sigue en pie la lista de la sección 5 (S1–S7, F1–F5, E1). Nuevas pruebas, en este orden.
Preparación: `rojo serve`, publicar el lugar con **API Services activado** (si no, el guardado usa
un perfil temporal y las pruebas G no sirven) y *Test → Start* con 1 jugador. Las pruebas C5 y M4
necesitan un segundo jugador.

**El Contador** (para llegar rápido: cava en vertical en el centro de la parcela hasta ~120 m)

| # | Prueba | Qué debe pasar |
|---|---|---|
| C1 | Bajar de 80 a 130 m sin tocar la sala | Se oyen tres golpes y una pausa, apagados (sin agudos), cada vez más claros. Anota a qué profundidad empiezas a oírlos. |
| C2 | Seguir una galería del sector 128–160 m | Termina a 1–2 celdas de una pared lisa. La pared no se raya: «La pala resbala... Suena hueca.» |
| C3 | Abrir un acceso (oeste u este, a la altura de la galería) | Aviso «UNA SALA QUE NADIE EXCAVÓ», sonido, nueva entrada en *Mochila → Diario*. Dentro: los golpes cesan, se oye un zumbido. |
| C4 | Mirar la sala | Suelo negro con líneas de luz, escalera invertida, marco de puerta, pilar flotante, máquina con tres anillos que oscilan, pantalla con glifos cambiantes. Anota si algo se ve mal a escala. |
| C5 | Leer la placa (F) y girar las manivelas | Cada giro rota su anillo suavemente; el correcto encaja con un sonido y deja de oscilar. Un segundo jugador recibe «La máquina no reacciona a tu mano.». |
| C6 | Completar la combinación | Se apaga la luz, tres golpes, cada anillo se ilumina, el número sube hasta tu total y aparece «Nos está contando.». Comprueba que el número coincide con `stats.cellsDug` (consola del servidor: `print(require(game.ServerScriptService.Server.Services.PlayerDataService).get(game.Players:GetPlayers()[1]).stats.cellsDug)`). |
| C7 | Cavar 10 bloques más y volver a la sala | La pantalla muestra el número aumentado. |
| C8 | Salir y volver a entrar | La sala sigue resuelta, los anillos quietos, el número en vivo, la entrada «Nos está contando» con el número del día en que la resolviste. |

**Movilidad**

| # | Prueba | Qué debe pasar |
|---|---|---|
| M1 | Pulsar R o «↑ Superficie» a 30 m y luego a 60 m | A 30 m subes. A 60 m el botón ya no está, aparece «Baliza», y R abre la baliza. Si se fuerza el evento, el servidor responde «usa la baliza o un montacargas». |
| M2 | Comprar cuerdas (garaje → *Equipo*) | 25 monedas cada una, máximo 5; el contador «Cuerda ×n» aparece al bajar. |
| M3 | Q al borde de una cámara de 5–20 m | Cuelga una cuerda hasta el suelo. Se puede bajar y **subir** trepando. En suelo plano: «Aquí no hace falta cuerda». Sobre un pozo de más de 20 m: «No llega al fondo». Contra una pared: «No hay espacio». |
| M4 | Recoger la cuerda (F, desde arriba) | Vuelve al contador. Desde abajo no hay aviso para recogerla. Un segundo jugador no puede recoger las tuyas. |
| M5 | Salir y volver a entrar | Las cuerdas colocadas siguen ahí. |
| M6 | Entre 50 y 150 m | Aparece «[H] Instalar Estación de las Minas · ● 250». H la instala si tienes 250 monedas. Muy cerca de otra estación: «Demasiado cerca». |
| M7 | En la superficie, F en el panel del torno «MONTACARGAS» | Menú con Superficie y tus estaciones. Elegir una: fundido a negro y apareces en la plataforma. Desde la plataforma, F → Superficie te sube. |
| M8 | Resolver el Contador | Aparece la Estación del Contador en la sala y en el menú. |
| M9 | Baliza a 70 m con la mochila cargada | El diálogo muestra destino, coste y «Conservas la mochila...». Activar: barra de 4 s. Moverte o cavar la cancela con un mensaje. Quieto: fundido, apareces en la estación de arriba o en la superficie, se descuentan las monedas y la mochila sigue igual. Con 0 monedas también funciona («el resto se perdona»). |
| M10 | Menú de Roblox (Esc) | «Reiniciar personaje» está desactivado. |
| M11 | Morir por debajo de una estación (en la consola del servidor: `game.Players:GetPlayers()[1].Character.Humanoid.Health = 0`) | Reapareces en la estación más cercana por encima, no en la superficie. |

**Guardado real (G)** (necesita API Services, solo en un lugar publicado)

| # | Prueba | Qué debe pasar |
|---|---|---|
| G1 | Jugar 5 min, salir y volver a entrar | Todo se conserva: monedas, contador, estaciones, cuerdas, colección, diario. |
| G2 | Cerrar Studio a la fuerza (sin detener la prueba) y volver a entrar enseguida | Puede tardar unos segundos (bloqueo); nunca se pierden datos. Si te echa con «No pudimos cargar tus datos», espera y vuelve: no debe perderse nada. |
| G3 | Perfil de la iteración 3 | Carga como v4 sin perder nada; Contador y movilidad vacíos. |

**Rendimiento (anota los números reales)**: MicroProfiler en el servidor al revelar la sala
(construcción del modelo) y al colocar o recoger cuerdas (`rebuildRopes` reconstruye todas las de
la parcela, como mucho 12). Cuenta de piezas de la sala.

### Nuevos hallazgos de esta iteración
| # | Gravedad | Problema | Estado |
|---|---|---|---|
| 19 | Alta | Si el jugador salía **mientras** se cargaba su perfil, el bloqueo de sesión quedaba tomado hasta caducar (6 min): al volver a entrar enseguida, la carga esperaba y acababa echándolo. | Corregido en `PlayerDataService.load` y cubierto por un test de sesión. |
| 20 | Media | En el repositorio había 6,6 MB de paquetes descargados por error en `src/client` desde la fase 1 (`.whl` y `luau-0.4.22.tar.gz`). Rojo los ignora, pero inflan el repositorio. | Eliminados del árbol (siguen en el historial). |
| 21 | Baja | Morir devuelve gratis a una estación o a la superficie. Hoy casi no hay daño, así que no se puede abusar. | Documentado; revisar cuando haya peligros. |
| 22 | Media | (Studio) La generación de sectores ocurría dentro de `THNE.Dig` (`task.spawn` ejecuta en el acto). | Corregido con `task.defer`; **verificado en Studio** (0 de 7 sectores dentro del golpe). |
| 23 | Alta | (Studio) La llegada a la Estación del Contador queda medio dentro de la pared; al caminar se atraviesa el terreno y se cae ~45 m. | Corregido (llegada al centro de la plataforma); pendiente de volver a probar en Studio. |
| 24 | Alta | (Studio) Con terreno suave, golpes en esquinas o en el fondo de un pozo se ignoraban en silencio: se podía quedar atascado cavando hacia abajo. | Corregido (celda vecina más cercana al impacto); pendiente de volver a probar en Studio. |
| 25 | Baja | (Studio) Parpadeo de glifos al terminar la secuencia del Contador. | Corregido; pendiente de volver a probar en Studio. |

### Ensanchamiento del subsuelo
**No se ha tocado**, por decisión tuya. Los números de `PROPOSAL_WIDE_UNDERGROUND.md` salen de la VM
de Luau y son **orientativos**: no son rendimiento confirmado en Roblox. El siguiente paso es medir
en Studio (MicroProfiler: `THNE.GenerateSlab` con 16 celdas, y el mismo benchmark en un servidor
real) antes de diseñar la migración. Cualquier migración necesitará claves de celda versionadas,
una copia del perfil anterior para poder volver atrás, verificación al cargar y un interruptor para
desactivarla.


## 7. Iteración 5: aspecto, escenas, progresión y vitrina. Pruebas de Studio

Verificado **solo en la VM** (55 tests, compilación, comprobaciones estáticas). Nada de esta
sección se ha ejecutado en Studio. Preparación: `rojo serve` y *Play* con 1 jugador. La Baseplate
de la plantilla ya se elimina sola: la consola debe avisar `removing the template Baseplate`.

| # | Prueba | Qué debe pasar |
|---|---|---|
| V1 | Bajar cavando de 0 a 160 m | La luz cambia poco a poco: sepia y polvo marrón cayendo en las Minas; hacia los 150 m, paso suave al azul violeta con chispas que suben. No debe haber cortes bruscos. |
| V2 | Cerca de los límites de capa (50, 150, 350 m) | Mezcla gradual a lo largo de unos 12 m. |
| V3 | ⚙ → Bajo / Alto | Con Bajo hay claramente menos partículas en el aire y menos polvo. Anota los FPS en los dos casos (Ctrl+Shift+F5). |
| V4 | Galerías de las Minas (64–150 m) | Raíles en las galerías llanas, una vagoneta en algún fondo de saco y, en alguna cámara, el campamento de E. con su farol parpadeando y la tabla «E.». |
| V5 | Galerías que llevan al Contador | Flechas de tiza en el suelo apuntando hacia la sala. |
| V6 | Cámaras de 150–350 m | Cristales colgando del techo; en las cámaras grandes, un corazón de cristal que late. |
| V7 | Cualquier cámara | Estalactitas y estalagmitas. Comprueba que nada flota ni queda enterrado del todo y que **cavar alrededor de una escena no la deja colgando de forma rara** (es decoración, no terreno). |
| V8 | Contar piezas | Tras bajar a 300 m: `print(#workspace.World:GetDescendants())` en la consola del servidor. Anota el número. |
| V9 | Golpear piedra con la pala oxidada y luego con el pico minero | El pico suena más grave, levanta más polvo, suelta chispas y sacude un poco la cámara. Con ⚙ → Sacudida «No» deja de sacudir. |
| V10 | Llevar una reliquia (o el fragmento antiguo) y vender | «Vendido por X · conservas 1 pieza(s)»; la pieza sigue en la mochila con «se conserva» y su botón «Vender» funciona junto al carro. |
| V11 | F en la vitrina de la casa | «Expuesto en la vitrina: ...»; la pieza aparece girando dentro. Sal y vuelve a entrar: sigue expuesta. |
| V12 | Misiones | Con una partida que ya había terminado la cadena antigua, la siguiente misión es «Instala una estación del montacargas». *Mochila → Descubrimientos* muestra las colecciones con barras. |
| V13 | Contador: manivelas | Las tres palancas están al nivel del suelo, delante de la pantalla; cada anillo se gira sin saltar y la palanca de un anillo bloqueado deja de ofrecer «Girar». |
| V14 | Fósil repetido | Ya no da +225 monedas («Nuevo descubrimiento: Fragmento fósil» no debe aparecer con monedas). |
| V15 | Cuerda desde la boca | De pie en el borde del agujero, Q cuelga la cuerda hacia el interior. |
| V16 | Consola | Sin avisos de `swoosh.wav`. |


## 8. Iteración 6: equipo, tutorial, ajustes y descarga de decoración. Pruebas de Studio

Verificado **solo en la VM** (59 tests, compilación, comprobaciones estáticas con 62 usos de
eventos remotos). Para probar el equipo sin jugar horas, date monedas en la consola del servidor
durante la prueba (no en el repositorio).

| # | Prueba | Qué debe pasar |
|---|---|---|
| W1 | Partida nueva | Abajo aparece «Apunta al suelo del agujero y mantén pulsado...». Tras cavar: «Cada bloque roto va a tu mochila...». Con 10 bloques: «Sube (R) y véndelos» y un «▼ VENDER» que flota sobre tu carro. Tras vender: «Reúne 100 monedas...» y luego «▼ GARAJE». A 25 m desaparece. Sal y vuelve a entrar: no reaparece. |
| W2 | ⚙ → Bajo, sacudida No; salir y entrar | Los ajustes se conservan (necesita guardado real). |
| W3 | Garaje → Equipo | Tres tarjetas (Linterna 400, Detector 1 500, Gancho 2 500). Comprar una: aparece su botón en la columna derecha y la barra «Batería». |
| W4 | Linterna (L) en una cámara oscura | La cámara se ilumina; la batería baja (unos 100 s con la batería básica); al vaciarse se apaga con aviso. Un segundo jugador ve la luz. |
| W5 | Detector (G) cerca de una geoda oculta | Mensaje «Resonancia: una geoda, muy cerca.» y una flecha luminosa violeta hacia ella. Sin nada cerca: «Silencio». Pulsar dos veces seguidas: «se está recargando». |
| W6 | Detector entre 100 y 128 m sin haber encontrado El Contador | «algo que no es roca», con una flecha cian hacia la sala. |
| W7 | Gancho (T) apuntando a una pared de una cámara a menos de 40 studs | Una cuerda visible y un tirón hasta la pared, con un pequeño impulso hacia arriba. Apuntando fuera del agujero, al aire o demasiado lejos: mensaje y nada más. **Comprueba que no atraviesa roca ni deja al personaje dentro del terreno.** |
| W8 | Batería | Se recarga en la superficie y quieto junto a una estación tuya; cavar no la gasta nunca. |
| W9 | Descarga de decoración | Baja a 300 m y espera 5 s: `#workspace.World:GetDescendants()` baja respecto a V8, porque los sectores de 64–200 m dejan de tener decoración. Vuelve en el montacargas a las Minas: los raíles y faroles reaparecen en unos 4 s, en el mismo sitio. |
| W10 | MicroProfiler al volver con el montacargas | La reconstrucción de la decoración no debe dar tirones (anota los ms). |
