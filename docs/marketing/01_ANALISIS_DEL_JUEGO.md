# 1. El juego como producto comercial

Análisis hecho sobre el código y las pruebas en Studio de este repositorio (noviembre de 2026), no sobre
suposiciones. Las cifras de tiempo salen de `tests/balance_sim.lua` (jugador simulado), no de jugadores reales.

## 1.1 Qué es el juego, en una frase

**Heredas una casa con jardín y una nota de alguien llamado E.; cavas en tu propio jardín, vendes lo que
encuentras, mejoras la herramienta y bajas por siete capas cada vez más extrañas hasta descubrir qué hay
en el fondo, a 2.200 metros.**

## 1.2 Inventario de lo que existe (lo que se puede enseñar sin mentir)

| Elemento | Contenido real en el juego |
|---|---|
| Zonas | El Jardín (0 m), Minas Olvidadas (50 m), Cuevas de Cristal (150 m), Cavernas Antiguas (350 m), Profundidades Volcánicas (650 m), El Abismo (1.000 m), El Núcleo Desconocido (1.500 m); roca madre a 2.200 m |
| Herramientas | Pala oxidada → Pala reforzada → Pala de acero → Pico minero → Pico industrial → Taladro portátil → Taladro avanzado → Excavador de plasma → Perforadora abisal → Herramienta ancestral (potencia 1 → 120) |
| Minerales | 9 rocas base y 19 tesoros: carbón, cobre, hierro, plata, oro, amatista, cristal azul, rubí, esmeralda, titanio, obsidiana especial, cristal abisal (legendario), geoda, fragmento antiguo, fósil, reliquia, artefacto antiguo (único) |
| Fósiles | 11, con nombres propios («Pez sin ojos», «Ojo del abismo», «El que cuenta»…) |
| Misterio | Notas de E., placa de piedra, salas especiales («El Contador», «El taller de E.», «El fondo»), pizarras de E. en los campamentos, final con la herramienta ancestral y «El agujero se hereda» |
| Progresión | 35 misiones, 7 colecciones, 3 hazañas opcionales, vitrina de trofeos y récords en la parcela |
| Movilidad | Cuerda, gancho, gancho motorizado, estaciones de montacargas instalables por zona, baliza, linterna, detector de resonancia |
| Superficie | Casa de cuento, jardín, tienda de excavación, mercado de minerales, castillete del montacargas, arco «EL AGUJERO» |
| Sensaciones | Minerales que saltan y vuelan hacia ti, hallazgo raro que sube en un haz de luz con su nombre, carro de venta con fuente de monedas, presentación 3D de herramienta nueva, cartel de zona nueva, música por zona |

## 1.3 Qué lo hace diferente

En Roblox hay decenas de juegos de cavar (ver [02_MERCADO_Y_COMPETENCIA.md](02_MERCADO_Y_COMPETENCIA.md)).
Lo que este tiene y la mayoría no:

1. **Un misterio con final.** La mayoría de simuladores de excavación son bucles infinitos de números
   (cavar → vender → mejorar → mundo nuevo). Aquí hay una historia (las notas de E.) y un final real a
   2.200 m que te devuelve al jardín. Los juegos de «cava para escapar» tienen historia pero son cortos y
   de una sola partida; este combina las dos cosas.
2. **El agujero es tuyo y es real.** Cavas en tu propia parcela, el terreno se rompe de verdad, el pozo
   queda y tus estaciones se quedan instaladas. No es una mina compartida ni un pozo prefabricado.
3. **Siete capas con identidad visual propia**, cada una con su música, su paleta y sus elementos
   (bombillas de mina, racimos de cristal, braseros e ídolos, pozas de lava, setas luminosas, pilares de luz).
4. **No hay mascotas ni renacimientos** (decisión de diseño). Es un argumento a favor ante el público
   cansado de simuladores «pay-to-win» con huevos, aunque también es menos «enganchante» para el público
   más pequeño (ver 1.8).

**Argumento comercial principal (propuesta):**

> **«Cava en tu jardín hasta el fondo del mundo. Algo te espera a 2.200 metros.»**

En inglés: **«Dig from your backyard to the bottom of the world. Something is waiting 2,200 m down.»**

Combina lo que se entiende al instante (cavar en tu jardín, profundidad) con lo que nos distingue
(hay algo concreto que descubrir y un final).

## 1.4 Qué funciona en vídeo corto (por orden de potencia visual)

| Momento | Por qué funciona | Dónde está |
|---|---|---|
| **Corte de profundidad**: cámara que baja por el pozo atravesando las 7 capas | Se entiende sin sonido ni idioma; promete escala | Cualquier pozo profundo |
| **Hallazgo legendario**: el cristal abisal subiendo en el haz de luz con su nombre | Recompensa, rareza, brillo | `LootController` (bigFind) |
| **Presentación de herramienta nueva** (tarjeta 3D girando) | Satisfacción de la mejora | `ToolShowcase` |
| **Pala oxidada contra perforadora abisal**, el mismo golpe | Antes/después, muy usado y eficaz en el género | Garaje + cavar |
| **Venta**: carga volando al carro y fuente de monedas | Recompensa visible | `LootController` (sold) |
| **Cartel de zona nueva** («ZONA 6 · EL ABISMO») | Hito, sensación de llegar lejos | `UIController` |
| **Lectura de una nota de E.** | Misterio, gancho narrativo para series | `Story.lua` |
| **El final** (sin destripar del todo) | Curiosidad máxima; «¿qué hay en el fondo?» | `CoreRoomBuilder` |
| **Bajar 135 m seguidos con E mantenida** | Ritmo hipnótico, ideal para acelerar ×4 | Comprobado en Studio |

## 1.5 Zonas más vistosas (según las capturas reales)

1. **El Abismo**: setas cian luminosas sobre roca oscura; el contraste es lo más llamativo del juego.
2. **Superficie**: casa de cuento, flores, tienda con toldo de rayas; colorida y legible para el icono.
3. **Minas Olvidadas con estación**: madera, bombillas y el montacargas industrial; se lee «mina» al instante.
4. **Profundidades Volcánicas**: lava y braseros (rojo y naranja, buen contraste con el resto).
5. **Cuevas de Cristal**: en las capturas actuales se ven oscuras y azul plano. **Necesita mejor plano o
   mejor iluminación antes de usarla en una miniatura.**

Ver las capturas en [capturas_referencia/](capturas_referencia/).

## 1.6 Qué atrae a cada público

**Niño que lo descubre (8–12 años)** (de momento no podrá jugar: ver 1.9):
cavar en tu propio jardín, gemas brillantes, herramientas cada vez más grandes, «¿hasta dónde llego?», la
casa de cuento, monedas saltando.

**Adolescentes y jóvenes (13–20)**: el misterio y las notas, el final secreto, los récords de profundidad,
los fósiles raros, el reto de las hazañas (bajar sin cuerdas, subir sin ayudas), presumir de la vitrina,
las capturas del abismo.

**Adultos jóvenes (16+, el público que Roblox deja entrar primero)**: la estética acogedora, el ritmo
relajante de cavar (ver el éxito de *A Game About Digging A Hole* fuera de Roblox), la sensación de
progreso sin presión de compra.

## 1.7 Público con más posibilidades

Por orden:

1. **Jugadores de Roblox de 13 a 20 años de España y Latinoamérica.** El juego está en español, la
   cuenta de Instagram es española y los grandes creadores hispanos de Roblox ya graban juegos de cavar
   con millones de visitas (ver [08_CREADORES.md](08_CREADORES.md)).
2. **Público 16+ con cuenta verificada por edad** (el único que puede jugar al principio).
3. Público internacional angloparlante, **después** de una pasada de traducción (ver 1.10).

## 1.8 Qué puede provocar abandono temprano (riesgos reales)

| Riesgo | Evidencia | Gravedad para el lanzamiento |
|---|---|---|
| **Juego 100 % en español** | No hay `LocalizationTable`; todos los textos están en español y muchos se montan con `string.format`, lo que la traducción automática de Roblox captura mal | Alta para tráfico internacional; baja para España/Latam |
| **Sin analíticas propias** | No hay eventos de embudo (`AnalyticsService`) en el código: no sabremos en qué minuto se va la gente | Alta: sin esto no se puede optimizar ni decidir publicidad |
| **Poco juego compartido** | Cada jugador cava en su parcela. Jugar con amigos («co-play») es una señal de Roblox para recomendar, y aquí apenas se premia | Media |
| **Sin invitaciones** | No hay botón de invitar a amigos (`SocialService:PromptGameInvite`) ni lectura de `LaunchData` | Media |
| **Contenido finito** | El jugador simulado llega al Núcleo en unos 103 min y a la perforadora abisal en unos 179 min. La retención a 28 días (señal principal de Roblox desde junio de 2026) puede sufrir si no hay motivos para volver | Media-alta a medio plazo |
| **Guardado y multijugador sin probar con el sitio publicado** | `docs/LAUNCH_REPORT.md`: NEEDS FINAL TESTING | **Bloqueante** |
| **Móvil sin probar en dispositivo** | Revisado en el código, no en un teléfono | Alta: gran parte del tráfico de Roblox es móvil |
| **Primeros 60 segundos** | Bien: primera venta a ~0,9 min y primera herramienta a ~3,2 min en la simulación | Bajo (confirmar con datos reales) |

## 1.9 Condición del mercado que lo cambia todo: el acceso por edades (2026)

Desde el **16 de junio de 2026**, Roblox separa a los usuarios en **Roblox Kids (5–8)**, **Roblox Select
(9–15)** y cuentas estándar (16+). Un juego nuevo **solo puede jugarlo gente de 16+ con la edad
comprobada** hasta que pasa una evaluación. Para llegar a los menores de 16 hace falta, según la
documentación oficial de Kids and Select:

- cuenta verificada (estimación facial si eres menor de 18, documento de identidad si eres mayor) y
  verificación en dos pasos;
- el cuestionario de madurez completo, con calificación Mínima, Leve o Moderada;
- dos meses seguidos de Roblox Plus o Premium, o una tarifa única reembolsable (la documentación no da la
  cantidad; un anuncio de Roblox en el DevForum habla de 1.000 Robux);
- **250 partidas únicas de «jugadores muy comprometidos» en 60 días**. Cuentan los jugadores con cierta
  antigüedad de cuenta, tiempo de juego en tu experiencia y alguna compra en cualquier parte de Roblox en
  los últimos 60 días. No hace falta que gasten en tu juego.

Consecuencias para la estrategia:

- **El primer público es 16+.** Eso encaja con tu cuenta de Instagram, cuyos seguidores probablemente
  sean mayoritariamente mayores de 16. Hay que comprobarlo (ver [06_INSTAGRAM.md](06_INSTAGRAM.md)).
- **El primer objetivo medible es llegar a 250 jugadores muy comprometidos**, no conseguir visitas.
  Se sigue en Creator Hub → tu juego → **Audience Reach**.
- El estilo visual es infantil y amable. Hay que comunicar también el misterio y el reto, para que no
  parezca «un juego de niños» al público 16+ que entra primero.

## 1.10 Mejoras recomendadas antes de promocionar (por prioridad)

| Prioridad | Mejora | Por qué | Esfuerzo |
|---|---|---|---|
| **Bloqueante** | Probar guardado real, dos jugadores y móvil (pasos de `docs/LAUNCH_REPORT.md`) | No se promociona un juego que puede perder partidas | Lo haces tú, con mi ayuda |
| **Bloqueante** | Eventos de embudo y eventos propios con `AnalyticsService` (primer golpe, primera venta, primera herramienta, Minas, cada zona, cada nota, final) | Sin ellos no sabremos dónde abandonan ni si un anuncio trae jugadores buenos | 1 sesión mía |
| Alta | Botón «Invitar amigos» y lectura de `LaunchData` (para enlaces con regalo de bienvenida) | Jugar con amigos es una señal de recomendación; permite medir Instagram | 1 sesión mía |
| Alta | Vídeo de juego subido en la pestaña **Videos** de la página | Roblox lo reproduce automáticamente en Recomendados; según Roblox, en sus pruebas los juegos con vídeo tuvieron hasta un 39 % más de tiempo de juego | Lo grabas tú (guion en 03) |
| Alta | 3–5 miniaturas limpias a 1920×1080 sin interfaz | Personalización de miniaturas (necesita 2 o más activas) | Tú, con la guía de 03 |
| Media | Pasada de inglés (tabla de localización o textos sin `string.format` frágiles) | Abre el mercado internacional | 2–3 sesiones mías |
| Media | Un motivo para volver cada día o semana (p. ej. un mineral del día en el mercado o una veta rara semanal) **sin rachas que castiguen** | Retención D7 y D28 | 1–2 sesiones mías |
| Media | Pequeña recompensa por cavar junto a un amigo (p. ej. +10 % de minerales si hay un amigo en el servidor) | Co-play | 1 sesión mía |
| Baja | Mejor iluminación de las Cuevas de Cristal para capturas | Miniaturas | 1 sesión mía |

**Conclusión de la parte 1:** el juego **todavía no está listo para campañas de pago**. Está listo para
una **beta pública controlada** (modo beta de Roblox, ver el plan operativo) en cuanto se pasen las tres
pruebas bloqueantes y se añadan las analíticas. Promocionar antes sería pagar por jugadores sin poder medir
qué hacen.
