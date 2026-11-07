# 10. Monetización responsable

## 10.1 Situación actual

El juego **no tiene ninguna compra** (no se usa `MarketplaceService` en el código) y la monetización está
desactivada por decisión tuya. Es una base sana para lanzar:

- Para llegar a menores de 16, **los jugadores muy comprometidos no necesitan gastar en tu juego**: la
  documentación dice que basta con que hayan comprado algo en cualquier parte de Roblox en los últimos
  60 días y que el juego gratuito cuenta.
- El **gasto** sí es una de las señales que Roblox menciona para recomendar. No es imprescindible, pero
  a medio plazo ayuda.

## 10.2 Opciones oficiales (2026)

| Opción | Qué es | ¿Encaja? |
|---|---|---|
| **Pases de juego** | Compra única y permanente | Sí, para cosas permanentes y no esenciales |
| **Productos de desarrollador** | Compras repetibles | Con cuidado: solo para cosas que no rompan la economía |
| **Suscripciones** | Pago recurrente con ventajas, en moneda local | No al principio: exige contenido continuo que lo justifique |
| **Servidores privados** | Se venden o se regalan desde la página | **Sí**, ideal para jugar con amigos |
| **Optimización de precios** | Herramienta de Roblox que prueba precios | Cuando haya productos y tráfico |
| **Anuncios recompensados** | Formato nativo de Roblox (desde el 4-may-2026 es el único permitido) | **No**: no se permiten para menores de 13 y rompen el tono |
| **Objetos aleatorios de pago** (cajas sorpresa) | Restringidos en algunos países; obligan a usar `PolicyService` | **No**: riesgo legal y ético con menores |
| Ventaja Premium | Roblox paga a los juegos por el tiempo de juego de los suscriptores Premium | Automática; también se puede dar una pequeña ventaja estética a Premium |

Roblox se queda con un 30 % de los Robux de cada venta (comisión del mercado, según su documentación).

## 10.3 Recomendación

**Lanzamiento: sin compras**, salvo **servidores privados** (gratis o baratos) para jugar con amigos.
Motivos: medir la retención limpia, evitar la imagen de «otro juego que te pide Robux» y no frenar la
llegada a los 250 jugadores muy comprometidos.

**A partir de 4–6 semanas, si D1 y D7 están en la referencia**, añadir compras **transparentes, no
aleatorias y que no aceleren el misterio**:

| Prioridad | Producto | Tipo | Precio orientativo | Por qué no es «pay-to-win» |
|---|---|---|---|---|
| 1 | **Pack de apoyo**: aspecto dorado de la pala + placa «Fundador» en la vitrina | Pase | Bajo | Puramente estético; el comprador apoya al creador |
| 2 | **Aspectos de herramienta** (pala de cristal, taladro volcánico) | Pase | Bajo | No cambian la potencia |
| 3 | **Estela de luz / linterna de color** | Pase | Muy bajo | Estético |
| 4 | **Decoración de la casa y del jardín** (veleta, buzón, flores especiales) | Pase | Bajo | La parcela es tuya; personalizar es el deseo natural |
| 5 | **Mochila más grande** | Pase | Medio | Comodidad: menos viajes. **Límite:** como mucho una mejora pequeña, y que se pueda conseguir jugando |
| — | **NO**: comprar monedas, saltar zonas, herramientas que no se pueden conseguir jugando, cajas sorpresa, ofertas con temporizador, «solo hoy» | — | — | — |

**Precios:** pon precios bajos al principio y usa la **optimización de precios** de Roblox cuando haya
tráfico. No te doy cifras de ingresos: no hay datos fiables comparables.

## 10.4 Requisitos y riesgos con menores

- Desde el 4-may-2026, Roblox **no permite anuncios recompensados para menores de 13** ni anunciar ciertas
  categorías (comida, cosmética, farmacia, finanzas) a menores de 13.
- **Objetos aleatorios de pago:** obligatorio consultar `PolicyService` para cada usuario. Mejor no hacerlos.
- Describe cada compra con claridad en su ventana: qué da exactamente y que es permanente.
- Nada de presión: ni contadores, ni «tus amigos ya lo tienen», ni recordatorios repetidos.
- **Pruebas:** como con el resto de cambios, nada de compras de prueba ni monedas gratis en producción.

## 10.5 Qué implementar antes del lanzamiento y qué después

| Antes | Después (con datos) |
|---|---|
| Activar servidores privados (gratis o baratos) | Pack de apoyo y aspectos |
| Nada más | Decoración de la parcela |
| | Revisar con la optimización de precios |
| | Suscripción solo si hay actualizaciones mensuales sostenidas |
