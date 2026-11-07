# 9. Cómo recomienda Roblox los juegos, analíticas y experimentos

## 9.1 Lo que dice Roblox oficialmente (2025–2026)

**[OFICIAL]** = newsroom de Roblox, Creator Hub o anuncios de personal de Roblox en el DevForum.
**[COMUNIDAD]** = blogs o comentarios de desarrolladores.

| Hecho | Fuente |
|---|---|
| *Recomendados para ti* coloca los juegos según métricas objetivas y las preferencias de cada jugador | [OFICIAL] Newsroom, 15-jun-2026 |
| Desde junio de 2026 el algoritmo mira **28 días** en vez de 7, y mide directamente la retención a largo plazo: señales de retención del **día 1, días 2–7 y días 8–28** | [OFICIAL] Newsroom, 15-jun-2026 |
| La antigua «qualified play-through rate» se separó en señales de **comportamiento de entrada, calidad de sesión y gasto** | [OFICIAL] Newsroom, 15-jun-2026 |
| Volver, **traer amigos (jugar juntos)** y gastar se citan como prueba de una experiencia valiosa | [OFICIAL] Newsroom, 15-jun-2026 |
| Roblox publicará la lista de señales y su importancia relativa en el panel de Analytics | [OFICIAL] Newsroom, 15-jun-2026 |
| Señal nueva **Deep play through rate**: interés sostenido y participación activa (marzo de 2026) | [OFICIAL] DevForum «How we are improving Home» |
| Señal **sesiones de juego cualificadas por usuario en 7 días**, visible en Analytics → Adquisición → Home recommendations (26-mar-2026) | [OFICIAL] DevForum |
| Los rechazos «No me interesa» se integran en el descubrimiento | [OFICIAL] DevForum |
| **Vídeos de juego**: se reproducen solos en Recomendados desde el 29-jul-2026. No cambian la posición, pero en las pruebas de Roblox los juegos con vídeo tuvieron hasta +39 % de tiempo de juego | [OFICIAL] DevForum |
| **Standout Games**: categoría de Inicio elegida por el equipo de curación para juegos novedosos; **se puede nominar el juego** con un formulario | [OFICIAL] DevForum |
| Anuncios: mezclados dentro de Recomendados; los usuarios que llegan por anuncios **no deberían afectar al ranking orgánico** | [OFICIAL] DevForum + documentación de Ads Manager |
| Tras un anuncio o una promoción, las impresiones en Recomendados pueden bajar: quien ya jugó pasa a la fila «Continuar» | [OFICIAL] DevForum (FAQ) |
| La tasa de rebote en la primera partida es una de las señales «más importantes» y negativa | [COMUNIDAD] blogs que resumen el cambio de junio; **no aparece en el texto del newsroom que leí** |
| Los beneficios de recomendación se limitan a los primeros 60 min diarios por usuario | [COMUNIDAD] sin fuente oficial: **no lo uses** |

**No existe una fórmula secreta publicada.** Lo que Roblox premia, en sus propias palabras: que la gente
**entre, se quede, vuelva durante semanas, traiga amigos y, si quiere, gaste**.

## 9.2 De cada señal a una acción en este juego

| Señal | Qué hacemos en el juego | Qué hacemos en la página o el marketing |
|---|---|---|
| Entrada (impresión → partida) | — | Icono A, 4 miniaturas en personalización, vídeo de juego, descripción con premisa |
| Rebote en la primera partida | Primer golpe en segundos (ya está); primera venta antes de 1 min (ya está, 0,9 min simulado); confirmarlo con el embudo | Imágenes fieles: nada de prometer lo que no hay |
| Calidad de sesión / juego profundo | El objetivo de llegar a las Minas en unos 10 min; zonas nuevas | Duración en la descripción (fija expectativas) |
| Retención D1 | Motivo para mañana: la nota siguiente, la próxima herramienta visible en el garaje, las estaciones instaladas | Stories del día siguiente: «¿A cuántos metros llegaste ayer?» |
| Retención D2–7 y D8–28 | **Lo más débil hoy**: contenido finito (~3 h). Añadir algo que cambie cada semana (veta semanal, fósil rotativo, récord semanal en la vitrina) y actualizaciones cada 2–3 semanas | Eventos de Roblox con «Notifícame»; grupo de Roblox |
| Jugar con amigos | **Botón de invitar** + pequeña ventaja por cavar con un amigo en el servidor | Reels para etiquetar amigos |
| Gasto | No hay compras (ver [10](10_MONETIZACION.md)) | — |
| Novedad | — | **Nominar el juego a Standout Games** tras el lanzamiento |

## 9.3 Qué datos existen realmente y dónde se miran

| Quiero medir | ¿Existe? | Dónde |
|---|---|---|
| Impresiones en Inicio y tasa de entrada | Sí | Creator Hub → Analytics → **Acquisition** (fuentes y conversión de las recomendaciones) |
| Visitas desde mis enlaces | Sí | **Share Links** (*Link Visits*) + Acquisition |
| Nuevos jugadores, usuarios activos diarios | Sí | Analytics Home / Overview |
| Fuente de adquisición (Inicio, búsqueda, anuncios, externa…) | Sí | Acquisition |
| Duración media de sesión | Sí | **Engagement** |
| Retención D1, D7 y D30 | Sí | **Retention** |
| Comparación con juegos parecidos | Sí, **con 100 o más usuarios activos diarios** | Overview → *Benchmark scorecards* |
| Progreso dentro del juego (zonas, ventas, compras) | **Solo si lo programamos** | *Funnel events* y *custom events* de `AnalyticsService` (hoy no están en el código) |
| Dónde abandonan | Solo con eventos de embudo | Funnels |
| Compras e ingresos | Sí, si hay productos | **Monetization** |
| Coste por jugador de anuncios | Sí | **Ads Manager** (CPP, Playtime) |
| Rendimiento de cada miniatura | Sí, con 2–5 activas | *Thumbnail Performance* |
| Jugadores muy comprometidos (para menores de 16) | Sí | **Audience Reach** |
| Opiniones | Con la Player Feedback API | *Feedback* (mencionado en el anuncio de Experience Betas) |
| Tráfico de Instagram | Indirecto | Share Link `ig_*` + Acquisition (fuente externa) |

## 9.4 Eventos que hay que añadir al juego antes de promocionar

**Embudo de primera partida** (onboarding funnel, en orden):

1. Entra en la parcela
2. Lee la nota de la casa
3. Primer golpe
4. Primer mineral
5. Primera venta
6. Compra la pala reforzada
7. Llega a 25 m
8. Llega a las Minas (50 m)
9. Instala la primera estación

**Eventos propios:** zona alcanzada (con su número), herramienta comprada (con su nivel), nota leída, hazaña
conseguida, llegada a El fondo, final completado, uso de cuerda o gancho, ajustes de música y calidad
(para saber cuánta gente baja la calidad).

**Por qué es imprescindible:** el día del lanzamiento vas a querer saber si la gente se va antes de la
primera venta (problema de inicio) o después de las Minas (problema de ritmo). Sin esto, toda decisión
sobre anuncios es a ciegas. Lo puedo programar yo en una sesión, cuando me lo pidas.

## 9.5 Panel de métricas recomendado (revisión diaria las 2 primeras semanas, luego semanal)

| Métrica | Fuente | Primer objetivo orientativo (a confirmar con *Benchmark scorecards*) |
|---|---|---|
| Nuevos jugadores al día por fuente | Acquisition | Que Instagram, TikTok y Shorts aparezcan como fuente |
| Conversión impresión → partida en Recomendados | Acquisition | Comparar con juegos parecidos |
| % de nuevos que hacen la primera venta | Embudo | La gran mayoría: es en el primer minuto |
| % que llega a las Minas | Embudo | La métrica de «le ha enganchado» |
| Sesión media | Engagement | Con margen sobre 10 min (llegar a las Minas) |
| **D1** | Retention | Por encima de la referencia de juegos parecidos |
| D7 / D30 | Retention | Que no caigan en picado respecto a D1 |
| Jugadores muy comprometidos | Audience Reach | 250 en 60 días |
| CPP y tiempo por partida pagada | Ads Manager | Comparar entre imágenes y mercados |
| Visitas por enlace | Share Links | Comparar canales |

> No doy porcentajes «buenos» universales de D1 o D7: dependen del género y Roblox ofrece la comparación
> real en *Benchmark scorecards* a partir de 100 usuarios activos diarios. Úsala en vez de cifras de blogs.

## 9.6 Experimentos

| Qué | Cómo | Duración mínima | Métrica |
|---|---|---|---|
| Miniaturas | Personalización con 2–5 activas | Hasta que la tabla *Thumbnail Performance* tenga miles de impresiones por miniatura | Partidas por impresión, tiempo de juego, tasa de victorias |
| Icono | Cambio secuencial (7 + 7 días) o imágenes de anuncio | 14 días | Conversión de Recomendados |
| Descripción | Cambio secuencial | 14 días | Clic → partida en anuncios; conversión en página |
| Anuncios | Varias imágenes en una campaña Plays | 3–5 días y al menos unos cientos de clics por imagen | CTR, tiempo por partida |
| Vídeos de redes | Formato contra formato | 3 vídeos por formato | Visitas por enlace |
| Inicio del juego | Un cambio por versión (p. ej. flecha al carro tras el primer mineral) | 1 semana por versión con tráfico parecido | % primera venta, % Minas, D1 |
| Economía | Un precio cada vez (p. ej. pala de acero 500 → 400) | 1–2 semanas | % que la compra y tiempo hasta las Minas |

**Cómo no engañarse con muestras pequeñas:**

1. **No decidas con menos de ~100 jugadores por variante** en cambios de juego, ni con menos de unos cientos
   de clics por imagen en anuncios. Con menos, la suerte manda.
2. **Un cambio cada vez.** Si cambias el icono y el inicio la misma semana, no sabrás qué funcionó.
3. **Compara días equivalentes** (fin de semana contra fin de semana; los festivos escolares cambian todo).
4. **Diferencias pequeñas no cuentan:** con poco tráfico, solo cuentan las grandes y repetidas.
5. **Apunta la hipótesis antes** de mirar los datos («creo que B tendrá más clics porque…»).

## 9.7 Reglas de decisión: ¿anunciar más o mejorar el juego?

```
SI la conversión de página es baja (muchas impresiones, pocas partidas)
   → mejorar icono, miniaturas y vídeo. No subir presupuesto.
SI entran pero no llegan a la primera venta
   → mejorar el primer minuto. Parar anuncios.
SI llegan a las Minas pero el D1 está por debajo de la referencia
   → motivos para volver (notas, objetivos visibles, novedades). Parar o mantener mínimo.
SI el D1 está en la referencia o por encima y el tiempo por partida pagada se parece al orgánico
   → escalar anuncios poco a poco y pasar al objetivo Engagement.
SI el D7 y el D30 caen mucho respecto a D1
   → contenido recurrente y actualizaciones antes de escalar.
```
