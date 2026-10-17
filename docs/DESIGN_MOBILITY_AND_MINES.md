# Diseño: movilidad, expediciones y el hallazgo de las Minas

**Estado (iteración 4):** El Contador y la movilidad v1 (cuerda, estaciones del montacargas y baliza
de rescate) **están implementados y compilan**. La lógica pura y el guardado pasan los tests en la VM
de Luau. **Nada de esto se ha ejecutado todavía en Roblox Studio.** Los pasos exactos para
probarlo están en `docs/AUDIT.md`, sección 6.

Lo que sigue pendiente de diseño o de implementación (gancho, batería con equipo, expediciones) está
marcado como **Pendiente**.

---

## A. Movilidad

### Principios (sin cambios)
1. **Bajar la primera vez es una expedición; volver a un sitio ya conquistado es rápido.**
2. **La movilidad abre rutas, no se salta la excavación.**
3. **Nunca te quedas atrapado**, pero salir de un apuro tiene un coste razonable.

### Decisiones finales de la v1

| Herramienta | Regla implementada | Dónde |
|---|---|---|
| **Retorno libre** | El botón «↑ Superficie» (y la tecla R) solo funciona hasta **50 m**. El servidor lo rechaza por debajo con «usa la baliza o un montacargas». | `DiggingService` (`ReturnToSurface`), `Mobility.FreeReturnDepth` |
| **Cuerda** | Se compra en el garaje (pestaña *Equipo*, 25 monedas, máximo 5 encima). Se coloca con **Q** (L1 en mando, botón «Cuerda ×n» en táctil). Cuelga 4 studs delante del jugador y el servidor exige tres cosas: que cuelgue dentro de **tu** agujero, que entre tú y el anclaje haya espacio abierto, y que llegue a un suelo a **8–80 studs (2–20 m)**. Nunca queda colgando en el vacío. Es un `TrussPart`, así que se trepa en ambos sentidos. **Solo se recoge desde arriba**: no puedes quitarte la cuerda por la que tienes que subir. Hay un máximo de 12 colocadas por parcela y se guardan. | `MobilityService.placeRope/retrieveRope`, `Config/Mobility.Rope` |
| **Montacargas** | Hay un torno junto a la boca del agujero (cartel MONTACARGAS). La tecla F abre un menú con la superficie y tus estaciones, y el viaje es un fundido de 2,5 s. Solo se puede llamar a menos de 12 studs de una estación o a 16 del torno. | `WorldBuilder` (torno), `MobilityService.travel`, `UI/MobilityUI` |
| **Estaciones** | Una por zona, instalada **donde estás** al llegar a esa zona. Aparece el aviso «[H] Instalar Estación de las Minas · ● 250». Deben estar a 6 o más celdas de otra estación. Se guardan en el perfil (`mobility.stations`) y se reconstruyen al entrar. Comparten aspecto con el torno de la superficie: plataforma de madera, bordes de acero, cable que se pierde en la roca, farol y cartel con la profundidad. | `MobilityService.installStation`, `Mobility.Stations` |
| **Baliza** | Por debajo de 50 m aparece el botón «Baliza» (también con R). **Antes de activarla** muestra el destino, el coste, lo que pagas si no te llega el dinero y «Conservas la mochila, tus hallazgos y tu progreso». Tras 4 s quieto te lleva a la **estación más cercana por encima** (al menos 5 m más arriba) o a la superficie. Moverte más de 4 studs, cavar o morir la cancela. El precio se recalcula al pagar. | `MobilityService.startRescue`, `Util/MobilityRules.quote` |
| **Muerte** | Reapareces en la estación más cercana por encima del sitio donde moriste, o en la superficie. El botón de reiniciar del menú de Roblox está desactivado (`ResetButtonCallback = false`) para que no sea un viaje gratis. | `MobilityService` (resolver), `PlotService.setRespawnResolver` |

**Fórmula de la baliza** (en `Config/Mobility.Rescue`):

```
coste = clamp(0,5 × profundidad + 0,04 × valor_mochila, 10, 50 + 1,5 × profundidad)
pagas = min(coste, monedas que llevas)        -- el resto se perdona
```

- **Nunca** quita objetos, hallazgos, fósiles, notas ni progreso narrativo. Solo monedas, y nunca
  más de las que tienes, así que nadie queda atrapado por ser pobre.
- El tope por profundidad impide que la baliza sea un impuesto al éxito. Con una mochila enorme a
  100 m cuesta como mucho 200.
- Ejemplos (tests): a 60 m con la mochila vacía cuesta 30; a 70 m con 150 de valor, 41.

**Ampliable:** las estaciones de Cristal, Cavernas, Volcánica, Abismo y Núcleo ya están definidas
en `Mobility.Stations` con su rango y su precio. El perfil admite cualquier id conocido y descarta
los desconocidos sin fallar, de modo que volver a una versión anterior no rompe nada. Para añadir el
contenedor de estación o la recarga de batería en una estación basta con colgarlo del modelo de
estación (`buildStation`).

### Estaciones definidas

| id | Nombre | Rango (m) | Precio |
|---|---|---|---|
| `mines` | Estación de las Minas | 50–150 | 250 |
| `counter` | Estación del Contador | sala del Contador | **gratis**: la da la máquina al resolverla |
| `crystal` | Estación de Cristal | 150–350 | 1 500 |
| `ancient` | Estación de las Cavernas | 350–650 | 6 000 |
| `volcanic` | Estación Volcánica | 650–1000 | 20 000 |
| `abyss` | Estación del Abismo | 1000–1500 | 60 000 |
| `core` | Estación del Núcleo | 1500+ | 150 000 |

### Limitaciones conocidas de la v1
- El montacargas es un **fundido con teletransporte**, no una cabina física. Una cabina movida por
  el servidor con jugadores dentro es un riesgo de física en red que hay que medir en Studio antes de
  intentarlo.
- La cuerda se valida con raycasts contra el terreno del servidor. Si el sector de abajo todavía no
  se ha generado (la cola de generación va por delante, pero no está garantizado), el raycast puede
  no encontrar suelo y la cuerda se rechaza. Es un error seguro: nunca coloca una cuerda inválida.
- Morir sigue siendo una forma gratuita de volver, pero en este juego casi no hay daño (no hay daño
  por caída ni ahogamiento). Habrá que revisarlo cuando haya peligros reales (lava).
- Un jugador podría usar la cuerda para bajar a una cámara más rápido que cavando. Eso es
  intencionado: solo funciona sobre huecos abiertos y como mucho 20 m.

### La batería
La excavación normal **nunca** gasta batería, y la mejora sigue oculta en la tienda
(`hidden = true`). **Pendiente:** cuando exista el primer equipo que la use (detector de
resonancia o linterna potente), se reactiva la barra y se recarga en la superficie y en las
estaciones. La cuerda, las estaciones y la baliza no la usan.

### Pendiente (por este orden)
1. Gancho (cruzar huecos o subir paredes de cámaras): `LinearVelocity` controlada por el servidor
   tras validar un raycast.
2. Equipo con batería: detector de resonancia, linterna potente, golpe cargado.
3. Banco de expedición (sección B).

---

## B. Preparación de expediciones (pendiente, sin cambios)

En el garaje, un **banco de expedición** con huecos: herramienta, mochila, batería, iluminación,
detector, movilidad y rescate. Decisiones reales: pico frente a taladro, detector frente a escáner
(ambos con batería), más cuerdas frente a gancho.

---

## C. «El Contador»: el diseño tal como está construido

### Comprobación previa: el contador de bloques
`profile.stats.cellsDug` lo incrementa **solo** `DiggingService`, una vez por celda rota, en el
servidor. **No** se calcula a partir de las celdas que siguen excavadas: esas se pierden al
regenerar el terreno. El test «block counter: server stat survives save and load, never derived from
the hole» lo comprueba con un perfil de 1 247 bloques y solo 3 celdas abiertas. Los tests de sesión
(sección 6 de AUDIT) también lo comprueban en un viaje real entre servidores con un DataStore
simulado.

### Recorrido del jugador

| Fase | Implementación |
|---|---|
| **Aproximación** | La máquina emite **tres golpes y una pausa** (periodo de 2,6 s) con sonido 3D audible a 220 studs (~55 m). Mientras la sala está sellada, un ecualizador quita los agudos (suena «a través de la roca») y se aclara al acercarte. No hay marcadores ni flechas. Las dos galerías del sector 4 (128–160 m) **terminan junto a la sala** (`guided = true`): seguir galerías y el sonido lleva hasta ella. |
| **La pared** | La sala es una caja reservada de 8×6×8 celdas en el centro de la parcela (136–141 m). Su envoltura no se puede excavar: la pala resbala y suena hueca. Tiene dos accesos, al oeste y al este, a la altura de las galerías. |
| **Revelación** | Al abrir un acceso, aviso «UNA SALA QUE NADIE EXCAVÓ», sonido propio y entrada en el diario. Dentro, si no está resuelta, **los golpes cesan de golpe** y solo queda un zumbido. |
| **La sala** | Contraste deliberado con las Minas: suelo de vidrio negro con líneas de neón, paredes lisas, banda de luz fría. Elementos imposibles: una escalera invertida, un marco de puerta que no lleva a ningún sitio y un pilar inclinado que flota. |
| **La máquina** | Pedestal, columna, núcleo con luz que late al ritmo, pantalla con glifos que cambian y **tres anillos** con 6 glifos cada uno. Los anillos respiran (oscilan) hasta que encajan. |
| **El enigma** | Una placa en la pared norte muestra la respuesta: ●, ●● y ●●● seguidos de un glifo cada uno. Cada anillo tiene su manivela (F). Solo el dueño de la parcela puede girarlos. Un anillo correcto se bloquea con un sonido. La solución depende de la semilla, nunca empieza resuelta y se resuelve en 15 giros como mucho. |
| **Secuencia** | Se apaga la luz, suenan tres golpes y cada uno ilumina un anillo. Después el número sube hasta el **total exacto de bloques excavados** (`cellsDug`) y aparece «Nos está contando.». Lo ve todo el que esté a menos de 160 studs. Desde entonces la pantalla muestra el contador **en vivo**: sube mientras sigues cavando. |
| **Recompensa** | La **Estación del Contador** (gratis), un acceso permanente a ~140 m que convierte la sala en un punto de regreso. Además, entrada narrativa. No hay objeto ni venta: el misterio no se reduce a un ítem. |
| **Diario** | `Config/Journal` + `Util/JournalView`. «Una sala que nadie excavó» al encontrarla; «Nos está contando», con el número del día en que la resolviste. Los párrafos de esa entrada **crecen** con descubrimientos posteriores: la huella fósil de pala, llegar a las Cuevas de Cristal, la criatura de cristal. Está en *Mochila → Diario*. |

### Persistencia
`profile.anomalies.counter = { found, solved, rings, solvedCount, solvedAt }` (perfil v4, migración
sin pérdida desde v3). Si los anillos guardados no son válidos, el enigma vuelve a la posición
inicial de la semilla. La sala se reconstruye al generar el sector y recuerda si está resuelta.

### Limitaciones
- **Audio provisional:** `counter_knock`, `counter_hum`, `counter_lock` y `counter_found` usan
  sonidos internos sin verificar. El Contador necesita audio propio (golpe grave de madera y metal,
  zumbido de sala), y es el primer sitio donde es imprescindible.
- El «detector de resonancia» propuesto como segunda recompensa **no** está implementado: depende
  del equipo con batería.
- No se ha visto nunca la sala renderizada en Roblox. Escala, iluminación y legibilidad de la placa
  están sin validar.
