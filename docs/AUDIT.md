# Auditoría técnica y de diseño

Auditoría hecha sobre el repositorio real (rama `claude/modest-albattani-hcyxrm`), no sobre los
informes anteriores. **Acceso a Roblox Studio: ninguno.** El entorno es un contenedor en la nube sin
Studio, y no hay ninguna sesión de Claude en tu PC conectada a este trabajo. Todo lo que figura como
"verificado" se ha comprobado con:

- compilación Luau de todos los scripts;
- análisis de tipos contra las definiciones de la API de Roblox;
- 31 tests de lógica e integración (`tests/run.lua`);
- mediciones de rendimiento en la VM de Luau (`tests/bench_generation.lua`);
- cortes renderizados del subsuelo generado (`tools/render`).

La física, la red, el aspecto visual, el audio y los DataStores **no se han ejecutado nunca**.

## 1. Estado real de cada sistema

| Sistema | Estado | Dónde | Notas |
|---|---|---|---|
| Excavación autoritativa en servidor | Implementado, sin probar en Studio | `DiggingService.handleDig` | Validación completa: tipos, frecuencia, cooldown, alcance, parcela, línea de visión, potencia y energía |
| Terreno por vóxeles y regeneración | Implementado | `TerrainChunkService`, `Logic/OreGeneration` | Generación movida fuera del golpe en esta iteración |
| Cuevas | **Reescrito en esta iteración** | `Logic/Caves`, `CaveProps`, `SpecialsService` | Antes: una elipse por bloque de 8×8×8 |
| Geodas | **Estructura física nueva** | `Logic/Caves` (huecos), `CaveProps.geode`, `SpecialsService.openGeode` | Antes: solo un objeto de inventario |
| Fósiles, reliquias, artefactos | Parcial | `Config/Resources` (`find`) | Solo objetos vendibles: no tienen forma física, no aportan información ni tienen otros usos |
| Anomalías únicas | No existe | — | |
| Registro de descubrimientos | Parcial | `UI/InventoryUI` | Falta dónde se encontró cada cosa (profundidad) |
| Notas e hitos de historia | Implementado (2 hitos y una nota) | `Config/Story`, `SpecialsService` | Solo texto: faltan estructuras, máquinas y grabaciones |
| Misiones | Implementado (cadena fija de 12) | `Config/Quests`, `Logic/QuestLogic` | Sin misiones opcionales ni temporales |
| Expediciones y equipamiento | No existe | — | Solo herramienta, mochila y batería |
| Linterna / detector como equipo | No existe | — | La linterna de cabeza es automática y el "detector" es un resaltado gratuito |
| Movilidad (cuerda, gancho, jetpack) | No existe | — | Solo teletransporte a la superficie |
| Casa y garaje evolutivos | No existe | `WorldBuilder` | Construcción fija |
| Multijugador | Parcial | `PlotService` | Parcelas separadas; el permiso de colaborador existe sin interfaz |
| Guardado | Implementado, sin probar en Studio | `PlayerDataService` | Bloqueo de sesión, reintentos, versión 2 con migración |
| Audio | Sin verificar | `Config/Sounds` | Rutas `rbxasset://` que no he podido comprobar que existan |
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
