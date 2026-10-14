# Informe de las Fases 2 y 3 + revisión general

Como en la Fase 1: **nada de esto se ha ejecutado todavía dentro de Roblox Studio.** Todo está
compilado, analizado contra los tipos de la API de Roblox y cubierto por tests fuera del motor.

## Nuevo contenido

| Sistema | Qué hace | Dónde |
|---|---|---|
| **Cuevas** | Huecos naturales con forma de elipsoide desde 56 m (una como mucho por bloque de 8×8×8 celdas; 32–45 % según la zona). Más grandes a partir de las Cuevas de Cristal. Nunca tocan el anillo protegido. | `Logic/OreGeneration` |
| **Decoración por zona** | Minas: puntales de madera, viga y farol. Cristal, volcánica, abismo y núcleo: racimos de cristales luminosos. Cavernas antiguas: columna con glifo brillante. | `SpecialsService.decorateCave` |
| **Cofres** | En el 45 % de las cuevas, sobre el suelo. Monedas según la zona más 2–4 unidades de un mineral valioso. Solo se pueden abrir cuando la cueva se ha abierto cavando, y una sola vez por parcela (guardado). | `SpecialsService` |
| **Hallazgos ocultos** | Fragmento antiguo, Geoda, Fósil raro, Reliquia y Artefacto antiguo dentro de la roca. Aparecen al romperla y no ocupan mochila. | `Config/Resources` (`find`) |
| **Historia** | La caja del minero (~44 m) y la placa de piedra (~138 m), selladas en la roca hasta que cavas junto a ellas. Cada una abre una nota del diario de E. con recompensa. Cuando estás cerca, un "detector" las resalta a través de la roca. | `Config/Story`, `SpecialsService`, `DetectorController` |
| **Misiones** | Cadena de 12 misiones (las 10 del encargo más la caja del minero y llegar a las Minas). El progreso se calcula siempre a partir del perfil, así que nunca pagan dos veces. | `Config/Quests`, `Logic/QuestLogic`, `QuestService` |
| **Diario** | Nueva pestaña en la mochila: pistas leídas (se pueden releer) y estadísticas de cuevas, cofres y hallazgos. | `UI/InventoryUI` |
| **HUD de misión** | Misión actual, progreso, pista y recompensa. | `UIController` |
| **Perfil v2** | Misiones, pistas, cofres abiertos y estadísticas nuevas. Migración desde v1 y saneado de datos manipulados. | `Logic/ProfileSchema` |
| **Reequilibrio** | Precios del juego medio y avanzado y dureza de las rocas profundas. Núcleo en ~2 h 15 min estimadas (antes ~1 h 15 min). | `docs/BALANCE.md` |

## Revisión de todo el proyecto: fallos encontrados y corregidos

| # | Gravedad | Fallo | Arreglo |
|---|---|---|---|
| 1 | Alta | Si un jugador salía y otro entraba enseguida, la limpieza del terreno (que se hace por partes) podía borrar el terreno recién generado del nuevo dueño de esa parcela. | La parcela queda marcada como "liberándose" y no se reasigna hasta terminar. Si no queda otra libre, el jugador espera hasta 15 s. |
| 2 | Alta | Si alguien salía durante la generación de su parcela, la generación seguía escribiendo terreno después de la limpieza. | La generación comprueba antes de cada chunk que el dueño sigue siendo el mismo. |
| 3 | Alta | Un autoguardado que llegaba al DataStore después del guardado de salida volvía a poner el bloqueo de sesión: el jugador no podía entrar en otro servidor durante ~6 min. | El autoguardado se cancela dentro de `UpdateAsync` si la sesión ya se liberó. |
| 4 | Media | Un jugador que entraba justo al arrancar el servidor podía cargarse dos veces (dos sesiones, dos parcelas). | Registro de jugadores en carga. |
| 5 | Baja | Al abrir un cofre, los demás veían al jugador hacer el gesto de cavar. | Sin gesto cuando el efecto no es de excavación. |
| 6 | Baja | Condición duplicada en el texto de objetivo del HUD. | Eliminada. |

### Revisado sin problemas

- **Remotes** (`Dig`, `Sell`, `Shop`, `ReturnToSurface`, `GetState`): todos validan tipos y valores, tienen limitador de frecuencia y deciden en el servidor.
- **ProximityPrompts** (vender, cofre, hallazgo, nota): el servidor comprueba la distancia real y el estado (revelado, no abierto, permiso de parcela), así que disparar el aviso con exploits no sirve.
- **Dinero**: solo cambia en el servidor y siempre con cantidades enteras.
- **Fugas de memoria**: las tablas por jugador se limpian al salir. El estado subterráneo se destruye con la parcela. Las cachés de generación tienen límite.
- **Rendimiento**: una escritura de vóxeles por golpe. La generación de un chunk nuevo (cada 16 m) se hace dentro del golpe y puede causar un pequeño tirón. Hay que medirlo con el MicroProfiler y, si molesta, pasarlo a un hilo aparte.

### Riesgos conocidos (no corregidos)

- **Exploits de movimiento** (volar o atravesar paredes): el personaje lo controla el cliente, como en todo Roblox. Un tramposo podría ahorrarse viajes, pero no cavar más rápido, abrir cofres sin revelar ni generar dinero.
- **`Players.MaxPlayers`** debe ser 8 o menos (hay 8 parcelas por servidor). Ajústalo en *Game Settings → Places*.
- Sin acceso a la API de DataStore en Studio, la carga tarda unos 6 s en pasar al perfil temporal.

## Lista de prueba en Studio (además de la de la Fase 1)

| # | Prueba | Estado |
|---|---|---|
| 16 | Leer la nota de la casa → aparece en *Mochila → Diario* | ⬜ |
| 17 | Bajar a ~44 m: la caja del minero se resalta a través de la roca; al cavar al lado se puede examinar; +150 monedas una sola vez | ⬜ |
| 18 | Abrir una cueva por debajo de 56 m → aviso, misión "Explora una cueva" | ⬜ |
| 19 | Abrir un cofre: se levanta la tapa, monedas y minerales; al salir y entrar no vuelve a aparecer | ⬜ |
| 20 | Encontrar un fragmento antiguo / geoda: aviso "¡Hallazgo!", no ocupa mochila | ⬜ |
| 21 | Las misiones avanzan solas y la recompensa no se repite al reconectar | ⬜ |
| 22 | Dos jugadores: uno sale y entra otro enseguida → la parcela se regenera bien | ⬜ |
| 23 | Perfil guardado con la versión de la Fase 1 carga sin perder nada (migración v1 → v2) | ⬜ |

## Pendiente (fases siguientes)

- Fase 4: interfaz de invitaciones y permisos (el permiso de colaborador ya existe en el servidor), clasificaciones y pruebas de reconexión.
- Fase 5: ruinas grandes, laboratorio del Abismo, revelaciones 2 y 3, evento del núcleo, Herramienta ancestral.
- Herramientas especiales del apartado 8 (dinamita, bomba, escáner, baliza, plataforma, cuerda, gancho) y mejoras de movilidad.
- Audio propio, MeshParts propias y animaciones con Animator.
