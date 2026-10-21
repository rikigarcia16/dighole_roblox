# Auditoría de juego: THE HOLE NEVER ENDS

Auditoría del repositorio real: rama `claude/modest-albattani-hcyxrm`, base `c9236b4`, árbol de
trabajo limpio. Se ha contrastado con la primera pasada en Roblox Studio
(`docs/STUDIO_REPORT_1.md`). La auditoría técnica detallada sigue en `docs/AUDIT.md`; este documento
mira el juego como experiencia.

**Niveles de verificación** (se usan en todo el documento):
- **[Studio]** ejecutado en Roblox Studio (informe 1);
- **[VM]** comprobado con tests en la VM de Luau;
- **[código]** solo leído en el código, nunca ejecutado.

## 1. Estado real del juego

Es un juego de excavación con autoridad del servidor. La partida empieza en una parcela de 16×16
celdas con casa y garaje. El terreno de vóxeles se genera por sectores y en segundo plano. Hay
7 zonas hasta más de 1 500 m, 10 herramientas y 3 mejoras visibles (mochila, velocidad y alcance;
la batería está oculta). Hay cuevas en sistemas conectados, geodas, cofres, 7 fósiles, 3 notas, una
cadena de 12 misiones, El Contador (sala, enigma y diario) y movilidad v1 (cuerda, montacargas y
baliza). El guardado usa DataStore con bloqueo de sesión y está en la versión 4.

**El bucle principal funciona** [Studio]: excavar, recoger, vender y comprar. El Contador, el
montacargas, la baliza y la reaparición se han probado en Studio con un jugador. El simulador de
economía [VM] llega a la zona 7 en unas 2 horas de juego estimadas.

## 2. Sistemas

| Estado | Sistemas |
|---|---|
| **Funcionan** | Excavación y dureza [Studio]; generación por sectores sin bloquear el golpe [Studio, arreglado]; venta y tienda [Studio]; fósiles F1–F3 [Studio]; El Contador C2–C7 [Studio]; montacargas, baliza y reaparición [Studio]; guardado y sesiones [VM]; validación de eventos remotos con límites de frecuencia [código + comprobación estática] |
| **Parciales** | Sonido: todos los archivos internos cargan, pero son genéricos y no hay audio propio [Studio]. Decoración de cuevas: correcta pero escasa y repetitiva [código]. Ambiente por zona: solo cambian luz y niebla [código]. Misiones: la cadena acaba a 150 m [código]. Herramientas: solo cambian estadísticas y modelo, sin identidad propia al golpear [código] |
| **Desconectados** | Las reliquias y los artefactos (`find`) se venden con el resto de la mochila, así que no hay decisión entre vender y conservar [código]. La batería está oculta a propósito. `balance_sim` todavía compra batería |
| **Pendientes** | Gancho, equipo con batería, expediciones, menú de ajustes, tutorial guiado (hoy solo hay misiones), casa que evolucione con el progreso, pruebas con dos jugadores [Studio], guardado real [Studio] |

## 3. Problemas críticos

Los fallos 1–4 del informe de Studio ya están arreglados: 1 y 4 en `31e01c7`, 2 y 3 sin volver a
probar en Studio. Las decisiones 7–11 están en `c9236b4`. Queda abierto:

| # | Problema | Impacto |
|---|---|---|
| G1 | **Por encima de 150 m no hay objetivos.** La cadena de misiones acaba en «Llega a 150 m». Las 5 zonas siguientes no tienen misiones, colecciones con recompensa ni pistas nuevas. | Es el mayor riesgo de abandono: hay 20–120 minutos de juego sin dirección. |
| G2 | Vender lo vende **todo**, incluidas las reliquias. | Las piezas narrativas se convierten en dinero y no hay decisión. |
| G3 | Una nota abierta se queda debajo del menú del montacargas. | Interfaz confusa (informe, punto 12). |
| G4 | El guardado real y el multijugador no se han probado en Studio. | Riesgo de pérdida de datos en publicación (los tests VM lo mitigan). |

## 4. Problemas visuales y de presentación

1. **Todas las zonas se ven casi iguales bajo tierra.** Solo cambian el color ambiente y la niebla.
   No hay gradación de color, partículas en el aire ni sensación de profundidad dentro de una zona.
2. **Decoración escasa:** 2–5 piezas por cámara. Las galerías mineras tienen puntales y faroles,
   pero no raíles, vagonetas, herramientas abandonadas ni campamentos. Las cuevas de cristal no
   tienen cristales en techo ni paredes. No hay nada que dé escala en las cámaras grandes.
3. **Nada se mueve:** las luces son fijas, los cristales no laten y no cae polvo.
4. **Las herramientas no se distinguen al golpear:** todas producen el mismo tipo de golpe; solo
   cambian el sonido y el modelo de la mano.
5. **Interfaz:** funcional pero genérica, sin menú de ajustes (calidad de efectos, volumen). El
   informe pide comprobar si las etiquetas superiores quedan cortadas.

## 5. Oportunidades de contenido y progresión

- **Misiones por zona** que lleven por cada capa: un mineral nuevo, una cueva, un fósil de la zona,
  una geoda, una estación y una pista narrativa.
- **Colecciones con recompensa:** completar los minerales de una zona y completar los fósiles.
- **Vitrina:** las reliquias se conservan por defecto. Se puede venderlas una a una o exponerlas,
  y exponerlas suma a la colección y al diario.
- **Escenas por estilo de cueva** que cuenten algo: el campamento de E. en las Minas, cristales
  gigantes en las Cuevas de Cristal, arcos rotos en las Cavernas, columnas de basalto con brasas en
  las Volcánicas y vegetación luminosa en el Abismo.
- **Vida ambiental en el cliente:** luces que parpadean, cristales que laten, polvo que cae del
  techo. Solo cerca del jugador.

## 6. Riesgos de rendimiento y guardado

- Decoración: hoy unas 30–60 piezas por sector y no se descarga nunca (P2-12 de `AUDIT.md`). Más
  escenografía exige **un presupuesto por sector, comprobado por test**, y luces limitadas.
- Animación ambiental: debe recorrer solo lo cercano, con un número fijo de elementos por frame, y
  reducirse con la calidad gráfica baja.
- Guardado: cualquier campo nuevo (vitrina, colecciones) va con valor por defecto en la
  reconciliación del perfil, sin cambiar de versión salvo que haga falta, y con test de ida y
  vuelta. Ampliar la cadena de misiones al final es compatible: `quests.index` sigue apuntando a la
  misma misión.
- **No** se amplía el ancho del subsuelo en esta iteración.

## 7. Plan de trabajo (por impacto en la diversión)

| # | Bloque | Por qué primero |
|---|---|---|
| 1 | Arreglos del informe de Studio y decisiones | Hecho: `c9236b4` |
| 2 | **Identidad visual por zona:** gradación de color, atmósfera, partículas en el aire, niebla que cambia con la profundidad y calidad gráfica | Lo más visible y lo más barato |
| 3 | **Escenografía de cuevas y vida ambiental** con presupuesto por sector | Que cada cueva cuente algo y no se repita |
| 4 | **Progresión:** misiones por zona hasta el Núcleo y colecciones con recompensa | Arregla G1, el mayor riesgo de abandono |
| 5 | **Vender o conservar:** reliquias protegidas, venta individual | Arregla G2 |
| 6 | **Identidad de cada herramienta al golpear** y ajustes de interfaz | Que se note la mejora |

Al final de cada bloque se actualiza la sección 8 con lo hecho, lo que queda abierto y las
pruebas de Studio.

## 8. Registro de bloques

### Bloque 1 (`c9236b4`): arreglos de Studio
- Manivelas del Contador a la altura del jugador, separadas 3 studs; la de un anillo bloqueado se
  desactiva.
- Las recompensas de estructura (fragmento fósil, geoda) ya no pagan la bonificación de
  descubrimiento. Lógica pura con test [VM].
- Cuerda desde el borde del agujero; placa de piedra 1000 → 250.
- Cimiento macizo bajo la sala del Contador. El test falla con el generador anterior y pasa con el
  nuevo [VM].
- El silbido del gesto usa ahora un clic suave hasta que haya audio propio; la Baseplate de la
  plantilla se elimina al arrancar; StyLua fijado a la versión 2.6.0.
- **Studio pendiente:** girar los tres anillos desde el suelo, cuerda desde el borde, ausencia de
  avisos de `swoosh.wav` en la consola.

### Bloque 2 (`baf1f18`): identidad visual por capa
- `Config/Visuals` define la gradación de color, el bloom, la atmósfera y las partículas de las 7
  capas. `Util/ZoneLook` es puro y tiene test de continuidad en cada límite y de oscurecimiento
  con la profundidad [VM].
- `AmbienceController` hace la transición gradual y lleva un único emisor de partículas alrededor
  de la cámara, escalado por la calidad gráfica. La superficie tiene ahora luz de tarde.
- **Studio pendiente:** ajustar los valores a ojo (ver `docs/ART_DIRECTION.md`).

### Bloque 3: escenas de cueva y vida ambiental
- `Logic/ScenePlan` (puro, con test) y `Services/CaveScenes`: 15 tipos de escena ligados a su
  estilo, entre ellos el campamento y las flechas de tiza de E., que conectan con la historia.
  Presupuesto de 60 objetos por sector; la media medida es 7,1 [VM].
- `AmbientLifeController` en el cliente: parpadeo, latido, giro y polvo que cae, con coste por
  fotograma acotado [código].
- **Studio pendiente:** aspecto, número real de piezas, coste en calidad baja y que nada estorbe
  al cavar (las estalagmitas y el corazón de cristal tienen colisión en la base).

### Bloque 4: progresión por capa y colecciones
- La cadena de misiones pasa de 12 a 32 y llega hasta el Núcleo (problema G1). Tipos nuevos:
  especies fósiles, El Contador (encontrado o resuelto), estaciones y colecciones. Cada capa
  trae un mineral nuevo, una estructura, la herramienta clave y la siguiente profundidad.
- Las misiones nuevas van **al final**: un `quests.index` guardado sigue apuntando a la misma
  misión, y quien había terminado la cadena antigua continúa por `station_1` (test [VM]).
- **6 colecciones con recompensa única** (`Config/Collections`, `Logic/CollectionSets`): menas
  altas, gemas de cristal, gemas profundas, materia legendaria, reliquias y fósiles. La
  finalización se guarda como `quests.completed["set_<id>"]`, así que no cambia el formato del
  guardado; el test de ida y vuelta confirma que no paga dos veces tras volver a entrar [VM].
- Las colecciones se ven con su barra de progreso en *Mochila → Descubrimientos*. El diario tiene
  una entrada nueva, «Lo que guarda el agujero», con una línea por colección completada.
- Economía: con las misiones se llega al Núcleo en unos 103 minutos estimados (antes 122); ver
  `docs/BALANCE.md`.
- **Studio pendiente:** que el aviso de misión y colección aparezca, cómo se ve la pestaña y que
  una partida antigua continúe la cadena.

### Bloque 4b: vender o conservar (G2)
- El fragmento antiguo, la reliquia y el artefacto llevan `keep`: «Vender todo» ya no los vende
  (`Inventory.takeSellable`, con test [VM]). En la mochila tienen su propio botón «Vender» (evento
  `SellItem`, validado en el servidor: pieza que se conserva, que la lleva encima y que está junto a
  la estación de venta).
- **Vitrina** en la casa (F en la vitrina): expone una unidad de cada pieza; se guarda en
  `collection.exhibit` y se reconstruye al entrar. Así la casa refleja el progreso.
- La colección «Restos de quien vino antes» (10 000) se completa **exponiendo**, no solo
  encontrando. Vender una reliquia (900) o el artefacto (5 000) da dinero ahora, pero retrasa la
  colección: es una decisión real.
- Compatibilidad: el campo es nuevo y no cambia la versión. Las partidas antiguas cargan con la
  vitrina vacía; los identificadores basura o de piezas que no se conservan se descartan (test
  [VM]). **Riesgo conocido:** si se vuelve a una versión anterior del juego, esa versión no conoce
  `exhibit` y lo perdería al guardar. Las piezas ya expuestas no vuelven a la mochila.
- **Studio pendiente:** la vitrina con las piezas girando, el botón «Vender» de una pieza y el
  aviso al vender cuando solo se llevan piezas conservadas.

### Bloque 5: identidad de cada herramienta y ajustes
- `DigFeel.ToolFeel`: cada herramienta tiene su peso (polvo, fragmentos y un sonido más grave),
  sus chispas (ninguna con la pala oxidada, metálicas con acero y picos, calientes con los
  taladros, de energía con plasma, la perforadora abisal y la herramienta ancestral), un destello
  en el punto de impacto con las de energía y una sacudida de cámara pequeña (≤ 0,5°) solo en los
  golpes propios. Cada golpe lleva además una variación aleatoria de tono del ±3 %. Test: el peso
  no baja nunca al mejorar de herramienta [VM].
- Ajustes (⚙, arriba a la derecha): calidad de efectos (Auto/Bajo/Medio/Alto, que escala las
  partículas, el bloom y el polvo) y sacudida de cámara (Sí/No). **Solo para la sesión:** todavía no
  se guardan.
- G3: abrir el menú del montacargas cierra la nota, la tienda y la mochila.

## 9. Iteración 6: lo que quedaba

| # | Problema | Estado |
|---|---|---|
| A1 | Nada de las iteraciones 4–6 se ha visto en Studio | **Abierto.** Lista exacta en `docs/AUDIT.md`, secciones 7 y 8 |
| A2 | La decoración no se descargaba nunca | **Hecho** (`d285b53`). `Logic/DecorStreaming`: solo los sectores a 2 o menos (64 m) de un jugador conservan la decoración, que se reconstruye de forma determinista al volver. Cofres, geodas, fósiles y El Contador no se descargan. Test [VM] |
| A3 | Audio propio | **Abierto.** No puedo crear ni subir audio a Roblox desde aquí. Los sonidos siguen siendo internos; ya cargan todos (el gesto usa un clic provisional) |
| A4 | Los ajustes no se guardaban | **Hecho** (`3dfb05a`). `profile.settings`, validado en el servidor (`ProfileSchema.applySettings`), con limitación de frecuencia; no reenvía el estado completo. Test [VM] |
| A5 | Dos jugadores y guardado real | **Abierto** (necesita un lugar publicado) |
| A6 | Equipo con batería y gancho | **Hecho** (`8c34db2`). Linterna potente, detector de resonancia y gancho; la batería vuelve a la tienda y se recarga en la superficie y junto a las estaciones. **Cavar sigue sin gastar batería.** Expediciones: **no**; con el equipo actual el banco de expedición no añade decisiones nuevas, y lo dejo hasta ver cómo se juega |
| A7 | Sin tutorial | **Hecho** (`3dfb05a`). `Util/TutorialLogic`: los pasos se deducen del estado real y terminan para siempre a 25 m, con marcadores sobre el carro y el garaje. Test [VM] |

Mejoras añadidas al cerrar:
- Las pistas de las misiones de geodas y de 250 m mencionan el detector y el gancho.
- La barra de energía se llama ahora «Batería» y solo aparece si llevas equipo que la usa.
- Los botones de equipo van en una columna a la derecha para que la barra inferior no se salga de
  la pantalla en el móvil.

**Riesgo conocido de guardado (aditivo):** `collection.exhibit`, `settings` y `gear` son campos
nuevos sin cambio de versión. Las partidas antiguas cargan con valores por defecto. Si se vuelve a
publicar una versión anterior del juego, esa versión los descartará al guardar: se perderían el
equipo comprado, la vitrina y los ajustes. Antes de volver a una versión anterior hay que
desplegar una que los conserve.

### Revisión independiente del código nuevo
Sin hallazgos críticos ni altos: la seguridad de los eventos remotos, la duplicación y la
propiedad de las parcelas están bien. Corregido lo que encontró, y algo más grave que salió al
revisarlo:
- **Carga que podía colgarse:** una partida corrupta con una longitud infinita o enorme en
  `plot.dug` hacía que `CellSet.decode` no terminara nunca. Ahora `decode` y la reconciliación del
  perfil cortan en el primer par no válido y conservan la parte buena del agujero. También se
  descartan las cantidades infinitas o NaN del inventario y una semilla no válida. Test [VM].
- El limitador de `SaveSettings` ya se libera al salir el jugador.
- La linterna deja de gastar batería mientras el personaje reaparece.
- La lámpara de cabeza vuelve tras reaparecer aunque el personaje antiguo no se destruya.
- La animación ambiental mantiene una lista de los objetos cercanos (como máximo 80, recalculada
  cada 0,5 s) y los anima en cada fotograma: así no tartamudea aunque el lugar tenga miles de
  objetos con etiqueta.
- Comprobado: `PlotService.onReady` se lanza después de cargar el perfil, así que la vitrina
  siempre se reconstruye.

## 10. Informe de Studio 2

Primera vez que las iteraciones 4–6 se ejecutan en Studio (`docs/STUDIO_REPORT_2.md`).

**Qué estaba mal y está arreglado** [Studio salvo donde se indica]:
- El hierro se generaba como césped (material `Granite` inexistente en terreno). Test nuevo de
  materiales [VM: pasa].
- Texto «Label» fijo en pantalla; sin forma de subir entre 2 y 8 m (justo cuando el tutorial lo
  pide); palancas del Contador con el indicador equivocado; cuerda desde el borde demasiado
  exigente; panel ⚙ encima de la Mochila; recarga de decoración en un fotograma.
- Rendimiento: 447 → 237 piezas por parcela vacía (valla). Al empezar, 1 928 piezas en total.
- Aspecto: Cristal y Abismo menos oscuros.
- Gancho: agarre de 1,5 s en la pared [parcial: probar en una cámara grande].

**Problemas abiertos:**

| # | Problema | Siguiente paso |
|---|---|---|
| A8 | Cavar con E/mando/táctil desde el borde de un hueco no hace nada (el rayo central cae lejos) | Fallback hacia el suelo bajo los pies |
| A9 | FPS reales en calidad Baja/Alta sin medir | El usuario, con la ventana activa (Ctrl+Shift+F5) |
| A10 | Interfaz en móvil sin revisar | *Test → Device* en Studio |
| A11 | Escenas de cueva (V4–V7), sensación de herramientas (V9), transiciones (V2) sin ver | El usuario, con las capturas del informe |
| A12 | Dos jugadores y guardado real | Lugar publicado (lista en el informe, §6) |
| A13 | ~~`luaucheck` no ejecutado en esta tanda~~ **Cerrado:** ejecutado sobre 68bcdd9/0b2eea2 sin cambios de código. `luaucheck check` sin errores; `tests/run.lua` 61 ok, 0 fallos (incluido «terrain materials are real terrain materials and not shared»); `tests/static_checks.lua` 62 usos de remotes verificados, 0 fallos | — |

## 11. Fase 3, primeros bloques

### Grietas y cavar desde el borde (`6f420c3`)
- Grietas en la celda según el daño: `Util/CrackPattern` (puro, con test) y dibujo en el cliente
  [Studio: aparecen y se borran al romper; el aspecto lo juzga el usuario].
- Apuntado de respaldo hacia el suelo bajo los pies: cavar con E, mando o táctil desde el borde de
  un hueco [código; no reproducido en Studio].

### Audio
- `docs/AUDIO_NEEDED.md`: lista de sonidos propios por prioridad, con duración y carácter.

### Segunda anomalía: «El taller de E.» (Cavernas Antiguas, 456–460 m)
- `Config/Anomalies` admite varias salas (`Rooms`, `RoomList`); El Contador conserva sus nombres.
  `Logic/Caves` reserva la sala del sector que toque, con cimiento y galerías guiadas.
- `WorkshopRoomBuilder` y `WorkshopService`: taller cálido (banco, farol, siete palas con sus
  números y un gancho vacío). Al colgar tu pala, las palas se balancean, el libro pasa la página y
  muestra tu número de bloques frente a los 3 912 de E. Utilidad: **batería +50 %**.
- Señal previa: `WorkshopController`, el ritmo grave de tres golpes a través de la roca (el diario
  del Contador ya lo anunciaba); se calla al abrir la sala.
- Diario: «El taller de E.» y «La octava pala», que crecen con lo que has hecho.
- Perfil: `anomalies.workshop` (campo nuevo, sin cambio de versión, saneado en `reconcile`, test de
  ida y vuelta). **Riesgo al volver a una versión anterior:** esa versión descartaría el campo y se
  perdería la batería extra y el estado del taller.
- **Compatibilidad del mundo:** el sector 14 (448–479 m) se genera algo distinto que antes (la caja
  reservada y dos galerías). Si alguien ya había cavado dentro de esa caja, esas celdas siguen
  abiertas (manda `plot.dug`).
- Studio [verificado]: se construye (70 piezas), suena y se calla al abrir, se revela con el aviso y
  la entrada del diario, colgar la pala funciona (libro «… — 5 104 (+1 192)», batería 60 → 90).
- Arreglos encontrados al probarlo, que afectan también al Contador: el terreno suave sobresale 2
  studs hacia dentro de las salas (el suelo de vidrio del Contador nunca se había visto) y los
  puntales de las galerías guiadas acababan dentro de las salas. Ambos corregidos y vistos en Studio.
- **Pendiente:** pasar `luaucheck` (tests nuevos de salas, diario y guardado del taller); revisar a
  ojo el taller y el Contador; el aviso narrativo ya no lo tapa un hallazgo épico [código, sin ver].

### Fósiles de las capas profundas
- Cuatro especies nuevas: Salamandra de ceniza (650–1 000 m), Mano con mango (700–1 100 m), Ojo del
  abismo (1 000–1 500 m) y «El que cuenta» (1 500–2 200 m), cada una con su modelo y una ficha que
  conecta con E., el gancho del taller o la máquina del Contador. Dos párrafos nuevos en el diario.
- **Guardados:** la colección «Fósiles del agujero» queda fija en sus siete especies, así que quien
  ya la había completado la sigue teniendo completa. Las nuevas forman «Fósiles del abismo»
  (25 000 monedas). La misión «fossils_all» pasa a llamarse «Registra siete especies fósiles» (mismo
  objetivo, mismo índice).
- **Mundo:** por encima de 650 m no cambia nada (ninguna especie nueva es válida allí y las vetas se
  resuelven de arriba abajo).
- Studio, ejecutando la lógica real: las cuatro especies aparecen en el 100 % de 60 parcelas, unos 29
  fósiles por parcela entre 650 y 2 200 m, ninguno fuera de su profundidad ni entre 400 y 650 m.
  Modelos vistos en una captura; aspecto pendiente de tu revisión. Tests añadidos (pendiente
  `luaucheck`).

### Casa que refleja el progreso
- Mapa de capas en la pared del fondo («EL AGUJERO»): cada capa se ilumina con su color al
  alcanzarla, las demás muestran «???» y su profundidad, y abajo el récord. Estante de trofeos en la
  pared oeste: uno por colección completada. Todo se deriva del perfil (sin campos nuevos) y se
  reconstruye solo cuando cambia (firma de capas, colecciones y récord) [Studio: visto].
- Bajo la casa y el garaje la capa superior del terreno es tierra: antes crecía césped alto
  atravesando el suelo de la casa [Studio: visto].

### Gancho motorizado
- Mejora del gancho (12 000, necesita el gancho): misma tecla T y sin botón propio (el botón pasa a
  «Gancho ⚡»). Alcance 80 studs y tirón de 100 studs/s; gasta 6 de batería solo cuando el
  lanzamiento pasa del alcance normal (40); sin batería funciona como el gancho. El servidor sigue
  validando línea de roca, parcela y distancia. Campo de perfil: `gear.motor_hook` (aditivo; una
  versión anterior lo descartaría).
- Studio: compra verificada (sin gancho: «Primero necesitas: Gancho.»; con él, cobra 12 000). El
  lanzamiento largo no se pudo comprobar (no encontré una cámara con pared a más de 40 studs).
- Mochila propulsora: **no**. Con el gancho, la cuerda y el gancho motorizado ya hay tres formas de
  moverse en vertical; una cuarta no añade decisiones.
