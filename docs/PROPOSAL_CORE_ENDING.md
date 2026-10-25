# Propuesta: el final del agujero (tercera anomalía, Núcleo)

**Estado:** propuesta, nada implementado. Decides tú.

## Qué falta hoy

- La **Herramienta ancestral** existe (`Config/Tools`, potencia 120, radio 3) y su descripción dice
  «Se desbloquea al descubrir el secreto del núcleo», pero **ningún código la concede**: hoy es
  imposible conseguirla.
- A **2200 m** hay roca madre irrompible (`GameConfig.MaxDepthCells`). Llegar ahí no tiene ninguna
  consecuencia: ni sala, ni entrada de diario, ni misión.
- Las misiones acaban en 1500 m. La historia (Contador a 128 m → taller de E. a 456 m → fósiles «El
  que cuenta» en el Núcleo) plantea preguntas que nunca se responden: ¿qué cuenta la máquina?,
  ¿quién era E.?, ¿por qué el agujero «nunca acaba»?
- Según la simulación, un jugador llega al Núcleo en unas 2 h. A partir de ahí no hay objetivo.

## Opción A: «El fondo» (sala final, recomendada como base)

El mismo patrón que el Contador y el taller (caja reservada con cimiento y galerías guiadas,
`Logic/Caves`, constructor de sala, servicio, controlador con señales previas, entrada de diario,
tests):

- **Dónde:** Núcleo Desconocido, justo encima de la roca madre (~2150–2165 m).
- **Señales previas:** desde 1800 m, los dos ritmos se oyen a la vez: tres golpes del Contador y
  tres del martillo de E., cada vez más sincronizados.
- **La sala:** pared de roca madre pulida con tres columnas de números grabados. La primera, nombres
  borrados y cifras enormes; la segunda, «E. — 3 912»; la tercera, vacía, con el hueco de una mano.
- **Interacción:** apoyar la mano (mantener F). Tu número de bloques excavados se graba en la tercera
  columna, con animación de cincel y los dos ritmos parando a la vez.
- **Revelación** ligada a lo que has hecho: el agujero no es de nadie, **se hereda**. Cada excavador
  llega hasta donde llegó el anterior y lo supera. El Contador cuenta a quien excava; el taller
  guarda sus palas; el fondo guarda sus números. «El agujero no se acaba: cambia de manos.»
- **Recompensa:** la Herramienta ancestral (por fin conseguible), con entrada de diario «El fondo»
  que crece con tu número, el de E. y el de la máquina.
- **Guardados:** `anomalies.core = { found, engraved, engravedCount, engravedAt }` con valores por
  defecto, saneado en `ProfileSchema.reconcile`, prueba de guardar y recargar. La herramienta
  ancestral se añade a `tools` como cualquier otra.
- **Coste:** parecido al taller, 1 o 2 bloques de trabajo.

## Opción B: A + «nunca acaba» de verdad

Todo lo de A y, además, la Herramienta ancestral **puede romper la roca madre**. Al romperla no se
genera terreno por debajo de 2200 m: la grieta se abre a una luz blanca y apareces **en el césped
de tu propia parcela**, con la cámara mirando el agujero, como el primer día. Una línea final en el
diario: «Debajo del fondo estaba el jardín.» Repetible: el agujero nunca acaba porque da la vuelta.

- **Guardados:** nada nuevo más allá de A (un contador `loops` opcional para el diario o la casa).
- **Sin riesgo de profundidad:** no se cavan celdas por debajo de 2200; romper la roca madre es una
  interacción especial (validada en el servidor: herramienta ancestral equipada, distancia, celda de
  roca madre de tu parcela), no una celda más.
- **Coste:** medio bloque más que A.

## Lo que no propongo

- Ensanchar o alargar el subsuelo: sigue fuera de alcance.
- Renacimientos, prestigio o recompensas por repetición: el bucle de B es narrativo, no un
  multiplicador.

## Recomendación

**B**: es el final que promete el título y cuesta poco más que A. Si prefieres un final más sobrio
o quieres dejar abierta una continuación, **A**.
