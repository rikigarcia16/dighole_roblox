# Auditoría técnica y de diseño

Auditoría hecha sobre el repositorio real (rama `claude/modest-albattani-hcyxrm`), no sobre los
informes anteriores. **Acceso a Roblox Studio: ninguno.** El entorno es un contenedor en la nube sin
Studio, y no hay ninguna sesión de Claude en tu PC conectada a este trabajo. Todo lo que figura como
"verificado" se ha comprobado con:

- compilación Luau de todos los scripts;
- análisis de tipos contra las definiciones de la API de Roblox;
- 37 tests de lógica e integración (`tests/run.lua`) y comprobaciones estáticas (`tests/static_checks.lua`);
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
| Anomalías únicas | No existe | — | |
| Registro de descubrimientos | Parcial | `UI/InventoryUI` | Los fósiles guardan la profundidad del primer hallazgo; los minerales todavía no |
| Notas e hitos de historia | Implementado (2 hitos y una nota) | `Config/Story`, `SpecialsService` | Solo texto: faltan estructuras, máquinas y grabaciones |
| Misiones | Implementado (cadena fija de 12) | `Config/Quests`, `Logic/QuestLogic` | Sin misiones opcionales ni temporales |
| Expediciones y equipamiento | No existe | — | Solo herramienta, mochila y batería |
| Linterna / detector como equipo | No existe | — | La linterna de cabeza es automática y el "detector" es un resaltado gratuito |
| Movilidad (cuerda, gancho, jetpack) | No existe | — | Solo teletransporte a la superficie |
| Casa y garaje evolutivos | No existe | `WorldBuilder` | Construcción fija |
| Multijugador | Parcial | `PlotService` | Parcelas separadas; el permiso de colaborador existe sin interfaz |
| Guardado | Implementado, sin probar en Studio | `PlayerDataService` | Bloqueo de sesión, reintentos, versión 3 con migraciones desde v1 y v2 |
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
