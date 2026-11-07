# 5. Roblox Ads Manager: guía completa y presupuestos

Fuente principal: documentación oficial de Ads Manager en Creator Hub (consultada el 7-nov-2026) y
anuncios oficiales del DevForum de 2026. **Si algo de la interfaz no coincide con esto, manda lo que veas
en pantalla.** Marco con ⚠️ lo que no he podido verificar en una fuente oficial.

## 5.1 Lo esencial antes de gastar un euro

1. **La publicidad no mejora tu posición orgánica.** La documentación dice que los anuncios no cambian el
   ranking de *Recomendados para ti*, y el DevForum (marzo de 2026) añade que los usuarios conseguidos con
   anuncios no deberían afectar al ranking orgánico. Pagar sirve para **conseguir jugadores y datos**,
   no para «activar el algoritmo».
2. **Un juego nuevo solo llega a usuarios 16+ con la edad comprobada** hasta que alcanza **250 jugadores
   muy comprometidos** en 60 días (ver [01](01_ANALISIS_DEL_JUEGO.md), apartado 1.9). Los anuncios a menores
   de 16 no sirven hasta entonces.
3. **El objetivo Engagement (beta desde el 16-jun-2026)** existe precisamente para eso: busca jugadores
   cuyas sesiones cuentan para el umbral de jugadores muy comprometidos. Según Roblox, solo está disponible
   para juegos que aún no están en Kids and Select, **cuesta más por partida** que el objetivo Plays,
   **no se pausa solo** al llegar al umbral (hay que vigilarlo) y conviene darle **3–5 días** antes de
   juzgarlo.
4. **No anuncies hasta tener analíticas en el juego**: sin eventos de embudo no sabrás si los jugadores
   pagados llegan a las Minas o se van en el primer minuto.

## 5.2 Requisitos y configuración de la cuenta

| Requisito | Detalle oficial |
|---|---|
| Edad y cuenta | Cuenta de Roblox de **13+** con **correo verificado** |
| Pago con tarjeta | Solo **18+**. Retención temporal de 1 $ que se devuelve en 7 días hábiles. **La primera vez que uses tarjeta se cobran 5 $** al enviar la campaña, que se descuentan de la primera factura |
| Pago con créditos publicitarios | 13+. Se compran con Robux; **mínimo 1 crédito**; la conversión es **permanente e irreversible** y los créditos solo sirven para anuncios. Lo que no gastes vuelve a tu cuenta (en créditos) al terminar la campaña |
| Equivalencia crédito-Robux | ⚠️ No está en la documentación. Webs de terceros hablan de 263–285 Robux por crédito. **La vista previa de conversión de Ads Manager te muestra la cifra exacta** |
| Método de pago | **No se puede cambiar después de publicar la campaña** |
| Juegos de grupo | Se gestionan desde el selector de grupo de Creator Hub |

**Recomendación:** paga **con tarjeta** (en dólares, con factura a final de mes o al llegar al umbral) en
vez de convertir Robux. La conversión es irreversible y los Robux te pueden servir para la tarifa de
publicación de Kids and Select.

## 5.3 Tutorial paso a paso

> Los nombres de botones están tal cual aparecen en la documentación oficial (en inglés). Si tu Creator Hub
> está en español pueden aparecer traducidos.

**Preparación (una vez)**

1. Abre **https://create.roblox.com** e inicia sesión con la cuenta dueña del juego.
2. Ve al portal de **Ads Manager** (en el menú de Creator Hub o en https://ads.roblox.com ⚠️; la
   documentación habla del «Ads Manager portal» sin dar la URL).
3. Pulsa **Start creating** → **Create campaign**. Elige la zona horaria (**Europe/Madrid**), revisa las
   condiciones de publicidad de Roblox y guarda.
4. **Billing & payments → Payment settings → Add Payment Method** → tarjeta.
5. Sube las imágenes al **asset library** con un día de margen: la moderación de imágenes tarda **hasta
   48 h** y la de cada anuncio unas **24 h**.

**Crear la campaña**

6. **Manage Ads → Create Campaign** → elige **The Hole Never Ends** como el juego al que irán los jugadores.
7. **Objetivo:**
   - Primera campaña de prueba → **Plays**: busca a quien tiene más probabilidad de empezar una partida.
     Es el más barato y el adecuado para probar creatividades.
   - Cuando el juego retenga bien (ver 5.6) → **Engagement** (beta) para llegar a los 250 jugadores muy
     comprometidos.
   - **No uses Earnings**: el juego no tiene compras.
8. **Audiencia:** **New Players** (no han jugado nunca o hace más de 180 días). *Recent* y *Lapsed* exigen
   10.000 y 20.000 jugadores, así que de momento no están disponibles.
9. **Advanced Targeting** (opcional): ubicación, edad, género, género de juego y dispositivo. Ver 5.5.
10. **Puja:** automática (Roblox la calcula a partir del presupuesto y la duración). No hay puja manual en
    la documentación actual.
11. **Presupuesto:** **Daily** (máximo al día) para pruebas, o **Lifetime** (máximo total). Usa Daily en las
    pruebas para poder cortar día a día.
12. **Calendario:** fecha, hora de inicio y duración. Se puede cancelar hasta **6 h antes** del inicio.
13. **Creatividades:** hasta **10 imágenes** por campaña, que se reparten **a partes iguales**. Se muestran en
    **16:9** (otras proporciones se reescalan). Puedes usar miniaturas existentes, subir nuevas o usar
    **AI generate** (3 variantes a partir de una descripción). **No recomiendo la generación con IA:** debe
    parecerse al juego real.
14. Revisa y envía. Moderación: unas 24 h por anuncio.

**Dónde aparece:** como mosaico patrocinado en **Inicio** (mezclado dentro de *Recomendados* según el
DevForum de marzo de 2026) y en los **resultados de búsqueda**.

**Durante la campaña (métricas de Ads Manager):** *Spent*, *Impressions*, *Clicks* (Inicio y Búsqueda),
*Plays*, *CPP* (coste por partida), *Playtime* y *Earnings*. Vistas: All Users, New Users, Recent Users y
Resurrected Users (7D y 30D).

- Impresiones y clics: **en tiempo real**.
- Partidas y ganancias: atribución de **hasta 30 días**; los datos pueden tardar **48 h**.
- Tráfico fraudulento: Roblox lo revisa **14 días** después del final y devuelve el dinero el **día 16**.

**Por eso no juzgues una campaña el primer día:** espera al menos 48 h para las partidas.

## 5.4 Las métricas que importan y cómo calcularlas

| Métrica | Cálculo | Dónde | Para qué |
|---|---|---|---|
| CTR | Clics ÷ Impresiones | Ads Manager | Qué imagen atrae |
| Clic → partida | Partidas ÷ Clics | Ads Manager | Si la página convence (icono, miniaturas, descripción) |
| **CPP** | Gasto ÷ Partidas | Ads Manager | Coste de cada partida |
| **Tiempo por partida pagada** | Playtime ÷ Partidas | Ads Manager | **La más importante**: si los jugadores pagados juegan o se van |
| Coste por jugador comprometido | Gasto ÷ jugadores pagados que llegan a las Minas (evento del embudo) | Ads Manager + Analytics (embudo filtrado por fecha) | La decisión de escalar |
| Progreso hacia 250 | Jugadores muy comprometidos | Creator Hub → **Audience Reach** | Llegar a menores de 16 |

## 5.5 Segmentación recomendada

| Prueba | Ubicación | Edad | Dispositivo | Motivo |
|---|---|---|---|---|
| 1 (principal) | España | 16+ (o la franja más baja permitida mientras el juego esté en 16+) | Todos | Coincide con el idioma y con Instagram |
| 2 | España + México + Argentina + Colombia + Chile | igual | Todos | Más volumen hispanohablante; compara su CPP con el de España |
| 3 | Todos los países | igual | Todos | Solo cuando haya inglés en el juego |
| 4 | España | igual | Solo móvil frente a solo ordenador | Si el embudo muestra diferencias por dispositivo |

⚠️ La documentación lista los filtros (ubicación, edad, género, género de juego, dispositivo) pero no sus
valores exactos. Comprueba en la interfaz qué franjas de edad ofrece.

**Género:** no segmentes por género, no hay motivo para el juego. **Género de juego:** prueba
«Aventura/Exploración» y «Simulación» en campañas separadas solo si tienes presupuesto para comparar.

## 5.6 Estrategia de campañas

**Fase 0: no anunciar** hasta que:
- guardado, dos jugadores y móvil estén probados;
- las analíticas de embudo funcionen;
- haya **3 o más miniaturas limpias** y el vídeo de juego subido.

**Fase 1: validar creatividades** (objetivo Plays, España, New Players):
- 4–6 imágenes distintas en la misma campaña (Roblox las reparte a partes iguales).
- Presupuesto diario bajo, **3–5 días**.
- Mira el CTR por imagen y el tiempo por partida de la campaña. Las imágenes con CTR alto pero que traen
  jugadores que se van enseguida son **imágenes engañosas**: quítalas.

**Fase 2: validar el juego con jugadores pagados**:
- Con las 2–3 mejores imágenes. Mira el embudo: % que vende la primera vez, % que compra la pala reforzada,
  % que llega a las Minas y retención del día 1.
- Si el D1 de los jugadores nuevos está muy por debajo de la referencia de Analytics (ver
  [09](09_DESCUBRIMIENTO_ANALITICAS.md)), **para y mejora el juego**.

**Fase 3: objetivo Engagement** (beta) hasta los 250 jugadores muy comprometidos:
- Solo si la fase 2 sale bien. Vigila *Audience Reach* **a diario** y **pausa a mano** al llegar.

**Fase 4: escalar** (solo con un juego que retiene):
- Sube el presupuesto un 20–30 % cada 3–4 días mientras el coste por jugador comprometido no empeore más de
  un 20–30 %. Subir de golpe suele llevar los anuncios a públicos peores (práctica habitual en publicidad,
  no es un dato de Roblox).

**Cómo no gastar en jugadores que se van al instante:**
1. Imágenes **fieles** al juego: el abandono en la primera partida es una señal negativa importante en las
   recomendaciones desde junio de 2026.
2. Segmentar por país e idioma (el juego está en español).
3. Que el primer minuto sea bueno: primer golpe en segundos y primera venta antes de 1 minuto.
4. Cortar cada imagen cuyo **tiempo por partida** sea claramente peor que el de las demás.

## 5.7 Simulación de presupuestos

**Lo que no sé y nadie publica:** el coste por partida (CPP) real. Roblox no publica precios de referencia
y no he encontrado datos fiables y comparables de juegos parecidos en España. Por eso **no doy cifras de
jugadores esperados**: la primera campaña sirve justamente para medir tu CPP. Con él, todo lo demás se
calcula así:

```
Partidas esperadas = Presupuesto ÷ CPP medido
Jugadores comprometidos esperados = Partidas × (% que llega a las Minas, medido en el embudo)
Días hasta 250 jugadores muy comprometidos ≈ (250 − actuales) ÷ (nuevos jugadores muy comprometidos al día, en Audience Reach)
```

**Mínimos reales:**
- Oficial: comprar al menos 1 crédito (si pagas con Robux) y 5 $ en el primer cargo con tarjeta.
- ⚠️ Usuarios del DevForum (julio de 2026, sin respuesta oficial): **5 créditos al día durante 2 días como
  mínimo** (10 créditos). Compruébalo en la interfaz; si es así, **25 € dan para unos pocos días de prueba**.
- Importes en euros aproximados: Roblox cobra en dólares.

| Presupuesto | ¿Viable? | Reparto | Días | Imágenes | Segmentación | Objetivo de la prueba | Éxito si… | Parar si… | Siguiente paso |
|---|---|---|---|---|---|---|---|---|---|
| **0 €** | Sí | 100 % orgánico: Instagram, TikTok, Shorts, creadores, grupo de Roblox | 30 | — | — | Llegar a 250 jugadores muy comprometidos con tu audiencia | 250 en ≤60 días; D1 sobre la referencia | Pocas visitas desde los enlaces de Instagram tras 2 semanas | Ver escenario D en el plan operativo |
| **25 €** | Justo | 100 % en una campaña Plays | 3 (un tope diario que dé 3 días) | 4 | España, 16+, New Players | **Medir el CPP y qué imagen gana** | Tienes CPP, CTR por imagen y tiempo por partida | Si a las 48 h no hay partidas (revisa moderación y segmentación) | Decide si el CPP es asumible para 50–100 € |
| **50 €** | Sí | 25 € creatividades (Plays) + 25 € validación con las 2 mejores | 3 + 4 | 5 → 2 | España | CPP + embudo de jugadores pagados | Tiempo por partida pagada ≥70 % del orgánico | Si menos del 20 % de los pagados llega a la primera venta | Mejorar el inicio o pasar a 100 € |
| **100 €** | Sí | 25 € creatividades + 35 € España + 40 € Latam (comparar) | 3 + 5 + 5 | 5 → 3 | España contra España+Latam | Mejor mercado y CPP | Un mercado con coste por jugador comprometido claramente menor | Si ningún mercado retiene | Concentrar en el mejor |
| **250 €** | Sí | 25 € creatividades + 75 € Plays en el mejor mercado + 150 € Engagement (beta) | 3 + 7 + 7–10 | 6 → 3 | Mejor mercado | Llegar a 250 jugadores muy comprometidos | Audience Reach sube cada día de Engagement | Si tras 5 días de Engagement no se mueve el contador | Revisar la definición en Audience Reach; ajustar |
| **500 €** | Sí, pero solo con un juego validado | 50 € pruebas + 150 € Plays + 200 € Engagement + 100 € reserva para la campaña de una actualización | 21–30 | 8–10, renovadas cada 2 semanas | Mejor mercado + prueba internacional si hay inglés | Umbral de 250 + crecimiento | Coste por jugador comprometido estable al subir el presupuesto | Si el D1 cae al escalar | Mantener lo orgánico y repetir con cada actualización |

**Recomendación de presupuesto:** **0 € al lanzar la beta**, luego **50 €** para medir el CPP y validar las
creatividades, y **250 €** solo si los datos de los 50 € son buenos. Los 500 € no tienen sentido hasta que el
juego demuestre que retiene.

## 5.8 Textos e imágenes para anuncios

Los anuncios de Roblox son **solo imágenes 16:9** (el nombre del juego lo pone Roblox). Por eso el texto
va dentro de la imagen y debe seguir las normas: describir el juego, sin promesas ni urgencia.

| Imagen | Texto en imagen ES | EN |
|---|---|---|
| Corte del agujero (miniatura 1) | ¿HASTA DÓNDE? | HOW DEEP? |
| Hallazgo legendario (2) | (ninguno) | (none) |
| Antes y después de herramienta (3) | P1 → P85 | P1 → P85 |
| Tu casa (4) | TU CASA. TU AGUJERO. | YOUR HOUSE. YOUR HOLE. |
| Abismo (5) | 1000 m | 1000 m |
| Minas (6) | MINAS OLVIDADAS | FORGOTTEN MINES |

## 5.9 Normas y problemas frecuentes

- Los anuncios cumplen las **normas de publicidad de Roblox** y pasan moderación (unas 24 h).
- Desde el **4-may-2026** hay una política nueva de **integraciones publicitarias** (marcas pagadas dentro
  de un juego). **No te afecta** mientras no metas marcas pagadas en el juego.
- Las cuentas con fraude publicitario pueden suspenderse: **no compres tráfico fuera de Ads Manager** (bots,
  «visitas garantizadas»).
- Si no pagas una factura de tarjeta, Roblox puede suspender la campaña o la cuenta.
- Problemas típicos: anuncio rechazado (revisa el texto de la imagen), 0 partidas el primer día (espera
  48 h de atribución), cambio del método de pago (imposible después de publicar).
