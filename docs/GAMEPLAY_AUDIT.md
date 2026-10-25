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

### Pestañas de la tienda
- La pestaña activa no se resaltaba al cambiar: el resaltado se conectaba antes de que la pestaña
  cambiara. Ahora cada pestaña cambia, resalta y redibuja en ese orden [código; StyLua; sin ver en
  Studio].

### Ensanchar el subsuelo: medido, no implementado
- Medido en Studio (sección 2b de `docs/PROPOSAL_WIDE_UNDERGROUND.md`): escribir terreno cuesta
  0,20 / 0,28 / 0,43 ms por capa con 16 / 24 / 40 celdas; el material de cada celda en Lua cuesta
  1,14 µs y es lo que crece. Proyección con 40 celdas: ~8,5 ms por capa y ~10–14 ms por sector de
  cuevas, por encima del presupuesto de 4 ms (habría que trocear); con 24 celdas cabe sin trocear.
- Añadidos a la propuesta: interruptor `WideUnderground` apagado por defecto que vuelve al formato
  antiguo sin publicar código nuevo. Memoria, red con varios jugadores y móvil siguen sin medir.
  **Decisión tuya.**

### Hazañas (retos opcionales)
- Tres hazañas que nadie te pide y que no aparecen en ninguna lista: solo se insinúan en una entrada
  nueva del diario, «Frases a tiza», cuando ya ha pasado algo relacionado, y se confirman al
  conseguirlas. Cada una se gana una vez y da una ventaja duradera en vez de monedas:
  - «Tres geodas en una bajada» (pista tras la primera geoda): el detector recarga en 1,5 s en vez
    de 2,5.
  - «A pulso»: llegar a 350 m desde la superficie sin montacargas (pista tras tener una estación):
    7 cuerdas en vez de 5.
  - «La subida»: volver a la superficie desde 150 m o más, con la mochila al 80 % y sin montacargas
    ni baliza (pista al llegar a las Cuevas de Cristal): la baliza cuesta la mitad.
- Una «bajada» va de salir de la superficie a volver a ella. Cualquier teletransporte (montacargas,
  baliza, reaparecer) la marca como asistida. Todo lo decide el servidor (sondeo cada 0,5 s, sin
  remotos nuevos); la lógica pura está en `Logic/Descent`.
- **Guardados:** campo nuevo `feats` (por defecto vacío, saneado: solo ids conocidos con `true`).
  Una versión anterior del juego lo ignoraría y perdería las hazañas al guardar: es lo único que se
  pierde si hay que volver atrás.
- Studio: concedidas las tres (bajar a 362 m a pulso, subir desde 160 m con la mochila llena y tres
  geodas en una bajada); bajar con teletransporte no cuenta; aviso «HAZAÑA» y notificación vistos;
  recompensas comprobadas (detector 1,5 s, baliza a 600 m 420 → 210, 7 cuerdas); diario con las
  pistas y las confirmaciones. Atajos usados en Play: mover al personaje anclado, llenar la mochila
  y llamar a la apertura de geoda desde el servidor. Tests añadidos (pendiente `luaucheck`).
- La sensación de golpe por material y por herramienta ya existía (`Config/DigFeel`: perfiles por
  material y peso, chispas y sacudida por herramienta); no la he tocado.

### Pizarras de E. en los campamentos de las Minas
- Cada campamento de E. (escena «camp», Minas) tiene ahora una pizarra apoyada con una de sus tres
  apuestas en tiza y su firma, distinta en cada sector. Las pistas de las hazañas existen también en
  el mundo, no solo en el diario; el diario dice ahora «En los campamentos de las Minas hay
  pizarras...».
- No todas las parcelas tienen campamento (en Studio, 23 campamentos en 120 sectores de las Minas
  con 40 semillas; salen las tres apuestas). Tu parcela de prueba no tiene ninguno.
- Studio: las tres variantes construidas con el constructor real y vistas en captura; corregido
  que el saco de dormir atravesaba la pizarra. Test añadido (pendiente `luaucheck`).

### Tests automáticos en local (Lune)
- Los tests ya se pueden pasar en este equipo sin Rust: `tools/lune/run.luau` da a Lune las mismas
  funciones que `luaucheck` (ver `tests/README.md`). Resultado: 71/71 tests, 62 usos de remotos
  verificados, todos los scripts compilan y la simulación de economía corre.
- Al pasarlos por primera vez salieron dos fallos, ambos en tests míos de esta fase y no en el
  juego: el del taller metía NaN en un guardado simulado (que lo rechaza, como haría DataStore) y el
  de colecciones buscaba las especies fósiles entre los minerales. Corregidos.

### Partida real de los primeros minutos (Studio, ratón y teclado)
Jugado como un jugador nuevo, sin atajos salvo el último paso (meter al personaje en el pozo para
mirar la cámara). Lo que estaba mal, por orden de gravedad:
1. **Cavar hacia abajo se atascaba** (era el «se queda atascado» del informe de Studio 2, no
   resuelto del todo). El servidor comprobaba la línea de visión hasta el *centro* de la celda; en
   un pozo de una celda las paredes redondeadas del terreno suave la cortan y el golpe se descartaba
   sin aviso. Medido: 18 golpes enviados, 0 aplicados; 4 bloques en 30 s y sin pasar de 0 m. Ahora
   se comprueba hasta el punto golpeado (margen 3 studs; sigue sin poder cavarse a través de una
   pared). Medido después: 43 bloques en 40 s, 9 m de profundidad [Studio: verificado].
2. **La cámara empezaba mirando al revés**: el personaje aparece en el SpawnLocation común y el
   servidor lo lleva a su parcela; la cámara no giraba, así que veías tu cara y no el agujero. Igual
   tras el montacargas, la baliza o reaparecer. Nuevo `CameraController`: tras cualquier salto de
   más de 24 studs (y al empezar) coloca la cámara detrás del personaje [Studio: verificado al
   entrar y al subir con R].
3. **No se veía dónde cavar**: la zona era césped como todo lo demás y el borde de madera quedaba
   enterrado (el terreno suave sube ~2 studs) y tapado por la hierba. Ahora el anillo que rodea el
   agujero es tierra sin hierba y el borde está apoyado encima; desde arriba se ve un marco claro
   [Studio: visto]. A ras de suelo la hierba alta aún lo disimula.
4. El primer aviso del tutorial pone «▼ CAVA AQUÍ» sobre el centro del agujero, como «▼ VENDER» y
   «▼ GARAJE»; busca la parcela otra vez si aún no estaba lista [Studio: activo y colocado en
   pantalla; la herramienta de capturas no muestra estas etiquetas, tampoco una de prueba: mírala
   tú].
- El ciclo cavar → llenar la mochila (20) → subir (R) → vender funciona: ~1,5 min hasta la primera
  venta (simulación: 0,9). Venta: 21 monedas + 20 de la misión.
- Cámara en pozos estrechos: ver el bloque siguiente.

### Pozos estrechos: cámara elevada y nada de quedarse encajado
- **Cámara elevada** (`Util/ShaftCamera`, `CameraController`): con paredes en casi todos los lados
  (6 de 8 rayos a menos de 6 studs), cielo abierto encima (10 studs o más) y la cabeza al menos 6
  studs bajo la superficie, la cámara sube hasta 16 studs sobre la cabeza (por debajo de cualquier
  techo) y mira hacia abajo con una ligera inclinación, para que «adelante» siga siendo adelante.
  Entra tras 0,25 s y sale tras 0,6 s (no salta al pasar por el borde). Si algo se interpone entre
  la cabeza y la cámara, la cámara se acerca: en la primera versión se metía en la roca. Al salir o
  teletransportarse vuelve la cámara normal [Studio: vista a 2 m; entrar y salir con R verificado].
- **Paredes más finas junto a lo cavado** (`GameConfig.DugWallOccupancy = 0.5`): el terreno suave
  redondeaba las paredes 1–2 studs hacia dentro y un pozo de una celda era una rendija. Medido: el
  personaje quedaba encajado sobre 24 studs de hueco o con la raíz dentro de la pared, y E no
  encontraba nada que cavar (0 golpes enviados). Ahora las celdas sólidas al lado de una celda cavada
  (misma capa) se escriben con ocupación 0,5; los suelos no cambian. El servidor reescribe una
  celda más alrededor de cada golpe para actualizar esas paredes.
- **Desencajar**: si aun así el personaje queda quieto, rodeado de paredes y con el suelo a más de 6
  studs bajo el centro de su celda, el cliente lo baja a ese suelo, centrado (no si trepa una cuerda).
- E lanza sus rayos desde la cabeza (desde la raíz fallaban si estaba dentro de la pared).
- Medido en Studio con E mantenida: antes 32 bloques y atascado a 2 m; ahora 24 m en 60 s.
- **Sin verificar a ojo:** el aspecto de las paredes más finas y de la cámara a más de 5 m. En mitad
  de la prueba, la vista 3D de Studio dejó de dibujarse, incluso nada más arrancar Play en la
  superficie y con mi cámara desactivada (la interfaz sí se veía). Es un problema de Studio, no del
  juego, pero impide juzgarlo por captura. Míralo tú.

### El final: «El fondo» y la roca madre (opción B de `PROPOSAL_CORE_ENDING.md`)
- **Qué faltaba:** la Herramienta ancestral no se podía conseguir, la roca madre de 2200 m no
  llevaba a nada y la historia no tenía desenlace.
- **La sala** (`Anomalies.Rooms.core`, sector 67, 2154–2158 m; `CoreRoomBuilder`, `CoreService`):
  mismo patrón que el Contador y el taller (caja reservada, cimiento, dos galerías guiadas). Paredes
  negras pulidas, grietas de luz fría en el suelo y tres columnas grabadas: excavadores anteriores
  con el nombre borrado (18 402, 11 930, 9 771, 6 215), «E. — 3 912» y una tercera vacía con la
  forma de una mano. Al abrir una puerta: «EL FONDO» y entrada de diario.
- **Interacción:** mantener F sobre la mano (solo el dueño de la parcela). La pared graba «Nombre —
  bloques excavados» letra a letra, los dos ritmos se paran, aparece «EL AGUJERO SE HEREDA» y la
  Herramienta ancestral pasa a ser tuya (se equipa en el garaje).
- **Señales previas** (`CoreController`): desde ~1 780 m se oyen a la vez los golpes del Contador y
  el martillo de E.; desacompasados de lejos, a la vez al llegar. Callan tras el grabado.
- **La roca madre:** la capa 2200 es ahora basalto negro (antes era materia del núcleo, sin
  distinguirse). Se puede golpear en cuanto la capa de encima está abierta. Sin la herramienta
  ancestral: «La roca madre no se deja rayar…». Con ella, 6 golpes seguidos: luz blanca a pantalla
  completa, «DEBAJO DEL FONDO ESTABA EL JARDÍN» y apareces en el césped de tu parcela, mirando al
  agujero. Se puede repetir. No se cava ninguna celda por debajo de 2200: es una interacción que el
  servidor valida (parcela, alcance, cadencia y herramienta equipada).
- **Diario:** entrada «El fondo», que crece con tu número, con el taller si colgaste la pala y con
  cada vuelta («Ya van N veces. El agujero nunca se acaba: da la vuelta.»).
- **Misiones:** tres al final de la cadena (35 en total): «Encuentra el fondo», «Deja tu número en
  la pared» y «Rompe la roca madre». Quien ya tenía la cadena terminada sigue con ellas.
- **Guardados:** `anomalies.core = { found, engraved, engravedCount, engravedAt, loops }` con valores
  por defecto, saneado (las vueltas exigen el grabado) y con prueba de guardar y recargar. La
  herramienta se guarda en `tools` como cualquier otra. Una versión anterior del juego perdería el
  estado del fondo, pero conservaría la herramienta.
- **Studio** (atajos en Play: generar el terreno hasta 2201, Perforadora abisal, mover al
  personaje, abrir una columna sobre la roca madre): la sala se construye y se revela; grabado con
  602 bloques, herramienta concedida; con la herramienta, la roca madre cede y apareces en el jardín
  (`loops = 1`, el diario lo cuenta); sin ella, el aviso y nada más [verificado y visto].
- **Pendiente de tu revisión:** los ritmos (no se oyen en capturas); las columnas empiezan altas en
  la pared; el aspecto del basalto. Al mover al personaje con mi atajo, sin pasar por el sistema de
  teletransporte, saltó la hazaña «A pulso»: es efecto del atajo, no del juego.

### El final en la casa y con sonido
- **Trofeo del fondo** (`ExhibitService`): al grabar tu número, entre el mapa de capas y la vitrina
  aparece una piedra negra pulida con una grieta de luz sobre un pedestal, con «El fondo» y, si ya
  has roto la roca madre, «Vueltas: N». Se reconstruye cuando cambian el grabado o las vueltas. Sin
  campos nuevos: sale de `anomalies.core` [Studio: visto; la primera posición quedaba tapada por la
  mesa de la nota y se movió].
- **Sonidos del final:** tres efectos de la biblioteca de Roblox, de ProSoundEffects (creador
  verificado, gratis y con licencia para experiencias de Roblox), encontrados con el buscador de
  Studio y comprobado que cargan: grabado («Rock Movement 21», 5,3 s), la roca madre cediendo («Rock
  Scrape Deep Grinding Impacts 16», 2,5 s) y la luz blanca («Magical Exit Sparkling Chimes 5»,
  3,5 s). Son la primera excepción a «solo sonidos internos»; no son audio propio y se cambian en
  `Config/Sounds` [cargan en Studio; cómo suenan, a tu oído].
- **Guardado real y dos jugadores:** preparada la prueba en `docs/TEST_SAVES_TWO_PLAYERS.md`.
  Necesita publicar el sitio (decisión y cuenta tuyas) y abrir dos clientes desde Studio.

### Superficie a ras y miniaturas del garaje (partida real, segunda parte)
- **El suelo estaba 2 studs más alto que todo lo construido.** El terreno suave con ocupación
  completa pone su superficie a y 2, y la casa, los caminos, la plataforma del carro, el borde del
  agujero y los cimientos están a y 0, así que quedaban enterrados y la hierba los atravesaba (casa,
  carro de venta). Medido en Studio: ocupación 1 → y 2, 0,75 → y 1, **0,5 → y 0**. Ahora la capa
  superior se escribe a media ocupación (`GameConfig.TopLayerOccupancy`,
  `TerrainChunkService.writeTopLayer`) en todo el mundo, bajo los edificios y en la primera capa del
  agujero. El borde vuelve a y 0 y el carro de venta tiene tierra debajo [Studio: visto desde
  arriba; caminos, plataformas y edificios asientan en el suelo].
- **Miniaturas del garaje:** las herramientas giraban sobre el mango y la hoja salía del recuadro.
  Ahora giran sobre su centro [Studio: visto].
- Partida: segundo y tercer ciclo de cavar y vender, 128 monedas a los ~4 min y el tutorial manda al
  garaje (simulación: 3,2 min). Con el suelo nuevo, E baja 16 m en 30 s.
- **A tu criterio:** la hierba del terreno de Roblox mide ~3 studs y ahora llega a la cintura del
  personaje (antes no se notaba porque todo estaba 2 studs más alto). Se puede bajar desactivando la
  decoración del terreno en Studio (Terreno → `Decoration`), que no se puede tocar desde código.

### Problemas abiertos de la fase 3
- Resuelto: los tests pasan en local con Lune.
- Lanzamiento largo del gancho motorizado sin comprobar en Studio.
- Revisión visual y sonora tuya: grietas, taller de E., fósiles nuevos, mapa de capas y trofeos.
- Revisión tuya de las hazañas: si las pistas se entienden y si las recompensas compensan.
