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

## 9. Problemas abiertos

| # | Problema | Siguiente paso |
|---|---|---|
| A1 | **Nada de las iteraciones 4 y 5 se ha visto en Studio** (aspecto, escala, coste real) | Lista de pruebas V1–V12 en `docs/AUDIT.md`, sección 7 |
| A2 | La decoración de los sectores no se descarga nunca (P2-12) | Medir piezas a 300 y 1000 m; si hace falta, descargar los sectores lejanos del dueño |
| A3 | Audio: todos los sonidos son internos y genéricos; el gesto usa un clic provisional | Subir audio propio (golpe por material, ritmo del Contador, zumbido) |
| A4 | Los ajustes no se guardan | Campo `settings` en el perfil, con la misma estrategia aditiva que `exhibit` |
| A5 | Pruebas con dos jugadores y guardado real (G1–G3) | Lugar publicado con API Services |
| A6 | Equipo con batería, gancho y expediciones (diseño en `DESIGN_MOBILITY_AND_MINES.md`) | Después de validar en Studio lo actual |
| A7 | No hay tutorial guiado: solo las primeras misiones | Indicaciones contextuales en los 5 primeros minutos (apuntar, golpear, vender, comprar) |
