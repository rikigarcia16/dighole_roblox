# Diseño: movilidad, expediciones y el hallazgo de las Minas

**Estado: diseño para aprobar. Nada de esto está implementado todavía.** Reutiliza la arquitectura
actual: perfil versionado, `SpecialsService` para las estructuras, `Logic/*` puro y testeable,
y `Config/*` para el balance.

---

## A. Movilidad: que el viaje sea exploración, no tiempo muerto

### Principios
1. **Bajar la primera vez es una expedición; volver a un sitio ya conquistado es rápido.**
2. **Cada herramienta de movilidad cambia lo que puedes hacer**, no solo lo rápido que lo haces.
3. **Nunca te quedas atrapado**, pero salir de un apuro tiene un coste razonable.

### Progresión

| Momento | Herramienta | Qué hace | Coste / requisito |
|---|---|---|---|
| Inicio (Jardín) | **Retorno libre** | El botón "Superficie" sigue siendo gratis hasta 50 m: el aprendizaje no castiga. | — |
| Inicio | **Cuerda** (consumible, 3 por carga) | Se ancla en el borde donde la colocas; cuelga 20 m y se puede trepar. Se recoge al volver a pasar. Sirve para bajar a cámaras grandes y para subir desde ellas. | 25 monedas por cuerda |
| ~50 m | **Montacargas** (en la boca del agujero) | Viaje vertical real (cabina visible, ~6–10 s) entre la superficie y cada **estación** que hayas instalado. | 300 monedas |
| Cada zona | **Estaciones del montacargas** | Al llegar por primera vez a 50, 150, 350... m aparece un punto de anclaje: lo instalas y desde ese momento tienes acceso permanente a esa profundidad. | Material de la zona (por ejemplo 20 hierro + 10 pizarra) |
| Minas | **Gancho** | Disparo a una superficie a 30 studs: tira de ti. Cruza huecos, sube paredes de cámaras y llega a galerías altas. | 2 500 monedas |
| Cuevas de Cristal | **Gancho motorizado** | Doble alcance y puede recogerte en el aire; usa batería. | Mejora + batería |
| Cavernas Antiguas | **Mochila propulsora** | Vuelo corto; gasta batería. | Batería |
| Siempre | **Baliza de rescate** (emergencia) | Por debajo de 50 m sustituye al retorno gratuito: 5 s de canalización (se cancela si cavas) y te devuelve a la estación más cercana por encima, o a la superficie. | 5 % del valor de la mochila (mínimo 10 monedas) |

### La batería, con utilidad real (sin frenar la excavación)
La excavación normal **nunca** gasta batería (ya implementado). La batería alimenta: detector de
minerales, escáner de anomalías, linterna potente (ilumina cámaras enormes), gancho motorizado,
mochila propulsora y un **golpe cargado** opcional (mantener para romper una celda dura de una vez).
Se recarga en la superficie y en las estaciones del montacargas. Así se convierte en una decisión de
preparación, no en un temporizador.

### Mochila
Sigue siendo la capacidad de transporte. Para que no moleste: el aviso de "llena" sugiere la
estación más cercana, los hallazgos y las reliquias no ocupan espacio (ya es así), y existe un
**contenedor de estación** que guarda lo recogido hasta que lo subas.

### Consecuencias técnicas
- Perfil v4: `stations = { [depth] = true }`, `mobility = { ropes, hook, ... }`.
- Montacargas: modelo anclado y movido en el servidor con `TweenService` sobre una plataforma con
  `AlignPosition`. Riesgo: física en red, porque los jugadores se mueven en la cabina. Hay que
  probarlo en Studio con latencia simulada.
- Cuerda: `RopeConstraint` + `TrussPart` (escalable). Gancho: `LinearVelocity` controlada por el
  servidor tras validar el raycast.
- Baliza: el servidor valida la canalización. Reutiliza `PlotService.teleportToSurface` con un
  destino de estación.

---

## B. Preparación de expediciones (resumen)

En el garaje, un **banco de expedición** con huecos: herramienta, mochila, batería, iluminación,
detector, movilidad y rescate. Ejemplos de decisiones reales:
- **Pico** (preciso, bueno con vetas) frente a **taladro** (rápido, malo con la roca más dura).
- **Detector** (señala minerales cercanos) frente a **escáner** (señala geodas, fósiles y
  anomalías). Ambos gastan batería: no se pueden llevar los dos a pleno rendimiento.
- **Más cuerdas** frente a **gancho**: las cuerdas son baratas y permanentes; el gancho es
  versátil pero cuesta batería en su versión motorizada.

---

## C. Primer gran hallazgo de las Minas: «El Contador»

### Idea
Al fondo de las Minas Olvidadas (~130 m) las galerías de los antiguos mineros no acaban por
casualidad: **todas convergen** hacia un punto. Allí hay una sala que no es una cueva. Sus paredes
son lisas, de un material que ninguna herramienta raya. En el centro, una columna de anillos de
piedra gira despacio. Cada anillo lleva grabados, y en la base hay un número tallado que cambia.

El número es **la cantidad exacta de bloques que el jugador ha excavado desde que llegó**. La
máquina lleva todo este tiempo escuchando su pala.

### Estructura de la experiencia

| Elemento | Diseño |
|---|---|
| **Aproximación** | Desde ~100 m se oye un golpe sordo y rítmico (tres golpes, una pausa: el ritmo que describía la caja del minero). Se oye más fuerte cuanto más cerca estás. Los puntales de las galerías cercanas llevan marcas de tiza de E. con flechas hacia abajo. Las galerías de los últimos sectores de las Minas se orientan hacia la sala. |
| **Presentación** | La sala se revela al abrir una galería que da a ella: silencio repentino (cesa el ritmo), luz fría y estable, una paleta distinta del resto de las Minas y un eco largo. Primera vez: aviso de zona especial "SALA DESCONOCIDA". |
| **Interacción** | La columna tiene tres anillos con símbolos. Hay que girarlos (interacción con F en cada uno) hasta la combinación que forman los símbolos de la placa de piedra y el ritmo de la caja del minero. Las pistas ya existentes en el diario la sugieren; no hace falta salir del juego para resolverla. |
| **Pista narrativa** | Al resolverla, los anillos se detienen y el número de la base se ilumina: muestra tu total de bloques excavados. Se graba una nueva entrada en el diario («Nos está contando»). Pregunta nueva: ¿quién está contando, para qué, y qué pasa cuando el número llegue a algo? Reinterpreta la huella de pala fósil: alguien cavó aquí antes, y la máquina también le contaba a él. |
| **Recompensa útil** | Primera **estación del montacargas** gratuita en la sala (acceso permanente a ~130 m) y el plano del **detector de resonancia**: un equipo que indica la dirección de la siguiente estructura anómala. |
| **Registro persistente** | Entrada en el diario con un boceto de la sala, el número que marcaba cuando la resolviste y una pregunta abierta. La sala queda resuelta para siempre y la columna sigue mostrando tu contador cada vez que vuelves. |

### Consecuencias técnicas
- **Generación**: `Logic/Caves` reserva el sector de ~128–160 m de cada parcela para una "sala
  especial". Es un hueco determinista de ~8×6×8 celdas sellado por roca, y dos galerías del sector
  apuntan hacia él. La posición es fija respecto al centro para que funcione también si se ensancha
  el subsuelo. La placa de piedra (hoy a 138 m) se integra en la sala.
- **Estructura**: modelo de piezas construido por `CaveProps` (paredes, columna de 3 anillos y
  número con `SurfaceGui`), revelado como los demás sistemas.
- **Servidor**: el estado del rompecabezas (`profile.anomalies.counter = { solved, rings }`) se
  valida en el servidor. La combinación se deriva de la semilla, para que cada parcela tenga la
  suya, y las pistas la muestran.
- **Audio**: necesita **audio propio** (el ritmo de tres golpes y la sala silenciosa). Los sonidos
  internos de Roblox no bastan para esto: es el primer sitio donde el audio propio es
  imprescindible.
- **Pruebas**: lógica del rompecabezas pura y testeada; colocación con renders y tests (sellada,
  alcanzable, sin cortar fósiles ni geodas).

### Por qué encaja
No es una escena prestada de otro juego: nace de lo que el jugador hace todo el rato, cavar.
Convierte un número que el juego ya guarda (`cellsDug`) en algo inquietante, y conecta las tres
pistas existentes (la nota de la casa, el ritmo de la caja del minero y la placa de piedra) con la
huella fósil.
